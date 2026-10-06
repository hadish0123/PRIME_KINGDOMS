ALTER TABLE players ADD COLUMN mounted boolean NOT NULL DEFAULT false;
ALTER TABLE players ADD COLUMN horse_x double precision;
ALTER TABLE players ADD COLUMN horse_y double precision;
ALTER TABLE players ADD COLUMN horse_z double precision;
UPDATE players p SET horse_x=v.x+12,horse_y=v.y+0.1,horse_z=v.z+20
  FROM villages v WHERE v.owner_player_id=p.id;
ALTER TABLE players ALTER COLUMN horse_x SET NOT NULL;
ALTER TABLE players ALTER COLUMN horse_y SET NOT NULL;
ALTER TABLE players ALTER COLUMN horse_z SET NOT NULL;
