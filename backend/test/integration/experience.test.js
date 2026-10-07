import test from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {once} from 'node:events';
import pg from 'pg';
import {createDatabase,migrate} from '../../src/database.js';
import {createApplication} from '../../src/server.js';

test('strategy experience: healing, commanders, goals, dispatches, moderation and complete war lifecycle',async()=>{
 assert.ok(process.env.TEST_DATABASE_URL,'A disposable PostgreSQL database is required');
 const admin=new pg.Pool({connectionString:process.env.TEST_DATABASE_URL});
 const schema='experience_'+randomUUID().replaceAll('-','');
 const url=new URL(process.env.TEST_DATABASE_URL); url.searchParams.set('options','-c search_path='+schema);
 let pool,server;
 try {
  await admin.query('CREATE SCHEMA "'+schema+'"');
  pool=createDatabase({databaseUrl:url.toString(),databasePoolMax:6});
  await migrate(pool); await migrate(pool);
  ({server}=createApplication({pool,config:{version:'experience-test',commit:'test'}}));
  server.listen(0,'127.0.0.1'); await once(server,'listening');
  const base='http://127.0.0.1:'+server.address().port;
  async function api(path,body,user) {
   const r=await fetch(base+path,{method:body===undefined?'GET':'POST',headers:{'Content-Type':'application/json',...(user?{Authorization:'Bearer '+user.token}:{})},...(body===undefined?{}:{body:JSON.stringify(body)})});
   return {status:r.status,body:await r.json()};
  }
  async function ruler(name) {
   const r=await api('/v1/auth/register',{email:name.replaceAll(' ','')+randomUUID()+'@example.com',password:'safe-experience-test-password',displayName:name});
   assert.equal(r.status,201,JSON.stringify(r.body));
   const u={id:r.body.state.player.id,token:r.body.session.token};
   assert.equal((await api('/v2/kingdom',undefined,u)).status,200);
   return u;
  }
  const a=await ruler('North Court'),b=await ruler('South Court');
  assert.equal((await api('/v2/scene/move',{position:{x:0,y:0,z:0},yaw:0},a)).status,404);
  assert.equal((await api('/v2/scene/mount',{mounted:true},a)).status,404);
  assert.equal((await api('/v2/units/heal',{requestId:randomUUID(),key:'swordsman',quantity:1},a)).body.error,'hospital_required');
  await pool.query("UPDATE kingdom_buildings SET level=3 WHERE player_id=$1 AND key IN ('hospital','commander_hall')",[a.id]);
  await pool.query("UPDATE kingdom_units SET wounded=3 WHERE player_id=$1 AND type='swordsman'",[a.id]);
  const treatment={requestId:randomUUID(),key:'swordsman',quantity:2};
  const healing=await api('/v2/units/heal',treatment,a);
  assert.equal(healing.status,200,JSON.stringify(healing.body));
  assert.deepEqual((await api('/v2/units/heal',treatment,a)).body,healing.body);
  assert.equal((await pool.query('SELECT count(*)::int AS n FROM kingdom_healing WHERE player_id=$1',[a.id])).rows[0].n,1);
  await pool.query("UPDATE kingdom_healing SET finishes_at=clock_timestamp()-interval '1 second' WHERE player_id=$1",[a.id]);
  const recovered=(await api('/v2/kingdom',undefined,a)).body;
  assert.equal(recovered.units.find(u=>u.type==='swordsman').wounded,1);
  assert.equal(recovered.units.find(u=>u.type==='swordsman').alive,10);
  assert.equal((await api('/v2/commanders/recruit',{requestId:randomUUID(),key:'arden',xp:999999},a)).status,200);
  assert.equal((await api('/v2/commanders',undefined,a)).body.commanders.find(c=>c.key==='arden').level,1);
  assert.equal((await api('/v2/army/preset',{requestId:randomUUID(),slot:1,name:'Royal Host',formation:'square',stance:'balanced',isDefense:true,commander:'arden',units:[{type:'swordsman',quantity:10}]},a)).status,200);
  assert.equal((await api('/v2/goals/claim',{requestId:randomUUID(),key:'first_keep'},a)).body.error,'goal_incomplete');
  await pool.query("UPDATE kingdom_buildings SET level=2 WHERE player_id=$1 AND key='keep'",[a.id]);
  const claim={requestId:randomUUID(),key:'first_keep'};
  const goal=await api('/v2/goals/claim',claim,a);
  assert.equal(goal.status,200,JSON.stringify(goal.body));
  assert.deepEqual((await api('/v2/goals/claim',claim,a)).body,goal.body);
  assert.equal((await api('/v2/goals/claim',{requestId:randomUUID(),key:'first_keep'},a)).body.error,'goal_claimed');
  const chat={requestId:randomUUID(),channel:'global',message:'The northern gates are open.'};
  assert.equal((await api('/v2/chat/send',chat,a)).status,200);
  assert.equal((await api('/v2/chat/send',chat,a)).status,200);
  assert.equal((await api('/v2/chat/send',{...chat,requestId:randomUUID()},a)).body.error,'chat_too_fast');
  const messages=(await api('/v2/chat?channel=global',undefined,b)).body.messages;
  assert.equal(messages.length,1);
  assert.equal((await api('/v2/chat/report',{requestId:randomUUID(),messageId:messages[0].id,reason:'Needs review',channel:'global'},b)).status,200);
  assert.equal((await api('/v2/chat/block',{requestId:randomUUID(),messageId:messages[0].id,channel:'global'},b)).body.chat.messages.length,0);
  assert.equal((await api('/v2/chat?channel=clan',undefined,b)).body.error,'clan_required');
  const inbox=(await api('/v2/inbox',undefined,a)).body.messages;
  assert.ok(inbox.length>=2);
  assert.equal((await api('/v2/inbox/read',{requestId:randomUUID(),id:inbox[0].id},b)).status,200);
  assert.equal((await api('/v2/inbox',undefined,a)).body.messages[0].read,false);
  assert.equal((await api('/v2/rankings',undefined,a)).body.rulers.length,2);
  // War fixtures adjust server data only; no public endpoint grants XP, currency or clock authority.
  for (const u of [a,b]) {
   await pool.query('UPDATE kingdoms SET xp=(SELECT cumulative_xp FROM kingdom_level_requirements WHERE level=15) WHERE player_id=$1',[u.id]);
   await pool.query("UPDATE kingdom_resources SET amount=5000 WHERE player_id=$1 AND resource='gold'",[u.id]);
  }
  async function clan(u,name,tag) {
   const r=await api('/v2/clans/create',{requestId:randomUUID(),name,tag,admission:'open',emblem:'lion',primaryColor:'#781c2a',secondaryColor:'#d5b35e'},u);
   assert.equal(r.status,200,JSON.stringify(r.body)); return r.body.clans.own.id;
  }
  const ca=await clan(a,'Northern League','NTH'),cb=await clan(b,'Southern League','STH');
  assert.equal((await api('/v2/clans/donate',{requestId:randomUUID(),resource:'gold',amount:1000},a)).status,200);
  const warBody={requestId:randomUUID(),clanId:cb};
  const declared=await api('/v2/wars/declare',warBody,a);
  assert.equal(declared.status,200,JSON.stringify(declared.body));
  assert.equal(declared.body.wars.wars[0].phase,'preparation');
  assert.deepEqual((await api('/v2/wars/declare',warBody,a)).body,declared.body);
  const warId=declared.body.wars.wars[0].id;
  assert.equal((await api('/v2/wars/declare',{requestId:randomUUID(),clanId:ca},b)).body.error,'war_active');
  await pool.query("UPDATE clan_wars SET preparation_ends_at=clock_timestamp()-interval '1 second',battle_ends_at=clock_timestamp()+interval '1 hour' WHERE id=$1",[warId]);
  assert.equal((await api('/v2/wars',undefined,a)).body.wars[0].phase,'battle');
  await pool.query('INSERT INTO clan_war_contributions(war_id,player_id,clan_id,score) VALUES($1,$2,$3,50)',[warId,a.id,ca]);
  await pool.query("UPDATE clan_wars SET attacker_score=50,battle_ends_at=clock_timestamp()-interval '1 second',preparation_ends_at=clock_timestamp()-interval '2 seconds' WHERE id=$1",[warId]);
  const result=(await api('/v2/wars',undefined,a)).body.wars[0];
  assert.equal(result.phase,'result'); assert.equal(result.won,true);
  const medals=(await pool.query('SELECT seasonal_medals FROM kingdoms WHERE player_id=$1',[a.id])).rows[0].seasonal_medals;
  assert.equal(medals,2);
  await api('/v2/wars',undefined,a);
  assert.equal((await pool.query('SELECT seasonal_medals FROM kingdoms WHERE player_id=$1',[a.id])).rows[0].seasonal_medals,medals);
  assert.equal((await api('/v2/wars/declare',{requestId:randomUUID(),clanId:cb},a)).body.error,'war_cooldown');
  for (const u of [a,b]) {
   await pool.query('UPDATE kingdoms SET xp=8000000000000000,prestige=2500,conquests=1000,seasonal_medals=100,ascension_tokens=3 WHERE player_id=$1',[u.id]);
   assert.equal((await api('/v2/kingdom',undefined,u)).body.progression.level,100,'Level 100 is attainable with earned gates, without a global quota');
  }
 } finally {
  if(server) await new Promise(r=>server.close(r));
  if(pool) await pool.end();
  await admin.query('DROP SCHEMA IF EXISTS "'+schema+'" CASCADE'); await admin.end();
 }
});
