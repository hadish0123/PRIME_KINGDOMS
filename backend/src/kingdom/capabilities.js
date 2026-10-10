export async function capabilities(db, playerId) {
  const row = (await db.query(
    'SELECT role,unlimited_resources,unlimited_army,divine_power FROM kingdom_capabilities WHERE player_id=$1',
    [playerId],
  )).rows[0];
  return row ? {
    role: row.role,
    unlimitedResources: Boolean(row.unlimited_resources),
    unlimitedArmy: Boolean(row.unlimited_army),
    divinePower: Boolean(row.divine_power),
  } : { role: null, unlimitedResources: false, unlimitedArmy: false, divinePower: false };
}

export async function grantOwnerCapability(db, playerId) {
  await db.query(`
    INSERT INTO kingdom_capabilities(player_id,role,unlimited_resources,unlimited_army,divine_power)
    VALUES($1,'owner',true,true,true)
    ON CONFLICT(player_id) DO UPDATE SET
      role='owner',unlimited_resources=true,unlimited_army=true,divine_power=true
  `, [playerId]);
  return capabilities(db, playerId);
}

export async function isGameOwner(db, playerId) {
  return Boolean((await db.query(
    "SELECT 1 FROM kingdom_capabilities WHERE player_id=$1 AND role='owner' AND divine_power",
    [playerId],
  )).rows.length);
}
