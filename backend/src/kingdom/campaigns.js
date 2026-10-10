import { ApiError } from '../errors.js';
import { transaction, integer, UUID } from './transaction.js';
import { levels, settle } from './economy.js';
import { loadPreset, attackTarget, resolveBattle, commandSnapshot } from './realm.js';
import { notify, settleWars } from './wars.js';
import { beginReturn, commanderAway, marchUnits, travelSeconds } from './campaign_inventory.js';
import { capabilities } from './capabilities.js';

async function reinforcementTarget(db, playerId, worldId, x, z) {
  const target=(await db.query('SELECT * FROM strategic_tiles WHERE world_id=$1 AND x=$2 AND z=$3 FOR UPDATE',[worldId,x,z])).rows[0];
  if (!target || target.kind!=='settlement' || !target.owner_player_id || target.owner_player_id===playerId) throw new ApiError(409,'reinforcement_target_required');
  const members=(await db.query('SELECT player_id,clan_id FROM clan_members WHERE player_id=ANY($1::uuid[])',[[playerId,target.owner_player_id]])).rows;
  if (members.length!==2 || members[0].clan_id!==members[1].clan_id) throw new ApiError(409,'reinforcement_ally_required');
  return target;
}

export async function startMarch(pool, identity, body, legacy=false) {
  return transaction(pool,identity,legacy?'battle_attack':'march_start',body,async(db,profile,now)=>{
    await settleWars(db,identity.world_id,now);
    Object.assign(profile,(await db.query('SELECT * FROM kingdoms WHERE player_id=$1',[profile.player_id])).rows[0]);
    await settle(db,profile,now);
    const kind=legacy?'attack':body.kind;
    if (!['attack','reinforce'].includes(kind)) throw new ApiError(400,'invalid_march_kind');
    const slot=integer(body.presetSlot,1,5,'invalid_preset_slot');
    const x=integer(body.x,-100000,100000,'invalid_target');
    const z=integer(body.z,-100000,100000,'invalid_target');
    const army=await loadPreset(db,profile.player_id,slot);
    if (await commanderAway(db,profile.player_id,army.commander)) throw new ApiError(409,'commander_away');
    const research=await levels(db,profile.player_id,'research');
    const powers=await capabilities(db,profile.player_id);
    const regularLimit=Math.min(Number((await db.query("SELECT value FROM kingdom_config WHERE key='march_maximum_slots'")).rows[0].value),1+Math.floor((research.leadership??0)/10));
    const limit=powers.divinePower
      ? Number((await db.query("SELECT value FROM kingdom_config WHERE key='owner_virtual_march_limit'")).rows[0]?.value ?? 100)
      : regularLimit;
    if (Number((await db.query("SELECT count(*)::int AS n FROM kingdom_marches WHERE player_id=$1 AND phase<>'completed'",[profile.player_id])).rows[0].n)>=limit) throw new ApiError(409,'march_capacity');
    const target=kind==='attack'?await attackTarget(db,identity,profile,x,z,army,now):await reinforcementTarget(db,profile.player_id,identity.world_id,x,z);
    if (kind==='reinforce' && Number((await db.query("SELECT count(*)::int AS n FROM kingdom_marches WHERE target_owner_id=$1 AND kind='reinforce' AND phase IN ('outbound','stationed')",[target.owner_player_id])).rows[0].n)>=30) throw new ApiError(409,'reinforcement_capacity');
    const home=(await db.query('SELECT map_x,map_z FROM strategic_plots WHERE player_id=$1',[profile.player_id])).rows[0];
    const seconds=await travelSeconds(db,profile.player_id,army.units,Math.hypot(x-home.map_x,z-home.map_z));
    const row=(await db.query(`INSERT INTO kingdom_marches(player_id,world_id,preset_slot,name,kind,phase,formation,stance,commander,target_x,target_z,target_owner_id,route_from_x,route_from_z,route_to_x,route_to_z,departed_at,route_started_at,arrives_at)
      VALUES($1,$2,$3,$4,$5,'outbound',$6,$7,$8,$9::integer,$10::integer,$11,$12,$13,$9::integer,$10::integer,$14,$14,$15) RETURNING id`,[profile.player_id,identity.world_id,slot,army.name,kind,army.formation,army.stance,army.commander,x,z,target.owner_player_id,home.map_x,home.map_z,now,new Date(now.getTime()+seconds*1000)])).rows[0];
    for (const unit of army.units) await db.query('INSERT INTO kingdom_march_units(march_id,unit_type,quantity) VALUES($1,$2,$3)',[row.id,unit.type,unit.quantity]);
    if (target.owner_player_id) await notify(db,target.owner_player_id,'march:'+row.id,'march',kind==='attack'?'An enemy army approaches':'Allied reinforcements are approaching',profile.empire_name+' has dispatched '+army.name+'.',row.id);
    return {marchId:row.id,command:await commandSnapshot(db,profile,now)};
  },{globalLock:true});
}

export async function recallMarch(pool,identity,body) {
  return transaction(pool,identity,'march_recall',body,async(db,profile,now)=>{
    if (!UUID.test(body.marchId??'')) throw new ApiError(400,'invalid_identifier');
    const march=(await db.query('SELECT * FROM kingdom_marches WHERE id=$1 AND player_id=$2 FOR UPDATE',[body.marchId,profile.player_id])).rows[0];
    if (!march) throw new ApiError(404,'march_unavailable');
    if (march.phase==='completed') throw new ApiError(409,'march_completed');
    if (march.phase!=='returning') await beginReturn(db,march,now,'recalled');
    return {command:await commandSnapshot(db,profile,now)};
  },{globalLock:true});
}

// A bounded worker and read-side catch-up both use this same transactional path.
// SQL selects trusted identities; neither request bodies nor client clocks drive it.
export async function processDueMarches(pool,{playerId=null,limit=6}={}) {
  const due=(await pool.query(`SELECT id,player_id,world_id FROM kingdom_marches WHERE phase IN ('outbound','returning') AND arrives_at<=clock_timestamp()
    AND ($1::uuid IS NULL OR player_id=$1 OR target_owner_id=$1) ORDER BY arrives_at,id LIMIT $2`,[playerId,Math.min(20,limit)])).rows;
  for (const entry of due) await transaction(pool,entry,'march_due',{},async(db,profile,now)=>{
    const march=(await db.query('SELECT * FROM kingdom_marches WHERE id=$1 FOR UPDATE',[entry.id])).rows[0];
    if (!march || !['outbound','returning'].includes(march.phase) || march.arrives_at>now) return;
    if (march.phase==='returning') {
      await db.query("UPDATE kingdom_marches SET phase='completed',completed_at=$2 WHERE id=$1",[march.id,now]);
      await notify(db,profile.player_id,'march-home:'+march.id,'march',march.name+' has returned','Your surviving soldiers are available for duty.',march.id);
      return;
    }
    const units=await marchUnits(db,march.id);
    await db.query('SAVEPOINT campaign_arrival');
    try {
      if (march.kind==='reinforce') {
        const target=await reinforcementTarget(db,profile.player_id,entry.world_id,march.target_x,march.target_z);
        if (target.owner_player_id!==march.target_owner_id) throw new ApiError(409,'target_changed');
        await db.query("UPDATE kingdom_marches SET phase='stationed',arrives_at=NULL WHERE id=$1",[march.id]);
        await notify(db,profile.player_id,'march-arrived:'+march.id,'march',march.name+' is guarding your ally','Your reinforcements remain stationed until recalled.',march.id);
      } else {
        const resolved=await resolveBattle(db,profile,now,entry,{x:march.target_x,z:march.target_z,presetSlot:march.preset_slot,expectedOwner:march.target_owner_id},
          {name:march.name,formation:march.formation,stance:march.stance,commander:march.commander,units});
        for (const unit of units) {
          const losses=resolved.battle.attackerLosses[unit.type]??{dead:0,wounded:0};
          await db.query('UPDATE kingdom_march_units SET quantity=quantity-$3 WHERE march_id=$1 AND unit_type=$2',[march.id,unit.type,losses.dead+losses.wounded]);
        }
        await db.query('UPDATE kingdom_marches SET report_id=$2 WHERE id=$1',[march.id,resolved.battle.id]);
        await beginReturn(db,march,now,'battle_resolved');
      }
      await db.query('RELEASE SAVEPOINT campaign_arrival');
    } catch(error) {
      if (!(error instanceof ApiError)) throw error;
      await db.query('ROLLBACK TO SAVEPOINT campaign_arrival');
      await beginReturn(db,march,now,error.code);
      await notify(db,profile.player_id,'march-cancelled:'+march.id,'march',march.name+' is returning','The target is no longer eligible for this order. Your soldiers are returning safely.',march.id);
    }
  },{replay:false,globalLock:true,presence:false});
  return due.length;
}

export function startMarchWorker(pool,logger=console) {
  let stopped=false;
  let active=null;
  const tick=()=>{
    if (stopped || active) return;
    active=processDueMarches(pool).catch(()=>logger.error(JSON.stringify({event:'campaign_worker_failed'}))).finally(()=>{active=null;});
  };
  const timer=setInterval(tick,2000);
  timer.unref();
  tick();
  return {stop:async()=>{stopped=true;clearInterval(timer);if(active)await active;}};
}
