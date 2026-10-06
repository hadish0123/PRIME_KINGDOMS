CREATE TABLE worlds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  seed integer NOT NULL CHECK (seed > 0),
  created_at timestamptz NOT NULL DEFAULT now()
);
