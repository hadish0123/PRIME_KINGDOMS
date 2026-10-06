ALTER TABLE worlds ADD COLUMN size_m integer NOT NULL DEFAULT 65536 CHECK (size_m >= 1024);

CREATE TABLE accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL UNIQUE,
  display_name text NOT NULL,
  password_hash text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE players (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id uuid NOT NULL UNIQUE REFERENCES accounts(id) ON DELETE CASCADE,
  world_id uuid NOT NULL REFERENCES worlds(id),
  x double precision NOT NULL,
  y double precision NOT NULL,
  z double precision NOT NULL,
  yaw double precision NOT NULL DEFAULT 0,
  position_updated_at timestamptz NOT NULL DEFAULT now(),
  last_seen_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX players_world_position ON players(world_id, x, z);

CREATE SEQUENCE village_slot_sequence START 0 MINVALUE 0;
CREATE TABLE villages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  world_id uuid NOT NULL REFERENCES worlds(id),
  owner_player_id uuid NOT NULL UNIQUE REFERENCES players(id) ON DELETE CASCADE,
  slot bigint NOT NULL DEFAULT nextval('village_slot_sequence'),
  name text NOT NULL,
  stage text NOT NULL DEFAULT 'village' CHECK (stage IN ('village','city','country','empire')),
  x double precision NOT NULL,
  y double precision NOT NULL,
  z double precision NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(world_id, slot)
);
CREATE INDEX villages_world_position ON villages(world_id, x, z);

CREATE TABLE npcs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  village_id uuid NOT NULL REFERENCES villages(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('soldier','villager')),
  ordinal integer NOT NULL CHECK (ordinal >= 0),
  name text NOT NULL,
  x double precision NOT NULL,
  y double precision NOT NULL,
  z double precision NOT NULL,
  personality jsonb NOT NULL DEFAULT '{}',
  UNIQUE(village_id, role, ordinal)
);

CREATE TABLE sessions (
  token_hash text PRIMARY KEY,
  account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX sessions_expiry ON sessions(expires_at);
