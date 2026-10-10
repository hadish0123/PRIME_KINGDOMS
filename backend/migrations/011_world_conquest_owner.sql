-- World conquest art/gameplay metadata and server-owned special-account capabilities.
-- Forward-only: existing worlds, tiles, owners, battles and identities remain intact.

ALTER TABLE strategic_tiles
  ADD COLUMN biome text NOT NULL DEFAULT 'grassland'
    CHECK (biome IN ('grassland','forest','highlands','wetlands')),
  ADD COLUMN site_type text NOT NULL DEFAULT 'empty'
    CHECK (site_type IN ('empty','resource_node','npc_camp','wildlife','settlement','fort')),
  ADD COLUMN site_level integer NOT NULL DEFAULT 0 CHECK(site_level BETWEEN 0 AND 10),
  ADD COLUMN resource_type text CHECK(resource_type IN ('food','wood','stone','iron','gold'));

UPDATE strategic_tiles
SET site_type=CASE kind
  WHEN 'settlement' THEN 'settlement'
  WHEN 'fort' THEN 'fort'
  WHEN 'resource' THEN 'resource_node'
  WHEN 'npc' THEN 'npc_camp'
  ELSE 'empty'
END,
resource_type=CASE WHEN kind='resource' THEN 'wood' ELSE NULL END
WHERE site_type='empty';

CREATE INDEX strategic_tiles_world_site ON strategic_tiles(world_id,site_type,x,z);
CREATE INDEX strategic_tiles_world_biome ON strategic_tiles(world_id,biome,x,z);

CREATE TABLE kingdom_capabilities (
  player_id uuid PRIMARY KEY REFERENCES kingdoms(player_id) ON DELETE CASCADE,
  role text NOT NULL CHECK(role IN ('owner')),
  unlimited_resources boolean NOT NULL DEFAULT false,
  unlimited_army boolean NOT NULL DEFAULT false,
  divine_power boolean NOT NULL DEFAULT false,
  granted_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO kingdom_config(key,value) VALUES
('world_map_default_radius','4'),
('world_map_max_radius','12'),
('world_map_search_limit','30'),
('owner_virtual_unit_limit','100000')
ON CONFLICT(key) DO NOTHING;
