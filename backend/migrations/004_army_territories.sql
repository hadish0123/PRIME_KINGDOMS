ALTER TABLE players ADD COLUMN army_order text NOT NULL DEFAULT 'guard'
  CHECK (army_order IN ('guard','follow'));

CREATE TABLE territories (
  world_id uuid NOT NULL REFERENCES worlds(id),
  cell_x integer NOT NULL CHECK (cell_x BETWEEN -63 AND 63),
  cell_z integer NOT NULL CHECK (cell_z BETWEEN -63 AND 63),
  owner_player_id uuid NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  is_home boolean NOT NULL DEFAULT false,
  claimed_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(world_id,cell_x,cell_z)
);
CREATE INDEX territories_owner ON territories(owner_player_id);
INSERT INTO territories(world_id,cell_x,cell_z,owner_player_id,is_home)
  SELECT world_id,round(x/512)::integer,round(z/512)::integer,owner_player_id,true FROM villages;
