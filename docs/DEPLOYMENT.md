# Deployment settings

## Strategy branch rollout

The 0.9.1 strategy candidate is developed on feature/production-strategy-polish.
It has not been deployed to production by this work. Existing Railway main deployment
and player data remain intact. The new APK requires the v2 backend for scene entry.

Before rollout, restore a production backup into a disposable database, run additive
migrations 006–009 with checksum verification and compare world/account/village/NPC/
horse/session/territory identifiers. Measure backfill duration and lock contention;
the default five-second statement timeout may need a maintenance migration setting
for large datasets. Deploy compatible API before distributing the new client.

Health `/health` remains process liveness; `/ready` requires PostgreSQL. Docker still
uses Node.js 24 with a non-root runtime. No graphics service or UDP server is added
to Railway. Keep production credentials and Android signing secrets outside git.
Rollback the application version while retaining additive tables; never reset data.

These settings are applied in Railway through its API/dashboard. This document
is a reference and is not an automatically applied configuration file.

## Live environment

- Project: [PRIME_KINGDOMS](https://railway.com/project/ae104ce9-d860-40ad-a75e-d918a60b93dc)
- Environment: `production`
- API: [prime-kingdoms-api-production.up.railway.app](https://prime-kingdoms-api-production.up.railway.app)
- Database readiness: [/ready](https://prime-kingdoms-api-production.up.railway.app/ready)
- World metadata: [/v1/world](https://prime-kingdoms-api-production.up.railway.app/v1/world)
- Initial verified CI: [Backend CI](https://github.com/hadish0123/PRIME_KINGDOMS/actions/runs/37399518295)
- Region: `sfo` for both API and database; one replica each.
- Database volume: `postgres-volume`, 5 GB, mounted at `/var/lib/postgresql/data`.

The current candidate is not yet deployed. Its final rollout requires a verified v2 backend and matching APK. The public API address returns JSON. The native Godot client connects to it over HTTPS. Android builds and real rendered village/login/settings/atlas previews are published in the repository’s versioned releases after native validation. Version 0.3 adds transactional account responses, finite movement credit, session limits and client lifecycle recovery while preserving the existing world.

## API service

| Setting | Value |
| --- | --- |
| Source | `hadish0123/PRIME_KINGDOMS`, branch `main` |
| Build context | Repository root |
| Dockerfile | `Dockerfile` |
| Port | `3000` |
| Health check | `/ready` |
| Health check timeout | 300 seconds |
| Restart policy | `ON_FAILURE`, maximum 5 retries |
| SIGTERM drain | 20 seconds |
| Replicas | 1 |
| Application sleeping | Disabled |
| Resource ceiling per replica | 8 GB RAM, 8 vCPU |
| Database pool | Maximum 5 connections |
| Database URL | `${{Postgres.DATABASE_URL}}`, resolved inside Railway |

The resource ceiling is not a promise of consumed resources, player capacity or
graphics quality. This initial API uses limited compute; rendering belongs
to the game client. Future simulation workers will have their own budgets.

## Database

Railway's `postgres` template supplies PostgreSQL, a persistent volume and
generated credentials. Keep database traffic on Railway's private network.
The application's database connection is configured with a reference; never
copy a resolved database password into GitHub or documentation.

## Verification

- CI checks configuration, credential validation, exact starter population and HTTP failure handling.
- CI runs real PostgreSQL migration, concurrent startup and account/village/position persistence tests, including server restart and account ownership checks.
- CI builds the same Dockerfile used for deployment.
- Verify public `/health`, `/ready` and `/v1/world` after deployment.
- Redeploy the API and compare the world's ID and seed to verify persistence.
