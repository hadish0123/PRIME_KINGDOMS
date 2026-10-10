import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { once } from 'node:events';
import pg from 'pg';
import { createDatabase, migrate } from '../../src/database.js';
import { createApplication } from '../../src/server.js';

test('world conquest and owner capability: global search, NPC camps, empty land and bounded infinity', async () => {
  assert.ok(process.env.TEST_DATABASE_URL, 'Use a disposable PostgreSQL database');
  const admin = new pg.Pool({ connectionString: process.env.TEST_DATABASE_URL });
  const schema = `world_conquest_${randomUUID().replaceAll('-', '')}`;
  const url = new URL(process.env.TEST_DATABASE_URL);
  url.searchParams.set('options', `-c search_path=${schema}`);
  let pool, server;
  try {
    await admin.query(`CREATE SCHEMA "${schema}"`);
    pool = createDatabase({ databaseUrl: url.toString(), databasePoolMax: 5 });
    await migrate(pool);
    const config = { version: 'world-conquest-test', commit: 'test', ownerAccountId: null };
    ({ server } = createApplication({ pool, config }));
    server.listen(0, '127.0.0.1');
    await once(server, 'listening');
    const base = `http://127.0.0.1:${server.address().port}`;

    async function api(path, body, token) {
      const response = await fetch(base + path, {
        method: body === undefined ? 'GET' : 'POST',
        headers: { 'Content-Type':'application/json', ...(token ? { Authorization:`Bearer ${token}` } : {}) },
        ...(body === undefined ? {} : { body:JSON.stringify(body) }),
      });
      return { status:response.status, body:await response.json() };
    }
    async function register(email, displayName) {
      const response = await api('/v1/auth/register', { email, password:'safe-owner-integration-password', displayName });
      assert.equal(response.status,201,JSON.stringify(response.body));
      return { token:response.body.session.token, playerId:response.body.state.player.id };
    }

    const owner = await register('owner@example.com','Prime Owner');
    const rival = await register('rival@example.com','Frontier Rival');
    config.ownerAccountId = (await pool.query('SELECT account_id FROM players WHERE id=$1',[owner.playerId])).rows[0].account_id;

    const ownerState = (await api('/v2/kingdom',undefined,owner.token)).body;
    assert.equal(ownerState.capabilities.role,'owner');
    assert.equal(ownerState.capabilities.unlimitedResources,true);
    assert.equal(ownerState.capabilities.unlimitedArmy,true);
    assert.equal(ownerState.capabilities.divinePower,true);
    assert.equal(ownerState.storageCapacity,null);
    assert.equal(ownerState.armyCapacity,null);
    assert.equal(ownerState.progression.levelDisplay,'∞');
    assert.equal(ownerState.stage,'empire');
    assert.ok(ownerState.realm.ownedTiles < 10,'Owner should not receive a giant starting territory');

    const resourcesBefore = structuredClone(ownerState.resources);
    const upgrade = await api('/v2/buildings/upgrade',{requestId:randomUUID(),key:'keep'},owner.token);
    assert.equal(upgrade.status,200,JSON.stringify(upgrade.body));
    for (const key of Object.keys(resourcesBefore)) assert.equal(upgrade.body.kingdom.resources[key],resourcesBefore[key],'Owner resources must not deplete');

    const preset = await api('/v2/army/preset',{
      requestId:randomUUID(),slot:1,name:'Divine Host',formation:'wedge',stance:'aggressive',isDefense:false,commander:null,
      units:[{type:'trebuchet',quantity:100000}],
    },owner.token);
    assert.equal(preset.status,200,JSON.stringify(preset.body));
    assert.equal(preset.body.command.presets[0].units[0].quantity,100000);

    const map = (await api('/v2/world/map?radius=12',undefined,owner.token)).body;
    assert.equal(map.tiles.length,625);
    assert.ok(map.tiles.some(t=>t.siteType==='npc_camp'),'Large viewport should materialize deterministic NPC camps');
    assert.ok(map.tiles.some(t=>t.biome==='forest'),'Large viewport should contain forest biome');
    assert.ok(map.tiles.some(t=>t.siteType==='wildlife'),'Large viewport should contain wildlife habitats');

    const rivalSearch = await api('/v2/world/search?q=Frontier',undefined,owner.token);
    assert.equal(rivalSearch.status,200);
    const rivalResult = rivalSearch.body.results.find(r=>r.playerId===rival.playerId);
    assert.ok(rivalResult,'Every registered ruler must be searchable before opening the strategy layer');

    const reservedView=(await api(`/v2/world/map?radius=2&x=${rivalResult.x}&z=${rivalResult.z}`,undefined,owner.token)).body;
    const reservedTile=reservedView.tiles.find(t=>t.x===rivalResult.x&&t.z===rivalResult.z);
    assert.ok(reservedTile&&reservedTile.reserved===true&&reservedTile.kind==='settlement','Inactive ruler must appear as a protected virtual settlement');
    assert.equal(reservedTile.ownerPlayerId,rival.playerId);
    assert.equal(reservedTile.attackable,false);
    const rivalKingdom=(await api('/v2/kingdom',undefined,rival.token)).body;
    assert.equal(rivalKingdom.stage,'village');
    const activatedView=(await api(`/v2/world/map?radius=2&x=${rivalResult.x}&z=${rivalResult.z}`,undefined,owner.token)).body;
    assert.ok(activatedView.tiles.some(t=>t.x===rivalResult.x&&t.z===rivalResult.z&&t.kind==='settlement'&&t.ownerPlayerId===rival.playerId&&!t.reserved),'Activation must replace the virtual marker with the authoritative settlement');

    const home = (await pool.query("SELECT x,z,world_id FROM strategic_tiles WHERE owner_player_id=$1 AND kind='settlement' LIMIT 1",[owner.playerId])).rows[0];
    assert.ok(home);
    await pool.query(`
      INSERT INTO strategic_tiles(world_id,x,z,kind,biome,site_type,site_level)
      VALUES($1,$2,$3,'neutral','grassland','empty',0)
      ON CONFLICT(world_id,x,z) DO UPDATE SET owner_player_id=NULL,owner_clan_id=NULL,kind='neutral',
        biome='grassland',site_type='empty',site_level=0,protected_until=NULL,occupied_until=NULL
    `,[home.world_id,home.x+1,home.z]);
    const started = await api('/v2/army/march',{requestId:randomUUID(),kind:'attack',presetSlot:1,x:home.x+1,z:home.z},owner.token);
    assert.equal(started.status,200,JSON.stringify(started.body));
    await pool.query("UPDATE kingdom_marches SET route_started_at=clock_timestamp()-interval '2 seconds',arrives_at=clock_timestamp()-interval '1 second' WHERE id=$1",[started.body.marchId]);
    const command=(await api('/v2/command',undefined,owner.token)).body;
    const march=command.marches.find(m=>m.id===started.body.marchId);
    const report=command.reports.find(r=>r.id===march.reportId);
    assert.equal(report.result,'attacker');
    assert.equal(report.territoryChange,'captured');
    assert.deepEqual(report.rewards,{},'Empty land expands territory but must not be farmable for free resources');
    assert.ok(Object.values(report.attackerLosses).every(loss=>loss.wounded===0&&loss.dead===0));
    assert.equal((await pool.query('SELECT owner_player_id FROM strategic_tiles WHERE world_id=$1 AND x=$2 AND z=$3',[home.world_id,home.x+1,home.z])).rows[0].owner_player_id,owner.playerId);

    const ordinary=(await api('/v2/kingdom',undefined,rival.token)).body;
    assert.notEqual(ordinary.capabilities.role,'owner');
    assert.notEqual(ordinary.storageCapacity,null);
    assert.notEqual(ordinary.armyCapacity,null);
  } finally {
    if (server) await new Promise(resolve=>server.close(resolve));
    if (pool) await pool.end();
    await admin.query(`DROP SCHEMA IF EXISTS "${schema}" CASCADE`);
    await admin.end();
  }
});
