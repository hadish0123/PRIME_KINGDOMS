# Deployment settings

These settings are applied in Railway through its API/dashboard. This document
is a reference and is not an automatically applied configuration file.

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
graphics quality. The API foundation uses very little compute; rendering belongs
to the game client. Future simulation workers will have their own budgets.

## Database

Railway's `postgres` template supplies PostgreSQL, a persistent volume and
generated credentials. Keep database traffic on Railway's private network.
The application's database connection is configured with a reference; never
copy a resolved database password into GitHub or documentation.

## Verification

- CI checks configuration validation and HTTP failure handling.
- CI runs real PostgreSQL migration, concurrency and persistence tests.
- CI builds the same Dockerfile used for deployment.
- Verify public `/health`, `/ready` and `/v1/world` after deployment.
- Redeploy the API and compare the world's ID and seed to verify persistence.
