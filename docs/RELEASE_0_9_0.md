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

Backend unit, disposable SQL, native account, strategy camera, reconnect, queue,
army and battle-report tests accompany the candidate. GitHub CI must separately
certify real PostgreSQL concurrency, native rendering, APK export and signature.

Candidate APKs are development builds when private release-signing secrets are
unavailable. A candidate is not the final production release. Environment art,
distinct commander/troop/siege representations, battle choreography, ceremonies,
march travel/reinforcement systems, live season operations, moderation operations,
physical Android testing and production rollout still require completion.

The API URL embedded in this candidate is the established Railway production
address. Until this backend is deployed there, installation alone cannot provide
the new game experience. Do not mistake a successful export for a usable production
release. Previous versioned downloads remain available.
