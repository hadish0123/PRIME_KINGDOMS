import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { once } from 'node:events';
import pg from 'pg';
import { createDatabase, initializeDatabase } from '../../src/database.js';
import { createApplication } from '../../src/server.js';

test('real PostgreSQL: register once, rejoin the same village, archived state and opaque sessions', async () => {
  assert.ok(process.env.TEST_DATABASE_URL, 'Set TEST_DATABASE_URL to a disposable database');
  const admin = new pg.Pool({ connectionString: process.env.TEST_DATABASE_URL });
  const schema = `game_${randomUUID().replaceAll('-', '')}`;
  const connection = new URL(process.env.TEST_DATABASE_URL);
  connection.searchParams.set('options', `-c search_path=${schema}`);
  const config = { databaseUrl: connection.toString(), databasePoolMax: 5, startupAttempts: 1, version: 'test', commit: 'integration' };
  let pool, server;
  try {
    await admin.query(`CREATE SCHEMA "${schema}"`);
    pool = createDatabase(config);
    await initializeDatabase(pool, config);
    ({ server } = createApplication({ pool, config }));
    server.listen(0, '127.0.0.1'); await once(server, 'listening');
    const base = `http://127.0.0.1:${server.address().port}`;
    async function api(path, body, token) {
      const response = await fetch(base + path, {
        method: body === undefined ? 'GET' : 'POST',
        headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      });
      return { status: response.status, body: await response.json() };
    }
    const credentials = { email: 'prime@example.com', displayName: 'PRIME', password: 'development-test-password' };
    const first = await api('/v1/auth/register', credentials);
    assert.equal(first.status, 201);
    const state = first.body.state, token = first.body.session.token;
    assert.equal(state.world.sizeM, 65536);
    assert.equal(state.village.soldierCount, 8); assert.equal(state.village.villagerCount, 5);
    assert.equal(new Set(state.village.npcs.map(n => n.id)).size, 13);
    assert.equal(state.village.ownerPlayerId, state.player.id);
    assert.equal((await api('/v1/auth/register', credentials)).status, 409);
    assert.equal((await api('/v1/auth/login', { ...credentials, password: 'incorrect-password' })).status, 401);
    assert.equal((await api('/v1/game')).status, 401);
    const stored = (await pool.query('SELECT * FROM sessions')).rows[0];
    assert.notEqual(stored.token_hash, token);
    assert.equal(stored.token_hash.length, 64);

    const second = await api('/v1/auth/register', { ...credentials, email: 'settler@example.com', displayName: 'Settler' });
    assert.equal(second.status, 201);
    assert.notDeepEqual(second.body.state.village.position, state.village.position);
    const target=state.player.position;
    for(const route of ['/v1/player/move','/v1/player/mount','/v1/player/order','/v1/territory/claim']) {
      assert.equal((await api(route,{},token)).status,404,'Obsolete gameplay route remains active');
    }
    assert.deepEqual((await api('/v1/game',undefined,token)).body.player.position,target);
    const nearby = await api('/v1/world/nearby', undefined, token);
    assert.equal(nearby.status, 200); assert.equal(nearby.body.villages.length, 2);
    assert.equal(nearby.body.players.length, 1);
    assert.equal((await api('/v1/auth/logout', {}, token)).status, 200);
    assert.equal((await api('/v1/game', undefined, token)).status, 401);

    await new Promise(resolve => server.close(resolve)); server = undefined;
    await pool.end(); pool = createDatabase(config); await initializeDatabase(pool, config);
    ({ server } = createApplication({ pool, config })); server.listen(0, '127.0.0.1'); await once(server, 'listening');
    const joined = await fetch(`http://127.0.0.1:${server.address().port}/v1/auth/login`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(credentials),
    });
    assert.equal(joined.status, 200);
    const rejoinedResult = await joined.json();
    const rejoined = rejoinedResult.state;
    assert.equal(rejoined.player.id, state.player.id); assert.deepEqual(rejoined.player.position, target);
    assert.equal(rejoined.village.id, state.village.id);
    assert.deepEqual(rejoined.village.npcs.map(n => n.id).sort(), state.village.npcs.map(n => n.id).sort());
    assert.equal((await pool.query('SELECT count(*)::int AS n FROM npcs')).rows[0].n, 26);
    const restartedBase = `http://127.0.0.1:${server.address().port}`;
    let newestSession;
    for (let attempt = 0; attempt < 5; attempt++) {
      const response = await fetch(restartedBase + '/v1/auth/login', {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(credentials),
      });
      assert.equal(response.status, 200);
      newestSession = (await response.json()).session.token;
    }
    assert.equal((await pool.query('SELECT count(*)::int AS n FROM sessions s JOIN players p ON p.account_id=s.account_id WHERE p.id=$1', [state.player.id])).rows[0].n, 5);
    assert.equal((await fetch(restartedBase + '/v1/game', { headers: { Authorization: `Bearer ${rejoinedResult.session.token}` } })).status, 401);
    assert.equal((await fetch(restartedBase + '/v1/game', { headers: { Authorization: `Bearer ${newestSession}` } })).status, 200);
    const sessions = await pool.query('UPDATE sessions SET expires_at=now()-interval \'1 second\' RETURNING token_hash');
    assert.ok(sessions.rows.length >= 1);
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    if (pool) await pool.end();
    await admin.query(`DROP SCHEMA IF EXISTS "${schema}" CASCADE`); await admin.end();
  }
});
