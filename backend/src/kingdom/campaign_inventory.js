import { ApiError } from '../errors.js';
import { territoryName } from './locations.js';
import { capabilities } from './capabilities.js';

export async function availableUnits(db, playerId) {
  const powers = await capabilities(db, playerId);
  if (powers.unlimitedArmy) {
    const limit = Number((await db.query("SELECT value FROM kingdom_config WHERE key='owner_virtual_unit_limit'")).rows[0]?.value ?? 100000);
    return (await db.query("SELECT key AS type FROM kingdom_catalog WHERE kind='unit' ORDER BY key")).rows.map(r => ({
      type:r.type,alive:limit,available:limit,deployed:0,wounded:0,dead:0,virtual:true,
    }));
  }
  return (await db.query('SELECT type,alive,available,deployed,wounded,dead FROM kingdom_unit_availability WHERE player_id=$1 ORDER BY type',[playerId])).rows;
}

export async function marchUnits(db, marchId) {
  return (await db.query('SELECT unit_type AS type,quantity FROM kingdom_march_units WHERE march_id=$1 AND quantity>0 ORDER BY unit_type',[marchId])).rows;
}

export async function commanderAway(db, playerId, key) {
  return key && Boolean((await db.query("SELECT 1 FROM kingdom_marches WHERE player_id=$1 AND commander=$2 AND phase<>'completed' LIMIT 1",[playerId,key])).rows.length);
}

export async function travelSeconds(db, playerId, units, distance) {
  const definitions=(await db.query("SELECT key,data FROM kingdom_catalog WHERE kind='unit' AND key=ANY($1::text[])",[units.map(u=>u.type)])).rows;
  const speed=Math.max(.5,Math.min(...definitions.map(u=>Number(u.data.speed))));
  const logistics=Number((await db.query("SELECT level FROM kingdom_research WHERE player_id=$1 AND key='logistics'",[playerId])).rows[0]?.level??0);
  const config=Object.fromEntries((await db.query("SELECT key,value FROM kingdom_config WHERE key IN ('march_minimum_seconds','march_tile_seconds','march_maximum_seconds')")).rows.map(r=>[r.key,Number(r.value)]));
  return Math.max(config.march_minimum_seconds,Math.min(config.march_maximum_seconds,Math.ceil(distance*config.march_tile_seconds/(speed*(1+logistics*.03)))));
}

export function routePosition(march, now) {
  if (march.phase==='stationed') return {x:march.target_x,z:march.target_z};
  const duration=Math.max(1,new Date(march.arrives_at)-new Date(march.route_started_at));
  const fraction=Math.max(0,Math.min(1,(now-new Date(march.route_started_at))/duration));
  return {x:march.route_from_x+(march.route_to_x-march.route_from_x)*fraction,z:march.route_from_z+(march.route_to_z-march.route_from_z)*fraction};
}

export async function beginReturn(db, march, now, reason='recalled') {
  const position=routePosition(march,now);
  const home=(await db.query('SELECT map_x,map_z FROM strategic_plots WHERE player_id=$1',[march.player_id])).rows[0];
  if (!home) throw new Error('Campaign owner has no settlement');
  const units=await marchUnits(db,march.id);
  const duration=await travelSeconds(db,march.player_id,units,Math.hypot(position.x-home.map_x,position.z-home.map_z));
  const arrives=new Date(now.getTime()+duration*1000);
  await db.query("UPDATE kingdom_marches SET phase='returning',route_from_x=$2,route_from_z=$3,route_to_x=$4,route_to_z=$5,route_started_at=$6,arrives_at=$7,return_reason=$8 WHERE id=$1",[march.id,position.x,position.z,home.map_x,home.map_z,now,arrives,reason]);
}

export async function prepareRelocation(db, playerId, now) {
  if ((await db.query("SELECT 1 FROM kingdom_marches WHERE player_id=$1 AND phase<>'completed' LIMIT 1",[playerId])).rows.length) throw new ApiError(409,'army_away');
  const incoming=(await db.query("SELECT * FROM kingdom_marches WHERE target_owner_id=$1 AND kind='reinforce' AND phase IN ('outbound','stationed') ORDER BY id FOR UPDATE",[playerId])).rows;
  for (const march of incoming) await beginReturn(db,march,now,'ally_relocated');
}

export async function campaignSnapshot(db, playerId, now) {
  const own=(await db.query("SELECT * FROM kingdom_marches WHERE player_id=$1 AND phase<>'completed' ORDER BY departed_at LIMIT 3",[playerId])).rows;
  const incoming=(await db.query("SELECT m.*,k.empire_name FROM kingdom_marches m JOIN kingdoms k ON k.player_id=m.player_id WHERE m.target_owner_id=$1 AND m.player_id<>$1 AND m.phase IN ('outbound','stationed') ORDER BY m.arrives_at NULLS LAST LIMIT 30",[playerId])).rows;
  const shape=async m=>({id:m.id,name:m.name,kind:m.kind,phase:m.phase,formation:m.formation,stance:m.stance,commander:m.commander,
    target:{x:m.target_x,z:m.target_z,name:territoryName(m.target_x,m.target_z),ownerPlayerId:m.target_owner_id},
    route:{from:{x:m.route_from_x,z:m.route_from_z},to:{x:m.route_to_x,z:m.route_to_z},startedAt:m.route_started_at,arrivesAt:m.arrives_at},
    position:routePosition(m,now),units:await marchUnits(db,m.id),returnReason:m.return_reason,reportId:m.report_id});
  return {serverTime:now,marches:await Promise.all(own.map(shape)),incoming:await Promise.all(incoming.map(async m=>({...await shape(m),realmName:m.empire_name})))};
}
