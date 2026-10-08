import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { once } from 'node:events';
import pg from 'pg';
import { createDatabase, migrate } from '../../src/database.js';
import { createApplication } from '../../src/server.js';

test('clans: level gate, real region, permissions, replay, races and lossless settlement relocation', async () => {
  assert.ok(process.env.TEST_DATABASE_URL, 'Use a disposable PostgreSQL database');
  const admin = new pg.Pool({ connectionString: process.env.TEST_DATABASE_URL });
  const schema = `clans_${randomUUID().replaceAll('-', '')}`;
  const url = new URL(process.env.TEST_DATABASE_URL); url.searchParams.set('options', `-c search_path=${schema}`);
  let pool, server;
  try {
    await admin.query(`CREATE SCHEMA "${schema}"`);
    pool = createDatabase({ databaseUrl: url.toString(), databasePoolMax: 6 }); await migrate(pool);
    ({ server } = createApplication({ pool, config: { version: 'clan-test' } })); server.listen(0, '127.0.0.1'); await once(server, 'listening');
    const base = `http://127.0.0.1:${server.address().port}`;
    async function api(path, body, user) {
      const response = await fetch(base + path, { method: body === undefined ? 'GET' : 'POST', headers: { 'Content-Type': 'application/json', ...(user ? { Authorization: `Bearer ${user.token}` } : {}) }, ...(body === undefined ? {} : { body: JSON.stringify(body) }) });
      return { status: response.status, body: await response.json() };
    }
    async function register(name) {
      const response = await api('/v1/auth/register', { email: `${name}@example.com`, password: 'safe-clan-test-password', displayName: name });
      assert.equal(response.status, 201);
      const user = { id: response.body.state.player.id, token: response.body.session.token, legacy: response.body.state };
      assert.equal((await api('/v2/kingdom', undefined, user)).status, 200);
      return user;
    }
    async function level(user, value) {
      await pool.query('UPDATE kingdoms SET xp=(SELECT cumulative_xp FROM kingdom_level_requirements WHERE level=$2) WHERE player_id=$1', [user.id, value]);
    }
    async function expireCooldown(user) {
      await pool.query("UPDATE clan_player_cooldowns SET join_after=clock_timestamp()-interval '1 second',leave_after=clock_timestamp()-interval '1 second',relocate_after=clock_timestamp()-interval '1 second' WHERE player_id=$1", [user.id]);
    }
    const founder = await register('founder'), applicant = await register('applicant'), invited = await register('invited'), outsider = await register('outsider'), second = await register('second');
    const creation = { requestId: randomUUID(), name: 'Emerald Clan', tag: 'EMR', emblem: 'eagle', primaryColor: '#117744', secondaryColor: '#ddcc22', admission: 'approval', level: 100 };
    assert.equal((await api('/v2/clans/create', creation, founder)).body.error, 'clan_level_15_required');
    await level(founder, 14);
    assert.equal((await api('/v2/clans/create', creation, founder)).body.error, 'clan_level_15_required');
    await level(founder, 15);
    const created = await api('/v2/clans/create', creation, founder);
    assert.equal(created.status, 200); assert.deepEqual(await api('/v2/clans/create', creation, founder), created);
    const clan = created.body.clans.own;
    assert.equal(clan.role, 'leader'); assert.equal(clan.members.length, 1); assert.equal(clan.members[0].plot, 1);
    assert.equal((await api('/v2/kingdom', undefined, founder)).body.resources.gold, 0);
    assert.equal((await pool.query('SELECT count(*)::int AS n FROM strategic_plots WHERE region_id=$1', [clan.regionId])).rows[0].n, 64);
    assert.equal((await pool.query("SELECT count(*)::int AS n FROM strategic_tiles WHERE owner_clan_id=$1 AND kind='fort'", [clan.id])).rows[0].n, 1);
    const clanMap = (await api('/v2/world/map', undefined, founder)).body;
    assert.equal(clanMap.region.kind, 'clan'); assert.equal(clanMap.region.id, clan.regionId);
    assert.deepEqual(clan.bounds,{minX:clan.capital.x,minZ:clan.capital.z,maxX:clan.capital.x+7,maxZ:clan.capital.z+7});
    assert.deepEqual(clanMap.regions.find(r=>r.clanId===clan.id).bounds,clan.bounds);
    assert.equal(clanMap.regions.find(r=>r.clanId===clan.id).secondaryColor,'#ddcc22');
    const farMap=(await api('/v2/world/map?x=90000&z=90000',undefined,founder)).body;
    assert.equal(farMap.regions.length,0,'A distant view exposed an unrelated clan boundary');
    assert.ok(clanMap.tiles.some(t => t.ownerClanId === clan.id && t.kind === 'fort' && t.primaryColor === '#117744'));
    assert.deepEqual((await api('/v1/game', undefined, founder)).body.village, founder.legacy.village);
    await level(second, 15);
    const other = (await api('/v2/clans/create', { ...creation, requestId: randomUUID(), name: 'Sun Clan', tag: 'SUN', admission: 'open' }, second)).body.clans.own;
    assert.ok(other.id);
    assert.equal((await api('/v2/clans/application', { requestId: randomUUID(), clanId: clan.id, playerId: applicant.id, decision: 'accept' }, outsider)).body.error, 'clan_permission');
    assert.equal((await api('/v2/clans/join', { requestId: randomUUID(), clanId: clan.id }, applicant)).status, 200);
    assert.equal((await api('/v2/clans', undefined, applicant)).body.own, null);
    assert.equal((await api('/v2/clans', undefined, founder)).body.own.applications[0].playerId, applicant.id);
    // Snapshot all existing persistent records before membership changes.
    async function persistent(user) {
      const result = {};
      for (const table of ['kingdom_buildings', 'kingdom_research', 'kingdom_resources', 'kingdom_units', 'kingdom_tasks', 'kingdom_scenes']) result[table] = (await pool.query(`SELECT * FROM ${table} WHERE player_id=$1 ORDER BY 1,2`, [user.id])).rows;
      result.kingdom = (await pool.query('SELECT * FROM kingdoms WHERE player_id=$1', [user.id])).rows;
      result.village = (await pool.query('SELECT * FROM villages WHERE owner_player_id=$1', [user.id])).rows;
      result.npcs = (await pool.query('SELECT n.* FROM npcs n JOIN villages v ON v.id=n.village_id WHERE v.owner_player_id=$1 ORDER BY n.id', [user.id])).rows;
      return result;
    }
    assert.equal((await api('/v2/buildings/upgrade', { requestId: randomUUID(), key: 'keep' }, applicant)).status, 200);
    const before = await persistent(applicant);
    const originalProtection = (await pool.query("SELECT protected_until FROM strategic_tiles WHERE owner_player_id=$1 AND kind='settlement'", [applicant.id])).rows[0].protected_until;
    const accept = { requestId: randomUUID(), clanId: clan.id, playerId: applicant.id, decision: 'accept' };
    const accepted = await Promise.all([api('/v2/clans/application', accept, founder), api('/v2/clans/application', accept, founder)]);
    assert.equal(accepted[0].status, 200); assert.deepEqual(accepted[0], accepted[1]);
    assert.deepEqual(await persistent(applicant), before);
    assert.equal((await api('/v2/clans', undefined, applicant)).body.own.role, 'member');
    assert.deepEqual((await pool.query("SELECT protected_until FROM strategic_tiles WHERE owner_player_id=$1 AND kind='settlement'", [applicant.id])).rows[0].protected_until, originalProtection);
    assert.equal((await api('/v2/clans/leave', { requestId: randomUUID() }, applicant)).body.error, 'clan_cooldown');
    assert.equal((await api('/v2/clans/join', { requestId: randomUUID(), clanId: other.id }, applicant)).body.error, 'already_in_clan');
    assert.equal((await api('/v2/clans/role', { requestId: randomUUID(), clanId: clan.id, playerId: founder.id, role: 'member' }, applicant)).body.error, 'clan_permission');
    assert.equal((await api('/v2/clans/invite', { requestId: randomUUID(), clanId: clan.id, playerId: invited.id }, founder)).status, 200);
    assert.equal((await api('/v2/clans', undefined, invited)).body.invitations.length, 1);
    const joins = await Promise.all([api('/v2/clans/join', { requestId: randomUUID(), clanId: clan.id }, invited), api('/v2/clans/join', { requestId: randomUUID(), clanId: other.id }, invited)]);
    assert.equal(joins.filter(r => r.status === 200).length, 1); assert.equal(joins.filter(r => r.body.error === 'already_in_clan').length, 1);
    assert.equal((await pool.query('SELECT count(*)::int AS n FROM strategic_plots WHERE player_id=$1', [invited.id])).rows[0].n, 1);
    assert.equal((await pool.query("SELECT count(*)::int AS n FROM strategic_tiles WHERE owner_player_id=$1 AND kind='settlement'", [invited.id])).rows[0].n, 1);
    const donation = { requestId: randomUUID(), resource: 'wood', amount: 25 };
    const donated = await api('/v2/clans/donate', donation, applicant); assert.equal(donated.status, 200);
    assert.deepEqual(await api('/v2/clans/donate', donation, applicant), donated); assert.equal(donated.body.clans.own.treasury.wood, 25);
    assert.equal((await api('/v2/clans/donate', { ...donation, amount: 30 }, applicant)).body.error, 'request_id_conflict');
    assert.equal((await api('/v2/clans/donate', { ...donation, requestId: randomUUID(), amount: -3 }, applicant)).status, 400);
    await expireCooldown(applicant);
    const war = (await pool.query("INSERT INTO clan_wars(attacker_id,defender_id,phase,preparation_ends_at,battle_ends_at) VALUES($1,$2,'preparation',clock_timestamp()+interval '1 hour',clock_timestamp()+interval '2 hours') RETURNING id", [clan.id, other.id])).rows[0];
    assert.equal((await api('/v2/clans/leave', { requestId: randomUUID() }, applicant)).body.error, 'clan_at_war');
    assert.equal((await api('/v2/clans/join', { requestId: randomUUID(), clanId: other.id }, outsider)).body.error, 'clan_at_war');
    await pool.query("UPDATE clan_wars SET phase='result' WHERE id=$1", [war.id]);
    const beforeLeave = await persistent(applicant);
    assert.equal((await api('/v2/clans/leave', { requestId: randomUUID() }, applicant)).status, 200);
    assert.deepEqual(await persistent(applicant), beforeLeave);
    const resettled = (await api('/v2/world/map', undefined, applicant)).body;
    assert.equal(resettled.region.kind, 'starter'); assert.equal((await api('/v2/clans', undefined, applicant)).body.own, null);
    assert.equal((await api('/v2/clans/join', { requestId: randomUUID(), clanId: other.id }, applicant)).body.error, 'clan_cooldown');
    assert.equal((await pool.query('SELECT count(*)::int AS n FROM settlement_relocations WHERE player_id=$1', [applicant.id])).rows[0].n, 2);
    assert.equal((await api('/v2/clans/leave', { requestId: randomUUID() }, founder)).body.error, 'transfer_leadership_required');
    // Upgrade reruns cannot put a clan member back in the original starter plot.
    await migrate(pool);
    assert.equal((await api('/v2/world/map', undefined, founder)).body.region.id, clan.regionId);
    assert.equal((await api('/v2/clans/invite', { requestId: randomUUID(), clanId: clan.id, playerId: outsider.id }, founder)).status, 200);
    assert.equal((await api('/v2/clans/join', { requestId: randomUUID(), clanId: clan.id }, outsider)).status, 200);
    assert.equal((await api('/v2/clans/role', { requestId: randomUUID(), clanId: clan.id, playerId: outsider.id, role: 'officer' }, founder)).status, 200);
    assert.equal((await api('/v2/clans/role', { requestId: randomUUID(), clanId: clan.id, playerId: founder.id, role: 'member' }, outsider)).body.error, 'clan_permission');
    assert.equal((await api('/v2/clans/kick', { requestId: randomUUID(), playerId: founder.id }, outsider)).body.error, 'clan_permission');
    assert.equal((await api('/v2/clans/role', { requestId: randomUUID(), clanId: clan.id, playerId: outsider.id, role: 'leader' }, founder)).status, 200);
    assert.equal((await api('/v2/clans', undefined, founder)).body.own.leaderId, outsider.id);
    assert.equal((await api('/v2/clans', undefined, founder)).body.own.role, 'officer');
    await expireCooldown(founder);
    const founderBefore = await persistent(founder);
    assert.equal((await api('/v2/clans/kick', { requestId: randomUUID(), playerId: founder.id }, outsider)).status, 200);
    assert.deepEqual(await persistent(founder), founderBefore);
    assert.equal((await api('/v2/world/map', undefined, founder)).body.region.kind, 'starter');
    assert.equal((await api('/v2/clans', undefined, founder)).body.own, null);
  } finally {
    if (server) await new Promise(r => server.close(r)); if (pool) await pool.end();
    await admin.query(`DROP SCHEMA IF EXISTS "${schema}" CASCADE`); await admin.end();
  }
});
