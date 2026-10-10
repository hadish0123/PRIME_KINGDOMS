import { createHash } from 'node:crypto';
import pg from 'pg';

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) throw new Error('DATABASE_URL is required');

const pool = new pg.Pool({
  connectionString: databaseUrl,
  max: 1,
  connectionTimeoutMillis: 8000,
  statement_timeout: 12000,
  query_timeout: 15000,
  application_name: 'prime-kingdoms-db-fingerprint',
});

const tables = [
  'accounts','players','worlds','villages','territories','npcs',
  'kingdoms','kingdom_resources','kingdom_buildings','kingdom_research',
  'kingdom_units','kingdom_tasks','kingdom_healing',
  'strategic_regions','strategic_plots','strategic_tiles',
  'army_presets','kingdom_marches','battle_reports',
  'clans','clan_members','clan_wars','kingdom_capabilities'
];

try {
  const migrations = (await pool.query(
    'SELECT name,checksum FROM schema_migrations ORDER BY name'
  )).rows;
  const counts = {};
  for (const table of tables) {
    const exists = (await pool.query(
      'SELECT to_regclass($1) AS name', ['public.' + table]
    )).rows[0].name;
    counts[table] = exists
      ? Number((await pool.query('SELECT count(*)::bigint AS n FROM ' + table)).rows[0].n)
      : null;
  }
  const worlds = (await pool.query(
    'SELECT id::text,slug,name,seed FROM worlds ORDER BY id'
  )).rows;
  const document = {
    schemaMigrations: migrations,
    counts,
    worlds,
  };
  const canonical = JSON.stringify(document);
  const fingerprint = createHash('sha256').update(canonical).digest('hex');
  process.stdout.write(JSON.stringify({ fingerprint, ...document }, null, 2) + '\n');
} finally {
  await pool.end();
}
