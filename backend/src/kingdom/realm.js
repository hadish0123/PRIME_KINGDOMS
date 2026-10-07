import { createHash, randomUUID } from 'node:crypto';
import { ApiError } from '../errors.js';
import { transaction, integer, text } from './transaction.js';
import { levels, settle } from './economy.js';
import { grantXP, progression } from './progression.js';
import { territoryName } from './locations.js';
import { notify, settleWars, eligibleWar } from './wars.js';
import { campaignSnapshot, commanderAway, marchUnits } from './campaign_inventory.js';

const FORMATIONS = new Set(['balanced', 'line', 'wedge', 'shield', 'square', 'skirmish']);
const STANCES = new Set(['aggressive', 'balanced', 'defensive']);
const CATEGORY_RESEARCH = { infantry: 'infantry', ranged: 'archery', cavalry: 'cavalry', siege: 'siege' };

function deterministic(seed, salt) {
  const hex = createHash('sha256').update(seed + ':' + salt).digest('hex').slice(0, 12);
  return Number.parseInt(hex, 16) / 0xffffffffffff;
}

async function ownedTileCount(db, playerId) {
  return Number((await db.query('SELECT count(*)::int AS n FROM strategic_tiles WHERE owner_player_id=$1', [playerId])).rows[0].n);
}

export async function realmStage(db, profile, buildings = null, progress = null) {
  buildings ??= await levels(db, profile.player_id, 'building');
  progress ??= await progression(db, profile);
  const ownedTiles = await ownedTileCount(db, profile.player_id);
  const requirements = (await db.query('SELECT * FROM realm_stage_requirements ORDER BY rank')).rows;
  let current = requirements[0];
  for (const row of requirements) {
    if ((buildings.keep ?? 0) < row.min_keep) break;
    if (progress.level < row.min_player_level) break;
    if (ownedTiles < row.min_owned_tiles) break;
    if (profile.conquests < row.min_conquests) break;
    if (['farm','lumber_mill','quarry','iron_mine','market'].reduce((n,k)=>n+(buildings[k]??0),0) < row.min_economy) break;
    const research = await levels(db,profile.player_id,'research');
    if (Object.values(research).reduce((a,b)=>a+b,0) < row.min_research || profile.prestige < row.min_prestige) break;
    current = row;
  }
  const earnedRank = Math.max(current.rank,profile.realm_rank??1);
  if (earnedRank > (profile.realm_rank??1)) {
    for (const row of requirements.filter(r=>r.rank>profile.realm_rank&&r.rank<=earnedRank)) {
      const event = await db.query('INSERT INTO kingdom_milestones(player_id,key,claimed_at) VALUES($1,$2,clock_timestamp()) ON CONFLICT DO NOTHING RETURNING key',[profile.player_id,'realm:'+row.stage]);
      if (event.rows.length) {
        await db.query("UPDATE kingdom_resources SET amount=least(amount+$2,1000000000000) WHERE player_id=$1 AND resource='gold'",[profile.player_id,row.rank*50]);
        if (row.rank>=4) {profile.ascension_tokens+=1; await db.query('UPDATE kingdoms SET ascension_tokens=$2 WHERE player_id=$1',[profile.player_id,profile.ascension_tokens]);}
        await notify(db,profile.player_id,'realm:'+row.stage,'realm','Your realm has risen to '+row.display_name,'Your people celebrate a new era. Royal rewards have been added to your stores.');
      }
    }
    profile.realm_rank=earnedRank;
    await db.query('UPDATE kingdoms SET realm_rank=$2 WHERE player_id=$1',[profile.player_id,earnedRank]);
  }
  current = requirements.find(r=>r.rank===earnedRank);
  const next = requirements.find(r => r.rank === current.rank + 1) ?? null;
  const shape = row => row ? {
    stage: row.stage,
    name: row.display_name,
    keep: row.min_keep,
    playerLevel: row.min_player_level,
    ownedTiles: row.min_owned_tiles,
    conquests: row.min_conquests,
    economy:row.min_economy, research:row.min_research,prestige:row.min_prestige,
  } : null;
  return { ...shape(current), rank: current.rank, next: shape(next), ownedTiles };
}

async function presetSnapshot(db, playerId) {
  const presets = (await db.query(
    'SELECT id,slot,name,formation,stance,is_defense,commander,created_at,updated_at FROM kingdom_army_presets WHERE player_id=$1 ORDER BY slot',
    [playerId],
  )).rows;
  if (!presets.length) return [];
  const units = (await db.query(
    'SELECT u.preset_id,u.unit_type,u.quantity FROM kingdom_army_preset_units u JOIN kingdom_army_presets p ON p.id=u.preset_id WHERE p.player_id=$1 ORDER BY u.preset_id,u.unit_type',
    [playerId],
  )).rows;
  return presets.map(p => ({
    id: p.id,
    slot: p.slot,
    name: p.name,
    formation: p.formation,
    stance: p.stance,
    isDefense: p.is_defense,
    commander:p.commander,
    units: units.filter(u => u.preset_id === p.id).map(u => ({ type: u.unit_type, quantity: u.quantity })),
    updatedAt: p.updated_at,
  }));
}

async function reportsSnapshot(db, playerId) {
  const limit = Math.min(100, Number((await db.query("SELECT value FROM kingdom_config WHERE key='battle_report_limit'")).rows[0]?.value ?? 50));
  const rows = (await db.query(`
    SELECT b.*,r.perspective,r.seen_at,ka.empire_name AS attacker_name,kd.empire_name AS defender_name
    FROM kingdom_battle_reports r
    JOIN kingdom_battles b ON b.id=r.battle_id
    JOIN kingdoms ka ON ka.player_id=b.attacker_id
    LEFT JOIN kingdoms kd ON kd.player_id=b.defender_id
    WHERE r.player_id=$1 ORDER BY b.resolved_at DESC LIMIT $2
  `, [playerId, limit])).rows;
  return rows.map(r => ({
    id: r.id,
    replay:r.replay,
    perspective: r.perspective,
    attackerId: r.attacker_id,
    attackerName: r.attacker_name,
    defenderId: r.defender_id,
    defenderName: r.defender_name,
    target: { name:territoryName(r.target_x,r.target_z), x: r.target_x, z: r.target_z, kind: r.target_kind },
    result: r.result,
    won: (r.perspective === 'attacker' && r.result === 'attacker') || (r.perspective === 'defender' && r.result === 'defender'),
    attackerPower: Number(r.attacker_power),
    defenderPower: Number(r.defender_power),
    attackerLosses: r.attacker_losses,
    defenderLosses: r.defender_losses,
    reinforcementLosses:r.reinforcement_losses,
    rewards: r.rewards,
    territoryChange: r.territory_change,
    resolvedAt: r.resolved_at,
    seenAt: r.seen_at,
  }));
}

export function getCommandState(pool, identity) {
  return transaction(pool, identity, 'command_state', {}, commandSnapshot, { replay: false });
}

export async function commandSnapshot(db, profile, now) {
    const buildings = await levels(db, profile.player_id, 'building');
    const progress = await progression(db, profile);
    return {
      realm: await realmStage(db, profile, buildings, progress),
      presets: await presetSnapshot(db, profile.player_id),
      reports: await reportsSnapshot(db, profile.player_id),
      ...await campaignSnapshot(db,profile.player_id,now),
    };
}

export function saveArmyPreset(pool, identity, body) {
  return transaction(pool, identity, 'army_preset_save', body, async (db, profile, now) => {
    const slot = integer(body.slot, 1, 5, 'invalid_preset_slot');
    const name = text(body.name, 2, 24, 'invalid_preset_name');
    if (!FORMATIONS.has(body.formation)) throw new ApiError(400, 'invalid_formation');
    if (!STANCES.has(body.stance)) throw new ApiError(400, 'invalid_stance');
    if (typeof body.isDefense !== 'boolean') throw new ApiError(400, 'invalid_defense_flag');
    if (!Array.isArray(body.units) || body.units.length < 1 || body.units.length > 20) throw new ApiError(400, 'invalid_army_units');

    if (body.commander != null && !(await db.query('SELECT 1 FROM kingdom_commanders WHERE player_id=$1 AND key=$2',[profile.player_id,String(body.commander)])).rows.length) throw new ApiError(409,'commander_locked');
    const seen = new Set();
    const requested = [];
    for (const unit of body.units) {
      if (!unit || typeof unit.type !== 'string' || seen.has(unit.type)) throw new ApiError(400, 'invalid_army_units');
      seen.add(unit.type);
      requested.push({ type: unit.type, quantity: integer(unit.quantity, 1, 100000, 'invalid_army_quantity') });
    }
    const owned = new Map((await db.query('SELECT type,alive FROM kingdom_units WHERE player_id=$1', [profile.player_id])).rows.map(r => [r.type, r.alive]));
    const known = new Set((await db.query("SELECT key FROM kingdom_catalog WHERE kind='unit'")).rows.map(r => r.key));
    for (const unit of requested) {
      if (!known.has(unit.type)) throw new ApiError(400, 'unknown_unit_type');
      if ((owned.get(unit.type) ?? 0) < unit.quantity) throw new ApiError(409, 'army_units_unavailable');
    }
    if (body.isDefense) await db.query('UPDATE kingdom_army_presets SET is_defense=false,updated_at=$2 WHERE player_id=$1 AND is_defense', [profile.player_id, now]);
    const preset = (await db.query(`
      INSERT INTO kingdom_army_presets(player_id,slot,name,formation,stance,is_defense,created_at,updated_at)
      VALUES($1,$2,$3,$4,$5,$6,$7,$7)
      ON CONFLICT(player_id,slot) DO UPDATE SET name=excluded.name,formation=excluded.formation,
        stance=excluded.stance,is_defense=excluded.is_defense,updated_at=excluded.updated_at
      RETURNING id
    `, [profile.player_id, slot, name, body.formation, body.stance, body.isDefense, now])).rows[0];
    await db.query('UPDATE kingdom_army_presets SET commander=$2 WHERE id=$1',[preset.id,body.commander??null]);
    await db.query('DELETE FROM kingdom_army_preset_units WHERE preset_id=$1', [preset.id]);
    for (const unit of requested) await db.query(
      'INSERT INTO kingdom_army_preset_units(preset_id,unit_type,quantity) VALUES($1,$2,$3)',
      [preset.id, unit.type, unit.quantity],
    );
    return { command: { realm: await realmStage(db, profile), presets: await presetSnapshot(db, profile.player_id), reports: await reportsSnapshot(db, profile.player_id), ...await campaignSnapshot(db,profile.player_id,now) } };
  });
}

export function deleteArmyPreset(pool, identity, body) {
  return transaction(pool, identity, 'army_preset_delete', body, async (db, profile, now) => {
    const slot = integer(body.slot, 1, 5, 'invalid_preset_slot');
    await db.query('DELETE FROM kingdom_army_presets WHERE player_id=$1 AND slot=$2', [profile.player_id, slot]);
    return { command: { realm: await realmStage(db, profile), presets: await presetSnapshot(db, profile.player_id), reports: await reportsSnapshot(db, profile.player_id), ...await campaignSnapshot(db,profile.player_id,now) } };
  });
}

async function combatPower(db, playerId, composition, formation, stance, targetKind, defending = false, commander = null, enemies = [], fortificationOwner = playerId) {
  if (!composition.length) return 0;
  const keys = [...new Set([...composition,...enemies].map(u => u.type))];
  const defs = new Map((await db.query("SELECT key,data FROM kingdom_catalog WHERE kind='unit' AND key=ANY($1::text[])", [keys])).rows.map(r => [r.key, r.data]));
  const research = await levels(db, playerId, 'research');
  const buildings = await levels(db, playerId, 'building');
  let power = 0;
  const led = commander ? (await db.query('SELECT key,xp FROM kingdom_commanders WHERE player_id=$1 AND key=$2',[playerId,commander])).rows[0] : null;
  const specialty = {arden:'infantry',serah:'ranged',idris:'cavalry'}[led?.key];
  const leadership = led ? 1.02 + Math.min(.12,Math.floor(Math.sqrt(Number(led.xp)/150))*.002) : 1;
  const enemyTotal = Math.max(1,enemies.reduce((n,u)=>n+u.quantity,0));
  const enemyCategories = {};
  for (const u of enemies) {
    const category = defs.get(u.type)?.category;
    if (category) enemyCategories[category]=(enemyCategories[category]??0)+u.quantity/enemyTotal;
  }
  for (const unit of composition) {
    const def = defs.get(unit.type);
    if (!def) continue;
    const researchLevel = research[CATEGORY_RESEARCH[def.category]] ?? 0;
    const quality = Number(def.health) * .22 + Number(def.attack) * 2.15 + Number(def.defense) * 1.65 + Number(def.speed) * 1.1;
    let category = 1 + researchLevel * .035;
    if (def.category === 'siege' && ['fort', 'settlement'].includes(targetKind)) category *= 1.18;
    if (def.category === 'cavalry' && formation === 'wedge') category *= 1.10;
    if (def.category === 'ranged' && formation === 'line') category *= 1.08;
    if (def.category === 'infantry' && formation === 'shield') category *= defending ? 1.14 : 1.04;
    if (formation==='square' && def.category==='infantry') category*=1.04+.15*(enemyCategories.cavalry??0);
    if (formation==='skirmish' && def.category==='ranged') category*=1.12-.10*(enemyCategories.cavalry??0);
    if (['spearman','pikeman'].includes(unit.type)) category*=1+.40*(enemyCategories.cavalry??0);
    if (def.category==='cavalry') category*=1+.25*(enemyCategories.ranged??0)-.12*(enemyCategories.infantry??0);
    if (def.category==='ranged') category*=1+.15*(enemyCategories.infantry??0);
    if (def.category==='siege' && ['fort','settlement'].includes(targetKind)) category*=1.30;
    if (def.category===specialty) category*=leadership;
    power += unit.quantity * quality * category * (1+(buildings.blacksmith??0)*.01);
  }
  const stanceMultiplier = stance === 'aggressive' ? 1.06 : (stance === 'defensive' ? (defending ? 1.10 : .96) : 1);
  const fortBuildings=fortificationOwner===playerId?buildings:await levels(db,fortificationOwner,'building');
  const fortResearch=fortificationOwner===playerId?research:await levels(db,fortificationOwner,'research');
  let fortification = 1;
  if (defending && targetKind === 'settlement') fortification += Math.min(.55, (fortBuildings.walls ?? 0) * .02+(fortBuildings.gatehouse??0)*.01+(fortBuildings.watch_towers??0)*.01 + (fortResearch.defense ?? 0) * .015);
  if (defending && targetKind === 'fort') fortification += .55 + Math.min(.30, (fortResearch.defense ?? 0) * .015);
  return power * stanceMultiplier * fortification;
}

export async function loadPreset(db, playerId, slot) {
  const preset = (await db.query(
    'SELECT id,slot,name,formation,stance,is_defense,commander FROM kingdom_army_presets WHERE player_id=$1 AND slot=$2',
    [playerId, slot],
  )).rows[0];
  if (!preset) throw new ApiError(409, 'army_preset_required');
  const units = (await db.query('SELECT unit_type,quantity FROM kingdom_army_preset_units WHERE preset_id=$1 ORDER BY unit_type', [preset.id])).rows
    .map(r => ({ type: r.unit_type, quantity: r.quantity }));
  if (!units.length) throw new ApiError(409, 'army_preset_empty');
  const owned = new Map((await db.query('SELECT type,available AS alive FROM kingdom_unit_availability WHERE player_id=$1', [playerId])).rows.map(r => [r.type, r.alive]));
  if (units.some(u => (owned.get(u.type) ?? 0) < u.quantity)) throw new ApiError(409, 'army_preset_stale');
  return { ...preset, units };
}

async function defenseComposition(db, playerId) {
  const preset = (await db.query('SELECT * FROM kingdom_army_presets WHERE player_id=$1 AND is_defense=true', [playerId])).rows[0];
  if (preset) {
    const units = (await db.query('SELECT unit_type,quantity FROM kingdom_army_preset_units WHERE preset_id=$1 ORDER BY unit_type', [preset.id])).rows
      .map(r => ({ type: r.unit_type, quantity: r.quantity }));
    const owned = new Map((await db.query('SELECT type,available AS alive FROM kingdom_unit_availability WHERE player_id=$1', [playerId])).rows.map(r => [r.type, r.alive]));
    const legal = units.map(u => ({ type: u.type, quantity: Math.min(u.quantity, owned.get(u.type) ?? 0) })).filter(u => u.quantity > 0);
    if (legal.length) return { formation: preset.formation, stance: preset.stance, commander:await commanderAway(db,playerId,preset.commander)?null:preset.commander, units: legal };
  }
  const rows = (await db.query('SELECT type,available AS alive FROM kingdom_unit_availability WHERE player_id=$1 AND available>0 ORDER BY type', [playerId])).rows;
  return {
    formation: 'shield',
    stance: 'defensive',
    units: rows.map(r => ({ type: r.type, quantity: Math.max(1, Math.min(r.alive, Math.ceil(r.alive * .35))) })).filter(r => r.quantity > 0),
  };
}

async function applyCasualties(db, playerId, composition, rate, seed, side) {
  const result = {};
  for (const unit of composition) {
    const variance = .85 + deterministic(seed, side + ':' + unit.type) * .30;
    const affected = Math.min(unit.quantity, Math.max(0, Math.floor(unit.quantity * rate * variance)));
    if (affected <= 0) {
      result[unit.type] = { wounded: 0, dead: 0 };
      continue;
    }
    const wounded = Math.min(affected, Math.round(affected * .68));
    const dead = affected - wounded;
    const updated = await db.query(`
      UPDATE kingdom_units SET alive=alive-$3,wounded=wounded+$4,dead=dead+$5
      WHERE player_id=$1 AND type=$2 AND alive >= $3 RETURNING alive
    `, [playerId, unit.type, affected, wounded, dead]);
    if (!updated.rows.length) throw new ApiError(409, 'army_changed');
    result[unit.type] = { wounded, dead };
  }
  return result;
}

async function clanId(db, playerId) {
  return (await db.query('SELECT clan_id FROM clan_members WHERE player_id=$1', [playerId])).rows[0]?.clan_id ?? null;
}

async function addRewards(db, profile, rewards, capacity) {
  for (const [resource, amount] of Object.entries(rewards)) {
    if (!['food', 'wood', 'stone', 'iron', 'gold'].includes(resource) || amount <= 0) continue;
    await db.query('UPDATE kingdom_resources SET amount=least($3::bigint,amount+$4::bigint) WHERE player_id=$1 AND resource=$2', [profile.player_id, resource, capacity, amount]);
  }
}

function npcPower(kind, x, z) {
  const base = { neutral: 145, resource: 240, npc: 520, fort: 900, settlement: 650 }[kind] ?? 180;
  return base * (1 + ((Math.abs(x * 13 + z * 7) % 9) / 20));
}

export async function attackTarget(db, identity, profile, x, z, army, now) {
  const connected=(await db.query('SELECT 1 FROM strategic_tiles WHERE world_id=$1 AND owner_player_id=$2 AND abs(x-$3::integer)+abs(z-$4::integer)=1 LIMIT 1',[identity.world_id,profile.player_id,x,z])).rows.length;
  if (!connected) throw new ApiError(409,'target_not_connected');
  const target=(await db.query('SELECT * FROM strategic_tiles WHERE world_id=$1 AND x=$2 AND z=$3 FOR UPDATE',[identity.world_id,x,z])).rows[0];
  if (!target) throw new ApiError(404,'target_unavailable');
  if (target.owner_player_id===profile.player_id) throw new ApiError(409,'already_owned');
  if (target.protected_until && target.protected_until>now) throw new ApiError(409,'target_protected');
  if (target.occupied_until && target.occupied_until>now) throw new ApiError(409,'target_occupied');
  const ownClan=await clanId(db,profile.player_id);
  const otherClan=target.owner_clan_id??(target.owner_player_id?await clanId(db,target.owner_player_id):null);
  if (ownClan && ownClan===otherClan) throw new ApiError(409,'friendly_territory');
  const war=await eligibleWar(db,ownClan,otherClan,now);
  if (target.kind==='fort' && !war) throw new ApiError(409,'clan_war_required');
  if (target.kind==='fort' && !army.units.some(u=>['battering_ram','ballista','catapult','siege_tower','trebuchet'].includes(u.type))) throw new ApiError(409,'siege_required');
  return target;
}

export async function resolveBattle(db,profile,now,identity,body,attacker) {
    await settleWars(db,identity.world_id,now);
    Object.assign(profile,(await db.query("SELECT * FROM kingdoms WHERE player_id=$1",[profile.player_id])).rows[0]);
    const targetX = integer(body.x, -100000, 100000, 'invalid_target');
    const targetZ = integer(body.z, -100000, 100000, 'invalid_target');
    const slot = integer(body.presetSlot, 1, 5, 'invalid_preset_slot');
    const economy = await settle(db, profile, now);

    const target = await attackTarget(db,identity,profile,targetX,targetZ,attacker,now);
    if (Object.hasOwn(body,'expectedOwner') && target.owner_player_id!==body.expectedOwner) throw new ApiError(409,'target_changed');

    const attackerClan = await clanId(db, profile.player_id);
    const defenderId = target.owner_player_id ?? null;
    let defenderClan = target.owner_clan_id ?? null;
    let defender = null;
    let defenderArmy = null;
    if (defenderId) {
      await db.query('SELECT id FROM players WHERE id=$1 FOR UPDATE', [defenderId]);
      defender = (await db.query('SELECT * FROM kingdoms WHERE player_id=$1 FOR UPDATE', [defenderId])).rows[0];
      if (!defender) throw new ApiError(409, 'defender_unavailable');
      defenderClan ??= await clanId(db, defenderId);
      if (attackerClan && defenderClan && attackerClan === defenderClan) throw new ApiError(409, 'friendly_territory');
      await settle(db,defender,now);
      defenderArmy = await defenseComposition(db, defenderId);
    }
    if (attackerClan && attackerClan===defenderClan) throw new ApiError(409,'friendly_territory');
    const war = await eligibleWar(db,attackerClan,defenderClan,now);
    if (target.kind==='fort' && !war) throw new ApiError(409,'clan_war_required');
    if (target.kind==='fort' && !attacker.units.some(u=>['battering_ram','ballista','catapult','siege_tower','trebuchet'].includes(u.type))) throw new ApiError(409,'siege_required');

    const guards = defender && target.kind==='settlement' ? (await db.query(`
      SELECT m.*,k.empire_name FROM kingdom_marches m JOIN kingdoms k ON k.player_id=m.player_id
      JOIN clan_members cm ON cm.player_id=m.player_id
      WHERE m.target_owner_id=$1 AND m.target_x=$2 AND m.target_z=$3 AND m.kind='reinforce'
      AND m.phase='stationed' AND cm.clan_id=$4 ORDER BY m.player_id,m.id FOR UPDATE OF m`,
      [defenderId,targetX,targetZ,defenderClan])).rows : [];
    for (const guard of guards) {
      await db.query('SELECT id FROM players WHERE id=$1 FOR UPDATE',[guard.player_id]);
      await db.query('SELECT player_id FROM kingdoms WHERE player_id=$1 FOR UPDATE',[guard.player_id]);
      guard.units=await marchUnits(db,guard.id);
    }
    const defendingUnits=[...(defenderArmy?.units??[]),...guards.flatMap(g=>g.units)];
    const battleId = randomUUID();
    const seed = createHash('sha256').update(battleId + ':' + identity.world_id).digest('hex');
    const attackerPower = await combatPower(db, profile.player_id, attacker.units, attacker.formation, attacker.stance, target.kind, false,attacker.commander,defendingUnits);
    let defenderPower;
    if (defender) defenderPower = await combatPower(db, defenderId, defenderArmy.units, defenderArmy.formation, defenderArmy.stance, target.kind, true,defenderArmy.commander,attacker.units);
    else defenderPower = npcPower(target.kind, targetX, targetZ);
    for (const guard of guards) defenderPower+=await combatPower(db,guard.player_id,guard.units,guard.formation,guard.stance,target.kind,true,guard.commander,attacker.units,defenderId);

    const attackRoll = .93 + deterministic(seed, 'attack') * .14;
    const defenseRoll = .93 + deterministic(seed, 'defense') * .14;
    const attackScore = attackerPower * attackRoll;
    const defenseScore = defenderPower * defenseRoll;
    const result = Math.abs(attackScore - defenseScore) / Math.max(1, attackScore, defenseScore) < .025 ? 'draw' : (attackScore > defenseScore ? 'attacker' : 'defender');
    const ratio = attackerPower / Math.max(1, defenderPower);
    const attackerRate = result === 'attacker' ? Math.max(.025, Math.min(.11, .075 / Math.max(.55, ratio))) : (result === 'draw' ? .12 : Math.min(.34, .18 + .06 / Math.max(.4, ratio)));
    const defenderRate = result === 'defender' ? Math.max(.025, Math.min(.11, .075 * Math.max(.55, ratio))) : (result === 'draw' ? .12 : Math.min(.36, .18 + .055 * Math.max(.7, ratio)));

    const attackerLosses = await applyCasualties(db, profile.player_id, attacker.units, attackerRate, seed, 'attacker');
    const npcQuantity=Math.max(1,Math.round(defenderPower/28));
    const npcAffected=Math.min(npcQuantity,Math.floor(npcQuantity*defenderRate*(.85+deterministic(seed,'defender:garrison')*.30)));
    const defenderLosses = defender ? await applyCasualties(db, defenderId, defenderArmy.units, defenderRate, seed, 'defender') : {garrison:{wounded:Math.round(npcAffected*.68),dead:npcAffected-Math.round(npcAffected*.68)}};
    const reinforcementLosses=[];
    for (const guard of guards) {
      const losses=await applyCasualties(db,guard.player_id,guard.units,defenderRate,seed,'guard:'+guard.id);
      reinforcementLosses.push({playerId:guard.player_id,realmName:guard.empire_name,armyName:guard.name,losses});
      for (const [type,loss] of Object.entries(losses)) {
        await db.query('UPDATE kingdom_march_units SET quantity=quantity-$3 WHERE march_id=$1 AND unit_type=$2',[guard.id,type,loss.wounded+loss.dead]);
        const total=defenderLosses[type]??={wounded:0,dead:0};
        total.wounded+=loss.wounded; total.dead+=loss.dead;
      }
    }

    let territoryChange = 'none';
    let rewards = {};
    if (result === 'attacker') {
      const rewardTable = {
        neutral: { food: 30, gold: 15 },
        resource: { wood: 45, stone: 35, gold: 25 },
        npc: { food: 75, iron: 30, gold: 60 },
        settlement: { food: 90, gold: 85 },
        fort: { iron: 55, gold: 110 },
      };
      rewards = rewardTable[target.kind] ?? {};
      if (defender) {
        const defenses=await levels(db,defenderId,'building');
        const protectedAmount=100+(defenses.granary??0)*100;
        for (const [resource,amount] of Object.entries(rewards)) {
          const row=(await db.query('SELECT amount FROM kingdom_resources WHERE player_id=$1 AND resource=$2',[defenderId,resource])).rows[0];
          rewards[resource]=Math.min(amount,Math.max(0,Number(row?.amount??0)-protectedAmount));
          await db.query('UPDATE kingdom_resources SET amount=amount-$3 WHERE player_id=$1 AND resource=$2',[defenderId,resource,rewards[resource]]);
        }
      }
      await addRewards(db, profile, rewards, economy.capacity);
      if (target.kind === 'settlement') {
        const seconds = Number((await db.query("SELECT value FROM kingdom_config WHERE key='battle_settlement_occupation_seconds'")).rows[0].value);
        await db.query('UPDATE strategic_tiles SET occupied_until=$4,last_battle_id=$5,version=version+1 WHERE world_id=$1 AND x=$2 AND z=$3', [identity.world_id, targetX, targetZ, new Date(now.getTime() + seconds * 1000), battleId]);
        territoryChange = 'occupied';
      } else if (target.kind === 'fort') {
        await db.query('UPDATE strategic_tiles SET owner_player_id=NULL,owner_clan_id=$4,captured_at=$5,occupied_until=NULL,last_battle_id=$6,version=version+1 WHERE world_id=$1 AND x=$2 AND z=$3', [identity.world_id, targetX, targetZ, attackerClan, now, battleId]);
        territoryChange = 'fort_captured';
        profile.conquests += 1;
      } else {
        const protection = Number((await db.query("SELECT value FROM kingdom_config WHERE key='battle_capture_protection_seconds'")).rows[0].value);
        await db.query('UPDATE strategic_tiles SET owner_player_id=$4,owner_clan_id=$5,captured_at=$6,protected_until=$7,occupied_until=NULL,last_battle_id=$8,version=version+1 WHERE world_id=$1 AND x=$2 AND z=$3', [identity.world_id, targetX, targetZ, profile.player_id, attackerClan, now, new Date(now.getTime() + protection * 1000), battleId]);
        territoryChange = 'captured';
        profile.conquests += 1;
      }
      profile.prestige += target.kind === 'settlement' ? 3 : (target.kind === 'fort' ? 8 : 2);
      await db.query('UPDATE kingdoms SET conquests=$2,prestige=$3 WHERE player_id=$1', [profile.player_id, profile.conquests, profile.prestige]);
      await grantXP(db, profile, 'battle', battleId, target.kind === 'settlement' ? 350 : (target.kind === 'fort' ? 500 : 200), now);
    } else {
      await db.query('UPDATE strategic_tiles SET last_battle_id=$4,version=version+1 WHERE world_id=$1 AND x=$2 AND z=$3', [identity.world_id, targetX, targetZ, battleId]);
    }

    await db.query(`
      INSERT INTO kingdom_battles(id,world_id,attacker_id,defender_id,target_x,target_z,target_kind,attacker_preset_slot,
        seed,attacker_power,defender_power,result,attacker_losses,defender_losses,rewards,territory_change,started_at,resolved_at)
      VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$17)
    `, [battleId, identity.world_id, profile.player_id, defenderId, targetX, targetZ, target.kind, slot, seed,
      attackerPower, defenderPower, result, attackerLosses, defenderLosses, rewards, territoryChange, now]);
    await db.query("INSERT INTO kingdom_battle_reports(battle_id,player_id,perspective) VALUES($1,$2,'attacker')", [battleId, profile.player_id]);
    if (defenderId) await db.query("INSERT INTO kingdom_battle_reports(battle_id,player_id,perspective) VALUES($1,$2,'defender')", [battleId, defenderId]);
    for (const guard of guards) {
      await db.query("INSERT INTO kingdom_battle_reports(battle_id,player_id,perspective) VALUES($1,$2,'defender') ON CONFLICT DO NOTHING",[battleId,guard.player_id]);
      await db.query('UPDATE kingdom_marches SET report_id=$2 WHERE id=$1',[guard.id,battleId]);
      await notify(db,guard.player_id,'battle:'+battleId,'battle','Your reinforcements defended an ally','Open the report to review the battle and your soldiers’ losses.',battleId);
    }

    const replay = {version:1,seed,formation:attacker.formation,stance:attacker.stance,commander:attacker.commander??null,
      attacker:attacker.units,defender:defender?defendingUnits:[{type:'garrison',quantity:npcQuantity}],
      phases:[{key:'deployment',duration:2},{key:'ranged',duration:2},{key:'advance',duration:2},{key:'melee',duration:3},{key:'conclusion',duration:2}],
      result,attackerLosses,defenderLosses,territoryChange};
    await db.query('UPDATE kingdom_battles SET replay=$2,war_id=$3,reinforcement_losses=$4 WHERE id=$1',[battleId,replay,war?.id??null,JSON.stringify(reinforcementLosses)]);
    if (attacker.commander) await db.query('UPDATE kingdom_commanders SET xp=xp+25 WHERE player_id=$1 AND key=$2',[profile.player_id,attacker.commander]);
    if (war && result==='attacker') {
      const score=target.kind==='fort'?50:target.kind==='settlement'?20:5;
      const column=attackerClan===war.attacker_id?'attacker_score':'defender_score';
      await db.query('UPDATE clan_wars SET '+column+'='+column+'+$2 WHERE id=$1',[war.id,score]);
      await db.query('INSERT INTO clan_war_contributions(war_id,player_id,clan_id,score) VALUES($1,$2,$3,$4) ON CONFLICT(war_id,player_id) DO UPDATE SET score=clan_war_contributions.score+excluded.score',[war.id,profile.player_id,attackerClan,score]);
    }
    await notify(db,profile.player_id,'battle:'+battleId,'battle',result==='attacker'?'Victory beyond the gates':result==='draw'?'Battle ended in a draw':'Your army has withdrawn','Open the battle report to review losses and the territory result.',battleId);
    if (defenderId) await notify(db,defenderId,'battle:'+battleId,'battle','Your realm was attacked','Review the battle report and tend to your wounded.',battleId);
    const buildings = await levels(db, profile.player_id, 'building');
    const progress = await progression(db, profile);
    return {
      battle: {
        id: battleId,
        replay,
        result,
        target: { name:territoryName(targetX,targetZ), x: targetX, z: targetZ, kind: target.kind },
        attackerPower: Math.round(attackerPower),
        defenderPower: Math.round(defenderPower),
        attackerLosses,
        defenderLosses,
        rewards,
        territoryChange,
      },
      realm: await realmStage(db, profile, buildings, progress),
      command: { presets: await presetSnapshot(db, profile.player_id), reports: await reportsSnapshot(db, profile.player_id) },
    };
}

export function getPresence(pool, identity) {
  return transaction(pool, identity, 'presence', {}, async (db, profile, now) => {
    await db.query('UPDATE players SET last_seen_at=$2 WHERE id=$1', [profile.player_id, now]);
    const plot = (await db.query('SELECT region_id FROM strategic_plots WHERE player_id=$1', [profile.player_id])).rows[0];
    if (!plot) return { online: 1, rulers: [] };
    const rows = (await db.query(`
      SELECT p.id,a.display_name,k.empire_name,k.primary_color,k.emblem,cm.clan_id,p.last_seen_at
      FROM strategic_plots sp
      JOIN players p ON p.id=sp.player_id
      JOIN accounts a ON a.id=p.account_id
      JOIN kingdoms k ON k.player_id=p.id
      LEFT JOIN clan_members cm ON cm.player_id=p.id
      WHERE sp.region_id=$1 AND p.last_seen_at >= $2::timestamptz - interval '45 seconds'
      ORDER BY p.last_seen_at DESC LIMIT 100
    `, [plot.region_id, now])).rows;
    return {
      online: rows.length,
      rulers: rows.map(r => ({ playerId: r.id, displayName: r.display_name, empireName: r.empire_name, primaryColor: r.primary_color, emblem: r.emblem, clanId: r.clan_id, self: r.id === profile.player_id })),
    };
  }, { replay: false });
}
