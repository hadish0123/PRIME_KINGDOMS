
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
