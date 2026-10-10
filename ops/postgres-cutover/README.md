# PostgreSQL cutover runbook

This runbook moves PRIME_KINGDOMS PostgreSQL without resetting accounts, worlds, villages, ownership, sessions, clans, battles or migration history.

## Safety contract

- Never edit an applied migration.
- Never drop the Railway source database during cutover.
- Freeze writes only for the final delta/cutover window.
- Verify source and target fingerprints before switching the API.
- Keep the Railway PostgreSQL service intact until the new target has been stable for at least one observation window and rollback is no longer required.
- Keep `DATABASE_URL` server-only.

## Required variables

`SOURCE_DATABASE_URL` — current Railway PostgreSQL connection string.

`TARGET_DATABASE_URL` — destination PostgreSQL connection string.

Both endpoints must support PostgreSQL 18-compatible schema/features and TLS for public-network connections.

## 1. Baseline source

From `backend/`:

```bash
DATABASE_URL="$SOURCE_DATABASE_URL" node scripts/db-fingerprint.js > source-fingerprint.json
```

The fingerprint records migration checksums and authoritative row counts, but no passwords or player content.

## 2. Initial copy

Use custom format so ownership/ACLs are not carried to the new provider:

```bash
pg_dump "$SOURCE_DATABASE_URL" \
  --format=custom \
  --no-owner --no-acl \
  --file=prime-kingdoms.dump

pg_restore \
  --dbname="$TARGET_DATABASE_URL" \
  --clean --if-exists \
  --no-owner --no-acl \
  --exit-on-error \
  prime-kingdoms.dump
```

Do not use `--create`; the target database is provisioned by the provider.

## 3. Verify copied target

```bash
DATABASE_URL="$TARGET_DATABASE_URL" node scripts/db-fingerprint.js > target-fingerprint.json
diff -u source-fingerprint.json target-fingerprint.json
```

The diff must be empty before final cutover.

## 4. Final cutover

For the shortest safe maintenance window:

1. Stop writes by taking the API out of service or enabling an explicit maintenance/read-only gate.
2. Capture a fresh source fingerprint.
3. Create a fresh dump and restore it to target.
4. Capture target fingerprint and require an exact match.
5. Change only the API's `DATABASE_URL` to `TARGET_DATABASE_URL`.
6. Deploy/restart the API and run health/login/world/kingdom smoke checks.
7. Keep the old Railway Postgres untouched for rollback.

## 5. Rollback

If API health, login, world ownership, migrations, or authoritative counts disagree:

1. Point `DATABASE_URL` back to the original Railway PostgreSQL value.
2. Restart/redeploy API.
3. Do not merge data written to both databases manually; investigate first.
4. Preserve both databases for forensic comparison.

## Provider notes

For a public PostgreSQL target, require TLS and restrict inbound network access as tightly as the provider permits. A self-managed VM additionally requires firewalling, OS patching, PostgreSQL backups, restore testing and monitoring.
