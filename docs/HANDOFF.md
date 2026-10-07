# Production strategy handoff — 0.9.0 candidate

Base implementation: feature/strategic-command-online-08 at
90c34eb3f3c6a00705375ab106381d7b5518d986.
Work branch: feature/production-strategy-polish.

## Implemented changes

Direct-control client scripts, movement HUD, avatar action inputs, old controller
settings/tutorial logic, direct movement/horse API writes and follow-to-claim combat
have been removed. Authenticated read access to historical account records remains.

The primary camera pans, zooms, rotates and selects buildings independently of the
ruler. The council uses one shared royal theme, human-readable location/unit names,
English localization sources, server-clock countdowns, shortage/effect previews and
designed error messages. Main navigation connects buildings, research, armies,
world, clans, objectives, inbox and settings. Additional council sections connect
commanders, rankings, wars, reports and chat.

Migration 009 preserves applied history and adds real treatment, commander,
objective, inbox, moderation, charter/activity, war contribution/reward and realm
promotion storage. Persistent player progression and idempotency remain server-owned.
Storage scales sufficiently to reach high-level building costs. Daily battle XP is
bounded. Level 100 remains attainable by every player who satisfies the earned gates.

Worlds and village identities are preserved. Clan relocation only changes strategic
allocation, in the existing transaction; queues, inventory, economy and research
remain attached to their original player. Battle plunder debits defender stores,
respecting protected resources. Rewards and war resolution cannot replay twice.

## Validation status

Local syntax/unit validation and seven disposable SQL integration suites passed.
Local SQL execution uses PostgreSQL compiled to WebAssembly (PGlite), serialized by
a test adapter. This validates SQL and HTTP semantics; it does not certify native
PostgreSQL connection pools, race scheduling or production load. GitHub PostgreSQL
18 integration CI is the required authority gate.

Native Godot account entry/re-entry and headless end-to-end kingdom commands passed.
Actual-render camera, login and settings checks passed. Additional rendered kingdom,
foliage/character and CI checks must pass on the exact published source commit.

No production migration or deployment is implied by these results. Railway main
and existing player data remain untouched until a verified rollout is performed.

## Remaining release blockers

- Environment composition and asset detail are below the requested final art bar.
  Current characters are licensed fitted humans with authored procedural movement.
  Distinct premium commanders, cavalry, ranged and siege visuals are not certified.
- Battle presentation consumes recorded server results but still needs class-specific
  animation, deployment/flanking/siege choreography and retreat presentation.
- Timed marches, recalls, reinforcement armies, equipment and full season operations
  are not complete.
- Realm promotions have persisted title/rewards and visual building milestones;
  final ceremonies and realm-wide architectural transformations remain.
- Chat persistence, block/report and moderation storage work; a staffed moderation
  workflow, retention policy and operational review interface remain.
- Final balance, physical-device FPS/battery/thermal/memory and installed Android
  lifecycle tests remain. Exported APK evidence cannot substitute for these.
- A signed final release, deployment of this API, production readiness/endpoints,
  migration timing on a restored production backup and production log review remain.

This is a tested strategy candidate, not completion of the master production scope.
