# PRIME KINGDOMS 0.9.0 — Strategy candidate

This candidate removes direct character gameplay and connects kingdom commands,
economy, armies, battle reports, healing, commanders, objectives, social dispatches
and clan war phases to persisted server authority.

## Compatibility and migration

Migration 009 adds experience, inbox, commanders, healing, chat/moderation storage,
war rewards/contributions, clan charter/activity, economic realm requirements and
persisted realm rank. Migration checksums 001–008 remain unchanged. No production
world, account, settlement, resident, resource, queue or research record is reset.
Historical scene movement rows remain archival; new kingdoms do not need them.

The new APK requires the v2 API. Authentication and read DTOs remain available.
Obsolete v1/v2 movement, horse and follow-to-claim write routes return not found.
Older action clients must upgrade. Both Android ABIs remain ARM32 and ARM64.
App/backend version is 0.9.0 and Android version code is 14.

## Evidence and limits

Source 790f737127ee7a0fad3d570ac125618af0cf6a42 passed Backend CI, GDScript Parse
and Native 3D Android on 7 October 2026. Thirteen unit tests and seven native
PostgreSQL 18 integration suites passed. All seven native Godot checks passed,
including rendered kingdom commands, clan relocation, reconnect and bounded
visual evidence. The APK exported successfully and signature schemes v2/v3
verified. Evidence is attached to workflow run 37652820504 and candidate 58.

The published APK uses a development certificate and a debuggable export;
it is 156,056,123 bytes. Android metadata confirms version code 14, ARM32/ARM64,
minimum SDK 24 and target SDK 36. It has not been installed on a physical device.

Candidate APKs are development builds when private release-signing secrets are
unavailable. A candidate is not the final production release. Environment art,
distinct commander/troop/siege representations, battle choreography, ceremonies,
march travel/reinforcement systems, live season operations, moderation operations,
physical Android testing and production rollout still require completion.

The API URL embedded in this candidate is the established Railway production
address. Until this backend is deployed there, installation alone cannot provide
the new game experience. Do not mistake a successful export for a usable production
release. Previous versioned downloads remain available.
