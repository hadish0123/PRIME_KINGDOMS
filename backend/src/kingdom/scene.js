import { ApiError } from '../errors.js';
import { gameState } from '../game.js';
import { settledHeight } from '../terrain.js';
import { transaction } from './transaction.js';

async function homeAndScene(db, playerId) {
  const home = (await db.query('SELECT v.*,w.seed FROM villages v JOIN worlds w ON w.id=v.world_id WHERE v.owner_player_id=$1', [playerId])).rows[0];
  const scene = (await db.query('SELECT * FROM kingdom_scenes WHERE player_id=$1 FOR UPDATE', [playerId])).rows[0];
  return { home, scene };
}
const worldPoint = (home, x, y, z) => ({ x: home.x + x, y: home.y + y, z: home.z + z });
export function getScene(pool, identity) {
  return transaction(pool, identity, 'scene', {}, async db => {
    const { home, scene } = await homeAndScene(db, identity.player_id);
    const state = await gameState(db, identity.player_id);
    state.player.position = worldPoint(home, scene.x, scene.y, scene.z);
    state.player.yaw = scene.yaw;
    state.player.mount = { mounted: scene.mounted, position: worldPoint(home, scene.horse_x, scene.horse_y, scene.horse_z) };
    // Residents keep their persistent IDs. Legacy expedition positions are
    // projected back to their settlement presentation without changing v1 data.
    for (const n of state.village.npcs) {
      if (Math.abs(n.position.x - home.x) > 120 || Math.abs(n.position.z - home.z) > 120) n.position = worldPoint(home, -23 + (n.ordinal % 4) * 3, .1, 22 + Math.floor(n.ordinal / 4) * 4);
    }
    state.scene = { type: 'settlement', id: home.id, halfSize: 128, mode: 'kingdom_strategy' };
    return state;
  }, { replay: false });
}

export function moveScene(pool, identity, body) {
  const p = body.position;
  if (!p || ![p.x, p.y, p.z, body.yaw].every(n => typeof n === 'number' && Number.isFinite(n))) throw new ApiError(400, 'invalid_position');
  return transaction(pool, identity, 'scene_move', body, async (db, _profile, now) => {
    const { home, scene } = await homeAndScene(db, identity.player_id);
    const x = p.x - home.x, y = p.y - home.y, z = p.z - home.z;
    if (Math.abs(x) > 126 || Math.abs(z) > 126) throw new ApiError(400, 'outside_scene');
    const ground = settledHeight(p.x, p.z, home.seed, [home]);
    if (p.y < ground - 1.5 || p.y > ground + 16) throw new ApiError(409, 'height_rejected');
    const travel = Math.hypot(x - scene.x, z - scene.z);
    const elapsed = Math.max(0, Math.min(30, (now - scene.updated_at) / 1000));
    const allowance = scene.movement_credit + elapsed * (scene.mounted ? 10 : 7);
    if (travel > allowance + .000001) throw new ApiError(409, 'movement_rejected');
    const yaw = ((body.yaw + Math.PI) % (2 * Math.PI) + 2 * Math.PI) % (2 * Math.PI) - Math.PI;
    await db.query('UPDATE kingdom_scenes SET x=$2,y=$3,z=$4,yaw=$5,movement_credit=$6,updated_at=$7,horse_x=CASE WHEN mounted THEN $2 ELSE horse_x END,horse_y=CASE WHEN mounted THEN $3 ELSE horse_y END,horse_z=CASE WHEN mounted THEN $4 ELSE horse_z END WHERE player_id=$1', [identity.player_id, x, y, z, yaw, Math.max(0, Math.min(4, allowance - travel)), now]);
    return { position: p, yaw, army: [] };
  }, { replay: false });
}

export function mountScene(pool, identity, body) {
  if (typeof body.mounted !== 'boolean') throw new ApiError(400, 'invalid_mount');
  return transaction(pool, identity, 'scene_mount', body, async (db, _profile, now) => {
    const { home, scene } = await homeAndScene(db, identity.player_id);
    if (body.mounted === scene.mounted) throw new ApiError(409, 'mount_unchanged');
    if (body.mounted && Math.hypot(scene.x - scene.horse_x, scene.y - scene.horse_y, scene.z - scene.horse_z) > 3.2) throw new ApiError(409, 'horse_too_far');
    const x = body.mounted ? scene.horse_x : scene.x + Math.cos(scene.yaw) * 1.35;
    const z = body.mounted ? scene.horse_z : scene.z - Math.sin(scene.yaw) * 1.35;
    if (Math.abs(x) > 126 || Math.abs(z) > 126) throw new ApiError(409, 'outside_scene');
    const y = body.mounted ? scene.horse_y : settledHeight(home.x + x, home.z + z, home.seed, [home]) - home.y + .1;
    await db.query('UPDATE kingdom_scenes SET mounted=$2,x=$3,y=$4,z=$5,updated_at=$6 WHERE player_id=$1', [identity.player_id, body.mounted, x, y, z, now]);
    return { mounted: body.mounted, playerPosition: worldPoint(home, x, y, z), horsePosition: worldPoint(home, scene.horse_x, scene.horse_y, scene.horse_z), yaw: scene.yaw };
  });
}
