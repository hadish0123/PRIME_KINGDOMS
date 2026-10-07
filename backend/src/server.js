import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';
import { ApiError } from './errors.js';
import { authenticate } from './auth.js';
import { register, login, gameState, nearbyWorld } from './game.js';
import { readJSON, createAuthLimiter, createGameLimiter } from './http.js';
import { getKingdom, enqueue, customize } from './kingdom/settlement.js';
import { getScene } from './kingdom/scene.js';
import { getMap } from './kingdom/world_map.js';
import { getClans, clanAction } from './kingdom/clans.js';
import { getCommandState, saveArmyPreset, deleteArmyPreset, attackTerritory, getPresence } from './kingdom/realm.js';
import { getCommanders, recruitCommander, healUnits, getGoals, claimGoal, getInbox, readInbox, getRankings, getChat, socialAction } from './kingdom/experience.js';
import { getWars, declareWar } from './kingdom/wars.js';

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
  const gameLimit = createGameLimiter();
  const routes = new Map([
    ['/', ['GET','HEAD']], ['/health', ['GET','HEAD']], ['/ready', ['GET','HEAD']], ['/v1/world', ['GET','HEAD']],
    ['/v1/auth/register', ['POST']], ['/v1/auth/login', ['POST']], ['/v1/auth/logout', ['POST']],
    ['/v1/game', ['GET']], ['/v1/world/nearby', ['GET']],
    ['/v2/kingdom',['GET']], ['/v2/world/map',['GET']], ['/v2/scene',['GET']], ['/v2/command',['GET']], ['/v2/presence',['GET']],
    ['/v2/buildings/upgrade',['POST']], ['/v2/research/start',['POST']], ['/v2/units/train',['POST']],
    ['/v2/empire/customize',['POST']],
    ['/v2/army/preset',['POST']], ['/v2/army/preset/delete',['POST']], ['/v2/battles/attack',['POST']],
    ['/v2/commanders',['GET']], ['/v2/commanders/recruit',['POST']], ['/v2/units/heal',['POST']],
    ['/v2/goals',['GET']], ['/v2/goals/claim',['POST']], ['/v2/inbox',['GET']], ['/v2/inbox/read',['POST']],
    ['/v2/rankings',['GET']], ['/v2/chat',['GET']], ...['send','block','report'].map(a=>[`/v2/chat/${a}`,['POST']]),
    ['/v2/wars',['GET']], ['/v2/wars/declare',['POST']],
    ['/v2/clans',['GET']], ...['create','join','application','invite','role','leave','kick','donate','describe'].map(action => [`/v2/clans/${action}`,['POST']]),
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
          stage: 'kingdom-strategy',
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
          gameLimit(identity.player_id, req.method, path);
          const body = req.method === 'POST' ? await readJSON(req) : {};
          const handlers = {
            '/v2/kingdom': () => getKingdom(pool, identity),
            '/v2/world/map': () => getMap(pool, identity, new URL(req.url,'http://localhost').searchParams),
            '/v2/scene': () => getScene(pool, identity),
            '/v2/buildings/upgrade': () => enqueue(pool, identity, body, 'building'),
            '/v2/research/start': () => enqueue(pool, identity, body, 'research'),
            '/v2/units/train': () => enqueue(pool, identity, body, 'training'),
            '/v2/empire/customize': () => customize(pool, identity, body),
            '/v2/command': () => getCommandState(pool, identity),
            '/v2/presence': () => getPresence(pool, identity),
            '/v2/army/preset': () => saveArmyPreset(pool, identity, body),
            '/v2/army/preset/delete': () => deleteArmyPreset(pool, identity, body),
            '/v2/battles/attack': () => attackTerritory(pool, identity, body),
            '/v2/clans': () => getClans(pool, identity),
            '/v2/commanders': () => getCommanders(pool, identity),
            '/v2/commanders/recruit': () => recruitCommander(pool, identity, body),
            '/v2/units/heal': () => healUnits(pool, identity, body),
            '/v2/goals': () => getGoals(pool, identity),
            '/v2/goals/claim': () => claimGoal(pool, identity, body),
            '/v2/inbox': () => getInbox(pool, identity),
            '/v2/inbox/read': () => readInbox(pool, identity, body),
            '/v2/rankings': () => getRankings(pool, identity),
            '/v2/chat': () => getChat(pool, identity, new URL(req.url,'http://localhost').searchParams.get('channel') ?? 'global'),
            '/v2/chat/send': () => socialAction(pool, identity, body, 'send'),
            '/v2/chat/block': () => socialAction(pool, identity, body, 'block'),
            '/v2/chat/report': () => socialAction(pool, identity, body, 'report'),
            '/v2/wars': () => getWars(pool, identity),
            '/v2/wars/declare': () => declareWar(pool, identity, body),
          };
          const result = path.startsWith('/v2/clans/') ? await clanAction(pool, identity, body, path.split('/').at(-1)) : await handlers[path]();
          json(res, 200, result, requestId);
          return;
        }
        if (path === '/v1/auth/logout') {
          await pool.query('DELETE FROM sessions WHERE token_hash = $1', [identity.tokenHash]);
          json(res, 200, { status: 'signed_out' }, requestId);
        } else if (path === '/v1/game') {
          json(res, 200, await gameState(pool, identity.player_id), requestId);
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
