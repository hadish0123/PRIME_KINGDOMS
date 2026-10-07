# Engineering handoff — strategy conversion in progress

Base main: `7532eb31187009c699fe0b6cd7017116431ddef7` (v0.5).
Working branch: `feature/kingdom-strategy-full`.
Latest committed implementation: `6678c04` (0.7.1 clan checkpoint).
Previous published checkpoint: `fcb21f22fb87ad3a66981ad6c691308dcb0c5c29` (0.7.0).
This handoff accompanies the implementation in a separate documentation commit.
It is not a claim that the complete product is finished.

## Implemented in the current checkpoint

- Additive migration 006; original world/account/village/NPC/horse/session/land
  records and migrations 001–005 remain intact. Exactly one new kingdom maps to
  each primary village. The eight existing NPC soldiers map once to unit inventory.
- Five integer resource wallets, fractional production carry, capacity, offline
  accrual and completion events at server timestamps. Row-serialized spending.
- Eighteen persistent building levels, costs/durations/prerequisites; three
  independent construction/training/research queues; thirteen trainable unit
  definitions, expandable persistent army counts; eleven research categories.
- Server-configurable 1–100 XP curve with prestige/conquest/season/ascension gates,
  unique XP events and capped training/research XP. No public XP mutation endpoint.
- Empire name/colors/approved emblems/banner data, shader color/emblem application
  on ruler cloth, soldier capes and settlement flags, persistent strategic tiles.
- Versioned v2 endpoints and player/operation/payload-bound request replay.
- New native authentication enters a bounded third-person settlement. Four fixed
  terrain pieces and physical borders; movement and horse state persist in separate
  scene records. Legacy expedition positions are preserved rather than destroyed.
- Native management UI for construction, resources, training, research, empire and
  map; bounded additional soldier display; original joystick/horse/sword/prone code.
- Four graphics profiles with the GL Compatibility renderer retained.
- Additive migration 007; level-15/500-gold clan creation, real clan region/capital,
  unique member plots, applications/invitations, role administration and leadership
  transfer. Atomic join/leave/kick relocation retains original village and all data.
- Clan treasury donations, cooldowns, active-war relocation protection, immutable
  starter-protection deadline, membership/plot race protection and relocation audit.
- Native clan UI, server level-gate rejection, region-map presentation and disk-backed
  unresolved request replay after restart. Per-player bounded v2 request lanes.

## Validation so far

Backend syntax and 13 unit checks passed. The 0.7.0 published Backend CI passed on
native PostgreSQL: https://github.com/hadish0123/PRIME_KINGDOMS/actions/runs/37583393100.
Its native account/kingdom/reconnect checks passed; full Android render/export is
still running at this checkpoint. Player character review passed.

New settlement and clan HTTP/SQL tests passed locally in separate fresh PostgreSQL
WASM (PGlite) instances. This is supplemental, not native PostgreSQL concurrency
certification. Running both schemas on one multiplexed PGlite socket caused a map
assertion failure; independent runs pass. Native PostgreSQL CI runs isolated schemas
and remains required for 007. New native clan join/donation/reconnect/render CI is
wired using a disposable localhost fixture; its result is pending publication.
Godot editor import parsed the clan UI and tests without errors.
Local Blender exits with SIGBUS in this workspace; the pinned pipeline previously
completed on GitHub. Do not replace the horse with a placeholder to hide this.

## Partial / remaining work

The complete requested game is NOT implemented. Building effects that require
future equipment/combat/social systems are not active yet. Unit catalogs share
existing infantry presentation; cavalry/ranged/siege-specific production visuals
and combat are not complete. Large-army animation LOD requires further work.

Next: army presets and deterministic battle instances/casualties/reports, connected territory capture,
army presets/commands, ruler block/dodge/defeat presentation, commanders/inventory,
clan wars, quests/achievements, social/rankings and moderation limits.

No changes have been deployed to Railway. Do not merge or call the release final
until full checks pass. No production test accounts, reset or signing secrets.

## Migration and rollout risks

006 backfills one strategy kingdom per existing player; 007 maps existing strategic
locations and adds clan tables/constraints. Test their
runtime on a restored production backup before deployment at large player counts.
Legacy v1 apps remain usable. The new APK needs the v2 backend before ordinary login
can enter a settlement; it displays retry instead of silently using an open world.
A scene adapter retains old canonical positions when they fit the own settlement;
positions from expeditions are retained in v1 and get a separate legal scene spawn.
Strategic plots are separate from original physical village coordinates.

Migrations added: `006_kingdom_strategy.sql`, `007_clan_regions.sql`.
Changed domains: backend/migrations/006_kingdom_strategy.sql and 007_clan_regions.sql; backend/src/kingdom/*;
backend/server/check; backend/test/integration/kingdom/upgrade; client strategy
panel/terrain/empire/contract/main/player/preferences/shaders/heraldry; CI, versions
and all requested architecture/domain/release documentation. Obtain exact changed
files with `git diff --name-status 7532eb31187009c699fe0b6cd7017116431ddef7 HEAD`.
For the clan checkpoint alone use `git diff --name-status 2c0582f 6678c04`.
