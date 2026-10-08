import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { once } from 'node:events';
import pg from 'pg';
import { createDatabase, migrate } from '../../src/database.js';
import { createApplication } from '../../src/server.js';

test('v2 settlement: forward compatibility, production, timers, replay, races, research and expanding armies', async () => {
  assert.ok(process.env.TEST_DATABASE_URL, 'Use a disposable PostgreSQL database');
  const admin = new pg.Pool({connectionString:process.env.TEST_DATABASE_URL});
  const schema = `kingdom_${randomUUID().replaceAll('-','')}`;
  const url = new URL(process.env.TEST_DATABASE_URL); url.searchParams.set('options',`-c search_path=${schema}`);
  let pool, server;
  try {
    await admin.query(`CREATE SCHEMA "${schema}"`);
    pool = createDatabase({databaseUrl:url.toString(),databasePoolMax:5}); await migrate(pool);
    ({server} = createApplication({pool,config:{version:'strategy-test'}})); server.listen(0,'127.0.0.1'); await once(server,'listening');
    const base = `http://127.0.0.1:${server.address().port}`;
    async function api(path, body, token) {
      const response = await fetch(base+path,{method:body===undefined?'GET':'POST',headers:{'Content-Type':'application/json',...(token?{Authorization:`Bearer ${token}`}:{})},...(body===undefined?{}:{body:JSON.stringify(body)})});
      return {status:response.status,body:await response.json()};
    }
    const user = await api('/v1/auth/register',{email:'kingdom@example.com',password:'safe-integration-password',displayName:'Kingdom'});
    assert.equal(user.status,201); const token=user.body.session.token, legacy=user.body.state, player=legacy.player.id;
    const foreign = await api('/v1/auth/register',{email:'foreign@example.com',password:'safe-integration-password',displayName:'Foreign'});
    assert.equal((await api('/v2/kingdom')).status,401);
    const first=(await api('/v2/kingdom',undefined,token)).body;
    assert.equal(first.progression.level,1); assert.equal(first.buildings.keep,1); assert.equal(first.units[0].alive,8);
    assert.equal(first.buildings.walls,1); assert.equal(first.buildings.gatehouse,1);
    assert.equal(first.progression.xp,0,'Starter enclosure must not grant replayable XP');
    assert.deepEqual(first.command.realm,first.realm,'Settlement and command must share one authoritative realm snapshot');
    assert.deepEqual(first.command.marches,[]);
    assert.equal(first.catalog.filter(c=>c.kind==='building').length,24); assert.equal(first.catalog.filter(c=>c.kind==='unit').length,16);
    assert.deepEqual((await api('/v1/game',undefined,token)).body.village,legacy.village);
    await pool.query("UPDATE kingdoms SET settled_at=clock_timestamp()-interval '1 hour' WHERE player_id=$1",[player]);
    const production=(await api('/v2/kingdom',undefined,token)).body;
    assert.equal(production.resources.food,first.resources.food+80); assert.equal(production.resources.wood,first.resources.wood+60);
    const request={requestId:randomUUID(),key:'keep',playerId:foreign.body.state.player.id,completedAt:'1900-01-01',xp:999999};
    const race=await Promise.all([api('/v2/buildings/upgrade',request,token),api('/v2/buildings/upgrade',request,token)]);
    assert.equal(race[0].status,200); assert.deepEqual(race[0],race[1]);
    assert.equal((await pool.query('SELECT count(*)::int AS n FROM kingdom_tasks WHERE player_id=$1',[player])).rows[0].n,1);
    assert.equal((await api('/v2/buildings/upgrade',{...request,key:'quarry'},token)).body.error,'request_id_conflict');
    assert.equal((await api('/v2/buildings/upgrade',{requestId:randomUUID(),key:'keep'},token)).body.error,'queue_busy');
    const before=(await api('/v2/kingdom',undefined,token)).body;
    assert.equal(before.buildings.keep,1); // Cannot complete by claiming a client timestamp.
    assert.equal((await api('/v2/kingdom',undefined,foreign.body.session.token)).body.buildings.farm,1);
    // Finish the first task via the disposable DB clock fixture, never a public API.
    async function finish(kind) {
      await pool.query("UPDATE kingdom_tasks SET started_at=clock_timestamp()-interval '2 minutes',finishes_at=clock_timestamp()-interval '1 second' WHERE player_id=$1 AND kind=$2 AND completed_at IS NULL",[player,kind]);
      await pool.query("UPDATE kingdoms SET settled_at=clock_timestamp()-interval '2 minutes' WHERE player_id=$1",[player]);
      return (await api('/v2/kingdom',undefined,token)).body;
    }
    const upgraded=await finish('building'); assert.equal(upgraded.buildings.keep,2); assert.equal(upgraded.progression.xp,100);
    assert.deepEqual(upgraded.command.realm,upgraded.realm);
    const xp=upgraded.progression.xp; assert.equal((await api('/v2/kingdom',undefined,token)).body.progression.xp,xp);
    assert.equal((await api('/v2/buildings/upgrade',{requestId:randomUUID(),key:'farm'},token)).status,200);
    assert.equal((await finish('building')).buildings.farm,2);
    const training={requestId:randomUUID(),key:'swordsman',quantity:4};
    assert.equal((await api('/v2/units/train',training,token)).status,200);
    assert.equal((await api('/v2/units/train',{requestId:randomUUID(),key:'archer',quantity:1},token)).body.error,'queue_busy');
    const trained=await finish('training'); assert.equal(trained.units.find(u=>u.type==='swordsman').alive,12);
    assert.equal((await api('/v1/game',undefined,token)).body.village.soldierCount,8); // Legacy identities untouched.
    assert.equal((await api('/v2/units/train',{requestId:randomUUID(),key:'swordsman',quantity:-1},token)).status,400);
    assert.equal((await api('/v2/units/train',{requestId:randomUUID(),key:'royal_cavalry',quantity:1},token)).body.error,'building_required');
    await pool.query("UPDATE kingdom_resources SET amount=5000 WHERE player_id=$1",[player]);
    assert.equal((await api('/v2/buildings/upgrade',{requestId:randomUUID(),key:'academy'},token)).status,200); await finish('building');
    assert.equal((await api('/v2/research/start',{requestId:randomUUID(),key:'economy'},token)).status,200);
    const researched=await finish('research'); assert.equal(researched.research.economy,1); assert.equal(researched.productionPerHour.food,168);
    const customize={requestId:randomUUID(),name:'Emerald Kingdom',primaryColor:'#117744',secondaryColor:'#ddcc22',emblem:'eagle',bannerStyle:'square'};
    assert.equal((await api('/v2/empire/customize',customize,token)).status,200);
    assert.equal((await api('/v2/empire/customize',{...customize,requestId:randomUUID(),emblem:'https://evil/upload.png'},token)).status,400);
    const map=(await api('/v2/world/map',undefined,token)).body; assert.equal(map.tiles.length,49); assert.equal(map.region.kind,'starter');
    assert.ok(map.tiles.some(t=>t.ownerPlayerId===player&&t.primaryColor==='#117744'), JSON.stringify({center:map.center,owned:map.tiles.filter(t=>t.ownerPlayerId),plots:(await pool.query('SELECT * FROM strategic_plots WHERE player_id=$1',[player])).rows}));
    const scene=(await api('/v2/scene',undefined,token)).body; assert.equal(scene.scene.halfSize,128); assert.equal(scene.scene.type,'settlement');
    assert.equal((await api('/v2/scene/move',{position:scene.player.position,yaw:0},token)).status,404);
    assert.equal((await api('/v2/scene/mount',{mounted:true},token)).status,404);
    assert.deepEqual((await api('/v1/game',undefined,token)).body.player.position,legacy.player.position);
    const reentered=(await api('/v2/scene',undefined,token)).body;
    assert.deepEqual(reentered.player.position,scene.player.position);
    await migrate(pool); assert.equal((await api('/v2/kingdom',undefined,token)).body.units.find(u=>u.type==='swordsman').alive,12);
    assert.equal((await pool.query('SELECT count(*)::int AS n FROM kingdom_legacy_units WHERE player_id=$1',[player])).rows[0].n,8);
    await pool.query('UPDATE kingdoms SET xp=8000000000000000 WHERE player_id=$1',[player]);
    assert.equal((await api('/v2/kingdom',undefined,token)).body.progression.level,75); // XP alone cannot bypass prestige/ascension.
  } finally {
    if(server)await new Promise(r=>server.close(r)); if(pool)await pool.end();
    await admin.query(`DROP SCHEMA IF EXISTS "${schema}" CASCADE`); await admin.end();
  }
});
