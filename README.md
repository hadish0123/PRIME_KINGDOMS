# PRIME KINGDOMS

A persistent third-person kingdom-building game, starting from a small village
and expanding through cities, countries and empires.

## Current stage

This repository currently contains the deployable **backend foundation**, not a
playable game or an Android APK. It provides an HTTP API, PostgreSQL persistence,
transactional migrations, health checks and CI. The Unity client, player login,
starter villages, NPC simulation and combat are subsequent work.

## Backend

- Node.js 24 LTS and PostgreSQL. The only runtime dependency is `pg`.
- `GET /`: project version, stage and endpoint links.
- `GET /health`: process liveness.
- `GET /ready`: live database connectivity; Railway's deployment health check.
- `GET /v1/world`: the world's persisted ID, name, seed and creation time.
- Startup creates the schema and one world exactly once. Its ID and seed survive
  application deployments. No public mutation or account endpoints are enabled.

### Development

Install Node.js 24 and provide a PostgreSQL database, then:

```sh
cd backend
npm ci
cp .env.example .env
# Edit .env with local development credentials.
node --env-file=.env src/main.js
```

`npm run check` and `npm test` run local checks. For real database integration
tests, point `TEST_DATABASE_URL` at a **disposable** PostgreSQL database and run
`npm run test:integration`. Integration tests create a temporary isolated schema
and remove it afterwards. GitHub Actions supplies a test database automatically.

### Railway

1. Deploy the `postgres` template into the project's production environment.
2. Connect a service to this repository's `main` branch.
3. Set `DATABASE_URL` to `${{Postgres.DATABASE_URL}}` using a Railway reference.
4. Set `PORT=3000` and `DATABASE_POOL_MAX=5`.
5. Set the service health check to `/ready`, timeout 300 seconds, restart policy
   `ON_FAILURE` with five retries, and SIGTERM draining to 20 seconds.
6. Railway automatically builds the root Dockerfile. Generate an HTTPS service
   domain routing to port 3000.

The database has a persistent volume. Secrets stay in Railway and are never
committed. Resource limits are configured in Railway, with one API replica to
start. Database-backed routes return 503 while the database is unavailable.

Settings are applied through Railway's API/dashboard and documented in
[deployment settings](docs/DEPLOYMENT.md). This new project does not use the
deprecated `railway.toml` / `railway.json` Config as Code mechanism.

The API deployment does not render graphics, build Unity or simulate the final
game world. Android/PC build workflows will be introduced with the Unity client.

See [the game direction](docs/GAME_DIRECTION.md) for agreed design requirements.
