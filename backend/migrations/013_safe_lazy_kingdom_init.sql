-- Make lazy kingdom initialization safely adopt only unowned generated tiles.
-- Existing owned strategic settlements remain authoritative and are never duplicated.

CREATE OR REPLACE FUNCTION initialize_kingdom(subject uuid) RETURNS void LANGUAGE plpgsql AS $$
DECLARE home villages%ROWTYPE; region uuid;
BEGIN
 SELECT * INTO home FROM villages WHERE owner_player_id=subject;
 IF home.id IS NULL THEN RAISE EXCEPTION 'primary village missing'; END IF;

 INSERT INTO kingdoms(player_id,village_id,empire_name)
 VALUES(subject,home.id,left(home.name,32)) ON CONFLICT DO NOTHING;
 INSERT INTO kingdom_resources(player_id,resource,amount)
 SELECT subject,r,500 FROM unnest(ARRAY['food','wood','stone','iron','gold']) r ON CONFLICT DO NOTHING;
 INSERT INTO kingdom_buildings(player_id,key,level)
 SELECT subject,key,CASE WHEN key IN ('keep','farm','lumber_mill','warehouse','barracks') THEN 1 ELSE 0 END
 FROM kingdom_catalog WHERE kind='building' ON CONFLICT DO NOTHING;
 INSERT INTO kingdom_research(player_id,key)
 SELECT subject,key FROM kingdom_catalog WHERE kind='research' ON CONFLICT DO NOTHING;
 INSERT INTO kingdom_units(player_id,type,alive)
 SELECT subject,'swordsman',count(*)::integer FROM npcs WHERE village_id=home.id AND role='soldier' ON CONFLICT DO NOTHING;
 INSERT INTO kingdom_legacy_units(npc_id,player_id,unit_type)
 SELECT id,subject,'swordsman' FROM npcs WHERE village_id=home.id AND role='soldier' ON CONFLICT DO NOTHING;

 INSERT INTO strategic_regions(world_id,key,name,kind)
 VALUES(home.world_id,'starter-'||(home.slot/64),'Starter Province '||(home.slot/64+1),'starter')
 ON CONFLICT DO NOTHING;
 SELECT id INTO region FROM strategic_regions
 WHERE world_id=home.world_id AND key='starter-'||(home.slot/64);

 INSERT INTO strategic_plots(region_id,plot,player_id)
 VALUES(region,(home.slot%64)::integer,subject) ON CONFLICT DO NOTHING;

 -- A surveyed viewport may already have created an unowned procedural row at a
 -- registered legacy cell. Adopt that row, but never overwrite another ruler.
 UPDATE strategic_tiles st SET
   owner_player_id=subject,
   owner_clan_id=NULL,
   kind=CASE
     WHEN t.is_home AND NOT EXISTS (
       SELECT 1 FROM strategic_tiles primary_tile
       WHERE primary_tile.owner_player_id=subject
         AND primary_tile.kind='settlement'
         AND (primary_tile.world_id<>st.world_id OR primary_tile.x<>st.x OR primary_tile.z<>st.z)
     ) THEN 'settlement'
     ELSE 'neutral'
   END,
   protected_until=CASE WHEN t.is_home THEN now()+interval '30 days' ELSE NULL END,
   occupied_until=NULL,
   site_type=CASE
     WHEN t.is_home AND NOT EXISTS (
       SELECT 1 FROM strategic_tiles primary_tile
       WHERE primary_tile.owner_player_id=subject
         AND primary_tile.kind='settlement'
         AND (primary_tile.world_id<>st.world_id OR primary_tile.x<>st.x OR primary_tile.z<>st.z)
     ) THEN 'settlement'
     ELSE 'empty'
   END,
   site_level=0,
   resource_type=NULL,
   version=st.version+1
 FROM territories t
 WHERE t.owner_player_id=subject
   AND st.world_id=t.world_id
   AND st.x=t.cell_x
   AND st.z=t.cell_z
   AND st.owner_player_id IS NULL;

 -- Fill only coordinates that do not exist. Repeated initialization becomes a
 -- no-op for strategic ownership, so it cannot create a second primary settlement.
 INSERT INTO strategic_tiles(
   world_id,x,z,owner_player_id,kind,protected_until,
   site_type,site_level,resource_type
 )
 SELECT t.world_id,t.cell_x,t.cell_z,subject,
   CASE
     WHEN t.is_home AND NOT EXISTS (
       SELECT 1 FROM strategic_tiles primary_tile
       WHERE primary_tile.owner_player_id=subject AND primary_tile.kind='settlement'
     ) THEN 'settlement'
     ELSE 'neutral'
   END,
   CASE WHEN t.is_home THEN now()+interval '30 days' ELSE NULL END,
   CASE
     WHEN t.is_home AND NOT EXISTS (
       SELECT 1 FROM strategic_tiles primary_tile
       WHERE primary_tile.owner_player_id=subject AND primary_tile.kind='settlement'
     ) THEN 'settlement'
     ELSE 'empty'
   END,
   0,NULL
 FROM territories t
 WHERE t.owner_player_id=subject
 ON CONFLICT(world_id,x,z) DO NOTHING;
END $$;
