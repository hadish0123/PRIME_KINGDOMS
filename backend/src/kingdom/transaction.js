import { createHash } from 'node:crypto';
import { ApiError } from '../errors.js';

export const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export function integer(value, min, max, code = 'invalid_quantity') {
  if (!Number.isSafeInteger(value) || value < min || value > max) throw new ApiError(400, code);
  return value;
}
export function text(value, min, max, code = 'invalid_name') {
  if (typeof value !== 'string') throw new ApiError(400, code);
  const result = value.trim().normalize('NFKC');
  if (Array.from(result).length < min || Array.from(result).length > max || /[\p{Cc}\p{Cf}<>]/u.test(result)) throw new ApiError(400, code);
  return result;
}
function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map(k => [k, canonical(value[k])]));
  return value;
}

// All domain writes serialize on the same player row. HTTP identity is the only subject.
export async function transaction(pool, identity, operation, body, perform, { replay = true, globalLock = false } = {}) {
  if (replay && !UUID.test(body?.requestId ?? '')) throw new ApiError(400, 'request_id_required');
  const db = await pool.connect();
  try {
    await db.query('BEGIN');
    if (globalLock) await db.query('SELECT pg_advisory_xact_lock(73462712)');
    if (!(await db.query('SELECT id FROM players WHERE id=$1 FOR UPDATE', [identity.player_id])).rows.length) throw new ApiError(404, 'player_unavailable');
    await db.query('SELECT initialize_kingdom($1)', [identity.player_id]);
    const profile = (await db.query('SELECT * FROM kingdoms WHERE player_id=$1 FOR UPDATE', [identity.player_id])).rows[0];
    const hash = createHash('sha256').update(JSON.stringify(canonical(body))).digest('hex');
    if (replay) {
      const previous = (await db.query('SELECT * FROM kingdom_requests WHERE player_id=$1 AND request_id=$2', [identity.player_id, body.requestId])).rows[0];
      if (previous) {
        if (previous.operation !== operation || previous.payload_hash !== hash) throw new ApiError(409, 'request_id_conflict');
        await db.query('COMMIT');
        return previous.response;
      }
    }
    const now = (await db.query('SELECT clock_timestamp() AS now')).rows[0].now;
    const response = await perform(db, profile, now);
    if (replay) await db.query('INSERT INTO kingdom_requests(player_id,request_id,operation,payload_hash,response) VALUES($1,$2,$3,$4,$5)', [identity.player_id, body.requestId, operation, hash, response]);
    await db.query('COMMIT');
    return response;
  } catch (error) {
    await db.query('ROLLBACK').catch(() => {});
    if (error.code === '23505') throw new ApiError(409, 'already_exists');
    throw error;
  } finally { db.release(); }
}
