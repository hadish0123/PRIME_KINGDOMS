-- Owner-only operational limits remain finite in storage while presenting as unlimited.
-- These caps protect the server from accidental unbounded rows; ordinary players are unchanged.
INSERT INTO kingdom_config(key,value) VALUES
  ('owner_virtual_march_limit','100')
ON CONFLICT(key) DO NOTHING;
