-- Additive v2 strategy domain. Legacy records and migration checksums are preserved.
CREATE TABLE kingdom_catalog (
 kind text NOT NULL CHECK(kind IN ('building','unit','research')), key text NOT NULL,
 data jsonb NOT NULL CHECK(jsonb_typeof(data)='object'), PRIMARY KEY(kind,key)
);
INSERT INTO kingdom_catalog(kind,key,data) VALUES
('building','keep','{"name":"Town Hall / Keep","baseCost":{"wood":160,"stone":120,"gold":40},"maxLevel":30,"seconds":30,"prerequisite":null,"effect":null,"xp":50}'::jsonb),
('building','barracks','{"name":"Barracks","baseCost":{"wood":100,"stone":60},"maxLevel":20,"seconds":30,"prerequisite":null,"effect":null,"xp":50}'::jsonb),
('building','archery_range','{"name":"Archery Range","baseCost":{"wood":140,"iron":30},"maxLevel":20,"seconds":30,"prerequisite":"barracks","effect":null,"xp":50}'::jsonb),
('building','stable','{"name":"Stable","baseCost":{"wood":160,"stone":80,"food":60},"maxLevel":20,"seconds":30,"prerequisite":"barracks","effect":null,"xp":50}'::jsonb),
('building','blacksmith','{"name":"Blacksmith","baseCost":{"wood":120,"stone":100,"iron":60},"maxLevel":20,"seconds":30,"prerequisite":null,"effect":null,"xp":50}'::jsonb),
('building','workshop','{"name":"Workshop","baseCost":{"wood":160,"stone":100},"maxLevel":20,"seconds":30,"prerequisite":"blacksmith","effect":null,"xp":50}'::jsonb),
('building','academy','{"name":"Academy","baseCost":{"wood":150,"stone":100,"gold":80},"maxLevel":20,"seconds":30,"prerequisite":null,"effect":null,"xp":50}'::jsonb),
('building','market','{"name":"Market","baseCost":{"wood":120,"stone":50,"gold":50},"maxLevel":20,"seconds":30,"prerequisite":null,"effect":"gold","xp":50}'::jsonb),
('building','warehouse','{"name":"Warehouse","baseCost":{"wood":120,"stone":80},"maxLevel":30,"seconds":30,"prerequisite":null,"effect":null,"xp":50}'::jsonb),
('building','farm','{"name":"Farm","baseCost":{"wood":80,"stone":30},"maxLevel":30,"seconds":30,"prerequisite":null,"effect":"food","xp":50}'::jsonb),
('building','lumber_mill','{"name":"Lumber Mill","baseCost":{"wood":60,"stone":40},"maxLevel":30,"seconds":30,"prerequisite":null,"effect":"wood","xp":50}'::jsonb),
('building','quarry','{"name":"Quarry","baseCost":{"wood":100,"iron":20},"maxLevel":30,"seconds":30,"prerequisite":null,"effect":"stone","xp":50}'::jsonb),
('building','iron_mine','{"name":"Iron Mine","baseCost":{"wood":140,"stone":80},"maxLevel":30,"seconds":30,"prerequisite":"quarry","effect":"iron","xp":50}'::jsonb),
('building','hospital','{"name":"Hospital","baseCost":{"wood":140,"stone":100,"gold":50},"maxLevel":20,"seconds":30,"prerequisite":"academy","effect":null,"xp":50}'::jsonb),
('building','clan_hall','{"name":"Embassy / Clan Hall","baseCost":{"wood":180,"stone":120,"gold":120},"maxLevel":20,"seconds":30,"prerequisite":null,"effect":null,"xp":50}'::jsonb),
('building','walls','{"name":"Walls","baseCost":{"stone":200,"wood":80},"maxLevel":30,"seconds":30,"prerequisite":null,"effect":null,"xp":50}'::jsonb),
('building','watch_towers','{"name":"Watch Towers","baseCost":{"stone":150,"wood":100},"maxLevel":20,"seconds":30,"prerequisite":"walls","effect":null,"xp":50}'::jsonb),
('building','siege_workshop','{"name":"Siege Workshop","baseCost":{"wood":240,"stone":180,"iron":100},"maxLevel":20,"seconds":30,"prerequisite":"workshop","effect":null,"xp":50}'::jsonb),
('unit','swordsman','{"name":"Swordsman","category":"infantry","facility":"barracks","requiredLevel":1,"health":80,"attack":12,"defense":8,"speed":3,"cost":{"food":30,"wood":15,"iron":10},"seconds":20,"upkeep":1,"equipmentCategory":"infantry"}'::jsonb),
('unit','spearman','{"name":"Spearman","category":"infantry","facility":"barracks","requiredLevel":1,"health":70,"attack":14,"defense":6,"speed":3.2,"cost":{"food":25,"wood":25,"iron":5},"seconds":20,"upkeep":1,"equipmentCategory":"infantry"}'::jsonb),
('unit','shield_guard','{"name":"Shield Guard","category":"infantry","facility":"barracks","requiredLevel":3,"health":110,"attack":9,"defense":16,"speed":2.5,"cost":{"food":40,"wood":20,"iron":25},"seconds":20,"upkeep":1,"equipmentCategory":"infantry"}'::jsonb),
('unit','heavy_infantry','{"name":"Heavy Infantry","category":"infantry","facility":"barracks","requiredLevel":6,"health":150,"attack":20,"defense":18,"speed":2,"cost":{"food":50,"iron":40,"gold":15},"seconds":20,"upkeep":1,"equipmentCategory":"infantry"}'::jsonb),
('unit','archer','{"name":"Archer","category":"ranged","facility":"archery_range","requiredLevel":1,"health":50,"attack":18,"defense":3,"speed":3.5,"cost":{"food":25,"wood":30},"seconds":20,"upkeep":1,"equipmentCategory":"ranged"}'::jsonb),
('unit','crossbowman','{"name":"Crossbowman","category":"ranged","facility":"archery_range","requiredLevel":3,"health":65,"attack":25,"defense":6,"speed":2.8,"cost":{"food":35,"wood":30,"iron":15},"seconds":20,"upkeep":1,"equipmentCategory":"ranged"}'::jsonb),
('unit','light_cavalry','{"name":"Light Cavalry","category":"cavalry","facility":"stable","requiredLevel":1,"health":120,"attack":20,"defense":8,"speed":8,"cost":{"food":65,"wood":20,"iron":15,"gold":20},"seconds":20,"upkeep":1,"equipmentCategory":"cavalry"}'::jsonb),
('unit','heavy_cavalry','{"name":"Heavy Cavalry","category":"cavalry","facility":"stable","requiredLevel":3,"health":180,"attack":30,"defense":20,"speed":6.5,"cost":{"food":90,"iron":50,"gold":40},"seconds":20,"upkeep":1,"equipmentCategory":"cavalry"}'::jsonb),
('unit','royal_cavalry','{"name":"Royal Cavalry","category":"cavalry","facility":"stable","requiredLevel":6,"health":220,"attack":40,"defense":28,"speed":7,"cost":{"food":130,"iron":70,"gold":70},"seconds":20,"upkeep":1,"equipmentCategory":"cavalry"}'::jsonb),
('unit','battering_ram','{"name":"Battering Ram","category":"siege","facility":"siege_workshop","requiredLevel":1,"health":450,"attack":35,"defense":25,"speed":1,"cost":{"wood":200,"iron":50,"gold":30},"seconds":90,"upkeep":3,"equipmentCategory":"siege"}'::jsonb),
('unit','ballista','{"name":"Ballista","category":"siege","facility":"siege_workshop","requiredLevel":3,"health":220,"attack":50,"defense":10,"speed":1.5,"cost":{"wood":160,"iron":70,"gold":40},"seconds":90,"upkeep":3,"equipmentCategory":"siege"}'::jsonb),
('unit','catapult','{"name":"Catapult","category":"siege","facility":"siege_workshop","requiredLevel":6,"health":280,"attack":65,"defense":12,"speed":1,"cost":{"wood":220,"stone":60,"iron":70,"gold":50},"seconds":90,"upkeep":3,"equipmentCategory":"siege"}'::jsonb),
('unit','siege_tower','{"name":"Siege Tower","category":"siege","facility":"siege_workshop","requiredLevel":6,"health":600,"attack":20,"defense":35,"speed":0.8,"cost":{"wood":300,"iron":100,"gold":70},"seconds":90,"upkeep":3,"equipmentCategory":"siege"}'::jsonb),
('research','economy','{"name":"Economy","maxLevel":20,"baseCost":{"wood":80,"stone":60,"iron":30,"gold":40},"seconds":60,"prerequisite":null,"xp":30}'::jsonb),
('research','agriculture','{"name":"Agriculture","maxLevel":20,"baseCost":{"wood":80,"stone":60,"iron":30,"gold":40},"seconds":60,"prerequisite":"economy","xp":30}'::jsonb),
('research','construction','{"name":"Construction","maxLevel":20,"baseCost":{"wood":80,"stone":60,"iron":30,"gold":40},"seconds":60,"prerequisite":"economy","xp":30}'::jsonb),
('research','infantry','{"name":"Infantry","maxLevel":20,"baseCost":{"wood":80,"stone":60,"iron":30,"gold":40},"seconds":60,"prerequisite":null,"xp":30}'::jsonb),
('research','archery','{"name":"Archery","maxLevel":20,"baseCost":{"wood":80,"stone":60,"iron":30,"gold":40},"seconds":60,"prerequisite":"economy","xp":30}'::jsonb),
('research','cavalry','{"name":"Cavalry","maxLevel":20,"baseCost":{"wood":80,"stone":60,"iron":30,"gold":40},"seconds":60,"prerequisite":"economy","xp":30}'::jsonb),
('research','siege','{"name":"Siege","maxLevel":20,"baseCost":{"wood":80,"stone":60,"iron":30,"gold":40},"seconds":60,"prerequisite":"economy","xp":30}'::jsonb),
('research','defense','{"name":"Defense","maxLevel":20,"baseCost":{"wood":80,"stone":60,"iron":30,"gold":40},"seconds":60,"prerequisite":"economy","xp":30}'::jsonb),
('research','logistics','{"name":"Logistics","maxLevel":20,"baseCost":{"wood":80,"stone":60,"iron":30,"gold":40},"seconds":60,"prerequisite":"economy","xp":30}'::jsonb),
('research','medicine','{"name":"Medicine","maxLevel":20,"baseCost":{"wood":80,"stone":60,"iron":30,"gold":40},"seconds":60,"prerequisite":"economy","xp":30}'::jsonb),
('research','leadership','{"name":"Leadership","maxLevel":20,"baseCost":{"wood":80,"stone":60,"iron":30,"gold":40},"seconds":60,"prerequisite":null,"xp":30}'::jsonb);
CREATE TABLE kingdom_level_requirements (
 level integer PRIMARY KEY CHECK(level BETWEEN 1 AND 100), cumulative_xp bigint NOT NULL CHECK(cumulative_xp BETWEEN 0 AND 8000000000000000),
 prestige integer NOT NULL DEFAULT 0, conquests integer NOT NULL DEFAULT 0,
 seasonal_medals integer NOT NULL DEFAULT 0, ascension_tokens integer NOT NULL DEFAULT 0
);
INSERT INTO kingdom_level_requirements(level,cumulative_xp,prestige,conquests,seasonal_medals,ascension_tokens)
 SELECT l, CASE WHEN l=1 THEN 0 ELSE floor(100*power((l-1)::numeric,2.5)*power(1.18::numeric,greatest(l-20,0)))::bigint END,
 CASE WHEN l<76 THEN 0 ELSE (l-75)*100 END, CASE WHEN l<91 THEN 0 ELSE (l-90)*100 END,
 CASE WHEN l<96 THEN 0 ELSE (l-95)*20 END, CASE WHEN l=100 THEN 3 ELSE 0 END FROM generate_series(1,100) l;
CREATE TABLE kingdoms (
 player_id uuid PRIMARY KEY REFERENCES players(id), village_id uuid NOT NULL UNIQUE REFERENCES villages(id),
 empire_name text NOT NULL CHECK(char_length(empire_name) BETWEEN 2 AND 32),
 primary_color text NOT NULL DEFAULT '#8f2636' CHECK(primary_color ~ '^#[0-9a-f]{6}$'),
 secondary_color text NOT NULL DEFAULT '#d5b35e' CHECK(secondary_color ~ '^#[0-9a-f]{6}$'),
 emblem text NOT NULL DEFAULT 'lion' CHECK(emblem IN ('lion','eagle','crown','stag','sun','wolf')),
 banner_style text NOT NULL DEFAULT 'swallowtail' CHECK(banner_style IN ('square','swallowtail','pennant')),
 xp bigint NOT NULL DEFAULT 0 CHECK(xp BETWEEN 0 AND 8000000000000000),
 prestige integer NOT NULL DEFAULT 0 CHECK(prestige>=0), conquests integer NOT NULL DEFAULT 0 CHECK(conquests>=0),
 seasonal_medals integer NOT NULL DEFAULT 0 CHECK(seasonal_medals>=0), ascension_tokens integer NOT NULL DEFAULT 0 CHECK(ascension_tokens>=0),
 settled_at timestamptz NOT NULL DEFAULT now(), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE kingdom_resources (
 player_id uuid NOT NULL REFERENCES kingdoms(player_id), resource text NOT NULL CHECK(resource IN ('food','wood','stone','iron','gold')),
 amount bigint NOT NULL CHECK(amount BETWEEN 0 AND 1000000000000), remainder integer NOT NULL DEFAULT 0 CHECK(remainder BETWEEN 0 AND 3599999),
 PRIMARY KEY(player_id,resource)
);
CREATE TABLE kingdom_buildings (
 player_id uuid NOT NULL REFERENCES kingdoms(player_id), key text NOT NULL,
 level integer NOT NULL DEFAULT 0 CHECK(level BETWEEN 0 AND 30), PRIMARY KEY(player_id,key)
);
CREATE TABLE kingdom_research (
 player_id uuid NOT NULL REFERENCES kingdoms(player_id), key text NOT NULL,
 level integer NOT NULL DEFAULT 0 CHECK(level BETWEEN 0 AND 20), PRIMARY KEY(player_id,key)
);
CREATE TABLE kingdom_units (
 player_id uuid NOT NULL REFERENCES kingdoms(player_id), type text NOT NULL,
 tier integer NOT NULL DEFAULT 1 CHECK(tier BETWEEN 1 AND 10), level integer NOT NULL DEFAULT 1 CHECK(level BETWEEN 1 AND 100),
 alive integer NOT NULL DEFAULT 0 CHECK(alive BETWEEN 0 AND 100000), wounded integer NOT NULL DEFAULT 0 CHECK(wounded BETWEEN 0 AND 100000),
 dead integer NOT NULL DEFAULT 0 CHECK(dead BETWEEN 0 AND 10000000), PRIMARY KEY(player_id,type)
);
CREATE TABLE kingdom_legacy_units (
 npc_id uuid PRIMARY KEY REFERENCES npcs(id), player_id uuid NOT NULL REFERENCES kingdoms(player_id), unit_type text NOT NULL
);
CREATE TABLE kingdom_tasks (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), player_id uuid NOT NULL REFERENCES kingdoms(player_id),
 kind text NOT NULL CHECK(kind IN ('building','research','training')), key text NOT NULL,
 target_level integer NOT NULL DEFAULT 1 CHECK(target_level BETWEEN 1 AND 30), quantity integer NOT NULL DEFAULT 1 CHECK(quantity BETWEEN 1 AND 100),
 started_at timestamptz NOT NULL, finishes_at timestamptz NOT NULL CHECK(finishes_at>started_at),
 completed_at timestamptz, cost jsonb NOT NULL, xp integer NOT NULL DEFAULT 0 CHECK(xp>=0)
);
CREATE UNIQUE INDEX kingdom_one_active_queue ON kingdom_tasks(player_id,kind) WHERE completed_at IS NULL;
CREATE INDEX kingdom_tasks_due ON kingdom_tasks(player_id,finishes_at) WHERE completed_at IS NULL;
CREATE TABLE kingdom_requests (
 player_id uuid NOT NULL REFERENCES kingdoms(player_id), request_id uuid NOT NULL,
 operation text NOT NULL, payload_hash text NOT NULL, response jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(player_id,request_id)
);
CREATE TABLE kingdom_xp_events (
 player_id uuid NOT NULL REFERENCES kingdoms(player_id), source text NOT NULL, event_id text NOT NULL,
 amount integer NOT NULL CHECK(amount BETWEEN 0 AND 100000), occurred_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(player_id,source,event_id)
);
CREATE INDEX kingdom_xp_daily ON kingdom_xp_events(player_id,occurred_at);
CREATE TABLE kingdom_scenes (
 player_id uuid PRIMARY KEY REFERENCES kingdoms(player_id), x double precision NOT NULL DEFAULT 0, y double precision NOT NULL DEFAULT 0.1,
 z double precision NOT NULL DEFAULT 12, yaw double precision NOT NULL DEFAULT pi(), mounted boolean NOT NULL DEFAULT false,
 horse_x double precision NOT NULL DEFAULT 12, horse_y double precision NOT NULL DEFAULT 0.1, horse_z double precision NOT NULL DEFAULT 20,
 movement_credit double precision NOT NULL DEFAULT 4 CHECK(movement_credit BETWEEN 0 AND 4), updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK(abs(x)<=128 AND abs(z)<=128 AND y BETWEEN -2 AND 100), CHECK(abs(horse_x)<=128 AND abs(horse_z)<=128)
);
CREATE TABLE strategic_regions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), world_id uuid NOT NULL REFERENCES worlds(id),
 key text NOT NULL, name text NOT NULL, kind text NOT NULL CHECK(kind IN ('starter','clan')),
 UNIQUE(world_id,key)
);
CREATE TABLE strategic_plots (
 region_id uuid NOT NULL REFERENCES strategic_regions(id), plot integer NOT NULL CHECK(plot BETWEEN 0 AND 1023),
 player_id uuid UNIQUE REFERENCES kingdoms(player_id), PRIMARY KEY(region_id,plot)
);
CREATE TABLE strategic_tiles (
 world_id uuid NOT NULL REFERENCES worlds(id), x integer NOT NULL, z integer NOT NULL,
 owner_player_id uuid REFERENCES kingdoms(player_id), kind text NOT NULL CHECK(kind IN ('settlement','neutral','resource','npc','fort')),
 protected_until timestamptz, occupied_until timestamptz, version integer NOT NULL DEFAULT 1,
 PRIMARY KEY(world_id,x,z)
);
CREATE INDEX strategic_tiles_owner ON strategic_tiles(owner_player_id);
CREATE TABLE kingdom_config (key text PRIMARY KEY, value jsonb NOT NULL);
INSERT INTO kingdom_config VALUES ('daily_training_xp_cap','1000'),('daily_research_xp_cap','3000'),('army_capacity_per_barracks_level','100'),('resource_base_capacity','5000');

CREATE FUNCTION initialize_kingdom(subject uuid) RETURNS void LANGUAGE plpgsql AS $$
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
 INSERT INTO kingdom_scenes(player_id,x,y,z,yaw,mounted,horse_x,horse_y,horse_z)
 SELECT subject,CASE WHEN abs(p.x-home.x)<=128 AND abs(p.z-home.z)<=128 THEN p.x-home.x ELSE 0 END,
 CASE WHEN abs(p.x-home.x)<=128 AND abs(p.z-home.z)<=128 THEN greatest(-2,least(100,p.y-home.y)) ELSE 0.1 END,
 CASE WHEN abs(p.x-home.x)<=128 AND abs(p.z-home.z)<=128 THEN p.z-home.z ELSE 12 END,p.yaw,
 p.mounted AND abs(p.x-home.x)<=128 AND abs(p.z-home.z)<=128 AND abs(p.horse_x-home.x)<=128 AND abs(p.horse_z-home.z)<=128,
 CASE WHEN abs(p.horse_x-home.x)<=128 AND abs(p.horse_z-home.z)<=128 THEN p.horse_x-home.x ELSE 12 END,
 CASE WHEN abs(p.horse_x-home.x)<=128 AND abs(p.horse_z-home.z)<=128 THEN p.horse_y-home.y ELSE 0.1 END,
 CASE WHEN abs(p.horse_x-home.x)<=128 AND abs(p.horse_z-home.z)<=128 THEN p.horse_z-home.z ELSE 20 END FROM players p WHERE p.id=subject ON CONFLICT DO NOTHING;
 INSERT INTO strategic_regions(world_id,key,name,kind) VALUES(home.world_id,'starter-'||(home.slot/64),'Starter Province '||(home.slot/64+1),'starter') ON CONFLICT DO NOTHING;
 SELECT id INTO region FROM strategic_regions WHERE world_id=home.world_id AND key='starter-'||(home.slot/64);
 INSERT INTO strategic_plots(region_id,plot,player_id) VALUES(region,(home.slot%64)::integer,subject) ON CONFLICT DO NOTHING;
 INSERT INTO strategic_tiles(world_id,x,z,owner_player_id,kind,protected_until)
 SELECT world_id,cell_x,cell_z,owner_player_id,CASE WHEN is_home THEN 'settlement' ELSE 'neutral' END,
 CASE WHEN is_home THEN now()+interval '30 days' ELSE NULL END FROM territories WHERE owner_player_id=subject ON CONFLICT DO NOTHING;
END $$;
SELECT initialize_kingdom(id) FROM players;
