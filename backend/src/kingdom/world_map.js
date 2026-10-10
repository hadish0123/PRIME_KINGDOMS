import { ApiError } from '../errors.js';
import { territoryName } from './locations.js';
import { integer, transaction } from './transaction.js';

function hash01(seed, x, z, salt = 0) {
  let h = (Number(seed) ^ Math.imul(x, 374761393) ^ Math.imul(z, 668265263) ^ Math.imul(salt + 1, 2246822519)) >>> 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177) >>> 0;
  h = (h ^ (h >>> 16)) >>> 0;
  return h / 4294967296;
}

function generatedTile(seed, x, z) {
  const biomeRoll = hash01(seed, x, z, 1);
  const biome = biomeRoll < .38 ? 'forest'
    : biomeRoll < .56 ? 'highlands'
      : biomeRoll < .68 ? 'wetlands' : 'grassland';
  const siteRoll = hash01(seed, x, z, 2);
  const level = Math.max(1, Math.min(10, 1 + Math.floor(Math.hypot(x, z) / 18)));
  if (siteRoll < .045) return { kind: 'npc', biome, siteType: 'npc_camp', siteLevel: level, resourceType: null };
  if (siteRoll < .14) {
    const resourceRoll = hash01(seed, x, z, 3);
    const options = biome === 'forest' ? ['wood','wood','food','gold']
      : biome === 'highlands' ? ['stone','iron','stone','gold']
        : biome === 'wetlands' ? ['food','food','wood','gold']
          : ['food','wood','stone','gold'];
    return { kind: 'resource', biome, siteType: 'resource_node', siteLevel: Math.max(1, Math.ceil(level / 2)), resourceType: options[Math.floor(resourceRoll * options.length)] };
  }
  const wildlife = hash01(seed, x, z, 4) < (biome === 'forest' ? .20 : .09);
  return { kind: 'neutral', biome, siteType: wildlife ? 'wildlife' : 'empty', siteLevel: wildlife ? Math.max(1, Math.ceil(level / 3)) : 0, resourceType: null };
}

async function ensureViewport(db, worldId, seed, centerX, centerZ, radius) {
  const rows = [];
  for (let x = centerX - radius; x <= centerX + radius; x++) {
    for (let z = centerZ - radius; z <= centerZ + radius; z++) {
      const tile = generatedTile(seed, x, z);
      rows.push([worldId, x, z, tile.kind, tile.biome, tile.siteType, tile.siteLevel, tile.resourceType]);
    }
  }
  if (!rows.length) return;
  const params = rows.flat();
  const values = rows.map((_, index) => {
    const offset = index * 8;
    return `($${offset + 1},$${offset + 2},$${offset + 3},$${offset + 4},$${offset + 5},$${offset + 6},$${offset + 7},$${offset + 8})`;
  }).join(',');
  await db.query(`
    INSERT INTO strategic_tiles(world_id,x,z,kind,biome,site_type,site_level,resource_type)
    VALUES ${values}
    ON CONFLICT(world_id,x,z) DO NOTHING
  `, params);
}

function queryInteger(query, key, fallback, min, max) {
  if (!query.has(key)) return fallback;
  const raw = query.get(key);
  if (!/^-?\d+$/.test(raw ?? '')) throw new ApiError(400, 'invalid_target');
  return integer(Number(raw), min, max, 'invalid_target');
}

function mapTile(t) {
  return {
    name: territoryName(t.x, t.z),
    x: t.x,
    z: t.z,
    kind: t.kind,
    biome: t.biome,
    siteType: t.site_type,
    siteLevel: t.site_level,
    resourceType: t.resource_type,
    ownerPlayerId: t.owner_player_id,
    ownerClanId: t.owner_clan_id,
    empireName: t.empire_name,
    primaryColor: t.primary_color,
    secondaryColor: t.secondary_color,
    emblem: t.emblem,
    protectedUntil: t.protected_until,
    occupiedUntil: t.occupied_until,
    version: t.version,
    online: Boolean(t.owner_online),
    attackable: Boolean(t.attackable),
  };
}

export function getMap(pool, identity, query = new URLSearchParams()) {
  return transaction(pool, identity, 'world_map', {}, async db => {
    const plot = (await db.query(
      'SELECT p.plot,p.map_x,p.map_z,r.id,r.name,r.kind FROM strategic_plots p JOIN strategic_regions r ON r.id=p.region_id WHERE p.player_id=$1',
      [identity.player_id],
    )).rows[0];
    if (!plot) throw new ApiError(409, 'strategic_plot_required');
    const configRows = (await db.query("SELECT key,value FROM kingdom_config WHERE key IN ('world_map_default_radius','world_map_max_radius')")).rows;
    const config = Object.fromEntries(configRows.map(r => [r.key, Number(r.value)]));
    const centerX = queryInteger(query, 'x', plot.map_x, -100000, 100000);
    const centerZ = queryInteger(query, 'z', plot.map_z, -100000, 100000);
    const radius = queryInteger(query, 'radius', config.world_map_default_radius ?? 4, 2, config.world_map_max_radius ?? 12);
    const seed = Number((await db.query('SELECT seed FROM worlds WHERE id=$1', [identity.world_id])).rows[0]?.seed);
    if (!Number.isSafeInteger(seed)) throw new ApiError(503, 'world_unavailable');
    await ensureViewport(db, identity.world_id, seed, centerX, centerZ, radius);

    const clan = (await db.query('SELECT clan_id FROM clan_members WHERE player_id=$1', [identity.player_id])).rows[0]?.clan_id ?? null;
    const tiles = (await db.query(`
      SELECT t.*,coalesce(k.empire_name,c.name) AS empire_name,
        coalesce(k.primary_color,c.primary_color) AS primary_color,
        coalesce(k.secondary_color,c.secondary_color) AS secondary_color,
        coalesce(k.emblem,c.emblem) AS emblem,
        (op.last_seen_at >= clock_timestamp()-interval '45 seconds') AS owner_online,
        EXISTS(
          SELECT 1 FROM strategic_tiles own
          WHERE own.world_id=t.world_id AND own.owner_player_id=$6
            AND abs(own.x-t.x)+abs(own.z-t.z)=1
        ) AND t.owner_player_id IS DISTINCT FROM $6
          AND ($7::uuid IS NULL OR t.owner_clan_id IS DISTINCT FROM $7)
          AND (t.protected_until IS NULL OR t.protected_until<=clock_timestamp())
          AND (t.occupied_until IS NULL OR t.occupied_until<=clock_timestamp()) AS attackable
      FROM strategic_tiles t
      LEFT JOIN kingdoms k ON k.player_id=t.owner_player_id
      LEFT JOIN clans c ON c.id=t.owner_clan_id
      LEFT JOIN players op ON op.id=t.owner_player_id
      WHERE t.world_id=$1
        AND t.x BETWEEN $2 AND $3
        AND t.z BETWEEN $4 AND $5
      ORDER BY t.z,t.x
      LIMIT 625
    `, [identity.world_id, centerX-radius, centerX+radius, centerZ-radius, centerZ+radius, identity.player_id, clan])).rows;
    const regionPlots = (await db.query(
      'SELECT p.plot,p.player_id,p.map_x,p.map_z,k.empire_name,k.primary_color,k.emblem FROM strategic_plots p LEFT JOIN kingdoms k ON k.player_id=p.player_id WHERE p.region_id=$1 ORDER BY p.plot LIMIT 1024',
      [plot.id],
    )).rows;
    return {
      center: { x: centerX, z: centerZ },
      radius,
      diameter: radius * 2 + 1,
      tiles: tiles.map(mapTile),
      region: {
        id: plot.id,
        name: plot.name,
        kind: plot.kind,
        clanId: clan,
        ownPlot: plot.plot,
        plots: regionPlots.map(p => ({
          plot: p.plot,
          x: p.map_x,
          z: p.map_z,
          ownerPlayerId: p.player_id,
          empireName: p.empire_name,
          primaryColor: p.primary_color,
          emblem: p.emblem,
        })),
      },
    };
  }, { replay: false });
}

export function searchMap(pool, identity, query = new URLSearchParams()) {
  return transaction(pool, identity, 'world_search', {}, async db => {
    const raw = (query.get('q') ?? '').trim().normalize('NFKC');
    if (Array.from(raw).length < 2 || Array.from(raw).length > 32 || /[\p{Cc}\p{Cf}<>]/u.test(raw)) throw new ApiError(400, 'invalid_search');
    const configured = Number((await db.query("SELECT value FROM kingdom_config WHERE key='world_map_search_limit'")).rows[0]?.value ?? 30);
    const limit = queryInteger(query, 'limit', Math.min(20, configured), 1, Math.min(50, configured));
    const rows = (await db.query(`
      SELECT k.player_id,k.empire_name,k.primary_color,k.secondary_color,k.emblem,k.realm_rank,
        p.map_x,p.map_z,a.display_name,
        (pl.last_seen_at >= clock_timestamp()-interval '45 seconds') AS online
      FROM kingdoms k
      JOIN players pl ON pl.id=k.player_id
      JOIN accounts a ON a.id=pl.account_id
      JOIN strategic_plots p ON p.player_id=k.player_id
      WHERE pl.world_id=$1
        AND (k.empire_name ILIKE $2 OR a.display_name ILIKE $2)
      ORDER BY
        CASE WHEN lower(k.empire_name)=lower($3) OR lower(a.display_name)=lower($3) THEN 0 ELSE 1 END,
        k.realm_rank DESC,k.empire_name,k.player_id
      LIMIT $4
    `, [identity.world_id, `%${raw}%`, raw, limit])).rows;
    return { query: raw, results: rows.map(r => ({
      playerId: r.player_id,
      playerName: r.display_name,
      empireName: r.empire_name,
      x: r.map_x,
      z: r.map_z,
      realmRank: r.realm_rank,
      primaryColor: r.primary_color,
      secondaryColor: r.secondary_color,
      emblem: r.emblem,
      online: Boolean(r.online),
    })) };
  }, { replay: false });
}
