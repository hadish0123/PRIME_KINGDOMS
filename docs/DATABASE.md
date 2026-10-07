# Database and forward migration

PostgreSQL remains authoritative. Startup applies numbered SQL files in one
transaction under advisory lock 73462710. SHA-256 checksums in schema_migrations
reject edits to applied files. Add a new numbered migration for every later change.

## Compatibility

001–005 remain unchanged. worlds, accounts, players, villages, npcs, sessions and
territories retain their IDs and data. Kingdoms reference the same unique primary
village; kingdom_legacy_units maps old soldier identities once. The eight legacy
NPCs remain available to v1 while the v2 army inventory can expand.

006 adds kingdom catalogs/configuration, 1–100 requirements, profiles, integer
resource wallets, buildings, research, aggregate units, queues, XP events, request
replays, bounded scene saves and strategic regions/plots/tiles. initialize_kingdom
uses conflict-safe inserts and never grants starting resources/soldiers twice.

007 adds clan identity/membership/roles/applications/invitations/treasury, relocation
audits and cooldowns. Plot map coordinates use the existing home territory mapping.
Each player has at most one allocated plot and one primary strategic settlement.
Clan capital plot 0 is reserved; member plots are 1–63. Legacy physical coordinates
and all village foreign keys are preserved during strategic relocation.

## Transaction boundaries

Economy/queue/scene mutations lock the authenticated player and kingdom row.
Clan mutations acquire global advisory lock 73462712 first, then actor and affected
player rows. This initial conservative lock serializes plot allocation and avoids
cross-clan races. Shard the lock by world/ordered region when measured load warrants
it, preserving lock order and database uniqueness constraints.

kingdom_requests binds player/request UUID to operation and canonical payload hash.
Retries replay the committed response; mismatched reuse returns 409. XP events have
unique source/event keys. Active queue uniqueness and wallet check constraints
provide secondary safeguards. All resources fit exact JavaScript integer limits.

Important indexes cover active queues, resource/profile keys, XP dates, region
plots, one primary settlement, clan roster, invitation recipients and relocation
history. No production table is dropped or truncated.

## Rollout risks

Backfill and index creation are transactional but can lock existing tables. Measure
on a restored backup before production rollout; the current statement timeout is
five seconds and may need a controlled migration maintenance setting for a large
population. Take a recoverable database backup. Deploy API compatibility first,
then the v2 APK. Roll back application code rather than undo additive data migrations.
Never delete villages or use test-schema cleanup against production.
