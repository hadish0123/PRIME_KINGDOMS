import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';
import { ApiError } from './errors.js';
import { authenticate } from './auth.js';
import { register, login, gameState, movePlayer, nearbyWorld } from './game.js';
import { readJSON, createAuthLimiter } from './http.js';
import { commandArmy, claimTerritory, mountHorse } from './strategy.js';
import { getKingdom, enqueue, customize } from './kingdom/settlement.js';
import { getScene, moveScene, mountScene } from './kingdom/scene.js';
import { getMap } from './kingdom/world_map.js';

function json(res, status, value, requestId, headers = {}) {
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff',
    'X-Request-Id': requestId,
    ...headers,
  });
  res.end(JSON.stringify(value));
}

export function createApplication({ pool, config, logger = console }) {
  let draining = false;
  const authLimit = createAuthLimiter();
  const routes = new Map([
    ['/', ['GET','HEAD']], ['/health', ['GET','HEAD']], ['/ready', ['GET','HEAD']], ['/v1/world', ['GET','HEAD']],
    ['/v1/auth/register', ['POST']], ['/v1/auth/login', ['POST']], ['/v1/auth/logout', ['POST']],
    ['/v1/game', ['GET']], ['/v1/player/move', ['POST']], ['/v1/world/nearby', ['GET']],
    ['/v1/player/order',['POST']], ['/v1/territory/claim',['POST']],
    ['/v1/player/mount',['POST']],
    ['/v2/kingdom',['GET']], ['/v2/world/map',['GET']], ['/v2/scene',['GET']],
    ['/v2/buildings/upgrade',['POST']], ['/v2/research/start',['POST']], ['/v2/units/train',['POST']],
    ['/v2/empire/customize',['POST']], ['/v2/scene/move',['POST']], ['/v2/scene/mount',['POST']],
  ]);
  const server = createServer(async (req, res) => {
    const requestId = randomUUID();
    try {
      let path;
      try {
        path = new URL(req.url, 'http://localhost').pathname;
      } catch {
        json(res, 400, { error: 'invalid_request' }, requestId);
        return;
      }
      if (!routes.has(path)) {
        json(res, 404, { error: 'not_found' }, requestId);
        return;
      }
      if (!routes.get(path).includes(req.method)) {
        json(res, 405, { error: 'method_not_allowed' }, requestId, { Allow: routes.get(path).join(', ') });
        return;
      }
      if (path === '/health') {
        json(res, 200, { status: 'ok', service: 'prime-kingdoms-backend' }, requestId);
        return;
      }
      if (path === '/') {
        json(res, 200, {
          project: 'PRIME KINGDOMS',
          stage: 'third-person-village',
          version: config.version,
          commit: config.commit,
          endpoints: { health: '/health', readiness: '/ready', world: '/v1/world', game: '/v1/game' },
        }, requestId);
        return;
      }
      if (draining) {
        json(res, 503, { status: 'unavailable' }, requestId);
        return;
      }
      if (path === '/ready') {
        await pool.query('SELECT 1');
        json(res, 200, { status: 'ready', database: 'connected' }, requestId);
        return;
      }
      if (path === '/v1/auth/register' || path === '/v1/auth/login') {
        authLimit(req);
        const body = await readJSON(req);
        const result = path.endsWith('register') ? await register(pool, body) : await login(pool, body);
        json(res, path.endsWith('register') ? 201 : 200, result, requestId);
        return;
      }
      if (path !== '/v1/world') {
        const identity = await authenticate(pool, req.headers.authorization);
        if (path.startsWith('/v2/')) {
          const body = req.method === 'POST' ? await readJSON(req) : {};
          const handlers = {
            '/v2/kingdom': () => getKingdom(pool, identity),
            '/v2/world/map': () => getMap(pool, identity),
            '/v2/scene': () => getScene(pool, identity),
            '/v2/scene/move': () => moveScene(pool, identity, body),
            '/v2/scene/mount': () => mountScene(pool, identity, body),
            '/v2/buildings/upgrade': () => enqueue(pool, identity, body, 'building'),
            '/v2/research/start': () => enqueue(pool, identity, body, 'research'),
            '/v2/units/train': () => enqueue(pool, identity, body, 'training'),
            '/v2/empire/customize': () => customize(pool, identity, body),
          };
          json(res, 200, await handlers[path](), requestId);
          return;
        }
        if (path === '/v1/auth/logout') {
          await pool.query('DELETE FROM sessions WHERE token_hash = $1', [identity.tokenHash]);
          json(res, 200, { status: 'signed_out' }, requestId);
        } else if (path === '/v1/game') {
          json(res, 200, await gameState(pool, identity.player_id), requestId);
        } else if (path === '/v1/player/move') {
          json(res, 200, await movePlayer(pool, identity, await readJSON(req)), requestId);
        } else if (path === '/v1/player/order') {
          json(res,200,await commandArmy(pool,identity,await readJSON(req)),requestId);
        } else if (path === '/v1/territory/claim') {
          await readJSON(req);
          json(res,200,await claimTerritory(pool,identity),requestId);
        } else if (path === '/v1/player/mount') {
          json(res,200,await mountHorse(pool,identity,await readJSON(req)),requestId);
        } else {
          json(res, 200, await nearbyWorld(pool, identity), requestId);
        }
        return;
      }
      const { rows } = await pool.query(`
        SELECT id, slug, name, seed, size_m, created_at
        FROM worlds WHERE slug = $1
      `, ['prime-world']);
      if (!rows[0]) {
        json(res, 503, { error: 'world_unavailable' }, requestId);
        return;
      }
      const world = rows[0];
      json(res, 200, { world: {
        id: world.id,
        slug: world.slug,
        name: world.name,
        seed: world.seed,
        sizeM: world.size_m,
        terrainVersion: 1,
        createdAt: world.created_at,
      } }, requestId);
    } catch (error) {
      if (!(error instanceof ApiError)) logger.error(JSON.stringify({ message: 'request_failed', requestId }));
      if (!res.headersSent) json(res, error instanceof ApiError ? error.status : 503,
        { error: error instanceof ApiError ? error.code : 'service_unavailable' }, requestId,
        error.status === 429 ? { 'Retry-After': '60' } : {});
      else res.destroy();
    }
  });
  server.requestTimeout = 10000;
  server.headersTimeout = 10000;
  server.keepAliveTimeout = 5000;
  server.maxHeadersCount = 64;
  server.on('clientError', (_, socket) => {
    if (socket.writable) socket.end('HTTP/1.1 400 Bad Request\r\nConnection: close\r\n\r\n');
  });
  return { server, beginDrain: () => { draining = true; } };
}
