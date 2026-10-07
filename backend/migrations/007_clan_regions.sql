-- Clan membership and relocation are separate from legacy village coordinates.
CREATE SEQUENCE clan_region_sequence START 100;
ALTER TABLE strategic_regions ADD COLUMN map_x integer NOT NULL DEFAULT 0;
ALTER TABLE strategic_regions ADD COLUMN map_z integer NOT NULL DEFAULT 0;
ALTER TABLE strategic_plots ADD COLUMN map_x integer;
ALTER TABLE strategic_plots ADD COLUMN map_z integer;
UPDATE strategic_plots p SET map_x=t.cell_x,map_z=t.cell_z FROM territories t WHERE p.player_id=t.owner_player_id AND t.is_home;
CREATE FUNCTION initialize_plot_location() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF NEW.player_id IS NOT NULL AND NEW.map_x IS NULL THEN
  SELECT cell_x,cell_z INTO NEW.map_x,NEW.map_z FROM territories WHERE owner_player_id=NEW.player_id AND is_home;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER strategic_plot_location BEFORE INSERT ON strategic_plots FOR EACH ROW EXECUTE FUNCTION initialize_plot_location();
CREATE TABLE clans (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), world_id uuid NOT NULL REFERENCES worlds(id),
 region_id uuid NOT NULL UNIQUE REFERENCES strategic_regions(id), founder_id uuid NOT NULL REFERENCES players(id), leader_id uuid NOT NULL REFERENCES players(id),
 name text NOT NULL CHECK(char_length(name) BETWEEN 3 AND 32), tag text NOT NULL CHECK(tag ~ '^[A-Z0-9]{3,6}$'),
 emblem text NOT NULL CHECK(emblem IN ('lion','eagle','crown','stag','sun','wolf')),
 primary_color text NOT NULL CHECK(primary_color ~ '^#[0-9a-f]{6}$'), secondary_color text NOT NULL CHECK(secondary_color ~ '^#[0-9a-f]{6}$'),
 admission text NOT NULL DEFAULT 'approval' CHECK(admission IN ('approval','open')), level integer NOT NULL DEFAULT 1 CHECK(level BETWEEN 1 AND 100),
 xp bigint NOT NULL DEFAULT 0 CHECK(xp>=0), created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(world_id,tag)
);
CREATE UNIQUE INDEX clan_unique_name ON clans(world_id,lower(name));
CREATE TABLE clan_members (
 player_id uuid PRIMARY KEY REFERENCES kingdoms(player_id), clan_id uuid NOT NULL REFERENCES clans(id),
 role text NOT NULL CHECK(role IN ('leader','officer','member')), joined_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX clan_one_leader ON clan_members(clan_id) WHERE role='leader';
CREATE INDEX clan_member_roster ON clan_members(clan_id,role,joined_at);
CREATE TABLE clan_player_cooldowns (
 player_id uuid PRIMARY KEY REFERENCES kingdoms(player_id), join_after timestamptz NOT NULL DEFAULT '-infinity',
 leave_after timestamptz NOT NULL DEFAULT '-infinity', relocate_after timestamptz NOT NULL DEFAULT '-infinity'
);
CREATE TABLE clan_applications (
 clan_id uuid NOT NULL REFERENCES clans(id), player_id uuid NOT NULL REFERENCES kingdoms(player_id),
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','accepted','rejected','withdrawn')),
 created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(clan_id,player_id)
);
CREATE TABLE clan_invitations (
 clan_id uuid NOT NULL REFERENCES clans(id), player_id uuid NOT NULL REFERENCES kingdoms(player_id),
 inviter_id uuid NOT NULL REFERENCES players(id), expires_at timestamptz NOT NULL,
 accepted_at timestamptz, PRIMARY KEY(clan_id,player_id)
);
CREATE INDEX clan_applications_player ON clan_applications(player_id,created_at DESC);
CREATE INDEX clan_invitations_player ON clan_invitations(player_id,expires_at);
CREATE TABLE clan_treasury (
 clan_id uuid NOT NULL REFERENCES clans(id), resource text NOT NULL CHECK(resource IN ('food','wood','stone','iron','gold')),
 amount bigint NOT NULL DEFAULT 0 CHECK(amount BETWEEN 0 AND 1000000000000), PRIMARY KEY(clan_id,resource)
);
CREATE TABLE settlement_relocations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), player_id uuid NOT NULL REFERENCES kingdoms(player_id), village_id uuid NOT NULL REFERENCES villages(id),
 from_region_id uuid NOT NULL REFERENCES strategic_regions(id), from_plot integer NOT NULL,
 to_region_id uuid NOT NULL REFERENCES strategic_regions(id), to_plot integer NOT NULL,
 reason text NOT NULL CHECK(reason IN ('create','join','leave','kick')), occurred_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX settlement_relocations_player ON settlement_relocations(player_id,occurred_at DESC);
ALTER TABLE strategic_tiles ADD COLUMN owner_clan_id uuid REFERENCES clans(id);
CREATE UNIQUE INDEX one_primary_strategic_settlement ON strategic_tiles(owner_player_id) WHERE kind='settlement' AND owner_player_id IS NOT NULL;
-- Battle/war domain adds command/simulation rules later; active lifecycle rows
-- already block unsafe relocation. This table is not a completed war system.
CREATE TABLE clan_wars (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), attacker_id uuid NOT NULL REFERENCES clans(id), defender_id uuid NOT NULL REFERENCES clans(id),
 phase text NOT NULL CHECK(phase IN ('preparation','battle','result','cancelled')), preparation_ends_at timestamptz NOT NULL,
 battle_ends_at timestamptz NOT NULL, attacker_score integer NOT NULL DEFAULT 0, defender_score integer NOT NULL DEFAULT 0,
 created_at timestamptz NOT NULL DEFAULT now(), CHECK(attacker_id<>defender_id), CHECK(battle_ends_at>preparation_ends_at)
);
CREATE INDEX clan_wars_active_attacker ON clan_wars(attacker_id) WHERE phase IN ('preparation','battle');
CREATE INDEX clan_wars_active_defender ON clan_wars(defender_id) WHERE phase IN ('preparation','battle');
