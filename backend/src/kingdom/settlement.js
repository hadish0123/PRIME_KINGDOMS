import { ApiError } from '../errors.js';
import { transaction, integer, text } from './transaction.js';
import { settle, levels, spend, scaledCost, storageCapacity } from './economy.js';
import { progression } from './progression.js';
import { realmStage } from './realm.js';
import { availableUnits } from './campaign_inventory.js';

export async function snapshot(db, profile, now) {
  const economy = await settle(db, profile, now);
  const buildings = await levels(db, profile.player_id, 'building');
  const research = await levels(db, profile.player_id, 'research');
  const healing = (await db.query('SELECT id,unit_type,quantity,finishes_at FROM kingdom_healing WHERE player_id=$1 AND completed_at IS NULL', [profile.player_id])).rows;
  const tasks = (await db.query('SELECT id,kind,key,target_level,quantity,started_at,finishes_at FROM kingdom_tasks WHERE player_id=$1 AND completed_at IS NULL ORDER BY finishes_at', [profile.player_id])).rows;
  const units = await availableUnits(db,profile.player_id);
  const catalog = (await db.query('SELECT kind,key,data FROM kingdom_catalog ORDER BY kind,key')).rows;
  const purposes = {
    keep:'Unlocks settlement improvements and realm advancement.', farm:'Produces food for troops and treatment.', lumber_mill:'Produces timber for buildings and equipment.',
    quarry:'Produces stone for buildings and fortifications.', iron_mine:'Produces iron for advanced troops.', market:'Produces gold for your court and diplomacy.',
    trading_post:'Increases hourly gold income.', warehouse:'Increases storage for all resources.', granary:'Protects additional resources from raids.',
    barracks:'Trains infantry and increases army capacity.', archery_range:'Trains archers and crossbowmen.', stable:'Trains cavalry.', siege_workshop:'Trains siege engines.',
    blacksmith:'Improves army attack strength.', workshop:'Supports siege production.', academy:'Unlocks research levels.', hospital:'Heals wounded soldiers.',
    embassy:'Increases clan treasury contribution value.', clan_hall:'Increases clan experience earned from contributions.', watch_towers:'Improves home defense.', walls:'Improves home defense.',
    gatehouse:'Strengthens fortified defense.', commander_hall:'Unlocks commanders.', training_grounds:'Speeds troop training.',
  };
  const effects = (key,level) => {
    const values = {farm:[80,'food / hour'],lumber_mill:[60,'wood / hour'],quarry:[50,'stone / hour'],iron_mine:[30,'iron / hour'],market:[15,'gold / hour'],trading_post:[10,'gold / hour'],warehouse:[5000,'storage'],granary:[100,'protected per resource'],barracks:[100,'army capacity'],training_grounds:[3,'training speed %'],blacksmith:[1,'army attack %'],walls:[2,'defense %'],gatehouse:[1,'defense %'],watch_towers:[1,'defense %']};
    if (key==='warehouse') return {value:storageCapacity(level)-5000,unit:'additional storage'};
    return values[key] ? {value:values[key][0]*level,unit:values[key][1]} : {value:level,unit:'facility level'};
  };
  const quotes = catalog.filter(c => c.kind !== 'unit').map(c => {
    const current = (c.kind === 'building' ? buildings : research)[c.key] ?? 0;
    const requirements=[];
    const require=(kind,key,level)=>requirements.push({kind,key,level,current:(kind==='building'?buildings:research)[key]??0});
    if (c.kind==='building') {
      if (c.key!=='keep') require('building','keep',current+1);
      if (c.data.prerequisite) require('building',c.data.prerequisite,1);
      if (c.key==='keep' && current+1>3) require('building','warehouse',Math.floor((current+1)/3));
    } else {
      require('building','academy',current+1);
      if (c.data.prerequisite) require('research',c.data.prerequisite,current+1);
    }
    return { requirements, purpose: c.kind==='building' ? purposes[c.key] : 'Strengthens the corresponding realm capability.', currentEffect:effects(c.key,current),nextEffect:effects(c.key,current+1),prerequisite:c.data.prerequisite??null, kind: c.kind, key: c.key, current, next: current + 1, maxLevel: c.data.maxLevel, cost: scaledCost(c.data.baseCost, current + 1), durationSeconds: Math.ceil(c.data.seconds * Math.pow(1.6, current) / (1 + (research.construction ?? 0) * .03)) };
  });
  const progress = await progression(db, profile);
  const realm = await realmStage(db, profile, buildings, progress);
  const resources = Object.fromEntries((await db.query('SELECT resource,amount FROM kingdom_resources WHERE player_id=$1', [profile.player_id])).rows.map(r => [r.resource, Number(r.amount)]));
  return { serverTime: now.toISOString(), settlementId: profile.village_id, stage: realm.stage, realm, empire: { name: profile.empire_name, primaryColor: profile.primary_color, secondaryColor: profile.secondary_color, emblem: profile.emblem, bannerStyle: profile.banner_style }, progression: progress, resources, productionPerHour: economy.rates, storageCapacity: economy.capacity, buildings, research, units, healing, economyBonuses:{territory:economy.territoryBonus,clan:economy.clanBonus}, armyCapacity: (buildings.barracks ?? 0) * Number((await db.query("SELECT value FROM kingdom_config WHERE key='army_capacity_per_barracks_level'")).rows[0].value), tasks, catalog, quotes };
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
    const speed = kind === 'training' ? 1 + (buildings.training_grounds??0)*.03 + research.logistics*.02 : 1 + research.construction*.03;
    const seconds = Math.max(1, Math.ceil(definition.seconds * (kind === 'training' ? quantity : Math.pow(1.6, target - 1)) / speed));
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
