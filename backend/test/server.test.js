import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { createApplication } from '../src/server.js';

async function fixture(t, pool = { query: async () => ({ rows: [] }) }) {
  const logs = [];
  const app = createApplication({
    pool,
    config: { version: '0.1.0', commit: 'test-commit' },
    logger: { error: (entry) => logs.push(entry) },
  });
  app.server.listen(0, '127.0.0.1');
  await once(app.server, 'listening');
  t.after(() => new Promise((resolve) => app.server.close(resolve)));
  return { ...app, logs, url: `http://127.0.0.1:${app.server.address().port}` };
}

test('liveness works when database is unavailable; readiness fails safely', async (t) => {
  const secret = 'postgresql://admin:secret-value@private-host/db';
  const app = await fixture(t, { query: async () => { throw new Error(secret); } });
  const health = await fetch(`${app.url}/health`);
  assert.equal(health.status, 200);
  const ready = await fetch(`${app.url}/ready`);
  assert.equal(ready.status, 503);
  assert.equal(ready.headers.get('cache-control'), 'no-store');
  assert.equal(ready.headers.get('x-content-type-options'), 'nosniff');
  assert.ok(ready.headers.get('x-request-id'));
  assert.equal((await ready.text()).includes(secret), false);
  assert.equal(app.logs.join('').includes(secret), false);
});

test('readiness succeeds only after a successful database query', async (t) => {
  let probes = 0;
  const app = await fixture(t, { query: async () => { probes++; return { rows: [{ value: 1 }] }; } });
  const response = await fetch(`${app.url}/ready`);
  assert.equal(response.status, 200);
  assert.equal((await response.json()).database, 'connected');
  assert.equal(probes, 1);
});

test('metadata clearly identifies the playable village milestone', async (t) => {
  const app = await fixture(t);
  const body = await (await fetch(app.url)).json();
  assert.equal(body.stage, 'third-person-village');
  assert.equal(body.commit, 'test-commit');
});

test('unknown routes and write methods are unavailable', async (t) => {
  const app = await fixture(t);
  assert.equal((await fetch(`${app.url}/v1/players`)).status, 404);
  const response = await fetch(`${app.url}/v1/world`, { method: 'POST', body: '{}' });
  assert.equal(response.status, 405);
  assert.equal(response.headers.get('allow'), 'GET, HEAD');
});

test('missing world is not reported as a successful playable world', async (t) => {
  const app = await fixture(t);
  const response = await fetch(`${app.url}/v1/world`);
  assert.equal(response.status, 503);
  assert.equal((await response.json()).error, 'world_unavailable');
});

test('draining refuses database traffic while allowing liveness', async (t) => {
  let queries = 0;
  const app = await fixture(t, { query: async () => { queries++; return { rows: [] }; } });
  app.beginDrain();
  assert.equal((await fetch(`${app.url}/ready`)).status, 503);
  assert.equal((await fetch(`${app.url}/v1/world`)).status, 503);
  assert.equal((await fetch(`${app.url}/health`)).status, 200);
  assert.equal(queries, 0);
});
