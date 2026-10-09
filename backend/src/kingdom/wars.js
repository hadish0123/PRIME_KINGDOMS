import { ApiError } from '../errors.js';
import { transaction, UUID } from './transaction.js';

export async function notify(db, playerId, eventKey, kind, title, message, referenceId = null) {
  await db.query(`INSERT INTO kingdom_inbox(player_id,event_key,kind,title,message,reference_id)
    VALUES($1,$2,$3,$4,$5,$6) ON CONFLICT(player_id,event_key) DO NOTHING`,
  [playerId,eventKey,kind,title,message,referenceId]);
}
export async function settleWars(db, worldId, now) {
  const due=(await db.query(`SELECT w.* FROM clan_wars w JOIN clans c ON c.id=w.attacker_id
    WHERE c.world_id=$1 AND w.phase IN ('preparation','battle') AND w.preparation_ends_at<=$2
    ORDER BY w.id FOR UPDATE OF w`,[worldId,now])).rows;
  for (const war of due) {
    if (war.battle_ends_at>now) {
      if (war.phase==='preparation') await db.query("UPDATE clan_wars SET phase='battle' WHERE id=$1",[war.id]);
      continue;
    }
    const winner=war.attacker_score===war.defender_score?null:(war.attacker_score>war.defender_score?war.attacker_id:war.defender_id);
    await db.query("UPDATE clan_wars SET phase='result',resolved_at=$2,winner_id=$3,rewards_paid=true WHERE id=$1",[war.id,now,winner]);
    if (war.rewards_paid) continue;
    for (const co of (await db.query('SELECT * FROM clan_war_contributions WHERE war_id=$1 AND score>0',[war.id])).rows) {
      await db.query('UPDATE kingdoms SET seasonal_medals=seasonal_medals+$2,prestige=prestige+$3 WHERE player_id=$1',
        [co.player_id,co.clan_id===winner?2:1,co.clan_id===winner?15:5]);
    }
    if (winner) {
      await db.query("UPDATE clan_treasury SET amount=least(1000000000000,amount+500) WHERE clan_id=$1 AND resource='gold'",[winner]);
      await db.query('UPDATE clans SET xp=xp+500,level=least(100,1+floor(sqrt((xp+500)/500.0))::int) WHERE id=$1',[winner]);
    }
    for (const m of (await db.query('SELECT player_id FROM clan_members WHERE clan_id=ANY($1::uuid[])',[[war.attacker_id,war.defender_id]])).rows) {
      await notify(db,m.player_id,'war-result:'+war.id,'war','The war has concluded','The final score is recorded. Contributions have earned prestige and season honors.',war.id);
    }
  }
}
export async function warSnapshot(db,identity,now) {
  await settleWars(db,identity.world_id,now);
  const member=(await db.query('SELECT * FROM clan_members WHERE player_id=$1',[identity.player_id])).rows[0];
  if (!member) return {serverTime:now,role:null,wars:[]};
  const rows=(await db.query(`SELECT w.*,a.name AS attacker_name,d.name AS defender_name FROM clan_wars w
    JOIN clans a ON a.id=w.attacker_id JOIN clans d ON d.id=w.defender_id
    WHERE w.attacker_id=$1 OR w.defender_id=$1 ORDER BY w.created_at DESC LIMIT 20`,[member.clan_id])).rows;
  const wars=[];
  for (const w of rows) {
    const contributions=(await db.query(`SELECT k.empire_name AS name,co.score FROM clan_war_contributions co
      JOIN kingdoms k ON k.player_id=co.player_id WHERE co.war_id=$1 ORDER BY co.score DESC LIMIT 63`,[w.id])).rows;
    wars.push({id:w.id,attackerName:w.attacker_name,defenderName:w.defender_name,phase:w.phase,
      preparationEndsAt:w.preparation_ends_at,battleEndsAt:w.battle_ends_at,attackerScore:w.attacker_score,defenderScore:w.defender_score,
      won:w.winner_id===member.clan_id,draw:w.phase==='result'&&!w.winner_id,contributions});
  }
  return {serverTime:now,role:member.role,wars};
}
export const getWars=(pool,identity)=>transaction(pool,identity,'wars',{},(db,_p,now)=>warSnapshot(db,identity,now),{replay:false,globalLock:true});
export function declareWar(pool,identity,body) {
  return transaction(pool,identity,'war_declare',body,async(db,_p,now)=>{
    await settleWars(db,identity.world_id,now);
    if (!UUID.test(body.clanId??'')) throw new ApiError(400,'invalid_identifier');
    const member=(await db.query('SELECT * FROM clan_members WHERE player_id=$1',[identity.player_id])).rows[0];
    if (!member||!['leader','officer'].includes(member.role)) throw new ApiError(403,'clan_permission');
    if (member.clan_id===body.clanId) throw new ApiError(409,'friendly_territory');
    const clans=(await db.query('SELECT * FROM clans WHERE world_id=$1 AND id=ANY($2::uuid[]) ORDER BY id FOR UPDATE',[identity.world_id,[member.clan_id,body.clanId]])).rows;
    if (clans.length!==2) throw new ApiError(404,'clan_not_found');
    if ((await db.query("SELECT 1 FROM clan_wars WHERE phase IN ('preparation','battle') AND (attacker_id=ANY($1::uuid[]) OR defender_id=ANY($1::uuid[]))",[[member.clan_id,body.clanId]])).rows.length) throw new ApiError(409,'war_active');
    const cfg=Object.fromEntries((await db.query("SELECT key,value FROM kingdom_config WHERE key LIKE 'war_%'")).rows.map(r=>[r.key,Number(r.value)]));
    if ((await db.query(`SELECT 1 FROM clan_wars WHERE (attacker_id=ANY($1::uuid[]) OR defender_id=ANY($1::uuid[]))
      AND phase='result' AND resolved_at>$2`,[[member.clan_id,body.clanId],new Date(now.getTime()-cfg.war_cooldown_seconds*1000)])).rows.length) throw new ApiError(409,'war_cooldown');
    if (!(await db.query("UPDATE clan_treasury SET amount=amount-$2 WHERE clan_id=$1 AND resource='gold' AND amount>=$2 RETURNING amount",[member.clan_id,cfg.war_gold_cost])).rows.length) throw new ApiError(409,'insufficient_resources');
    const start=new Date(now.getTime()+cfg.war_preparation_seconds*1000),end=new Date(start.getTime()+cfg.war_battle_seconds*1000);
    const war=(await db.query(`INSERT INTO clan_wars(attacker_id,defender_id,phase,preparation_ends_at,battle_ends_at)
      VALUES($1,$2,'preparation',$3,$4) RETURNING id`,[member.clan_id,body.clanId,start,end])).rows[0];
    for (const m of (await db.query('SELECT player_id FROM clan_members WHERE clan_id=ANY($1::uuid[])',[[member.clan_id,body.clanId]])).rows) await notify(db,m.player_id,'war-declared:'+war.id,'war','War has been declared','Prepare your forces. Clan forts become eligible when preparation ends.',war.id);
    return {wars:await warSnapshot(db,identity,now)};
  },{globalLock:true});
}
export async function eligibleWar(db,a,d,now) {
  if (!a||!d) return null;
  const war=(await db.query(`SELECT * FROM clan_wars WHERE ((attacker_id=$1 AND defender_id=$2) OR (attacker_id=$2 AND defender_id=$1))
    AND phase IN ('preparation','battle') ORDER BY created_at DESC LIMIT 1 FOR UPDATE`,[a,d])).rows[0];
  if (war?.preparation_ends_at>now) throw new ApiError(409,'war_preparation');
  return war?.phase==='battle'?war:null;
}
