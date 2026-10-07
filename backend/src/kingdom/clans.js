import { ApiError } from '../errors.js';
import { transaction, UUID, text, integer } from './transaction.js';
import { progression } from './progression.js';
import { settle, spend, RESOURCES } from './economy.js';

const DAY = 86400000;
const emblems = ['lion', 'eagle', 'crown', 'stag', 'sun', 'wolf'];
function identifier(value) {
  if (!UUID.test(value ?? '')) throw new ApiError(400, 'invalid_identifier');
  return value;
}
async function membership(db, player) {
  return (await db.query('SELECT m.*,c.region_id,c.world_id FROM clan_members m JOIN clans c ON c.id=m.clan_id WHERE m.player_id=$1', [player])).rows[0];
}
async function clan(db, id, world) {
  const result = (await db.query('SELECT * FROM clans WHERE id=$1 AND world_id=$2 FOR UPDATE', [identifier(id), world])).rows[0];
  if (!result) throw new ApiError(404, 'clan_not_found');
  return result;
}
async function authorize(db, player, clanId, roles = ['leader', 'officer']) {
  const member = await membership(db, player);
  if (!member || member.clan_id !== clanId || !roles.includes(member.role)) throw new ApiError(403, 'clan_permission');
  return member;
}
async function noWar(db, ...clanIds) {
  const ids = clanIds.filter(Boolean);
  if (ids.length && (await db.query("SELECT id FROM clan_wars WHERE phase IN ('preparation','battle') AND (attacker_id=ANY($1::uuid[]) OR defender_id=ANY($1::uuid[])) LIMIT 1", [ids])).rows.length) throw new ApiError(409, 'clan_at_war');
}
async function cooldown(db, player, columns, now) {
  await db.query('INSERT INTO clan_player_cooldowns(player_id) VALUES($1) ON CONFLICT DO NOTHING', [player]);
  // Column identifiers are from internal constants, never from the request.
  if ((await db.query(`SELECT player_id FROM clan_player_cooldowns WHERE player_id=$1 AND (${columns.map(c => `${c}>$2`).join(' OR ')})`, [player, now])).rows.length) throw new ApiError(409, 'clan_cooldown');
}
async function targetProfile(db, player, world) {
  if (!(await db.query('SELECT id FROM players WHERE id=$1 AND world_id=$2 FOR UPDATE', [identifier(player), world])).rows.length) throw new ApiError(404, 'player_not_found');
  await db.query('SELECT initialize_kingdom($1)', [player]);
  return (await db.query('SELECT * FROM kingdoms WHERE player_id=$1 FOR UPDATE', [player])).rows[0];
}

async function relocate(db, profile, destination, plot, reason, now, ownerClan = null) {
  const previous = (await db.query('SELECT p.*,r.kind FROM strategic_plots p JOIN strategic_regions r ON r.id=p.region_id WHERE p.player_id=$1 FOR UPDATE OF p', [profile.player_id])).rows[0];
  if (!previous) throw new Error('Settlement has no strategic plot');
  const home = (await db.query('SELECT world_id FROM players WHERE id=$1', [profile.player_id])).rows[0];
  const protection = (await db.query("SELECT protected_until FROM strategic_tiles WHERE owner_player_id=$1 AND kind='settlement'", [profile.player_id])).rows[0]?.protected_until ?? null;
  // Preserve the original village, legacy coordinates and every dependent record.
  // Only strategic location changes. A released starter holding remains a fort.
  await db.query("UPDATE strategic_tiles SET kind=CASE WHEN $2='clan' THEN 'neutral' ELSE 'fort' END,owner_player_id=CASE WHEN $2='clan' THEN NULL ELSE owner_player_id END,protected_until=NULL,version=version+1 WHERE owner_player_id=$1 AND kind='settlement'", [profile.player_id, previous.kind]);
  await db.query('UPDATE strategic_plots SET player_id=NULL WHERE region_id=$1 AND plot=$2', [previous.region_id, previous.plot]);
  const claimed = (await db.query('UPDATE strategic_plots SET player_id=$3 WHERE region_id=$1 AND plot=$2 AND player_id IS NULL RETURNING *', [destination, plot, profile.player_id])).rows[0];
  if (!claimed || claimed.map_x === null || claimed.map_z === null) throw new ApiError(409, 'plot_unavailable');
  const existing = (await db.query('SELECT * FROM strategic_tiles WHERE world_id=$1 AND x=$2 AND z=$3 FOR UPDATE', [home.world_id, claimed.map_x, claimed.map_z])).rows[0];
  if (existing?.owner_player_id && existing.owner_player_id !== profile.player_id) throw new ApiError(409, 'plot_occupied');
  // Relocation never renews starter immunity or erases an expired deadline.
  const protectedUntil = protection;
  await db.query("INSERT INTO strategic_tiles(world_id,x,z,kind,owner_player_id,owner_clan_id,protected_until) VALUES($1,$2,$3,'settlement',$4,$5,$6) ON CONFLICT(world_id,x,z) DO UPDATE SET kind='settlement',owner_player_id=excluded.owner_player_id,owner_clan_id=excluded.owner_clan_id,protected_until=excluded.protected_until,version=strategic_tiles.version+1", [home.world_id, claimed.map_x, claimed.map_z, profile.player_id, ownerClan, protectedUntil]);
  await db.query('INSERT INTO settlement_relocations(player_id,village_id,from_region_id,from_plot,to_region_id,to_plot,reason,occurred_at) VALUES($1,$2,$3,$4,$5,$6,$7,$8)', [profile.player_id, profile.village_id, previous.region_id, previous.plot, destination, plot, reason, now]);
  await db.query('INSERT INTO clan_player_cooldowns(player_id,join_after,leave_after,relocate_after) VALUES($1,$2,$2,$2) ON CONFLICT(player_id) DO UPDATE SET join_after=$2,leave_after=$2,relocate_after=$2', [profile.player_id, new Date(now.getTime() + DAY)]);
}

async function addMember(db, profile, group, reason, now) {
  if (await membership(db, profile.player_id)) throw new ApiError(409, 'already_in_clan');
  await cooldown(db, profile.player_id, ['join_after', 'relocate_after'], now);
  await noWar(db, group.id);
  const plot = (await db.query('SELECT plot FROM strategic_plots WHERE region_id=$1 AND plot BETWEEN 1 AND 63 AND player_id IS NULL ORDER BY plot LIMIT 1 FOR UPDATE', [group.region_id])).rows[0];
  if (!plot) throw new ApiError(409, 'clan_region_full');
  await db.query('INSERT INTO clan_members(player_id,clan_id,role,joined_at) VALUES($1,$2,$3,$4)', [profile.player_id, group.id, reason === 'create' ? 'leader' : 'member', now]);
  await relocate(db, profile, group.region_id, plot.plot, reason, now, group.id);
  await db.query("UPDATE clan_applications SET status=CASE WHEN clan_id=$2 THEN 'accepted' ELSE 'withdrawn' END WHERE player_id=$1 AND status='pending'", [profile.player_id, group.id]);
  await db.query('UPDATE clan_invitations SET accepted_at=$3 WHERE player_id=$1 AND clan_id=$2', [profile.player_id, group.id, now]);
}

async function resettle(db, profile, reason, now) {
  const home = (await db.query('SELECT v.*,p.world_id FROM villages v JOIN players p ON p.id=v.owner_player_id WHERE v.id=$1', [profile.village_id])).rows[0];
  const region = (await db.query("INSERT INTO strategic_regions(world_id,key,name,kind) VALUES($1,$2,'Starter province','starter') ON CONFLICT(world_id,key) DO UPDATE SET key=excluded.key RETURNING id", [home.world_id, `starter-${Math.floor(home.slot / 64)}`])).rows[0];
  const preferred = home.slot % 64;
  const location = (await db.query('SELECT cell_x,cell_z FROM territories WHERE owner_player_id=$1 AND is_home', [profile.player_id])).rows[0];
  let plot = (await db.query('SELECT * FROM strategic_plots WHERE region_id=$1 AND plot=$2 FOR UPDATE', [region.id, preferred])).rows[0];
  let slot = preferred;
  if (plot?.player_id && plot.player_id !== profile.player_id) slot = Math.max(64, Number((await db.query('SELECT coalesce(max(plot),63)+1 AS n FROM strategic_plots WHERE region_id=$1', [region.id])).rows[0].n));
  if (slot > 1023) throw new ApiError(409, 'starter_region_full');
  await db.query('INSERT INTO strategic_plots(region_id,plot,map_x,map_z) VALUES($1,$2,$3,$4) ON CONFLICT(region_id,plot) DO NOTHING', [region.id, slot, location.cell_x, location.cell_z]);
  await db.query('UPDATE strategic_plots SET map_x=$3,map_z=$4 WHERE region_id=$1 AND plot=$2 AND player_id IS NULL', [region.id, slot, location.cell_x, location.cell_z]);
  await relocate(db, profile, region.id, slot, reason, now);
}

async function snapshot(db, profile, now) {
  const member = await membership(db, profile.player_id);
  let own = null;
  if (member) {
    const group = (await db.query('SELECT c.*,r.map_x,r.map_z FROM clans c JOIN strategic_regions r ON r.id=c.region_id WHERE c.id=$1', [member.clan_id])).rows[0];
    const members = (await db.query('SELECT m.player_id,m.role,m.joined_at,k.empire_name,p.plot,p.map_x,p.map_z FROM clan_members m JOIN kingdoms k ON k.player_id=m.player_id JOIN strategic_plots p ON p.player_id=m.player_id WHERE m.clan_id=$1 ORDER BY m.joined_at,m.player_id', [group.id])).rows;
    const treasury = Object.fromEntries((await db.query('SELECT resource,amount FROM clan_treasury WHERE clan_id=$1', [group.id])).rows.map(r => [r.resource, Number(r.amount)]));
    const pending = ['leader', 'officer'].includes(member.role) ? (await db.query("SELECT a.player_id,k.empire_name,a.created_at FROM clan_applications a JOIN kingdoms k ON k.player_id=a.player_id WHERE a.clan_id=$1 AND a.status='pending' ORDER BY a.created_at LIMIT 100", [group.id])).rows : [];
    own = { id: group.id, name: group.name, tag: group.tag, emblem: group.emblem, primaryColor: group.primary_color, secondaryColor: group.secondary_color, leaderId: group.leader_id, founderId: group.founder_id, level: group.level, xp: Number(group.xp), admission: group.admission, role: member.role, regionId: group.region_id, capital: { x: group.map_x, z: group.map_z }, treasury, members: members.map(m => ({ playerId: m.player_id, role: m.role, empireName: m.empire_name, plot: m.plot, x: m.map_x, z: m.map_z, joinedAt: m.joined_at })), applications: pending.map(a => ({ playerId: a.player_id, empireName: a.empire_name, createdAt: a.created_at })) };
  }
  const invitations = (await db.query('SELECT i.clan_id,c.name,c.tag,i.expires_at FROM clan_invitations i JOIN clans c ON c.id=i.clan_id WHERE i.player_id=$1 AND i.accepted_at IS NULL AND i.expires_at>$2 ORDER BY i.expires_at LIMIT 50', [profile.player_id, now])).rows;
  const applications = (await db.query('SELECT a.clan_id,c.name,a.status FROM clan_applications a JOIN clans c ON c.id=a.clan_id WHERE a.player_id=$1 ORDER BY a.created_at DESC LIMIT 50', [profile.player_id])).rows;
  const groups = (await db.query('SELECT c.id,c.name,c.tag,c.emblem,c.primary_color,c.admission,c.level,count(m.player_id)::int AS members FROM clans c LEFT JOIN clan_members m ON m.clan_id=c.id WHERE c.world_id=(SELECT world_id FROM players WHERE id=$1) GROUP BY c.id ORDER BY c.created_at DESC LIMIT 50', [profile.player_id])).rows;
  const cd = (await db.query("SELECT CASE WHEN join_after='-infinity'::timestamptz THEN NULL ELSE join_after END AS join_after,CASE WHEN leave_after='-infinity'::timestamptz THEN NULL ELSE leave_after END AS leave_after,CASE WHEN relocate_after='-infinity'::timestamptz THEN NULL ELSE relocate_after END AS relocate_after FROM clan_player_cooldowns WHERE player_id=$1", [profile.player_id])).rows[0];
  return { serverTime: now, creationLevel: 15, creationCost: { gold: 500 }, memberCapacity: 63, own, cooldowns: cd ?? null, invitations: invitations.map(i => ({ clanId: i.clan_id, name: i.name, tag: i.tag, expiresAt: i.expires_at })), applications: applications.map(a => ({ clanId: a.clan_id, name: a.name, status: a.status })), directory: groups.map(g => ({ id: g.id, name: g.name, tag: g.tag, emblem: g.emblem, primaryColor: g.primary_color, admission: g.admission, level: g.level, members: g.members })) };
}

export const getClans = (pool, identity) => transaction(pool, identity, 'clans', {}, snapshot, { replay: false, globalLock: true });

export function clanAction(pool, identity, body, action) {
  return transaction(pool, identity, `clan_${action}`, body, async (db, profile, now) => {
    const current = await membership(db, profile.player_id);
    if (action === 'create') {
      if (current) throw new ApiError(409, 'already_in_clan');
      if ((await progression(db, profile)).level < 15) throw new ApiError(403, 'clan_level_15_required');
      const name = text(body.name, 3, 32), tag = text(body.tag, 3, 6, 'invalid_tag').toUpperCase();
      if (!/^[A-Z0-9]{3,6}$/.test(tag)) throw new ApiError(400, 'invalid_tag');
      if (!emblems.includes(body.emblem) || ![body.primaryColor, body.secondaryColor].every(c => typeof c === 'string' && /^#[0-9a-f]{6}$/i.test(c)) || !['open', 'approval'].includes(body.admission)) throw new ApiError(400, 'invalid_clan_identity');
      await cooldown(db, profile.player_id, ['join_after', 'relocate_after'], now);
      await settle(db, profile, now); await spend(db, profile.player_id, { gold: 500 });
      const sequence = Number((await db.query("SELECT nextval('clan_region_sequence') AS slot")).rows[0].slot);
      const x = 1000 + sequence * 16, z = 1000;
      const region = (await db.query("INSERT INTO strategic_regions(world_id,key,name,kind,map_x,map_z) VALUES($1,$2,$3,'clan',$4,$5) RETURNING id", [identity.world_id, `clan-${sequence}`, name, x, z])).rows[0];
      const group = (await db.query('INSERT INTO clans(world_id,region_id,founder_id,leader_id,name,tag,emblem,primary_color,secondary_color,admission) VALUES($1,$2,$3,$3,$4,$5,$6,$7,$8,$9) RETURNING *', [identity.world_id, region.id, profile.player_id, name, tag, body.emblem, body.primaryColor.toLowerCase(), body.secondaryColor.toLowerCase(), body.admission])).rows[0];
      await db.query('INSERT INTO strategic_plots(region_id,plot,map_x,map_z) SELECT $1,n,$2::integer+n%8,$3::integer+n/8 FROM generate_series(0,63) n', [region.id, x, z]);
      await db.query("INSERT INTO strategic_tiles(world_id,x,z,kind,owner_clan_id) VALUES($1,$2,$3,'fort',$4)", [identity.world_id, x, z, group.id]);
      for (const resource of RESOURCES) await db.query('INSERT INTO clan_treasury(clan_id,resource) VALUES($1,$2)', [group.id, resource]);
      await addMember(db, profile, group, 'create', now);
    } else if (action === 'join') {
      if (current) throw new ApiError(409, 'already_in_clan');
      await cooldown(db, profile.player_id, ['join_after', 'relocate_after'], now);
      const group = await clan(db, body.clanId, identity.world_id); await noWar(db, group.id);
      const invitation = (await db.query('SELECT clan_id FROM clan_invitations WHERE clan_id=$1 AND player_id=$2 AND accepted_at IS NULL AND expires_at>$3', [group.id, profile.player_id, now])).rows[0];
      if (group.admission === 'open' || invitation) await addMember(db, profile, group, 'join', now);
      else await db.query("INSERT INTO clan_applications(clan_id,player_id,created_at) VALUES($1,$2,$3) ON CONFLICT(clan_id,player_id) DO UPDATE SET status='pending',created_at=excluded.created_at", [group.id, profile.player_id, now]);
    } else if (action === 'application') {
      const group = await clan(db, body.clanId, identity.world_id); await authorize(db, profile.player_id, group.id);
      if (!['accept', 'reject'].includes(body.decision)) throw new ApiError(400, 'invalid_decision');
      const applicant = (await db.query("SELECT player_id FROM clan_applications WHERE clan_id=$1 AND player_id=$2 AND status='pending' FOR UPDATE", [group.id, identifier(body.playerId)])).rows[0];
      if (!applicant) throw new ApiError(404, 'application_not_found');
      if (body.decision === 'accept') await addMember(db, await targetProfile(db, applicant.player_id, identity.world_id), group, 'join', now);
      else await db.query("UPDATE clan_applications SET status='rejected' WHERE clan_id=$1 AND player_id=$2", [group.id, applicant.player_id]);
    } else if (action === 'invite') {
      const group = await clan(db, body.clanId, identity.world_id); await authorize(db, profile.player_id, group.id); await noWar(db, group.id);
      const target = await targetProfile(db, body.playerId, identity.world_id);
      if (await membership(db, target.player_id)) throw new ApiError(409, 'already_in_clan');
      await db.query('INSERT INTO clan_invitations(clan_id,player_id,inviter_id,expires_at) VALUES($1,$2,$3,$4) ON CONFLICT(clan_id,player_id) DO UPDATE SET inviter_id=excluded.inviter_id,expires_at=excluded.expires_at,accepted_at=NULL', [group.id, target.player_id, profile.player_id, new Date(now.getTime() + 7 * DAY)]);
    } else if (action === 'role') {
      const group = await clan(db, body.clanId, identity.world_id); await authorize(db, profile.player_id, group.id, ['leader']);
      if (!['member', 'officer', 'leader'].includes(body.role) || body.playerId === profile.player_id) throw new ApiError(400, 'invalid_role');
      const target = await membership(db, identifier(body.playerId));
      if (!target || target.clan_id !== group.id) throw new ApiError(404, 'member_not_found');
      if (body.role === 'leader') {
        await db.query("UPDATE clan_members SET role='officer' WHERE player_id=$1", [profile.player_id]);
        await db.query('UPDATE clans SET leader_id=$2 WHERE id=$1', [group.id, target.player_id]);
      }
      await db.query('UPDATE clan_members SET role=$2 WHERE player_id=$1', [target.player_id, body.role]);
    } else if (action === 'leave' || action === 'kick') {
      if (!current) throw new ApiError(409, 'not_in_clan');
      let subject = profile, member = current;
      if (action === 'kick') {
        await authorize(db, profile.player_id, current.clan_id);
        if (body.playerId === profile.player_id) throw new ApiError(400, 'cannot_kick_self');
        subject = await targetProfile(db, body.playerId, identity.world_id); member = await membership(db, subject.player_id);
        if (!member || member.clan_id !== current.clan_id) throw new ApiError(404, 'member_not_found');
        if (current.role === 'officer' && member.role !== 'member') throw new ApiError(403, 'clan_permission');
      }
      if (member.role === 'leader') throw new ApiError(409, 'transfer_leadership_required');
      await noWar(db, current.clan_id);
      // Kicks also respect relocation protection: officers cannot force a timer bypass.
      await cooldown(db, subject.player_id, ['leave_after', 'relocate_after'], now);
      await resettle(db, subject, action, now);
      await db.query('DELETE FROM clan_members WHERE player_id=$1', [subject.player_id]);
    } else if (action === 'donate') {
      if (!current) throw new ApiError(409, 'not_in_clan');
      if (!RESOURCES.includes(body.resource)) throw new ApiError(400, 'invalid_resource');
      const amount = integer(body.amount, 1, 1000000);
      await settle(db, profile, now); await spend(db, profile.player_id, { [body.resource]: amount });
      const result = await db.query('UPDATE clan_treasury SET amount=amount+$3 WHERE clan_id=$1 AND resource=$2 AND amount+$3<=1000000000000 RETURNING amount', [current.clan_id, body.resource, amount]);
      if (!result.rows.length) throw new ApiError(409, 'treasury_capacity');
    } else throw new ApiError(400, 'unknown_clan_action');
    return { clans: await snapshot(db, profile, now) };
  }, { globalLock: true });
}
