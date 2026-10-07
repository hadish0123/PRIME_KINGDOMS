import { transaction } from './transaction.js';

export function getMap(pool, identity) {
  return transaction(pool, identity, 'world_map', {}, async db => {
    const plot = (await db.query('SELECT p.plot,p.map_x,p.map_z,r.id,r.name,r.kind FROM strategic_plots p JOIN strategic_regions r ON r.id=p.region_id WHERE p.player_id=$1', [identity.player_id])).rows[0];
    const x = plot.map_x, z = plot.map_z;
    // Persistent starter frontier. No client can claim ownership by drawing a tile.
    for (let dx = -3; dx <= 3; dx++) for (let dz = -3; dz <= 3; dz++) {
      const kind = (Math.abs(x + dx) * 17 + Math.abs(z + dz) * 31) % 7 === 0 ? 'resource' : 'neutral';
      await db.query('INSERT INTO strategic_tiles(world_id,x,z,kind) VALUES($1,$2,$3,$4) ON CONFLICT DO NOTHING', [identity.world_id, x + dx, z + dz, kind]);
    }
    const tiles = (await db.query('SELECT t.*,coalesce(k.empire_name,c.name) AS empire_name,coalesce(k.primary_color,c.primary_color) AS primary_color,coalesce(k.secondary_color,c.secondary_color) AS secondary_color,coalesce(k.emblem,c.emblem) AS emblem FROM strategic_tiles t LEFT JOIN kingdoms k ON k.player_id=t.owner_player_id LEFT JOIN clans c ON c.id=t.owner_clan_id WHERE t.world_id=$1 AND t.x BETWEEN $2::integer-3 AND $2::integer+3 AND t.z BETWEEN $3::integer-3 AND $3::integer+3 ORDER BY t.z,t.x LIMIT 49', [identity.world_id, x, z])).rows;
    const regionPlots = (await db.query('SELECT p.plot,p.player_id,k.empire_name,k.primary_color,k.emblem FROM strategic_plots p LEFT JOIN kingdoms k ON k.player_id=p.player_id WHERE p.region_id=$1 ORDER BY p.plot LIMIT 1024', [plot.id])).rows;
    return { center: { x, z }, tiles: tiles.map(t => ({ x: t.x, z: t.z, kind: t.kind, ownerPlayerId: t.owner_player_id, ownerClanId: t.owner_clan_id, empireName: t.empire_name, primaryColor: t.primary_color, secondaryColor: t.secondary_color, emblem: t.emblem, protectedUntil: t.protected_until, occupiedUntil: t.occupied_until, version: t.version })), region: { id: plot.id, name: plot.name, kind: plot.kind, ownPlot: plot.plot, plots: regionPlots.map(p => ({ plot: p.plot, ownerPlayerId: p.player_id, empireName: p.empire_name, primaryColor: p.primary_color, emblem: p.emblem })) } };
  }, { replay: false });
}
