// CI-only fixture: never exposes progression mutation through a production API.
import { randomUUID } from 'node:crypto';
import pg from 'pg';
const api = new URL(process.env.PRIME_TEST_API_URL);
const database = new URL(process.env.DATABASE_URL);
if (api.hostname !== '127.0.0.1' || database.hostname !== '127.0.0.1') throw new Error('Native fixture requires disposable localhost API and database');
async function request(path, body, token) {
  const response = await fetch(new URL(path, api), { method: 'POST', headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: JSON.stringify(body) });
  const data = await response.json(); if (!response.ok) throw new Error(`Fixture request failed: ${data.error}`); return data;
}
const suffix = randomUUID().slice(0, 8);
const user = await request('/v1/auth/register', { email: `native-clan-${suffix}@example.com`, password: 'safe-native-clan-fixture', displayName: 'Native Clan Founder' });
const state = await fetch(new URL('/v2/kingdom', api), { headers: { Authorization: `Bearer ${user.session.token}` } });
if (!state.ok) throw new Error('Fixture profile initialization failed');
const pool = new pg.Pool({ connectionString: database.toString() });
try {
  await pool.query('UPDATE kingdoms SET xp=(SELECT cumulative_xp FROM kingdom_level_requirements WHERE level=15) WHERE player_id=$1', [user.state.player.id]);
} finally { await pool.end(); }
const group = await request('/v2/clans/create', { requestId: randomUUID(), name: `Native Clan ${suffix}`, tag: suffix.slice(0, 6).toUpperCase(), emblem: 'sun', primaryColor: '#2244aa', secondaryColor: '#ffdd55', admission: 'open' }, user.session.token);
console.log(group.clans.own.id);
