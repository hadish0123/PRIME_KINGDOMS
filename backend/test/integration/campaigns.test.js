import test from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {once} from 'node:events';
import pg from 'pg';
import {createDatabase,migrate} from '../../src/database.js';
import {createApplication} from '../../src/server.js';
import {processDueMarches,startMarchWorker} from '../../src/kingdom/campaigns.js';

test('campaign authority: reservations, recall, offline arrivals, allied defense and safe relocation',async()=>{
 assert.ok(process.env.TEST_DATABASE_URL,'Use a disposable PostgreSQL database');
 const admin=new pg.Pool({connectionString:process.env.TEST_DATABASE_URL});
 const schema='campaign_'+randomUUID().replaceAll('-','');
 const url=new URL(process.env.TEST_DATABASE_URL);url.searchParams.set('options','-c search_path='+schema);
 let pool,server,worker;
 try {
  await admin.query('CREATE SCHEMA "'+schema+'"');
  pool=createDatabase({databaseUrl:url.toString(),databasePoolMax:8});await migrate(pool);await migrate(pool);
  ({server}=createApplication({pool,config:{version:'campaign-test'},logger:{error(){}}}));
  server.listen(0,'127.0.0.1');await once(server,'listening');
  const base='http://127.0.0.1:'+server.address().port;
  async function api(path,body,user){
   const r=await fetch(base+path,{method:body===undefined?'GET':'POST',headers:{'Content-Type':'application/json',...(user?{Authorization:'Bearer '+user.token}:{})},...(body===undefined?{}:{body:JSON.stringify(body)})});
   return {status:r.status,body:await r.json()};
  }
  async function ruler(name){
   const r=await api('/v1/auth/register',{email:name+randomUUID()+'@example.com',password:'safe-campaign-test-password',displayName:name});
   assert.equal(r.status,201);const u={id:r.body.state.player.id,token:r.body.session.token};
   await api('/v2/kingdom',undefined,u);return u;
  }
  async function preset(u,n){const r=await api('/v2/army/preset',{requestId:randomUUID(),slot:1,name:'Royal Host',formation:'shield',stance:'defensive',isDefense:true,units:[{type:'swordsman',quantity:n}]},u);assert.equal(r.status,200,JSON.stringify(r.body));}
  async function expire(id){await pool.query("UPDATE kingdom_marches SET route_started_at=clock_timestamp()-interval '2 seconds',arrives_at=clock_timestamp()-interval '1 second' WHERE id=$1",[id]);}
  async function march(u,x,z,kind='attack'){return api('/v2/army/march',{requestId:randomUUID(),presetSlot:1,x,z,kind},u);}
  async function homecoming(id){await expire(id);await processDueMarches(pool);}
  const a=await ruler('Marcher'),b=await ruler('Ally'),c=await ruler('Reinforcer');
  const home=(await pool.query('SELECT map_x AS x,map_z AS z FROM strategic_plots WHERE player_id=$1',[a.id])).rows[0];
  const world=(await pool.query('SELECT world_id FROM players WHERE id=$1',[a.id])).rows[0].world_id;
  const x=home.x+1,z=home.z;
  await pool.query("INSERT INTO strategic_tiles(world_id,x,z,kind) VALUES($1,$2,$3,'neutral') ON CONFLICT(world_id,x,z) DO UPDATE SET kind='neutral',owner_player_id=NULL,owner_clan_id=NULL,protected_until=NULL,occupied_until=NULL",[world,x,z]);
  await preset(a,8);
  const raced=await Promise.all([march(a,x,z),march(a,x,z)]);
  assert.deepEqual(raced.map(r=>r.status).sort(),[200,409]);
  const first=raced.find(r=>r.status===200);
  assert.equal(first.body.battle,undefined);assert.equal(first.body.command.reports.length,0);
  let units=(await api('/v2/kingdom',undefined,a)).body.units[0];
  assert.equal(units.alive,8);assert.equal(units.available,0);assert.equal(units.deployed,8);
  assert.equal((await api('/v2/army/recall',{requestId:randomUUID(),marchId:first.body.marchId},b)).body.error,'march_unavailable');
  const recalled=await api('/v2/army/recall',{requestId:randomUUID(),marchId:first.body.marchId},a);
  assert.equal(recalled.body.command.marches[0].phase,'returning');
  const returnTime=recalled.body.command.marches[0].route.arrivesAt;
  assert.equal((await api('/v2/army/recall',{requestId:randomUUID(),marchId:first.body.marchId},a)).body.command.marches[0].route.arrivesAt,returnTime,'Repeated recall reset return time');
  assert.equal((await api('/v2/kingdom',undefined,a)).body.units[0].available,0,'Recall teleported soldiers home');
  await homecoming(first.body.marchId);assert.equal((await api('/v2/kingdom',undefined,a)).body.units[0].available,8);
  const order={requestId:randomUUID(),presetSlot:1,x,z,kind:'attack',victory:true,arrivesAt:'1900-01-01',rewards:{gold:999999}};
  const depart=await api('/v2/army/march',order,a);assert.equal(depart.status,200);
  assert.deepEqual((await api('/v2/army/march',order,a)).body,depart.body);
  assert.equal(depart.body.command.reports.length,0);
  assert.equal((await pool.query("SELECT count(*)::int AS n FROM kingdom_marches WHERE player_id=$1 AND phase='outbound'",[a.id])).rows[0].n,1);
  await preset(a,1); // Departure freezes the actual army, independent of later blueprint edits.
  await pool.query("UPDATE players SET last_seen_at=clock_timestamp()-interval '1 hour' WHERE id=$1",[a.id]);
  const oldSeen=(await pool.query('SELECT last_seen_at FROM players WHERE id=$1',[a.id])).rows[0].last_seen_at;
  await expire(depart.body.marchId);await Promise.all([processDueMarches(pool),processDueMarches(pool)]);
  let row=(await pool.query('SELECT * FROM kingdom_marches WHERE id=$1',[depart.body.marchId])).rows[0];
  assert.equal(row.phase,'returning');assert.ok(row.report_id);
  assert.equal((await pool.query('SELECT last_seen_at FROM players WHERE id=$1',[a.id])).rows[0].last_seen_at.getTime(),oldSeen.getTime(),'Offline simulation changed online presence');
  const report=(await api('/v2/command',undefined,a)).body.reports[0];
  assert.equal(report.replay.attacker[0].quantity,8);assert.equal(report.result,'attacker');assert.equal(report.territoryChange,'captured');
  assert.equal((await pool.query('SELECT count(*)::int AS n FROM kingdom_battles WHERE attacker_id=$1',[a.id])).rows[0].n,1,'Arrival resolved twice');
  await homecoming(depart.body.marchId);units=(await api('/v2/kingdom',undefined,a)).body.units[0];
  assert.equal(units.available,units.alive);assert.equal(units.deployed,0);assert.equal(units.alive+units.wounded+units.dead,8);
  const nx=x+1;await pool.query("INSERT INTO strategic_tiles(world_id,x,z,kind) VALUES($1,$2,$3,'neutral')",[world,nx,z]);
  const changed=await march(a,nx,z);assert.equal(changed.status,200);
  await pool.query("UPDATE strategic_tiles SET protected_until=clock_timestamp()+interval '1 hour' WHERE world_id=$1 AND x=$2 AND z=$3",[world,nx,z]);
  await expire(changed.body.marchId);await processDueMarches(pool);
  row=(await pool.query('SELECT * FROM kingdom_marches WHERE id=$1',[changed.body.marchId])).rows[0];
  assert.equal(row.phase,'returning');assert.equal(row.return_reason,'target_protected');assert.equal(row.report_id,null);await homecoming(row.id);
  await pool.query('UPDATE strategic_tiles SET protected_until=NULL WHERE world_id=$1 AND x=$2 AND z=$3',[world,nx,z]);
  const pending=await march(a,nx,z);assert.equal(pending.status,200);await expire(pending.body.marchId);
  const failures=[];worker=startMarchWorker(pool,{error(v){failures.push(v);}});
  for(let i=0;i<80;i++){row=(await pool.query('SELECT phase FROM kingdom_marches WHERE id=$1',[pending.body.marchId])).rows[0];if(row.phase==='returning')break;await new Promise(r=>setTimeout(r,25));}
  await worker.stop();worker=null;assert.deepEqual(failures,[]);assert.equal(row.phase,'returning');await homecoming(pending.body.marchId);
  for(const u of [b,c]){await pool.query('UPDATE kingdoms SET xp=(SELECT cumulative_xp FROM kingdom_level_requirements WHERE level=15) WHERE player_id=$1',[u.id]);await pool.query("UPDATE kingdom_resources SET amount=5000 WHERE player_id=$1 AND resource='gold'",[u.id]);}
  const clan=await api('/v2/clans/create',{requestId:randomUUID(),name:'Campaign League',tag:'CMP',admission:'open',emblem:'lion',primaryColor:'#781c2a',secondaryColor:'#d5b35e'},b);
  assert.equal(clan.status,200,JSON.stringify(clan.body));assert.equal((await api('/v2/clans/join',{requestId:randomUUID(),clanId:clan.body.clans.own.id},c)).status,200);
  const allyHome=(await pool.query('SELECT map_x AS x,map_z AS z FROM strategic_plots WHERE player_id=$1',[b.id])).rows[0];
  assert.equal((await march(a,allyHome.x,allyHome.z,'reinforce')).body.error,'reinforcement_ally_required');
  await pool.query("UPDATE kingdom_units SET alive=1000 WHERE player_id=$1 AND type='swordsman'",[c.id]);await preset(c,1000);
  const reinforcement=await march(c,allyHome.x,allyHome.z,'reinforce');assert.equal(reinforcement.status,200,JSON.stringify(reinforcement.body));await expire(reinforcement.body.marchId);await processDueMarches(pool);
  assert.equal((await api('/v2/command',undefined,c)).body.marches[0].phase,'stationed');assert.equal((await api('/v2/kingdom',undefined,c)).body.units[0].available,0);assert.equal((await api('/v2/command',undefined,b)).body.incoming[0].phase,'stationed');
  await pool.query("UPDATE clan_player_cooldowns SET leave_after='-infinity',relocate_after='-infinity' WHERE player_id=$1",[c.id]);
  const before=(await api('/v2/kingdom',undefined,c)).body;
  assert.equal((await api('/v2/clans/leave',{requestId:randomUUID()},c)).body.error,'army_away');
  const after=(await api('/v2/kingdom',undefined,c)).body;
  assert.equal(after.settlementId,before.settlementId);assert.deepEqual(after.units,before.units);assert.deepEqual(after.buildings,before.buildings);assert.equal((await api('/v2/clans',undefined,c)).body.own.id,clan.body.clans.own.id);
  await pool.query("UPDATE kingdom_units SET alive=1000 WHERE player_id=$1 AND type='swordsman'",[a.id]);await preset(a,1000);
  await pool.query('UPDATE kingdom_units SET alive=0 WHERE player_id=$1',[b.id]);
  await pool.query('UPDATE strategic_tiles SET protected_until=NULL WHERE world_id=$1 AND x=$2 AND z=$3',[world,allyHome.x,allyHome.z]);
  await pool.query("INSERT INTO strategic_tiles(world_id,x,z,kind,owner_player_id) VALUES($1,$2,$3,'neutral',$4) ON CONFLICT(world_id,x,z) DO UPDATE SET owner_player_id=$4,owner_clan_id=NULL,kind='neutral'",[world,allyHome.x-1,allyHome.z,a.id]);
  const assault=await march(a,allyHome.x,allyHome.z);assert.equal(assault.status,200,JSON.stringify(assault.body));await expire(assault.body.marchId);await processDueMarches(pool);
  const guardReport=(await api('/v2/command',undefined,c)).body.reports[0];
  assert.ok(guardReport.defenderPower>0);assert.equal(guardReport.reinforcementLosses.length,1);
  const guardLoss=guardReport.reinforcementLosses[0].losses.swordsman;assert.ok(guardLoss.wounded+guardLoss.dead>0);
  units=(await api('/v2/kingdom',undefined,c)).body.units[0];assert.equal(units.alive+units.wounded+units.dead,1000);assert.equal(units.available,0);assert.equal(units.deployed,units.alive);
  assert.equal((await api('/v2/command',undefined,b)).body.reports[0].id,guardReport.id);await homecoming(assault.body.marchId);
  await pool.query('UPDATE clans SET leader_id=$2 WHERE id=$1',[clan.body.clans.own.id,c.id]);
  await pool.query("UPDATE clan_members SET role=CASE WHEN player_id=$2 THEN 'leader' ELSE 'member' END WHERE clan_id=$1",[clan.body.clans.own.id,c.id]);
  await pool.query("UPDATE clan_player_cooldowns SET leave_after='-infinity',relocate_after='-infinity' WHERE player_id=$1",[b.id]);
  const hostId=(await api('/v2/kingdom',undefined,b)).body.settlementId;
  const departed=await api('/v2/clans/leave',{requestId:randomUUID()},b);assert.equal(departed.status,200,JSON.stringify(departed.body));assert.equal((await api('/v2/kingdom',undefined,b)).body.settlementId,hostId);
  row=(await pool.query('SELECT * FROM kingdom_marches WHERE id=$1',[reinforcement.body.marchId])).rows[0];assert.equal(row.phase,'returning');assert.equal(row.return_reason,'ally_relocated');await homecoming(row.id);
  units=(await api('/v2/kingdom',undefined,c)).body.units[0];assert.equal(units.available,units.alive);
  await migrate(pool);assert.equal((await api('/v2/kingdom',undefined,c)).body.settlementId,before.settlementId);
 } finally {
  if(worker)await worker.stop();if(server)await new Promise(r=>server.close(r));if(pool)await pool.end();
  await admin.query('DROP SCHEMA IF EXISTS "'+schema+'" CASCADE');await admin.end();
 }
});
