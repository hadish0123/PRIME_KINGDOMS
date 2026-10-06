import { ApiError } from './errors.js';
import { hashPassword, verifyPassword, normalizeEmail, validatePassword, validateDisplayName, createSession } from './auth.js';
import { villageLocation, settledHeight } from './terrain.js';

export async function register(pool, body) {
  const email = normalizeEmail(body.email);
  const password = validatePassword(body.password);
  const displayName = validateDisplayName(body.displayName);
  const passwordHash = await hashPassword(password);
  const client = await pool.connect();
  let playerId, session, state;
  try {
    await client.query('BEGIN');
    const account = (await client.query(`
      INSERT INTO accounts(email, display_name, password_hash) VALUES ($1,$2,$3) RETURNING id
    `, [email, displayName, passwordHash])).rows[0];
    const world = (await client.query("SELECT id, seed FROM worlds WHERE slug = 'prime-world'")).rows[0];
    if (!world) throw new ApiError(503, 'world_unavailable');
    const slot = Number((await client.query("SELECT nextval('village_slot_sequence') AS slot")).rows[0].slot);
    let position;
    try { position = villageLocation(slot, world.seed); }
    catch { throw new ApiError(503, 'world_capacity'); }
    playerId = (await client.query(`
      INSERT INTO players(account_id, world_id, x, y, z) VALUES ($1,$2,$3,$4,$5) RETURNING id
    `, [account.id, world.id, position.x, position.y + 0.1, position.z + 12])).rows[0].id;
    const village = (await client.query(`
      INSERT INTO villages(world_id, owner_player_id, slot, name, x, y, z)
      VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id
    `, [world.id, playerId, slot, `${displayName}'s Village`, position.x, position.y, position.z])).rows[0];
    for (const [role, count] of [['soldier', 8], ['villager', 5]]) {
      for (let ordinal = 0; ordinal < count; ordinal++) {
        const x = position.x + (role === 'soldier' ? -23 : 23) + (ordinal % 4) * 3;
        const z = position.z + (role === 'soldier' ? 22 : -16) + Math.floor(ordinal / 4) * 4;
        await client.query(`
          INSERT INTO npcs(village_id, role, ordinal, name, x, y, z, personality)
          VALUES ($1,$2,$3,$4,$5,$6,$7,$8::jsonb)
        `, [village.id, role, ordinal, `${role === 'soldier' ? 'Guard' : 'Settler'} ${ordinal + 1}`,
          x, position.y, z, JSON.stringify({ loyalty: 0.7, courage: role === 'soldier' ? 0.8 : 0.4, sociability: 0.4 + ordinal * 0.05 })]);
      }
    }
    session = await createSession(client, account.id);
    state = await gameState(client, playerId);
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    if (error.code === '23505') throw new ApiError(409, 'account_exists');
    throw error;
  } finally { client.release(); }
  return { session, state };
}

export async function login(pool, body) {
  const email = normalizeEmail(body.email);
  const password = validatePassword(body.password);
  const account = (await pool.query('SELECT id, password_hash FROM accounts WHERE email = $1', [email])).rows[0];
  if (!await verifyPassword(password, account?.password_hash)) throw new ApiError(401, 'invalid_credentials');
  const player = (await pool.query('SELECT id FROM players WHERE account_id = $1', [account.id])).rows[0];
  if (!player) throw new ApiError(503, 'player_unavailable');
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const session = await createSession(client, account.id);
    const state = await gameState(client, player.id);
    await client.query('COMMIT');
    return { session, state };
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally { client.release(); }
}

function villageDTO(row, npcs = []) {
  return {
    id: row.id, ownerPlayerId: row.owner_player_id, name: row.name, stage: row.stage,
    position: { x: row.x, y: row.y, z: row.z },
    soldierCount: npcs.filter((npc) => npc.role === 'soldier').length,
    villagerCount: npcs.filter((npc) => npc.role === 'villager').length,
    npcs: npcs.map((npc) => ({ id: npc.id, name: npc.name, role: npc.role, ordinal: npc.ordinal,
      position: { x: npc.x, y: npc.y, z: npc.z } })),
  };
}

export async function gameState(pool, playerId) {
  const player = (await pool.query(`
    SELECT p.*, a.display_name, w.seed, w.size_m, w.name AS world_name
    FROM players p JOIN accounts a ON a.id = p.account_id JOIN worlds w ON w.id = p.world_id
    WHERE p.id = $1
  `, [playerId])).rows[0];
  if (!player) throw new ApiError(404, 'player_unavailable');
  const village = (await pool.query('SELECT * FROM villages WHERE owner_player_id = $1', [playerId])).rows[0];
  if (!village) throw new ApiError(503, 'village_unavailable');
  const npcs = (await pool.query('SELECT * FROM npcs WHERE village_id = $1 ORDER BY role, ordinal', [village.id])).rows;
  await pool.query('UPDATE players SET last_seen_at = now() WHERE id = $1', [playerId]);
  return {
    player: { id: player.id, displayName: player.display_name, position: { x: player.x, y: player.y, z: player.z }, yaw: player.yaw },
    world: { id: player.world_id, name: player.world_name, seed: player.seed, sizeM: player.size_m, terrainVersion: 1 },
    village: villageDTO(village, npcs),
  };
}

export async function movePlayer(pool, identity, body) {
  const pos = body.position;
  if (!pos || ![pos.x, pos.y, pos.z, body.yaw].every((value) => typeof value === 'number' && Number.isFinite(value))) {
    throw new ApiError(400, 'invalid_position');
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const previous = (await client.query(`
      SELECT p.x, p.y, p.z, p.position_updated_at, p.movement_credit, w.size_m, w.seed,
        extract(epoch FROM (now() - p.position_updated_at))::double precision AS elapsed
      FROM players p JOIN worlds w ON w.id = p.world_id WHERE p.id = $1 FOR UPDATE OF p
    `, [identity.player_id])).rows[0];
    if (!previous) throw new ApiError(404, 'player_unavailable');
    const edge = previous.size_m / 2 - 20;
    if (Math.abs(pos.x) > edge || Math.abs(pos.z) > edge || pos.y < -20 || pos.y > 256) {
      throw new ApiError(400, 'outside_world');
    }
    const travel = Math.hypot(pos.x - previous.x, pos.z - previous.z);
    const allowance = previous.movement_credit + 12 * Math.max(0, Math.min(previous.elapsed, 30));
    if (travel > allowance + 0.000001) {
      throw new ApiError(409, 'movement_rejected');
    }
    const villages = (await client.query(`
      SELECT x,y,z FROM villages WHERE world_id=$1
        AND x BETWEEN $2-125 AND $2+125 AND z BETWEEN $3-125 AND $3+125
      ORDER BY slot
    `, [identity.world_id, pos.x, pos.z])).rows;
    const ground = settledHeight(pos.x, pos.z, previous.seed, villages);
    // Includes the existing building rooftops and jumping. Full building and
    // combat authority are a separate milestone; arbitrary sky/underground saves are refused.
    if (pos.y < ground - 1.5 || pos.y > ground + 16) throw new ApiError(409, 'height_rejected');
    const credit = Math.max(0, Math.min(4, allowance - travel));
    const yaw = ((body.yaw + Math.PI) % (Math.PI * 2) + Math.PI * 2) % (Math.PI * 2) - Math.PI;
    await client.query(`
      UPDATE players SET x=$2, y=$3, z=$4, yaw=$5, movement_credit=$6, position_updated_at=now(), last_seen_at=now()
      WHERE id=$1
    `, [identity.player_id, pos.x, pos.y, pos.z, yaw, credit]);
    await client.query('COMMIT');
    return { position: pos, yaw };
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally { client.release(); }
}

export async function nearbyWorld(pool, identity) {
  const player = (await pool.query('SELECT x,z FROM players WHERE id = $1', [identity.player_id])).rows[0];
  if (!player) throw new ApiError(404, 'player_unavailable');
  const villages = (await pool.query(`
    SELECT * FROM villages WHERE world_id = $1 AND x BETWEEN $2-1024 AND $2+1024
      AND z BETWEEN $3-1024 AND $3+1024 ORDER BY slot LIMIT 25
  `, [identity.world_id, player.x, player.z])).rows;
  const npcs = villages.length ? (await pool.query('SELECT * FROM npcs WHERE village_id = ANY($1::uuid[]) ORDER BY role,ordinal', [villages.map((v) => v.id)])).rows : [];
  const players = (await pool.query(`
    SELECT p.id,a.display_name,p.x,p.y,p.z,p.yaw FROM players p JOIN accounts a ON a.id=p.account_id
    WHERE p.world_id=$1 AND p.id<>$2 AND p.last_seen_at > now() - interval '15 seconds'
      AND p.x BETWEEN $3-800 AND $3+800 AND p.z BETWEEN $4-800 AND $4+800 LIMIT 50
  `, [identity.world_id, identity.player_id, player.x, player.z])).rows;
  return {
    villages: villages.map((village) => villageDTO(village, npcs.filter((npc) => npc.village_id === village.id))),
    players: players.map((p) => ({ id: p.id, displayName: p.display_name, position: { x: p.x, y: p.y, z: p.z }, yaw: p.yaw })),
  };
}
