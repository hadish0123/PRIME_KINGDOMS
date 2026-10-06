import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';

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
  const routes = new Set(['/', '/health', '/ready', '/v1/world']);
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
      if (req.method !== 'GET' && req.method !== 'HEAD') {
        json(res, 405, { error: 'method_not_allowed' }, requestId, { Allow: 'GET, HEAD' });
        return;
      }
      if (path === '/health') {
        json(res, 200, { status: 'ok', service: 'prime-kingdoms-backend' }, requestId);
        return;
      }
      if (path === '/') {
        json(res, 200, {
          project: 'PRIME KINGDOMS',
          stage: 'backend-foundation',
          version: config.version,
          commit: config.commit,
          endpoints: { health: '/health', readiness: '/ready', world: '/v1/world' },
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
      const { rows } = await pool.query(`
        SELECT id, slug, name, seed, created_at
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
        createdAt: world.created_at,
      } }, requestId);
    } catch {
      logger.error(JSON.stringify({ event: 'request_failed', requestId }));
      if (!res.headersSent) json(res, 503, { error: 'service_unavailable' }, requestId);
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
