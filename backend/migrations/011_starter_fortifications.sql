-- Starter fortifications are real completed buildings, not cosmetic combat bonuses.
-- Grant missing defenses once. Preserve upgrades and any active construction queue.
INSERT INTO kingdom_buildings(player_id,key,level)
SELECT k.player_id,c.key,CASE WHEN EXISTS(
  SELECT 1 FROM kingdom_tasks t WHERE t.player_id=k.player_id
    AND t.kind='building' AND t.key=c.key AND t.completed_at IS NULL
) THEN 0 ELSE 1 END
FROM kingdoms k CROSS JOIN kingdom_catalog c
WHERE c.kind='building' AND c.key IN ('walls','gatehouse')
ON CONFLICT DO NOTHING;

UPDATE kingdom_buildings b SET level=1
WHERE b.key IN ('walls','gatehouse') AND b.level=0
AND NOT EXISTS(SELECT 1 FROM kingdom_tasks t WHERE t.player_id=b.player_id
  AND t.kind='building' AND t.key=b.key AND t.completed_at IS NULL);

-- ON CONFLICT DO NOTHING keeps every existing player's records and granted units intact.
CREATE OR REPLACE FUNCTION initialize_kingdom(subject uuid) RETURNS void LANGUAGE plpgsql AS $$
DECLARE home villages%ROWTYPE; region uuid;
BEGIN
 SELECT * INTO home FROM villages WHERE owner_player_id=subject;
 IF home.id IS NULL THEN RAISE EXCEPTION 'primary village missing'; END IF;
 INSERT INTO kingdoms(player_id,village_id,empire_name) VALUES(subject,home.id,left(home.name,32)) ON CONFLICT DO NOTHING;
 INSERT INTO kingdom_resources(player_id,resource,amount) SELECT subject,r,500 FROM unnest(ARRAY['food','wood','stone','iron','gold']) r ON CONFLICT DO NOTHING;
 INSERT INTO kingdom_buildings(player_id,key,level) SELECT subject,key,CASE WHEN key IN ('keep','farm','lumber_mill','warehouse','barracks','walls','gatehouse') THEN 1 ELSE 0 END FROM kingdom_catalog WHERE kind='building' ON CONFLICT DO NOTHING;
 INSERT INTO kingdom_research(player_id,key) SELECT subject,key FROM kingdom_catalog WHERE kind='research' ON CONFLICT DO NOTHING;
 INSERT INTO kingdom_units(player_id,type,alive) SELECT subject,'swordsman',count(*)::integer FROM npcs WHERE village_id=home.id AND role='soldier' ON CONFLICT DO NOTHING;
 INSERT INTO kingdom_legacy_units(npc_id,player_id,unit_type) SELECT id,subject,'swordsman' FROM npcs WHERE village_id=home.id AND role='soldier' ON CONFLICT DO NOTHING;
 INSERT INTO strategic_regions(world_id,key,name,kind) VALUES(home.world_id,'starter-'||(home.slot/64),'Starter Province '||(home.slot/64+1),'starter') ON CONFLICT DO NOTHING;
 SELECT id INTO region FROM strategic_regions WHERE world_id=home.world_id AND key='starter-'||(home.slot/64);
 INSERT INTO strategic_plots(region_id,plot,player_id) VALUES(region,(home.slot%64)::integer,subject) ON CONFLICT DO NOTHING;
 INSERT INTO strategic_tiles(world_id,x,z,owner_player_id,kind,protected_until)
 SELECT world_id,cell_x,cell_z,owner_player_id,CASE WHEN is_home THEN 'settlement' ELSE 'neutral' END,
 CASE WHEN is_home THEN now()+interval '30 days' ELSE NULL END FROM territories WHERE owner_player_id=subject ON CONFLICT DO NOTHING;
END $$;
