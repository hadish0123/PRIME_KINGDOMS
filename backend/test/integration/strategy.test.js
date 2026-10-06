import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { once } from 'node:events';
import pg from 'pg';
import { createDatabase, initializeDatabase } from '../../src/database.js';
import { createApplication } from '../../src/server.js';
import { settledHeight } from '../../src/terrain.js';

test('real PostgreSQL: authenticated army march, exclusive land claims, progression and re-entry',async()=>{
  assert.ok(process.env.TEST_DATABASE_URL,'A disposable database is required');
  const admin=new pg.Pool({connectionString:process.env.TEST_DATABASE_URL});
  const schema=`strategy_${randomUUID().replaceAll('-','')}`;
  const url=new URL(process.env.TEST_DATABASE_URL);url.searchParams.set('options',`-c search_path=${schema}`);
  const config={databaseUrl:url.toString(),databasePoolMax:5,startupAttempts:1,version:'test'};
  let pool,server;
  try {
    await admin.query(`CREATE SCHEMA "${schema}"`);
    pool=createDatabase(config);await initializeDatabase(pool,config);
    ({server}=createApplication({pool,config}));server.listen(0,'127.0.0.1');await once(server,'listening');
    const base=`http://127.0.0.1:${server.address().port}`;
    async function api(path,body,token){
      const response=await fetch(base+path,{method:body===undefined?'GET':'POST',headers:{'Content-Type':'application/json',...(token?{Authorization:`Bearer ${token}`}:{})},...(body===undefined?{}:{body:JSON.stringify(body)})});
      return {status:response.status,body:await response.json()};
    }
    const credentials={email:'marcher@example.com',displayName:'Marcher',password:'persistent-strategy-test'};
    const first=await api('/v1/auth/register',credentials);assert.equal(first.status,201);
    const state=first.body.state,token=first.body.session.token;
    const other=await api('/v1/auth/register',{...credentials,email:'neighbor@example.com',displayName:'Neighbor'});
    assert.equal(other.status,201);assert.equal(state.territories.owned,1);
    assert.equal((await api('/v1/player/order',{order:'follow'})).status,401);
    assert.equal((await api('/v1/player/order',{order:'attack'},token)).status,400);
    assert.equal((await api('/v1/territory/claim',{},token)).body.error,'army_required');
    assert.equal(state.player.mount.mounted,false);
    assert.equal((await api('/v1/player/mount',{mounted:true})).status,401);
    assert.equal((await api('/v1/player/mount',{mounted:'true'},token)).status,400);
    assert.equal((await api('/v1/player/mount',{mounted:true},token)).body.error,'horse_too_far');
    assert.equal((await api('/v1/player/order',{order:'follow',playerId:other.body.state.player.id},token)).status,200);
    assert.equal((await api('/v1/game',undefined,other.body.session.token)).body.player.armyOrder,'guard');
    let position={...state.player.position};
    async function march(x,z){
      const distance=Math.hypot(x-position.x,z-position.z),steps=Math.max(1,Math.ceil(distance/10));
      const start={...position};
      for(let i=1;i<=steps;i++){
        const px=start.x+(x-start.x)*i/steps,pz=start.z+(z-start.z)*i/steps;
        const homes=(await pool.query('SELECT x,y,z FROM villages ORDER BY slot')).rows;
        const next={x:px,y:settledHeight(px,pz,state.world.seed,homes)+0.1,z:pz};
        await pool.query("UPDATE players SET position_updated_at=now()-interval '2 seconds' WHERE id=$1",[state.player.id]);
        const response=await api('/v1/player/move',{position:next,yaw:Math.atan2(x-start.x,z-start.z)},token);
        assert.equal(response.status,200,JSON.stringify(response.body));assert.equal(response.body.army.length,8);
        position=next;
      }
    }
    const horse=state.player.mount.position;
    await march(horse.x,horse.z);
    const mounted=await api('/v1/player/mount',{mounted:true,playerId:other.body.state.player.id},token);
    assert.equal(mounted.status,200);assert.equal(mounted.body.mounted,true);
    position=mounted.body.playerPosition;
    assert.equal((await api('/v1/game',undefined,other.body.session.token)).body.player.mount.mounted,false);
    await march(horse.x+18.5,horse.z+4.125);
    const parked={...position};
    const ridingLogin=await api('/v1/auth/login',credentials);
    assert.equal(ridingLogin.body.state.player.mount.mounted,true);
    assert.deepEqual(ridingLogin.body.state.player.mount.position,parked);
    const dismounted=await api('/v1/player/mount',{mounted:false},token);
    assert.equal(dismounted.status,200);assert.equal(dismounted.body.mounted,false);
    assert.deepEqual(dismounted.body.horsePosition,parked);position=dismounted.body.playerPosition;
    await march(-512,0);
    assert.deepEqual((await api('/v1/game',undefined,token)).body.player.mount.position,parked);
    const marchState=(await api('/v1/game',undefined,token)).body;
    assert.deepEqual(marchState.village.npcs.map(n=>n.id),state.village.npcs.map(n=>n.id));
    assert.ok(marchState.village.npcs.filter(n=>n.role==='soldier').every(n=>Math.hypot(n.position.x-position.x,n.position.z-position.z)<40));
    assert.deepEqual(marchState.village.npcs.filter(n=>n.role==='villager'),state.village.npcs.filter(n=>n.role==='villager'));
    const captured=await api('/v1/territory/claim',{position:{x:16000,z:16000},playerId:other.body.state.player.id},token);
    assert.equal(captured.status,200);assert.deepEqual(captured.body.claimed,{x:-1,z:0});assert.equal(captured.body.territories.owned,2);
    assert.equal((await api('/v1/territory/claim',{},token)).body.error,'territory_already_owned');
    await march(-512,-512);assert.equal((await api('/v1/territory/claim',{},token)).status,200);
    await march(0,-512);
    const race=await Promise.all([api('/v1/territory/claim',{},token),api('/v1/territory/claim',{},token)]);
    assert.deepEqual(race.map(r=>r.status).sort(),[200,409]);
    const upgraded=race.find(r=>r.status===200).body;
    assert.equal(upgraded.stage,'city');assert.equal(upgraded.territories.owned,4);
    await march(other.body.state.village.position.x,other.body.state.village.position.z);
    assert.equal((await api('/v1/territory/claim',{},token)).body.error,'territory_occupied');
    // Registration must skip captured spawn cells, never reassign their owner.
    await pool.query("SELECT setval('village_slot_sequence',5,false)");
    const frontier=await api('/v1/auth/register',{...credentials,email:'frontier@example.com',displayName:'Frontier'});
    assert.equal(frontier.status,201);assert.deepEqual(frontier.body.state.village.position.x,512);assert.deepEqual(frontier.body.state.village.position.z,-512);
    assert.equal((await pool.query('SELECT owner_player_id FROM territories WHERE cell_x=-1 AND cell_z=0')).rows[0].owner_player_id,state.player.id);
    const homeId=state.village.id,npcIds=state.village.npcs.map(n=>n.id);
    const joined=await api('/v1/auth/login',credentials);assert.equal(joined.status,200);
    assert.equal(joined.body.state.village.id,homeId);assert.deepEqual(joined.body.state.village.npcs.map(n=>n.id),npcIds);
    assert.equal(joined.body.state.player.armyOrder,'follow');assert.equal(joined.body.state.territories.owned,4);assert.equal(joined.body.state.village.stage,'city');
    assert.equal((await pool.query('SELECT count(*)::int AS n FROM npcs WHERE village_id=$1',[homeId])).rows[0].n,13);
  } finally {
    if(server)await new Promise(resolve=>server.close(resolve));
    if(pool)await pool.end();
    await admin.query(`DROP SCHEMA IF EXISTS "${schema}" CASCADE`);await admin.end();
  }
});
