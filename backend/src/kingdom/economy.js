import { ApiError } from '../errors.js';
import { grantXP } from './progression.js';
import { notify } from './wars.js';
import { capabilities } from './capabilities.js';

export const RESOURCES = ['food', 'wood', 'stone', 'iron', 'gold'];
export async function levels(db, playerId, kind) {
  const table = kind === 'research' ? 'kingdom_research' : 'kingdom_buildings';
  return Object.fromEntries((await db.query(`SELECT key,level FROM ${table} WHERE player_id=$1`, [playerId])).rows.map(r => [r.key, r.level]));
}
export function storageCapacity(level,base=5000) {
  return Math.min(1000000000000,base+Math.floor(5000*(Math.pow(1.45,level)-1)/.45));
}
export function production(buildings, research, territoryBonus = 0, clanBonus = 0) {
  const bonus = 100 + (research.economy ?? 0) * 5 + territoryBonus + clanBonus;
  return { food: Math.floor((buildings.farm ?? 0) * 80 * (bonus + (research.agriculture ?? 0) * 5) / 100), wood: Math.floor((buildings.lumber_mill ?? 0) * 60 * bonus / 100), stone: Math.floor((buildings.quarry ?? 0) * 50 * bonus / 100), iron: Math.floor((buildings.iron_mine ?? 0) * 30 * bonus / 100), gold: Math.floor(((buildings.market ?? 0) * 15 + (buildings.trading_post ?? 0) * 10) * bonus / 100) };
}
async function accrue(db, profile, until) {
  until = new Date(Math.max(until.getTime(), profile.settled_at.getTime()));
  const elapsed = until.getTime() - profile.settled_at.getTime();
  const buildings = await levels(db, profile.player_id, 'building');
  const research = await levels(db, profile.player_id, 'research');
  const territoryBonus = Math.min(30, Number((await db.query("SELECT count(*)::int AS n FROM strategic_tiles WHERE owner_player_id=$1 AND kind='resource'", [profile.player_id])).rows[0].n) * 3);
  const clanBonus = Math.min(10, Number((await db.query('SELECT c.level FROM clan_members m JOIN clans c ON c.id=m.clan_id WHERE m.player_id=$1', [profile.player_id])).rows[0]?.level ?? 0));
  const rates = production(buildings, research, territoryBonus, clanBonus);
  const base = Number((await db.query("SELECT value FROM kingdom_config WHERE key='resource_base_capacity'")).rows[0].value);
  const powers = await capabilities(db, profile.player_id);
  const capacity = powers.unlimitedResources ? 1000000000000 : storageCapacity(buildings.warehouse??0,base);
  const wallets = (await db.query('SELECT * FROM kingdom_resources WHERE player_id=$1 ORDER BY resource', [profile.player_id])).rows;
  for (const w of wallets) {
    const numerator = BigInt(Math.floor(elapsed)) * BigInt(rates[w.resource]) + BigInt(w.remainder);
    // Integer fractional carry makes repeated polling yield identical production.
    const amount = Math.min(capacity, Number(w.amount) + Number(numerator / 3600000n));
    const remainder = amount === capacity ? 0 : Number(numerator % 3600000n);
    await db.query('UPDATE kingdom_resources SET amount=$3,remainder=$4 WHERE player_id=$1 AND resource=$2', [profile.player_id, w.resource, amount, remainder]);
  }
  profile.settled_at = until;
  await db.query('UPDATE kingdoms SET settled_at=$2 WHERE player_id=$1', [profile.player_id, until]);
  return { rates, capacity, territoryBonus, clanBonus };
}

export async function settle(db, profile, now) {
  const due = (await db.query('SELECT * FROM kingdom_tasks WHERE player_id=$1 AND completed_at IS NULL AND finishes_at<=$2 ORDER BY finishes_at,id FOR UPDATE', [profile.player_id, now])).rows;
  for (const task of due) {
    await accrue(db, profile, task.finishes_at);
    if (task.kind === 'building' || task.kind === 'research') {
      const table = task.kind === 'building' ? 'kingdom_buildings' : 'kingdom_research';
      await db.query(`UPDATE ${table} SET level=$3 WHERE player_id=$1 AND key=$2`, [profile.player_id, task.key, task.target_level]);
    } else {
      await db.query('INSERT INTO kingdom_units(player_id,type,alive) VALUES($1,$2,$3) ON CONFLICT(player_id,type) DO UPDATE SET alive=kingdom_units.alive+excluded.alive', [profile.player_id, task.key, task.quantity]);
    }
    await db.query('UPDATE kingdom_tasks SET completed_at=$2 WHERE id=$1', [task.id, task.finishes_at]);
    await grantXP(db, profile, task.kind, task.id, task.xp, task.finishes_at);
    const name = (await db.query('SELECT data FROM kingdom_catalog WHERE kind=$1 AND key=$2', [task.kind === 'training' ? 'unit' : task.kind, task.key])).rows[0]?.data.name ?? 'Improvement';
    await notify(db, profile.player_id, 'task:' + task.id, task.kind, name + ' is ready', task.kind === 'training' ? task.quantity + ' soldiers have joined your forces.' : 'Your realm has completed a new improvement.', task.id);
  }
  const healing = (await db.query('SELECT * FROM kingdom_healing WHERE player_id=$1 AND completed_at IS NULL AND finishes_at<=$2 FOR UPDATE', [profile.player_id, now])).rows;
  for (const task of healing) {
    const updated = await db.query('UPDATE kingdom_units SET wounded=wounded-$3,alive=alive+$3 WHERE player_id=$1 AND type=$2 AND wounded>=$3 RETURNING alive', [profile.player_id, task.unit_type, task.quantity]);
    if (!updated.rows.length) throw new Error('Healing inventory integrity failure');
    await db.query('UPDATE kingdom_healing SET completed_at=$2 WHERE id=$1', [task.id, task.finishes_at]);
    await notify(db, profile.player_id, 'healing:' + task.id, 'healing', 'Soldiers have recovered', task.quantity + ' recovered soldiers are ready for duty.', task.id);
  }
  return accrue(db, profile, now);
}

export async function spend(db, playerId, cost) {
  for (const [key, value] of Object.entries(cost)) {
    if (!RESOURCES.includes(key) || !Number.isSafeInteger(value) || value < 0 || value > 1000000000000) throw new Error('Invalid server catalog cost');
  }
  const powers = await capabilities(db, playerId);
  if (powers.unlimitedResources) return;
  const wallets = Object.fromEntries((await db.query('SELECT resource,amount FROM kingdom_resources WHERE player_id=$1', [playerId])).rows.map(r => [r.resource, Number(r.amount)]));
  for (const [key, value] of Object.entries(cost)) {
    if (wallets[key] < value) throw new ApiError(409, 'insufficient_resources');
  }
  for (const [key, value] of Object.entries(cost)) await db.query('UPDATE kingdom_resources SET amount=amount-$3 WHERE player_id=$1 AND resource=$2', [playerId, key, value]);
}
export function scaledCost(base, level = 1, quantity = 1) {
  return Object.fromEntries(Object.entries(base).map(([key, amount]) => [key, Math.ceil(amount * Math.pow(1.45, level - 1)) * quantity]));
}
