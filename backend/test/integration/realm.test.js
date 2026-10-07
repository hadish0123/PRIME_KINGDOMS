import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { once } from 'node:events';
import pg from 'pg';
import { createDatabase, migrate } from '../../src/database.js';
import { createApplication } from '../../src/server.js';

test('strategic command: presets, online presence, deterministic battles, reports and realm growth', async () => {
  assert.ok(process.env.TEST_DATABASE_URL, 'Use a disposable PostgreSQL database');
  const admin = new pg.Pool({ connectionString: process.env.TEST_DATABASE_URL });
  const schema = `realm_${randomUUID().replaceAll('-', '')}`;
  const url = new URL(process.env.TEST_DATABASE_URL);
  url.searchParams.set('options', `-c search_path=${schema}`);
  let pool, server;
  try {
    await admin.query(`CREATE SCHEMA "${schema}"`);
    pool = createDatabase({ databaseUrl: url.toString(), databasePoolMax: 6 });
    await migrate(pool);
    ({ server } = createApplication({ pool, config: { version: 'realm-test', commit: 'test' } }));
    server.listen(0, '127.0.0.1');
    await once(server, 'listening');
    const base = `http://127.0.0.1:${server.address().port}`;

    async function api(path, body, user) {
      const response = await fetch(base + path, {
        method: body === undefined ? 'GET' : 'POST',
        headers: { 'Content-Type': 'application/json', ...(user ? { Authorization: `Bearer ${user.token}` } : {}) },
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      });
      return { status: response.status, body: await response.json() };
    }
    async function register(name) {
      const response = await api('/v1/auth/register', {
        email: `${name}-${randomUUID()}@example.com`,
        password: 'safe-strategic-command-password',
        displayName: name,
      });
      assert.equal(response.status, 201);
      const user = { id: response.body.state.player.id, token: response.body.session.token };
      assert.equal((await api('/v2/kingdom', undefined, user)).status, 200);
      return user;
    }
    async function preset(user, slot, quantity, isDefense = false) {
      return api('/v2/army/preset', {
        requestId: randomUUID(),
        slot,
        name: isDefense ? 'Home Guard' : 'Royal Host',
        formation: isDefense ? 'shield' : 'wedge',
        stance: isDefense ? 'defensive' : 'aggressive',
        isDefense,
        units: [{ type: 'swordsman', quantity }],
      }, user);
    }

    async function attack(user, body) {
      const started=await api('/v2/battles/attack',{requestId:randomUUID(),...body},user);
      assert.equal(started.status,200,JSON.stringify(started.body));
      assert.ok(started.body.marchId);
      assert.equal(started.body.battle,undefined,'Departure must not decide victory');
      const due=async()=>pool.query("UPDATE kingdom_marches SET route_started_at=clock_timestamp()-interval '2 seconds',arrives_at=clock_timestamp()-interval '1 second' WHERE id=$1",[started.body.marchId]);
      await due();
      const command=(await api('/v2/command',undefined,user)).body;
      const battle=command.reports.find(r=>r.id===command.marches.find(m=>m.id===started.body.marchId).reportId);
      assert.ok(battle,'Arrival must create the persistent report');
      await due(); await api('/v2/kingdom',undefined,user);
      return {status:200,body:{battle}};
    }

    const attacker = await register('Attacker');
    const defender = await register('Defender');

    const attackPreset = await preset(attacker, 1, 8, false);
    assert.equal(attackPreset.status, 200);
    assert.equal(attackPreset.body.command.presets[0].slot, 1);
    assert.equal((await preset(defender, 1, 4, true)).status, 200);

    const own = (await pool.query(
      "SELECT t.x,t.z,sp.region_id FROM strategic_tiles t JOIN strategic_plots sp ON sp.player_id=t.owner_player_id WHERE t.owner_player_id=$1 AND t.kind='settlement' LIMIT 1",
      [attacker.id],
    )).rows[0];
    assert.ok(own);

    // Put the second disposable account in the same strategic region for presence testing.
    await pool.query(
      'UPDATE strategic_plots SET region_id=$2,plot=63,map_x=$3,map_z=$4 WHERE player_id=$1',
      [defender.id, own.region_id, own.x + 2, own.z],
    );
    assert.equal((await api('/v2/presence', undefined, attacker)).status, 200);
    const presence = (await api('/v2/presence', undefined, defender)).body;
    assert.ok(presence.online >= 2);
    assert.ok(presence.rulers.some(r => r.playerId === attacker.id));
    assert.ok(presence.rulers.some(r => r.playerId === defender.id));

    // One connected neutral tile is enough to prove real capture and progression state.
    await pool.query(
      "INSERT INTO strategic_tiles(world_id,x,z,kind) SELECT world_id,$2,$3,'neutral' FROM players WHERE id=$1 ON CONFLICT(world_id,x,z) DO UPDATE SET owner_player_id=NULL,owner_clan_id=NULL,kind='neutral',protected_until=NULL,occupied_until=NULL",
      [attacker.id, own.x + 1, own.z],
    );
    const neutral = await attack(attacker,{x:own.x+1,z:own.z,presetSlot:1});
    assert.equal(neutral.status, 200, JSON.stringify(neutral.body));
    assert.equal(neutral.body.battle.result, 'attacker');
    assert.equal(neutral.body.battle.territoryChange, 'captured');
    assert.equal((await pool.query('SELECT owner_player_id FROM strategic_tiles WHERE world_id=(SELECT world_id FROM players WHERE id=$1) AND x=$2 AND z=$3', [attacker.id, own.x + 1, own.z])).rows[0].owner_player_id, attacker.id);

    // A real online opponent can own an adjacent non-home tile; server simulation and reports are authoritative.
    await pool.query(
      "INSERT INTO strategic_tiles(world_id,x,z,kind,owner_player_id) SELECT world_id,$2,$3,'neutral',$4 FROM players WHERE id=$1 ON CONFLICT(world_id,x,z) DO UPDATE SET owner_player_id=$4,owner_clan_id=NULL,kind='neutral',protected_until=NULL,occupied_until=NULL",
      [attacker.id, own.x + 2, own.z, defender.id],
    );
    const pvp = await attack(attacker,{x:own.x+2,z:own.z,presetSlot:1});
    assert.equal(pvp.status, 200, JSON.stringify(pvp.body));
    assert.equal(pvp.body.battle.result, 'attacker');
    assert.equal(pvp.body.battle.territoryChange, 'captured');

    const defenderCommand = (await api('/v2/command', undefined, defender)).body;
    assert.ok(defenderCommand.reports.some(r => r.id === pvp.body.battle.id && r.perspective === 'defender'));
    assert.ok(Object.values(defenderCommand.reports.find(r => r.id === pvp.body.battle.id).defenderLosses).some(v => v.wounded + v.dead >= 0));

    const attackerCommand = (await api('/v2/command', undefined, attacker)).body;
    assert.ok(attackerCommand.reports.length >= 2);
    assert.ok(attackerCommand.realm.ownedTiles >= 3);
    assert.ok(attackerCommand.realm.conquests === undefined || attackerCommand.realm.stage);

    // Realm stage is based on server requirements, not a cosmetic client flag.
    await pool.query("UPDATE kingdom_buildings SET level=4 WHERE player_id=$1 AND key='keep'", [attacker.id]);
    await pool.query("UPDATE kingdoms SET xp=(SELECT cumulative_xp FROM kingdom_level_requirements WHERE level=8),conquests=1 WHERE player_id=$1", [attacker.id]);
    await pool.query(
      "INSERT INTO strategic_tiles(world_id,x,z,kind,owner_player_id) SELECT world_id,$2,$3,'neutral',$1 FROM players WHERE id=$1 ON CONFLICT(world_id,x,z) DO UPDATE SET owner_player_id=$1,kind='neutral'",
      [attacker.id, own.x + 1, own.z + 1],
    );
    const incomplete=(await api('/v2/kingdom',undefined,attacker)).body;
    assert.equal(incomplete.stage,'village','Keep and XP must not bypass economic development');
    await pool.query("UPDATE kingdom_buildings SET level=2 WHERE player_id=$1 AND key IN ('farm','lumber_mill')",[attacker.id]);
    const grown = (await api('/v2/kingdom', undefined, attacker)).body;
    assert.equal(grown.stage, 'town');
    assert.equal(grown.realm.stage, 'town');
    assert.equal(grown.realm.next.stage, 'city');
    const promotionGold=grown.resources.gold;
    assert.equal((await api('/v2/kingdom',undefined,attacker)).body.resources.gold,promotionGold,'Promotion paid twice');
    await pool.query("UPDATE kingdom_buildings SET level=1 WHERE player_id=$1 AND key='keep'",[attacker.id]);
    assert.equal((await api('/v2/kingdom',undefined,attacker)).body.stage,'town','Earned realm title regressed');

    // Connected-edge and stale-preset protections are enforced by the server.
    assert.equal((await api('/v2/battles/attack', { requestId: randomUUID(), x: own.x + 30, z: own.z + 30, presetSlot: 1 }, attacker)).body.error, 'target_not_connected');
    await pool.query("UPDATE kingdom_units SET alive=1 WHERE player_id=$1 AND type='swordsman'", [attacker.id]);
    assert.equal((await api('/v2/battles/attack', { requestId: randomUUID(), x: own.x + 3, z: own.z, presetSlot: 1 }, attacker)).body.error, 'army_preset_stale');
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    if (pool) await pool.end();
    await admin.query(`DROP SCHEMA IF EXISTS "${schema}" CASCADE`);
    await admin.end();
  }
});
