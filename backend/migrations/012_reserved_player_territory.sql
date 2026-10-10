-- Repair lazy strategy initialization when a world viewport was surveyed first.
-- Registered legacy territory remains reserved; generated neutral rows may be safely
-- converted only when they are still unowned.

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

 INSERT INTO strategic_tiles(
   world_id,x,z,owner_player_id,kind,protected_until,
   site_type,site_level,resource_type
 )
 SELECT world_id,cell_x,cell_z,owner_player_id,
   CASE WHEN is_home THEN 'settlement' ELSE 'neutral' END,
   CASE WHEN is_home THEN now()+interval '30 days' ELSE NULL END,
   CASE WHEN is_home THEN 'settlement' ELSE 'empty' END,
   0,NULL
 FROM territories WHERE owner_player_id=subject
 ON CONFLICT(world_id,x,z) DO UPDATE SET
   owner_player_id=EXCLUDED.owner_player_id,
   owner_clan_id=NULL,
   kind=EXCLUDED.kind,
   protected_until=EXCLUDED.protected_until,
   occupied_until=NULL,
   site_type=EXCLUDED.site_type,
   site_level=0,
   resource_type=NULL,
   version=strategic_tiles.version+1
 WHERE strategic_tiles.owner_player_id IS NULL
    OR strategic_tiles.owner_player_id=EXCLUDED.owner_player_id;
END $$;
