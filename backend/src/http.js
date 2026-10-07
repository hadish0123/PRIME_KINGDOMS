import { isIP } from 'node:net';
import { ApiError } from './errors.js';

export async function readJSON(req) {
  if (!req.headers['content-type']?.toLowerCase().startsWith('application/json')) throw new ApiError(415, 'json_required');
  const chunks = [];
  let size = 0;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > 16384) throw new ApiError(413, 'request_too_large');
    chunks.push(chunk);
  }
  try {
    const value = JSON.parse(Buffer.concat(chunks).toString('utf8'));
    if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error();
    return value;
  } catch { throw new ApiError(400, 'invalid_json'); }
}

export function createAuthLimiter() {
  const windows = new Map();
  return (req) => {
    // Railway replaces/appends the client address at its trusted edge. Local
    // development uses the socket peer. Do not use the first forwarded value.
    const forwarded = process.env.RAILWAY_PROJECT_ID ? req.headers['x-forwarded-for']?.split(',').at(-1)?.trim() : null;
    const address = forwarded && isIP(forwarded) ? forwarded : req.socket.remoteAddress;
    const now = Date.now();
    for (const [key, window] of windows) if (window.until <= now) windows.delete(key);
    let window = windows.get(address);
    if (!window) {
      if (windows.size >= 5000) throw new ApiError(429, 'rate_limited');
      window = { count: 0, until: now + 60000 };
      windows.set(address, window);
    }
    if (++window.count > 12) throw new ApiError(429, 'rate_limited');
  };
}

export function createGameLimiter({ clock = Date.now, maxKeys = 20000 } = {}) {
  const windows = new Map();
  let pruneAt = 0;
  return (playerId, method, path) => {
    const now = clock();
    if (now >= pruneAt) {
      for (const [key, window] of windows) if (window.until <= now) windows.delete(key);
      pruneAt = now + 10000;
    }
    const lane = path === '/v2/scene/move' ? 'move' : method === 'GET' ? 'read' : 'write';
    const key = `${playerId}:${lane}`;
    let window = windows.get(key);
    if (!window || window.until <= now) {
      if (!window && windows.size >= maxKeys) throw new ApiError(429, 'rate_limited');
      window = { count: 0, until: now + 60000 };
      windows.set(key, window);
    }
    const limit = lane === 'move' ? 300 : lane === 'read' ? 240 : 120;
    if (++window.count > limit) throw new ApiError(429, 'rate_limited');
  };
}
