import { ApiError } from '../errors.js';
import { transaction, integer, text } from './transaction.js';
import { settle, levels, spend, scaledCost } from './economy.js';
import { progression } from './progression.js';
import { realmStage } from './realm.js';

export async function snapshot(db, profile, now) {
  const economy = await settle(db, profile, now);
  const buildings = await levels(db, profile.player_id, 'building');
  const research = await levels(db, profile.player_id, 'research');
  const resources = Object.fromEntries((await db.query('SELECT resource,amount FROM kingdom_resources WHERE player_id=$1', [profile.player_id])).rows.map(r => [r.resource, Number(r.amount)]));
  const tasks = (await db.query('SELECT id,kind,key,target_level,quantity,started_at,finishes_at FROM kingdom_tasks WHERE player_id=$1 AND completed_at IS NULL ORDER BY finishes_at', [profile.player_id])).rows;
  const units = (await db.query('SELECT * FROM kingdom_units WHERE player_id=$1 ORDER BY type', [profile.player_id])).rows.map(({ player_id, ...r }) => r);
  const catalog = (await db.query('SELECT kind,key,data FROM kingdom_catalog ORDER BY kind,key')).rows;
  const quotes = catalog.filter(c => c.kind !== 'unit').map(c => {
    const current = (c.kind === 'building' ? buildings : research)[c.key] ?? 0;
    return { kind: c.kind, key: c.key, current, next: current + 1, maxLevel: c.data.maxLevel, cost: scaledCost(c.data.baseCost, current + 1), durationSeconds: Math.ceil(c.data.seconds * Math.pow(1.6, current) / (1 + (research.construction ?? 0) * .03)) };
  });
  const progress = await progression(db, profile);
  const realm = await realmStage(db, profile, buildings, progress);
  return { serverTime: now.toISOString(), settlementId: profile.village_id, stage: realm.stage, realm, empire: { name: profile.empire_name, primaryColor: profile.primary_color, secondaryColor: profile.secondary_color, emblem: profile.emblem, bannerStyle: profile.banner_style }, progression: progress, resources, productionPerHour: economy.rates, storageCapacity: economy.capacity, buildings, research, units, armyCapacity: (buildings.barracks ?? 0) * Number((await db.query("SELECT value FROM kingdom_config WHERE key='army_capacity_per_barracks_level'")).rows[0].value), tasks, catalog, quotes };
}

export const getKingdom = (pool, identity) => transaction(pool, identity, 'snapshot', {}, snapshot, { replay: false });

export function enqueue(pool, identity, body, kind) {
  return transaction(pool, identity, kind, body, async (db, profile, now) => {
    await settle(db, profile, now);
    if ((await db.query('SELECT id FROM kingdom_tasks WHERE player_id=$1 AND kind=$2 AND completed_at IS NULL', [profile.player_id, kind])).rows.length) throw new ApiError(409, 'queue_busy');
    const catalogKind = kind === 'training' ? 'unit' : kind;
    const definition = (await db.query('SELECT data FROM kingdom_catalog WHERE kind=$1 AND key=$2', [catalogKind, typeof body.key === 'string' ? body.key : ''])).rows[0]?.data;
    if (!definition) throw new ApiError(400, 'unknown_catalog_entry');
    const buildings = await levels(db, profile.player_id, 'building');
    const research = await levels(db, profile.player_id, 'research');
    let target = 1, quantity = 1;
    if (kind === 'training') {
      quantity = integer(body.quantity, 1, 100);
      if ((buildings[definition.facility] ?? 0) < definition.requiredLevel) throw new ApiError(409, 'building_required');
      const alive = Number((await db.query('SELECT coalesce(sum(alive+wounded),0) AS n FROM kingdom_units WHERE player_id=$1', [profile.player_id])).rows[0].n);
      const capacity = buildings.barracks * Number((await db.query("SELECT value FROM kingdom_config WHERE key='army_capacity_per_barracks_level'")).rows[0].value);
      if (alive + quantity > Math.min(100000, capacity)) throw new ApiError(409, 'army_capacity');
    } else {
      target = (kind === 'building' ? buildings : research)[body.key] + 1;
      if (target > definition.maxLevel) throw new ApiError(409, 'maximum_level');
      if (kind === 'building') {
        if (body.key !== 'keep' && buildings.keep < target) throw new ApiError(409, 'keep_required');
        if (definition.prerequisite && buildings[definition.prerequisite] < 1) throw new ApiError(409, 'building_required');
        if (body.key === 'keep' && target > 3 && buildings.warehouse < Math.floor(target / 3)) throw new ApiError(409, 'warehouse_required');
      } else {
        if (buildings.academy < target) throw new ApiError(409, 'academy_required');
        if (definition.prerequisite && research[definition.prerequisite] < target) throw new ApiError(409, 'research_required');
      }
    }
    const cost = scaledCost(definition.baseCost ?? definition.cost, target, quantity);
    await spend(db, profile.player_id, cost);
    const seconds = Math.max(1, Math.ceil(definition.seconds * (kind === 'training' ? quantity : Math.pow(1.6, target - 1)) / (1 + research.construction * .03)));
    const finishes = new Date(now.getTime() + seconds * 1000);
    const task = (await db.query('INSERT INTO kingdom_tasks(player_id,kind,key,target_level,quantity,started_at,finishes_at,cost,xp) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING id', [profile.player_id, kind, body.key, target, quantity, now, finishes, cost, kind === 'training' ? quantity * 5 : definition.xp * target])).rows[0];
    return { taskId: task.id, kingdom: await snapshot(db, profile, now) };
  });
}

export function customize(pool, identity, body) {
  return transaction(pool, identity, 'empire', body, async (db, profile, now) => {
    const name = text(body.name, 2, 32);
    if (![body.primaryColor, body.secondaryColor].every(c => typeof c === 'string' && /^#[0-9a-f]{6}$/i.test(c))) throw new ApiError(400, 'invalid_color');
    if (!['lion', 'eagle', 'crown', 'stag', 'sun', 'wolf'].includes(body.emblem) || !['square', 'swallowtail', 'pennant'].includes(body.bannerStyle)) throw new ApiError(400, 'invalid_heraldry');
    await db.query('UPDATE kingdoms SET empire_name=$2,primary_color=$3,secondary_color=$4,emblem=$5,banner_style=$6 WHERE player_id=$1', [profile.player_id, name, body.primaryColor.toLowerCase(), body.secondaryColor.toLowerCase(), body.emblem, body.bannerStyle]);
    Object.assign(profile, { empire_name: name, primary_color: body.primaryColor.toLowerCase(), secondary_color: body.secondaryColor.toLowerCase(), emblem: body.emblem, banner_style: body.bannerStyle });
    return { kingdom: await snapshot(db, profile, now) };
  });
}
