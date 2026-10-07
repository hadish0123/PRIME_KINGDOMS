-- Strategic command, online presence and battle/conquest foundation.
-- Additive only: legacy/v0.7 records remain authoritative and intact.

CREATE TABLE realm_stage_requirements (
  stage text PRIMARY KEY CHECK(stage IN ('village','town','city','country','kingdom','empire')),
  rank integer NOT NULL UNIQUE CHECK(rank BETWEEN 1 AND 6),
  display_name text NOT NULL,
  min_keep integer NOT NULL CHECK(min_keep BETWEEN 1 AND 30),
  min_player_level integer NOT NULL CHECK(min_player_level BETWEEN 1 AND 100),
  min_owned_tiles integer NOT NULL CHECK(min_owned_tiles BETWEEN 1 AND 100000),
  min_conquests integer NOT NULL CHECK(min_conquests BETWEEN 0 AND 1000000)
);
INSERT INTO realm_stage_requirements(stage,rank,display_name,min_keep,min_player_level,min_owned_tiles,min_conquests) VALUES
('village',1,'Village',1,1,1,0),
('town',2,'Town',4,8,3,1),
('city',3,'City',8,20,8,4),
('country',4,'Country',12,35,18,12),
('kingdom',5,'Kingdom',18,55,35,30),
('empire',6,'Empire',24,75,64,60);

CREATE TABLE kingdom_army_presets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL REFERENCES kingdoms(player_id),
  slot integer NOT NULL CHECK(slot BETWEEN 1 AND 5),
  name text NOT NULL CHECK(char_length(name) BETWEEN 2 AND 24),
  formation text NOT NULL CHECK(formation IN ('balanced','line','wedge','shield')),
  stance text NOT NULL CHECK(stance IN ('aggressive','balanced','defensive')),
  is_defense boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(player_id,slot)
);
CREATE UNIQUE INDEX kingdom_one_defense_preset ON kingdom_army_presets(player_id) WHERE is_defense;

CREATE TABLE kingdom_army_preset_units (
  preset_id uuid NOT NULL REFERENCES kingdom_army_presets(id) ON DELETE CASCADE,
  unit_type text NOT NULL,
  quantity integer NOT NULL CHECK(quantity BETWEEN 1 AND 100000),
  PRIMARY KEY(preset_id,unit_type)
);

CREATE TABLE kingdom_battles (
  id uuid PRIMARY KEY,
  world_id uuid NOT NULL REFERENCES worlds(id),
  attacker_id uuid NOT NULL REFERENCES kingdoms(player_id),
  defender_id uuid REFERENCES kingdoms(player_id),
  target_x integer NOT NULL,
  target_z integer NOT NULL,
  target_kind text NOT NULL CHECK(target_kind IN ('settlement','neutral','resource','npc','fort')),
  attacker_preset_slot integer NOT NULL CHECK(attacker_preset_slot BETWEEN 1 AND 5),
  seed text NOT NULL,
  attacker_power numeric NOT NULL CHECK(attacker_power>=0),
  defender_power numeric NOT NULL CHECK(defender_power>=0),
  result text NOT NULL CHECK(result IN ('attacker','defender','draw')),
  attacker_losses jsonb NOT NULL CHECK(jsonb_typeof(attacker_losses)='object'),
  defender_losses jsonb NOT NULL CHECK(jsonb_typeof(defender_losses)='object'),
  rewards jsonb NOT NULL CHECK(jsonb_typeof(rewards)='object'),
  territory_change text NOT NULL CHECK(territory_change IN ('none','captured','occupied','fort_captured')),
  started_at timestamptz NOT NULL,
  resolved_at timestamptz NOT NULL,
  CHECK(resolved_at>=started_at)
);
CREATE INDEX kingdom_battles_attacker ON kingdom_battles(attacker_id,resolved_at DESC);
CREATE INDEX kingdom_battles_defender ON kingdom_battles(defender_id,resolved_at DESC) WHERE defender_id IS NOT NULL;
CREATE INDEX kingdom_battles_tile ON kingdom_battles(world_id,target_x,target_z,resolved_at DESC);

ALTER TABLE strategic_tiles ADD COLUMN captured_at timestamptz;
ALTER TABLE strategic_tiles ADD COLUMN last_battle_id uuid;

CREATE TABLE kingdom_battle_reports (
  battle_id uuid NOT NULL REFERENCES kingdom_battles(id) ON DELETE CASCADE,
  player_id uuid NOT NULL REFERENCES kingdoms(player_id),
  perspective text NOT NULL CHECK(perspective IN ('attacker','defender')),
  seen_at timestamptz,
  PRIMARY KEY(battle_id,player_id)
);
CREATE INDEX kingdom_reports_player ON kingdom_battle_reports(player_id,seen_at);

INSERT INTO kingdom_config(key,value) VALUES
('battle_capture_protection_seconds','900'),
('battle_settlement_occupation_seconds','1800'),
('battle_report_limit','50')
ON CONFLICT(key) DO NOTHING;
