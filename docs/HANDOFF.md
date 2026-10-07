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

Source commit 790f737127ee7a0fad3d570ac125618af0cf6a42 passed all three GitHub
workflows on 7 October 2026: Backend CI 37652818724, GDScript Parse 37652818772
and Native 3D Android 37652820504. The backend authority gate passed 13 unit tests
and seven integration suites against native PostgreSQL 18. Docker validation also
passed. Earlier local SQL checks used serialized PGlite and are supplementary.

Godot 4.7.2 passed native account entry/re-entry, persistent village identity,
rendered construction/training/army/battle commands, clan region relocation,
reconnect, late response, application pause/resume and durable request recovery
checks. Camera pinch/rotation/bounds, four graphics profiles, presentation,
bounded foliage and character rig checks passed. All seven native scripts
reported no failures; the logs contain no SCRIPT ERROR or ERROR entries.

Candidate v0.9.0-candidate-58 contains the exported APK and checksums, preserving
older releases. Android metadata confirms version 0.9.0, version code 14,
ARM32/ARM64, minimum SDK 24 and target SDK 36. APK signature schemes v2/v3
verified. This run used a development certificate and a debuggable export.
APK size is 156,056,123 bytes. Physical Android installation and performance
have not been verified.

Actual CI images were inspected. They show real server balances and contextual
building panels, with no character action controls. The settlement composition
is sparse and the battle scene is below the final art bar. A camera smoke image
uses a scene-only fixture and cannot certify the account/resource interface.

Railway API and PostgreSQL remain online with one running replica each, no active
warnings/criticals and no recent deployment failures. Read-only checks of /,
/health and /ready returned HTTP 200; /ready reported a connected database.
Production still runs 0.5.0. An error-filtered runtime log review returned no
entries for the inspected period. No production migration, merge or deployment
of this candidate has occurred. Its embedded production URL does not yet serve
the required v2 API, so the APK is not a usable new production game yet.

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
