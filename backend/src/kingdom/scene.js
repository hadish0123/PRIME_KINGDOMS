import { gameState } from '../game.js';
import { transaction } from './transaction.js';
export function getScene(pool, identity) {
  return transaction(pool, identity, 'scene', {}, async db => {
    const home = (await db.query('SELECT * FROM villages WHERE owner_player_id=$1', [identity.player_id])).rows[0];
    const state = await gameState(db, identity.player_id);
    // The ruler is a court representation. Archival v1 travel data stays untouched.
    state.player.position = { x:home.x+3, y:home.y+.1, z:home.z-15 };
    state.player.yaw = .45;
    state.player.mount = { mounted:false, position:{x:home.x+14,y:home.y+.1,z:home.z+24} };
    for (const n of state.village.npcs) {
      if (Math.abs(n.position.x-home.x)>120 || Math.abs(n.position.z-home.z)>120) {
        n.position={x:home.x-23+(n.ordinal%4)*3,y:home.y+.1,z:home.z+22+Math.floor(n.ordinal/4)*4};
      }
    }
    state.scene={type:'settlement',id:home.id,halfSize:128,mode:'kingdom_strategy'};
    return state;
  }, { replay:false });
}
