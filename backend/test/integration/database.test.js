import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { once } from 'node:events';
import pg from 'pg';
import { createDatabase, initializeDatabase, migrate } from '../../src/database.js';
import { createApplication } from '../../src/server.js';

test('real PostgreSQL: concurrent startup, persistence, HTTP and migration integrity', async () => {
  assert.ok(process.env.TEST_DATABASE_URL, 'Set TEST_DATABASE_URL to a disposable PostgreSQL database');
  const admin = new pg.Pool({ connectionString: process.env.TEST_DATABASE_URL });
  const schema = `test_${randomUUID().replaceAll('-', '')}`;
  const scopedUrl = new URL(process.env.TEST_DATABASE_URL);
  scopedUrl.searchParams.set('options', `-c search_path=${schema}`);
  const config = { databaseUrl: scopedUrl.toString(), databasePoolMax: 5, startupAttempts: 1, version: 'test', commit: 'integration' };
  let pool, secondPool, server;
  try {
    await admin.query(`CREATE SCHEMA "${schema}"`);
    pool = createDatabase(config);
    secondPool = createDatabase(config);
    await Promise.all([
      initializeDatabase(pool, config),
      initializeDatabase(secondPool, config),
    ]);
    const initial = (await pool.query('SELECT * FROM worlds')).rows;
    assert.equal(initial.length, 1);
    assert.ok(initial[0].seed > 0);
    await migrate(pool);
    const restarted = (await secondPool.query('SELECT * FROM worlds')).rows[0];
    assert.equal(restarted.id, initial[0].id);
    assert.equal(restarted.seed, initial[0].seed);

    ({ server } = createApplication({ pool, config }));
    server.listen(0, '127.0.0.1');
    await once(server, 'listening');
    const url = `http://127.0.0.1:${server.address().port}`;
    assert.equal((await fetch(`${url}/ready`)).status, 200);
    const response = await fetch(`${url}/v1/world`);
    assert.equal(response.status, 200);
    const world = (await response.json()).world;
    assert.equal(world.id, initial[0].id);
    assert.equal(world.seed, initial[0].seed);
    assert.equal(world.name, 'PRIME KINGDOMS');
    assert.ok(world.createdAt);

    await pool.query("UPDATE schema_migrations SET checksum = 'tampered'");
    await assert.rejects(() => migrate(pool), /Applied migration was modified/);
    assert.equal((await pool.query('SELECT count(*)::int AS total FROM worlds')).rows[0].total, 1);
  } finally {
    if (server) await new Promise((resolve) => server.close(resolve));
    if (pool) await pool.end();
    if (secondPool) await secondPool.end();
    await admin.query(`DROP SCHEMA IF EXISTS "${schema}" CASCADE`);
    await admin.end();
  }
});
