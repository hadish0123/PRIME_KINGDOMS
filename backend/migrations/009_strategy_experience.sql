-- Forward-only strategy expansion. No existing identity, wallet, queue or village is deleted.
ALTER TABLE kingdoms ADD COLUMN realm_rank integer NOT NULL DEFAULT 1 CHECK(realm_rank BETWEEN 1 AND 6);
ALTER TABLE realm_stage_requirements ADD COLUMN min_economy integer NOT NULL DEFAULT 0;
ALTER TABLE realm_stage_requirements ADD COLUMN min_research integer NOT NULL DEFAULT 0;
ALTER TABLE realm_stage_requirements ADD COLUMN min_prestige integer NOT NULL DEFAULT 0;
UPDATE realm_stage_requirements SET min_economy=(rank-1)*4,min_research=greatest(0,(rank-2)*3),min_prestige=greatest(0,(rank-2)*12);
-- A demanding, attainable lifetime curve; prestige/conquest/season gates remain authoritative.
UPDATE kingdom_level_requirements SET cumulative_xp=CASE WHEN level=1 THEN 0 ELSE floor(100*power((level-1)::numeric,2.2)*power(1.045::numeric,greatest(level-20,0)))::bigint END;
CREATE TABLE kingdom_milestones (
 player_id uuid NOT NULL REFERENCES kingdoms(player_id), key text NOT NULL,
 claimed_at timestamptz NOT NULL, PRIMARY KEY(player_id,key)
);
CREATE TABLE kingdom_inbox (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), player_id uuid NOT NULL REFERENCES kingdoms(player_id),
 event_key text NOT NULL, kind text NOT NULL, title text NOT NULL, message text NOT NULL,
 reference_id uuid, created_at timestamptz NOT NULL DEFAULT now(), seen_at timestamptz,
 UNIQUE(player_id,event_key)
);
CREATE INDEX kingdom_inbox_recent ON kingdom_inbox(player_id,created_at DESC);
CREATE TABLE kingdom_commanders (
 player_id uuid NOT NULL REFERENCES kingdoms(player_id), key text NOT NULL,
 xp bigint NOT NULL DEFAULT 0 CHECK(xp>=0), PRIMARY KEY(player_id,key)
);
ALTER TABLE kingdom_army_presets ADD COLUMN commander text CHECK(commander IN ('arden','serah','idris'));
ALTER TABLE kingdom_army_presets DROP CONSTRAINT kingdom_army_presets_formation_check;
ALTER TABLE kingdom_army_presets ADD CONSTRAINT kingdom_army_presets_formation_check CHECK(formation IN ('balanced','line','wedge','shield','square','skirmish'));
ALTER TABLE kingdom_battles ADD COLUMN replay jsonb;
ALTER TABLE kingdom_battles ADD COLUMN war_id uuid REFERENCES clan_wars(id);
CREATE TABLE kingdom_healing (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), player_id uuid NOT NULL REFERENCES kingdoms(player_id),
 unit_type text NOT NULL, quantity integer NOT NULL CHECK(quantity BETWEEN 1 AND 100),
 finishes_at timestamptz NOT NULL, completed_at timestamptz
);
CREATE UNIQUE INDEX one_healing_queue ON kingdom_healing(player_id) WHERE completed_at IS NULL;
CREATE TABLE kingdom_chat (
 id bigserial PRIMARY KEY, world_id uuid NOT NULL REFERENCES worlds(id), player_id uuid NOT NULL REFERENCES kingdoms(player_id),
 clan_id uuid REFERENCES clans(id), message text NOT NULL CHECK(char_length(message) BETWEEN 1 AND 240),
 created_at timestamptz NOT NULL DEFAULT now(), hidden_at timestamptz
);
CREATE INDEX kingdom_chat_world ON kingdom_chat(world_id,id DESC) WHERE clan_id IS NULL;
CREATE INDEX kingdom_chat_clan ON kingdom_chat(clan_id,id DESC) WHERE clan_id IS NOT NULL;
CREATE TABLE kingdom_blocks (
 player_id uuid NOT NULL REFERENCES kingdoms(player_id), target_id uuid NOT NULL REFERENCES kingdoms(player_id),
 PRIMARY KEY(player_id,target_id), CHECK(player_id<>target_id)
);
CREATE TABLE kingdom_reports (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), player_id uuid NOT NULL REFERENCES kingdoms(player_id),
 message_id bigint NOT NULL REFERENCES kingdom_chat(id), reason text NOT NULL CHECK(char_length(reason) BETWEEN 3 AND 240),
 created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(player_id,message_id)
);
ALTER TABLE clans ADD COLUMN description text NOT NULL DEFAULT '' CHECK(char_length(description)<=240);
ALTER TABLE clans ADD COLUMN announcement text NOT NULL DEFAULT '' CHECK(char_length(announcement)<=240);
CREATE TABLE clan_activity (
 id bigserial PRIMARY KEY, clan_id uuid NOT NULL REFERENCES clans(id),
 player_id uuid REFERENCES players(id), kind text NOT NULL, message text NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE clan_wars ADD COLUMN resolved_at timestamptz;
ALTER TABLE clan_wars ADD COLUMN winner_id uuid REFERENCES clans(id);
ALTER TABLE clan_wars ADD COLUMN rewards_paid boolean NOT NULL DEFAULT false;
CREATE TABLE clan_war_contributions (
 war_id uuid NOT NULL REFERENCES clan_wars(id), player_id uuid NOT NULL REFERENCES kingdoms(player_id),
 clan_id uuid NOT NULL REFERENCES clans(id), score integer NOT NULL DEFAULT 0 CHECK(score>=0),
 PRIMARY KEY(war_id,player_id)
);
INSERT INTO kingdom_catalog(kind,key,data) VALUES
('building','granary','{"name":"Granary","baseCost":{"wood":90,"stone":60},"maxLevel":30,"seconds":40,"xp":50}'),
('building','embassy','{"name":"Embassy","baseCost":{"wood":180,"stone":120,"gold":80},"maxLevel":20,"seconds":60,"xp":60}'),
('building','gatehouse','{"name":"Gatehouse","baseCost":{"stone":180,"iron":50},"maxLevel":30,"seconds":60,"prerequisite":"walls","xp":60}'),
('building','trading_post','{"name":"Trading Post","baseCost":{"wood":140,"gold":40},"maxLevel":20,"seconds":40,"prerequisite":"market","xp":50}'),
('building','commander_hall','{"name":"Commander Hall","baseCost":{"stone":150,"wood":120,"gold":90},"maxLevel":20,"seconds":60,"prerequisite":"barracks","xp":60}'),
('building','training_grounds','{"name":"Training Grounds","baseCost":{"wood":100,"stone":70},"maxLevel":20,"seconds":40,"prerequisite":"barracks","xp":50}'),
('unit','militia','{"name":"Militia","category":"infantry","facility":"barracks","requiredLevel":1,"health":55,"attack":7,"defense":5,"speed":3,"cost":{"food":15,"wood":10},"seconds":12}'),
('unit','pikeman','{"name":"Pikeman","category":"infantry","facility":"barracks","requiredLevel":4,"health":95,"attack":19,"defense":12,"speed":2.6,"cost":{"food":35,"wood":30,"iron":20},"seconds":25}'),
('unit','trebuchet','{"name":"Trebuchet","category":"siege","facility":"siege_workshop","requiredLevel":8,"health":320,"attack":85,"defense":10,"speed":0.8,"cost":{"wood":300,"stone":80,"iron":90,"gold":70},"seconds":120}')
ON CONFLICT DO NOTHING;
UPDATE kingdom_catalog SET data=jsonb_set(data,'{name}','"Keep"') WHERE kind='building' AND key='keep';
UPDATE kingdom_catalog SET data=jsonb_set(data,'{name}','"Clan Hall"') WHERE kind='building' AND key='clan_hall';
INSERT INTO kingdom_config(key,value) VALUES ('war_preparation_seconds','3600'),('war_battle_seconds','86400'),('war_cooldown_seconds','86400'),('war_gold_cost','1000') ON CONFLICT DO NOTHING;

-- Legacy scene rows are archival. New strategy kingdoms need no movement record.
CREATE OR REPLACE FUNCTION initialize_kingdom(subject uuid) RETURNS void LANGUAGE plpgsql AS $$
DECLARE home villages%ROWTYPE; region uuid;
BEGIN
 SELECT * INTO home FROM villages WHERE owner_player_id=subject;
 IF home.id IS NULL THEN RAISE EXCEPTION 'primary village missing'; END IF;
 INSERT INTO kingdoms(player_id,village_id,empire_name) VALUES(subject,home.id,left(home.name,32)) ON CONFLICT DO NOTHING;
 INSERT INTO kingdom_resources(player_id,resource,amount) SELECT subject,r,500 FROM unnest(ARRAY['food','wood','stone','iron','gold']) r ON CONFLICT DO NOTHING;
 INSERT INTO kingdom_buildings(player_id,key,level) SELECT subject,key,CASE WHEN key IN ('keep','farm','lumber_mill','warehouse','barracks') THEN 1 ELSE 0 END FROM kingdom_catalog WHERE kind='building' ON CONFLICT DO NOTHING;
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

ALTER TABLE clan_members ADD COLUMN IF NOT EXISTS contribution bigint NOT NULL DEFAULT 0 CHECK(contribution>=0);

INSERT INTO kingdom_config(key,value) VALUES('daily_battle_xp_cap','4000') ON CONFLICT DO NOTHING;
