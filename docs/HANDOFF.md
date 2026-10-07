# Engineering handoff — strategy conversion in progress

Base main: `7532eb31187009c699fe0b6cd7017116431ddef7` (v0.5).
Working branch: `feature/kingdom-strategy-full`.
Latest implementation checkpoint: `27e10be` (followed by CI/version wiring).
The next checkpoint records the implementation SHA after validation; this document
is not a claim that the complete product is finished.

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

## Validation so far

Backend syntax/unit checks passed. New v2 HTTP/SQL integration test passed locally
using PostgreSQL WASM (PGlite); this does not certify a native PostgreSQL concurrency
or deployment environment. Native Godot editor import parsed the new scripts with
no errors. Full PostgreSQL and real-render Android CI is pending.
Local Blender exits with SIGBUS in this workspace; the pinned pipeline previously
completed on GitHub. Do not replace the horse with a placeholder to hide this.

## Partial / remaining work

The complete requested game is NOT implemented. Building effects that require
future equipment/combat/social systems are not active yet. Unit catalogs share
existing infantry presentation; cavalry/ranged/siege-specific production visuals
and combat are not complete. Large-army animation LOD requires further work.

Next: level-15 clan gate, real regions/capital/member plots, transactional relocation
and role/application/invitation controls, cooldowns and active-war protection;
connect all implemented actions to native UI and add concurrent-join tests.
Then deterministic battle instances/casualties/reports, connected territory capture,
army presets/commands, ruler block/dodge/defeat presentation, commanders/inventory,
clan wars, quests/achievements, social/rankings and moderation limits.

No changes have been deployed to Railway. Do not merge or call the release final
until full checks pass. No production test accounts, reset or signing secrets.

## Migration and rollout risks

006 backfills one strategy kingdom per existing player in a transaction. Test its
runtime on a restored production backup before deployment at large player counts.
Legacy v1 apps remain usable. The new APK needs the v2 backend before ordinary login
can enter a settlement; it displays retry instead of silently using an open world.
A scene adapter retains old canonical positions when they fit the own settlement;
positions from expeditions are retained in v1 and get a separate legal scene spawn.
Strategic plots are separate from original physical village coordinates.

Changed domains: backend/migrations/006_kingdom_strategy.sql; backend/src/kingdom/*;
backend/server/check; backend/test/integration/kingdom/upgrade; client strategy
panel/terrain/empire/contract/main/player/preferences/shaders/heraldry; CI, versions
and architecture/release documentation. Obtain the exact list with `git diff main`.
