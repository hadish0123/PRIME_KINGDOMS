# PRIME KINGDOMS

A persistent third-person kingdom game, beginning with a small village and eventually growing into cities, countries and empires.

## Play the development build

[Download the Android APK](https://github.com/hadish0123/PRIME_KINGDOMS/releases/tag/v0.2.0) · [Android build checks](https://github.com/hadish0123/PRIME_KINGDOMS/actions/workflows/android-build.yml) · [Backend checks](https://github.com/hadish0123/PRIME_KINGDOMS/actions/workflows/backend-ci.yml)

Install the APK, choose a ruler name, email and password (at least 10 characters), then select **CREATE ACCOUNT**. Select **ENTER WORLD** for an existing account. The app remembers an unexpired session on the same device.

## Milestone 0.2

- Native Godot 4.7.2 3D client with a rigged, animated human character and a third-person orbit camera.
- Walking, sprinting, jumping, terrain/building collisions, mouse camera control and mobile touch controls.
- A deterministic 65.536 × 65.536 km world, streamed in bounded chunks as the player moves. Terrain near villages is flattened; the rest is currently empty hills.
- Each account receives exactly one permanent village, **8 soldiers and 5 villagers**, created atomically on the server. Subsequent logins keep the same village, NPC identities and saved position.
- Village houses, hall, blacksmith, well, market, fences and paths, with warm sunlight, shadows and atmospheric fog.
- Nearby registered villages and online players appear in the shared world. Player movement is saved periodically, on application pause and before sign-out.
- Railway hosts the Node.js/PostgreSQL API. Graphics run on the Android device, not on Railway.

This is a playable **stylized prototype**, not finished photorealistic or AAA graphics. NPCs have basic local presentation patrols; full server NPC simulation, combat, economy, village growth, PRIME's god powers and seven Legends are future milestones. Android hardware performance has not been measured yet. Development builds use a test certificate; replacing one rebuilt APK with another may require uninstalling the old app and signing back into the same server account.

## Controls

| Action | Desktop | Android |
| --- | --- | --- |
| Walk | WASD / arrow keys | Left virtual stick |
| Look | Hold right mouse and drag | Drag the right side |
| Sprint | Shift | RUN toggle |
| Jump | Space | JUMP |
| Camera distance | Mouse wheel | Default third-person distance |
| World atlas | M / Tab / MAP | MAP |

## Client development

```sh
npm ci --prefix tools/assets
npm run --prefix tools/assets prepare:models
# Open client/project.godot in Godot 4.7.2, then run the project.
```

The asset pipeline downloads only pinned CC0 models, verifies their Git blob checksums and converts them to Godot-compatible GLB. Models are embedded in the APK; no model download is required during gameplay. [Asset credits](client/assets/ATTRIBUTION.md).

```sh
godot --headless --path client --editor --import
godot --headless --path client --script res://tests/smoke.gd -- --smoke
```

The native smoke test checks terrain agreement with the server, actual rigged character animations, all village models, the exact 8/5 population, walking, jumping, landing, camera orbit and terrain streaming. GitHub Actions additionally renders a real village screenshot, exports the Android APK and verifies its signature. Export presets are in `client/export_presets.cfg`; the Android workflow uses verified official engine binaries and OpenJDK 17.

## Backend development

Node.js 24 LTS and PostgreSQL, with `pg` as the only runtime dependency.

```sh
cd backend
npm ci
cp .env.example .env
# Set local DATABASE_URL in .env.
node --env-file=.env src/main.js
npm run check
npm test
```

Set `TEST_DATABASE_URL` to a **disposable** PostgreSQL database and run `npm run test:integration`. Tests create isolated temporary schemas and remove them afterwards. GitHub Actions supplies PostgreSQL 18 automatically.

[API contract](docs/API.md) · [Live deployment settings](docs/DEPLOYMENT.md) · [Long-term game direction](docs/GAME_DIRECTION.md)

Accounts use salted scrypt password hashes and opaque, expiring bearer sessions. Only session hashes are stored in PostgreSQL; no database credentials or player passwords are included in the client. Migrations are transactional and checksum-verified. The existing world ID and seed survive API redeployments.
