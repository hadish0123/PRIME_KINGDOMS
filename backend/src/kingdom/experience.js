import { ApiError } from '../errors.js';
import { transaction, integer, text, UUID } from './transaction.js';
import { settle, levels, spend } from './economy.js';
import { snapshot } from './settlement.js';
import { grantXP } from './progression.js';
import { notify } from './wars.js';

export const COMMANDERS={
  arden:{name:'Arden Vale',title:'Marshal of the Host',specialty:'infantry',hall:1,cost:100},
  serah:{name:'Serah Rowan',title:'Warden of the Marches',specialty:'ranged',hall:2,cost:200},
  idris:{name:'Idris Fen',title:'Master of the Vanguard',specialty:'cavalry',hall:3,cost:300},
};
export async function commanderSnapshot(db,id) {
  const b=await levels(db,id,'building');
  const owned=new Map((await db.query('SELECT key,xp FROM kingdom_commanders WHERE player_id=$1',[id])).rows.map(r=>[r.key,Number(r.xp)]));
  return Object.entries(COMMANDERS).map(([key,c])=>({key,...c,owned:owned.has(key),available:(b.commander_hall??0)>=c.hall,
    xp:owned.get(key)??0,level:Math.min(60,1+Math.floor(Math.sqrt((owned.get(key)??0)/150)))}));
}
export const getCommanders=(pool,id)=>transaction(pool,id,'commanders',{},async(db,p)=>({commanders:await commanderSnapshot(db,p.player_id)}),{replay:false});
export function recruitCommander(pool,id,body) {
  return transaction(pool,id,'commander_recruit',body,async(db,p,now)=>{
    const c=COMMANDERS[body.key];
    if (!c) throw new ApiError(400,'unknown_catalog_entry');
    if ((await levels(db,p.player_id,'building')).commander_hall<c.hall) throw new ApiError(409,'commander_locked');
    if ((await db.query('SELECT 1 FROM kingdom_commanders WHERE player_id=$1 AND key=$2',[p.player_id,body.key])).rows.length) throw new ApiError(409,'already_exists');
    await settle(db,p,now); await spend(db,p.player_id,{gold:c.cost});
    await db.query('INSERT INTO kingdom_commanders(player_id,key) VALUES($1,$2)',[p.player_id,body.key]);
    await notify(db,p.player_id,'commander:'+body.key,'commander','A commander has joined your court',c.name+' is ready to lead an army.');
    return {commanders:await commanderSnapshot(db,p.player_id),kingdom:await snapshot(db,p,now)};
  });
}
export function healUnits(pool,id,body) {
  return transaction(pool,id,'healing',body,async(db,p,now)=>{
    const quantity=integer(body.quantity,1,100);
    await settle(db,p,now);
    if ((await levels(db,p.player_id,'building')).hospital<1) throw new ApiError(409,'hospital_required');
    if ((await db.query('SELECT 1 FROM kingdom_healing WHERE player_id=$1 AND completed_at IS NULL',[p.player_id])).rows.length) throw new ApiError(409,'queue_busy');
    const unit=(await db.query('SELECT wounded FROM kingdom_units WHERE player_id=$1 AND type=$2',[p.player_id,String(body.key??'')])).rows[0];
    if (!unit||unit.wounded<quantity) throw new ApiError(409,'insufficient_wounded');
    const research=await levels(db,p.player_id,'research');
    await spend(db,p.player_id,{food:quantity*10,gold:quantity*2});
    await db.query('INSERT INTO kingdom_healing(player_id,unit_type,quantity,finishes_at) VALUES($1,$2,$3,$4)',[p.player_id,body.key,quantity,new Date(now.getTime()+Math.ceil(15*quantity/(1+(research.medicine??0)*.05))*1000)]);
    return {kingdom:await snapshot(db,p,now)};
  });
}
const GOALS=[
 {key:'first_keep',title:'Strengthen the Heart',message:'Upgrade the Keep to Level 2.',kind:'keep',target:2,xp:80,gold:35},
 {key:'first_training',title:'A Standing Army',message:'Complete your first troop training.',kind:'training',target:1,xp:60,gold:25},
 {key:'first_research',title:'Knowledge Endures',message:'Complete your first research.',kind:'research',target:1,xp:100,gold:40},
 {key:'first_conquest',title:'Beyond the Gates',message:'Secure one neighboring territory.',kind:'conquests',target:1,xp:100,gold:50},
 {key:'alliance',title:'Strength in Unity',message:'Join or found a clan.',kind:'clan',target:1,xp:150,gold:75},
 {key:'daily',title:'Daily Stewardship',message:'Complete three improvements, trainings or battles today.',kind:'daily',target:3,xp:100,gold:30},
 {key:'weekly',title:'A Week of Progress',message:'Complete twenty improvements, trainings or battles this week.',kind:'weekly',target:20,xp:500,gold:150},
];
async function goalsSnapshot(db,p,now) {
 const b=await levels(db,p.player_id,'building');
 const stats=(await db.query(`SELECT count(*) FILTER(WHERE source='training')::int AS training,count(*) FILTER(WHERE source='research')::int AS research,
  count(*) FILTER(WHERE source IN ('building','research','training','battle') AND occurred_at>=date_trunc('day',$2::timestamptz AT TIME ZONE 'UTC') AT TIME ZONE 'UTC')::int AS daily,
  count(*) FILTER(WHERE source IN ('building','research','training','battle') AND occurred_at>=date_trunc('week',$2::timestamptz AT TIME ZONE 'UTC') AT TIME ZONE 'UTC')::int AS weekly
  FROM kingdom_xp_events WHERE player_id=$1`,[p.player_id,now])).rows[0];
 stats.keep=b.keep??0; stats.conquests=p.conquests;
 stats.clan=(await db.query('SELECT 1 FROM clan_members WHERE player_id=$1',[p.player_id])).rows.length;
 const claimed=new Set((await db.query('SELECT key FROM kingdom_milestones WHERE player_id=$1',[p.player_id])).rows.map(r=>r.key));
 const week=new Date(now); week.setUTCDate(week.getUTCDate()-(week.getUTCDay()+6)%7);
 return GOALS.map(g=>({...g,claimKey:g.key==='daily'?'daily:'+now.toISOString().slice(0,10):g.key==='weekly'?'weekly:'+week.toISOString().slice(0,10):g.key,progress:Math.min(g.target,stats[g.kind]??0)}))
  .map(g=>({...g,claimed:claimed.has(g.claimKey),complete:g.progress>=g.target}));
}
export const getGoals=(pool,id)=>transaction(pool,id,'goals',{},async(db,p,now)=>{
 await settle(db,p,now); return {goals:await goalsSnapshot(db,p,now)};
},{replay:false});
export function claimGoal(pool,id,body) {
 return transaction(pool,id,'goal_claim',body,async(db,p,now)=>{
  const economy=await settle(db,p,now);
  const goal=(await goalsSnapshot(db,p,now)).find(g=>g.key===body.key);
  if (!goal||!goal.complete) throw new ApiError(409,'goal_incomplete');
  if (goal.claimed) throw new ApiError(409,'goal_claimed');
  await db.query('INSERT INTO kingdom_milestones(player_id,key,claimed_at) VALUES($1,$2,$3)',[p.player_id,goal.claimKey,now]);
  await grantXP(db,p,'goal',goal.claimKey,goal.xp,now);
  await db.query("UPDATE kingdom_resources SET amount=least(amount+$2,$3) WHERE player_id=$1 AND resource='gold'",[p.player_id,goal.gold,economy.capacity]);
  if (goal.key==='weekly') {p.seasonal_medals+=1; await db.query('UPDATE kingdoms SET seasonal_medals=$2 WHERE player_id=$1',[p.player_id,p.seasonal_medals]);}
  return {goals:await goalsSnapshot(db,p,now),kingdom:await snapshot(db,p,now)};
 });
}
export const getInbox=(pool,id)=>transaction(pool,id,'inbox',{},async(db,p)=>{
 const rows=(await db.query('SELECT id,kind,title,message,reference_id,created_at,seen_at FROM kingdom_inbox WHERE player_id=$1 ORDER BY created_at DESC LIMIT 50',[p.player_id])).rows;
 return {messages:rows.map(r=>({id:r.id,kind:r.kind,title:r.title,message:r.message,referenceId:r.reference_id,createdAt:r.created_at,read:!!r.seen_at}))};
},{replay:false});
export const readInbox=(pool,id,body)=>transaction(pool,id,'inbox_read',body,async(db,p,now)=>{
 if (!UUID.test(body.id??'')) throw new ApiError(400,'invalid_identifier');
 await db.query('UPDATE kingdom_inbox SET seen_at=$3 WHERE player_id=$1 AND id=$2',[p.player_id,body.id,now]); return {read:true};
});
export const getRankings=(pool,id)=>transaction(pool,id,'rankings',{},async(db)=>{
 const rulers=(await db.query(`SELECT k.player_id,k.empire_name,k.prestige,k.conquests,k.realm_rank,k.seasonal_medals FROM kingdoms k
  JOIN players p ON p.id=k.player_id WHERE p.world_id=$1 ORDER BY k.prestige DESC,k.conquests DESC,k.xp DESC,k.player_id LIMIT 50`,[id.world_id])).rows;
 const clans=(await db.query('SELECT name,tag,level,xp FROM clans WHERE world_id=$1 ORDER BY xp DESC,created_at LIMIT 50',[id.world_id])).rows;
 return {rulers:rulers.map((r,i)=>({rank:i+1,name:r.empire_name,prestige:r.prestige,conquests:r.conquests,realmRank:r.realm_rank,seasonHonors:r.seasonal_medals,self:r.player_id===id.player_id})),clans};
},{replay:false});

async function chatChannel(db,id,channel) {
 if (channel==='global') return null;
 if (channel!=='clan') throw new ApiError(400,'invalid_channel');
 const member=(await db.query('SELECT clan_id FROM clan_members WHERE player_id=$1',[id.player_id])).rows[0];
 if (!member) throw new ApiError(403,'clan_required'); return member.clan_id;
}
async function chatSnapshot(db,id,clanId) {
 const rows=(await db.query(`SELECT m.id,m.player_id,k.empire_name,m.message,m.created_at FROM kingdom_chat m JOIN kingdoms k ON k.player_id=m.player_id
  WHERE m.world_id=$1 AND m.clan_id IS NOT DISTINCT FROM $2::uuid AND m.hidden_at IS NULL
  AND NOT EXISTS(SELECT 1 FROM kingdom_blocks b WHERE b.player_id=$3 AND b.target_id=m.player_id) ORDER BY m.id DESC LIMIT 40`,[id.world_id,clanId,id.player_id])).rows;
 return {messages:rows.reverse().map(r=>({id:Number(r.id),playerId:r.player_id,name:r.empire_name,message:r.message,createdAt:r.created_at,self:r.player_id===id.player_id}))};
}
export const getChat=(pool,id,channel='global')=>transaction(pool,id,'chat',{},async(db)=>chatSnapshot(db,id,await chatChannel(db,id,channel)),{replay:false});
export function socialAction(pool,id,body,action) {
 return transaction(pool,id,'social_'+action,body,async(db,p,now)=>{
  const clanId=await chatChannel(db,id,body.channel??'global');
  if (action==='send') {
   const message=text(body.message,1,240,'invalid_message');
   const recent=(await db.query("SELECT count(*)::int AS n,max(created_at) AS latest FROM kingdom_chat WHERE player_id=$1 AND created_at>$2::timestamptz-interval '1 minute'",[p.player_id,now])).rows[0];
   if (recent.n>=10||recent.latest&&now-recent.latest<3000) throw new ApiError(429,'chat_too_fast');
   await db.query('INSERT INTO kingdom_chat(world_id,player_id,clan_id,message,created_at) VALUES($1,$2,$3,$4,$5)',[id.world_id,p.player_id,clanId,message,now]);
  } else {
   const messageId=integer(body.messageId,1,Number.MAX_SAFE_INTEGER,'invalid_identifier');
   const m=(await db.query('SELECT * FROM kingdom_chat WHERE id=$1 AND world_id=$2 AND clan_id IS NOT DISTINCT FROM $3::uuid',[messageId,id.world_id,clanId])).rows[0];
   if (!m) throw new ApiError(404,'message_unavailable');
   if (action==='block') {
    if (m.player_id===p.player_id) throw new ApiError(400,'invalid_identifier');
    await db.query('INSERT INTO kingdom_blocks(player_id,target_id) VALUES($1,$2) ON CONFLICT DO NOTHING',[p.player_id,m.player_id]);
   } else await db.query('INSERT INTO kingdom_reports(player_id,message_id,reason) VALUES($1,$2,$3) ON CONFLICT DO NOTHING',[p.player_id,messageId,text(body.reason,3,240,'invalid_message')]);
  }
  return {chat:await chatSnapshot(db,id,clanId)};
 });
}
