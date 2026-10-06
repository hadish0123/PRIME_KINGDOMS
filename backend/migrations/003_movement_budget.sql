-- A latency allowance is a finite reservoir, not a fresh grant per request.
ALTER TABLE players ADD COLUMN movement_credit double precision NOT NULL DEFAULT 4
  CHECK (movement_credit >= 0 AND movement_credit <= 4);
-- New rulers face the village hall; existing saved headings are preserved.
ALTER TABLE players ALTER COLUMN yaw SET DEFAULT pi();
CREATE INDEX sessions_account_created ON sessions(account_id, created_at DESC);
