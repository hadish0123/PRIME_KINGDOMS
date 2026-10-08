import { territoryName } from './locations.js';
import { integer } from './transaction.js';
import { transaction } from './transaction.js';

export function getMap(pool, identity, query = new URLSearchParams()) {
  return transaction(pool, identity, 'world_map', {}, async db => {
    const plot = (await db.query('SELECT p.plot,p.map_x,p.map_z,r.id,r.name,r.kind FROM strategic_plots p JOIN strategic_regions r ON r.id=p.region_id WHERE p.player_id=$1', [identity.player_id])).rows[0];
    const x = query.has('x') ? integer(Number(query.get('x')),-99997,99997,'invalid_target') : plot.map_x;
    const z = query.has('z') ? integer(Number(query.get('z')),-99997,99997,'invalid_target') : plot.map_z;
    const clan=(await db.query('SELECT clan_id FROM clan_members WHERE player_id=$1',[identity.player_id])).rows[0]?.clan_id;
    // Persistent starter frontier. No client can claim ownership by drawing a tile.
    for (let dx = -3; dx <= 3; dx++) for (let dz = -3; dz <= 3; dz++) {
      const kind = (Math.abs(x + dx) * 17 + Math.abs(z + dz) * 31) % 7 === 0 ? 'resource' : 'neutral';
      await db.query('INSERT INTO strategic_tiles(world_id,x,z,kind) VALUES($1,$2,$3,$4) ON CONFLICT DO NOTHING', [identity.world_id, x + dx, z + dz, kind]);
    }
    const tiles = (await db.query(`SELECT t.*,coalesce(k.empire_name,c.name) AS empire_name,coalesce(k.primary_color,c.primary_color) AS primary_color,coalesce(k.secondary_color,c.secondary_color) AS secondary_color,coalesce(k.emblem,c.emblem) AS emblem, (op.last_seen_at >= clock_timestamp()-interval '45 seconds') AS owner_online, EXISTS(SELECT 1 FROM strategic_tiles own WHERE own.world_id=t.world_id AND own.owner_player_id=$4 AND abs(own.x-t.x)+abs(own.z-t.z)=1) AS attackable FROM strategic_tiles t LEFT JOIN kingdoms k ON k.player_id=t.owner_player_id LEFT JOIN clans c ON c.id=t.owner_clan_id LEFT JOIN players op ON op.id=t.owner_player_id WHERE t.world_id=$1 AND t.x BETWEEN $2::integer-3 AND $2::integer+3 AND t.z BETWEEN $3::integer-3 AND $3::integer+3 ORDER BY t.z,t.x LIMIT 49`, [identity.world_id, x, z, identity.player_id])).rows;
    const borders = (await db.query(`
      SELECT c.id,c.name,c.tag,c.emblem,c.primary_color,c.secondary_color,r.map_x,r.map_z
      FROM strategic_regions r JOIN clans c ON c.region_id=r.id
      WHERE r.world_id=$1 AND r.map_x<=$2::integer+3 AND r.map_x+7>=$2::integer-3
        AND r.map_z<=$3::integer+3 AND r.map_z+7>=$3::integer-3
      ORDER BY r.map_x,r.map_z LIMIT 9
    `,[identity.world_id,x,z])).rows.map(r=>({clanId:r.id,name:r.name,tag:r.tag,
      emblem:r.emblem,primaryColor:r.primary_color,secondaryColor:r.secondary_color,
      bounds:{minX:r.map_x,minZ:r.map_z,maxX:r.map_x+7,maxZ:r.map_z+7}}));
    const regionPlots = (await db.query('SELECT p.plot,p.player_id,k.empire_name,k.primary_color,k.emblem FROM strategic_plots p LEFT JOIN kingdoms k ON k.player_id=p.player_id WHERE p.region_id=$1 ORDER BY p.plot LIMIT 1024', [plot.id])).rows;
    return { center: { x, z }, regions: borders, tiles: tiles.map(t => ({ name:territoryName(t.x,t.z), x: t.x, z: t.z, kind: t.kind, ownerPlayerId: t.owner_player_id, ownerClanId: t.owner_clan_id, empireName: t.empire_name, primaryColor: t.primary_color, secondaryColor: t.secondary_color, emblem: t.emblem, protectedUntil: t.protected_until, occupiedUntil: t.occupied_until, version: t.version, online: Boolean(t.owner_online), attackable: Boolean(t.attackable) && t.owner_player_id !== identity.player_id && (!t.protected_until || t.protected_until<=new Date()) && (!t.occupied_until || t.occupied_until<=new Date()) && (!clan || clan!==t.owner_clan_id) })), region: { id: plot.id, name: plot.name, kind: plot.kind, clanId: clan, ownPlot: plot.plot, plots: regionPlots.map(p => ({ plot: p.plot, ownerPlayerId: p.player_id, empireName: p.empire_name, primaryColor: p.primary_color, emblem: p.emblem })) } };
  }, { replay: false });
}
