import { createHash, randomInt } from 'node:crypto';
import { readFile, readdir } from 'node:fs/promises';
import { setTimeout as delay } from 'node:timers/promises';
import pg from 'pg';

const migrationsDirectory = new URL('../migrations/', import.meta.url);

export function createDatabase(config, logger = console) {
  const pool = new pg.Pool({
    connectionString: config.databaseUrl,
    max: config.databasePoolMax,
    connectionTimeoutMillis: 5000,
    idleTimeoutMillis: 30000,
    statement_timeout: 5000,
    query_timeout: 6000,
    application_name: 'prime-kingdoms-backend',
  });
  pool.on('error', () => logger.error(JSON.stringify({ event: 'database_connection_error' })));
  return pool;
}

export async function migrate(pool) {
  const files = (await readdir(migrationsDirectory))
    .filter((name) => /^\d+_[a-z0-9_]+\.sql$/.test(name)).sort();
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('SELECT pg_advisory_xact_lock(73462710)');
    await client.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        name text PRIMARY KEY,
        checksum text NOT NULL,
        applied_at timestamptz NOT NULL DEFAULT now()
      )
    `);
    const { rows } = await client.query('SELECT name, checksum FROM schema_migrations');
    const applied = new Map(rows.map((row) => [row.name, row.checksum]));
    for (const name of files) {
      const sql = await readFile(new URL(name, migrationsDirectory), 'utf8');
      const checksum = createHash('sha256').update(sql).digest('hex');
      if (applied.has(name)) {
        if (applied.get(name) !== checksum) throw new Error('Applied migration was modified');
        continue;
      }
      await client.query(sql);
      await client.query('INSERT INTO schema_migrations (name, checksum) VALUES ($1, $2)', [name, checksum]);
    }
    await client.query(`
      INSERT INTO worlds (slug, name, seed)
      VALUES ($1, $2, $3)
      ON CONFLICT (slug) DO NOTHING
    `, ['prime-world', 'PRIME KINGDOMS', randomInt(1, 2147483647)]);
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

export async function initializeDatabase(pool, config, logger = console) {
  for (let attempt = 1; attempt <= config.startupAttempts; attempt++) {
    try {
      await migrate(pool);
      return;
    } catch (error) {
      logger.error(JSON.stringify({ event: 'database_startup_retry', attempt }));
      if (attempt === config.startupAttempts) throw error;
      await delay(config.startupRetryMs);
    }
  }
}
