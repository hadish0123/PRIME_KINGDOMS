# PRIME KINGDOMS

A persistent third-person kingdom game, beginning with a small village and eventually growing into cities, countries and empires.

## Play milestone 0.5

[Download the Android APK](https://github.com/hadish0123/PRIME_KINGDOMS/releases/tag/v0.5.0) · [Android build checks](https://github.com/hadish0123/PRIME_KINGDOMS/actions/workflows/android-build.yml) · [Backend checks](https://github.com/hadish0123/PRIME_KINGDOMS/actions/workflows/backend-ci.yml)

Install the APK, choose a ruler name, email and password (at least 10 characters), then select **CREATE ACCOUNT**. Select **ENTER WORLD** for an existing account. The app remembers an unexpired session on the same device.

## Completed village foundation

- Native Godot 4.7.2 3D client with a rigged, animated human character and a third-person orbit camera.
- Walking, sprinting, buffered jumping, terrain/building/fence collisions, mouse camera control and mobile touch controls. Camera collision ignores resident capsules.
- A deterministic 65.536 × 65.536 km world, streamed in bounded chunks as the player moves. Terrain near villages is flattened; hills have deterministic, streamed grass and trees.
- Each account receives exactly one permanent village, **8 soldiers and 5 villagers**, created atomically on the server. Subsequent logins keep the same village, NPC identities and saved position.
- Village houses, hall, blacksmith, well, market, fences and paths, with photographic PBR surfaces, HDR sky lighting, shadows and atmospheric fog.
- Nearby registered villages and online players appear in the shared world. Player movement is saved periodically, on application pause and before sign-out.
- Connection recovery restores server-confirmed position with retry backoff. Menus, Android pause/resume and stale responses from older logins cannot bypass freezes or mutate a new world.
- Saved LOW/BALANCED/HIGH graphics profiles, camera sensitivity and vertical inversion. Distant villages unload and distant residents stop physics/animation until approached.
- A real 3D animated login backdrop, retry for remembered sessions, scrollable account form, safe-area controls, settings and a world atlas.
- Railway hosts the Node.js/PostgreSQL API. Graphics run on the Android device, not on Railway.

Version 0.5 adds a visible draw/sheathe sword, practice strikes, lying/crawling, an anatomical horse with persisted mount/parked state, server-saved follow/hold orders for the same eight soldiers and exclusive claims of unoccupied land. It includes sixteen human clips, five horse clips, armor/cape, a fortified village, photographic foliage/rocks and an actual 3D minimap. Fractional movement saves no longer fail and snap the player back. This remains below the supplied photorealistic reference: full hostile combat, occupied-village conquest, physical-device performance, economy, autonomous NPC brains, PRIME powers and seven Legends are unfinished. [Release notes, controls and actual limits](docs/RELEASE_0_5.md).

## Controls

| Action | Desktop | Android |
| --- | --- | --- |
| Walk | WASD / arrow keys | Left virtual stick |
| Look | Hold right mouse and drag | Drag the right side |
| Sprint | Shift | RUN toggle |
| Jump | Space | JUMP |
| Camera distance | Mouse wheel | Default third-person distance |
| World atlas | M / Tab / MAP | MAP |
| Graphics / camera settings | Escape / SETTINGS | SETTINGS / device Back |

## Client development

```sh
npm ci --prefix tools/assets
npm run --prefix tools/assets prepare:models
# Open client/project.godot in Godot 4.7.2, then run the project.
```

The asset pipeline downloads pinned CC0 data and photographic textures, verifies Git/SHA-256 checksums, fits a clothed human and generates its rig/animations as a shared Godot-compatible GLB. Models are embedded in the APK; no model download is required during gameplay. [Asset credits](client/assets/ATTRIBUTION.md).

```sh
godot --headless --path client --editor --import
godot --headless --path client --script res://tests/smoke.gd -- --smoke
godot --headless --path client --script res://tests/resilience.gd -- --smoke
```

The native smoke test checks terrain agreement with the server, actual rigged animations, village models, the exact 8/5 population, walking, jumping, landing, camera orbit, touch release and terrain streaming. Resilience checks exercise lost connections, stale responses, Android resume and distant NPC processing. GitHub Actions supplies a disposable PostgreSQL API for the native account/save/sign-out contract, renders village/human/login/settings/atlas screenshots and a real controller-driven motion video, exports the APK and verifies its signature. Export presets are in `client/export_presets.cfg`; the workflow uses verified official engine binaries and OpenJDK 17.

Production APK signing accepts `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD` and `ANDROID_KEY_ALIAS` as **private repository secrets**. The keystore and key passwords must match. Without these, the workflow clearly exports a development APK. Never commit a production keystore or password. Existing release downloads are immutable; a code change requiring a new APK receives a new version.

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

Accounts use salted scrypt password hashes and opaque, expiring bearer sessions. Only session hashes are stored in PostgreSQL; no database credentials or player passwords are included in the client. At most five sessions remain active per account. Movement uses a finite latency allowance and terrain-relative height bounds. Migrations are transactional and checksum-verified. The existing world ID and seed survive API redeployments.
