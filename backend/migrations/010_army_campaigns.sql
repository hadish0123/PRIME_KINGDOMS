-- Additive campaign records. Existing troop totals and reports remain intact.
CREATE TABLE kingdom_marches (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 player_id uuid NOT NULL REFERENCES kingdoms(player_id),
 world_id uuid NOT NULL REFERENCES worlds(id),
 preset_slot integer NOT NULL CHECK(preset_slot BETWEEN 1 AND 5),
 name text NOT NULL,
 kind text NOT NULL CHECK(kind IN ('attack','reinforce')),
 phase text NOT NULL CHECK(phase IN ('outbound','returning','stationed','completed')),
 formation text NOT NULL,
 stance text NOT NULL,
 commander text,
 target_x integer NOT NULL,
 target_z integer NOT NULL,
 target_owner_id uuid REFERENCES players(id),
 route_from_x double precision NOT NULL,
 route_from_z double precision NOT NULL,
 route_to_x double precision NOT NULL,
 route_to_z double precision NOT NULL,
 departed_at timestamptz NOT NULL,
 route_started_at timestamptz NOT NULL,
 arrives_at timestamptz,
 completed_at timestamptz,
 report_id uuid REFERENCES kingdom_battles(id),
 return_reason text,
 CHECK(kind<>'reinforce' OR target_owner_id IS NOT NULL),
 CHECK(arrives_at IS NULL OR arrives_at>route_started_at),
 CHECK((phase='completed')=(completed_at IS NOT NULL)),
 CHECK(phase<>'stationed' OR (kind='reinforce' AND arrives_at IS NULL))
);
CREATE INDEX kingdom_marches_due ON kingdom_marches(arrives_at,id)
 WHERE phase IN ('outbound','returning');
CREATE INDEX kingdom_marches_owner ON kingdom_marches(player_id,phase);
CREATE INDEX kingdom_marches_target ON kingdom_marches(target_owner_id,phase);
CREATE TABLE kingdom_march_units (
 march_id uuid NOT NULL REFERENCES kingdom_marches(id),
 unit_type text NOT NULL,
 quantity integer NOT NULL CHECK(quantity>=0),
 PRIMARY KEY(march_id,unit_type)
);
-- Healthy totals retain their established meaning. Availability excludes every
-- expedition until its survivors physically return to their own settlement.
CREATE VIEW kingdom_unit_availability AS
 SELECT u.*,u.alive-coalesce(r.deployed,0)::integer AS available,
        coalesce(r.deployed,0)::integer AS deployed
 FROM kingdom_units u
 LEFT JOIN (
  SELECT m.player_id,mu.unit_type,sum(mu.quantity) AS deployed
  FROM kingdom_marches m JOIN kingdom_march_units mu ON mu.march_id=m.id
  WHERE m.phase<>'completed' GROUP BY m.player_id,mu.unit_type
 ) r ON r.player_id=u.player_id AND r.unit_type=u.type;
INSERT INTO kingdom_config(key,value) VALUES
 ('march_minimum_seconds','10'),('march_tile_seconds','30'),
 ('march_maximum_seconds','43200'),('march_maximum_slots','3')
ON CONFLICT DO NOTHING;
ALTER TABLE kingdom_battles ADD COLUMN reinforcement_losses jsonb NOT NULL DEFAULT '[]'::jsonb;
