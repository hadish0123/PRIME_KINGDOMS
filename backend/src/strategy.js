import { ApiError } from './errors.js';
import { settledHeight } from './terrain.js';

export const LAND_LOCK = 73462711;

export async function territoryState(pool, player) {
  const count = (await pool.query('SELECT count(*)::int AS n FROM territories WHERE owner_player_id=$1', [player.id])).rows[0].n;
  const cells = (await pool.query(`
    SELECT cell_x,cell_z,owner_player_id,is_home FROM territories WHERE world_id=$1
      AND cell_x BETWEEN $2::integer-6 AND $2::integer+6
      AND cell_z BETWEEN $3::integer-6 AND $3::integer+6
    ORDER BY cell_x,cell_z LIMIT 169
  `, [player.world_id,Math.round(player.x/512),Math.round(player.z/512)])).rows;
  return { owned: count, cells: cells.map(c => ({ x:c.cell_x,z:c.cell_z,ownerPlayerId:c.owner_player_id,home:c.is_home })) };
}

export async function commandArmy(pool, identity, body) {
  if (!['guard','follow'].includes(body.order)) throw new ApiError(400,'invalid_order');
  // Client supplied player/unit IDs never select the subject of a command.
  await pool.query('UPDATE players SET army_order=$2 WHERE id=$1', [identity.player_id,body.order]);
  return { order:body.order };
}

export async function marchArmy(client, identity, player, position, yaw, _villages) {
  if (player.army_order !== 'follow') return [];
  const units=(await client.query(`
    SELECT n.* FROM npcs n JOIN villages v ON v.id=n.village_id
    WHERE v.owner_player_id=$1 AND n.role='soldier' ORDER BY n.ordinal FOR UPDATE OF n
  `,[identity.player_id])).rows;
  const step=Math.min(12,5.4*Math.max(0,player.elapsed));
  const planned=[];
  for (const unit of units) {
    const side=(unit.ordinal%2-0.5)*3.0, depth=4+Math.floor(unit.ordinal/2)*1.8;
    const tx=position.x+Math.cos(yaw)*side-Math.sin(yaw)*depth;
    const tz=position.z-Math.sin(yaw)*side-Math.cos(yaw)*depth;
    const distance=Math.hypot(tx-unit.x,tz-unit.z), weight=distance>0 ? Math.min(1,step/distance) : 0;
    const x=unit.x+(tx-unit.x)*weight,z=unit.z+(tz-unit.z)*weight;
    planned.push({unit,x,z});
  }
  const villages=(await client.query(`
    SELECT v.x,v.y,v.z FROM villages v WHERE v.world_id=$1 AND EXISTS (
      SELECT 1 FROM unnest($2::double precision[],$3::double precision[]) AS p(x,z)
        WHERE v.x BETWEEN p.x-125 AND p.x+125 AND v.z BETWEEN p.z-125 AND p.z+125
    ) ORDER BY v.slot
  `,[identity.world_id,planned.map(p=>p.x),planned.map(p=>p.z)])).rows;
  const result=[];
  for (const {unit,x,z} of planned) {
    const y=settledHeight(x,z,player.seed,villages)+0.05;
    await client.query('UPDATE npcs SET x=$2,y=$3,z=$4 WHERE id=$1',[unit.id,x,y,z]);
    result.push({ id:unit.id,position:{x,y,z} });
  }
  return result;
}

export async function claimTerritory(pool, identity) {
  const client=await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('SELECT pg_advisory_xact_lock($1)',[LAND_LOCK]);
    const player=(await client.query('SELECT * FROM players WHERE id=$1 FOR UPDATE',[identity.player_id])).rows[0];
    if (!player) throw new ApiError(404,'player_unavailable');
    if (player.army_order!=='follow') throw new ApiError(409,'army_required');
    const x=Math.round(player.x/512),z=Math.round(player.z/512);
    if (Math.abs(x)>63 || Math.abs(z)>63 || Math.hypot(player.x-x*512,player.z-z*512)>90) throw new ApiError(409,'territory_center_required');
    const soldiers=(await client.query(`
      SELECT n.* FROM npcs n JOIN villages v ON v.id=n.village_id
      WHERE v.owner_player_id=$1 AND n.role='soldier'
    `,[identity.player_id])).rows;
    if (soldiers.length!==8 || soldiers.some(n => Math.hypot(n.x-player.x,n.z-player.z)>40)) throw new ApiError(409,'army_too_far');
    const occupied=(await client.query('SELECT owner_player_id,is_home FROM territories WHERE world_id=$1 AND cell_x=$2 AND cell_z=$3',[player.world_id,x,z])).rows[0];
    if (occupied) throw new ApiError(409,occupied.owner_player_id===player.id?'territory_already_owned':'territory_occupied');
    await client.query('INSERT INTO territories(world_id,cell_x,cell_z,owner_player_id) VALUES($1,$2,$3,$4)',[player.world_id,x,z,player.id]);
    const count=(await client.query('SELECT count(*)::int AS n FROM territories WHERE owner_player_id=$1',[player.id])).rows[0].n;
    const stage=count>=32?'empire':(count>=12?'country':(count>=4?'city':'village'));
    await client.query('UPDATE villages SET stage=$2 WHERE owner_player_id=$1',[player.id,stage]);
    const territories=await territoryState(client,player);
    await client.query('COMMIT');
    return { claimed:{x,z},stage,territories };
  } catch(error) {
    await client.query('ROLLBACK').catch(()=>{});
    throw error;
  } finally { client.release(); }
}

export async function mountHorse(pool,identity,body) {
  if(typeof body.mounted!=='boolean')throw new ApiError(400,'invalid_mount');
  const client=await pool.connect();
  try {
    await client.query('BEGIN');
    const p=(await client.query(`
      SELECT p.*,w.seed,w.size_m FROM players p JOIN worlds w ON w.id=p.world_id
      WHERE p.id=$1 FOR UPDATE OF p
    `,[identity.player_id])).rows[0];
    if(!p)throw new ApiError(404,'player_unavailable');
    if(p.mounted===body.mounted)throw new ApiError(409,'mount_unchanged');
    if(body.mounted && Math.hypot(p.x-p.horse_x,p.y-p.horse_y,p.z-p.horse_z)>3.2)throw new ApiError(409,'horse_too_far');
    const pos=body.mounted?{x:p.horse_x,y:p.horse_y,z:p.horse_z}:{x:p.x+Math.cos(p.yaw)*1.35,y:p.y,z:p.z-Math.sin(p.yaw)*1.35};
    const edge=p.size_m/2-20;
    if(Math.abs(pos.x)>edge || Math.abs(pos.z)>edge)throw new ApiError(409,'outside_world');
    if(!body.mounted){
      const villages=(await client.query(`SELECT x,y,z FROM villages WHERE world_id=$1
        AND x BETWEEN $2::double precision-125 AND $2::double precision+125
        AND z BETWEEN $3::double precision-125 AND $3::double precision+125 ORDER BY slot`,[p.world_id,pos.x,pos.z])).rows;
      pos.y=settledHeight(pos.x,pos.z,p.seed,villages)+0.1;
    }
    await client.query('UPDATE players SET mounted=$2,x=$3,y=$4,z=$5,last_seen_at=now() WHERE id=$1',[p.id,body.mounted,pos.x,pos.y,pos.z]);
    await client.query('COMMIT');
    return {mounted:body.mounted,playerPosition:pos,horsePosition:{x:p.horse_x,y:p.horse_y,z:p.horse_z},yaw:p.yaw};
  } catch(error){
    await client.query('ROLLBACK').catch(()=>{});throw error;
  } finally{client.release();}
}
