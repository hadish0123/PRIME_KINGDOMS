# PRIME KINGDOMS

A mobile medieval empire strategy game with a directly controlled third-person ruler,
a strategic world map, bounded 3D settlements and planned battle instances.

The existing repository and v0.5 accounts are preserved. Strategy conversion is in
active development on [feature/kingdom-strategy-full](https://github.com/hadish0123/PRIME_KINGDOMS/pull/7).
This branch is not the finished full product; [HANDOFF](docs/HANDOFF.md) records exact status.
[Android checks/artifacts](https://github.com/hadish0123/PRIME_KINGDOMS/actions/workflows/android-build.yml)
· [Backend checks](https://github.com/hadish0123/PRIME_KINGDOMS/actions/workflows/backend-ci.yml)
· [Existing releases](https://github.com/hadish0123/PRIME_KINGDOMS/releases).

## Implemented strategy systems

- Godot 4.7.2 native Android, GL Compatibility, third-person ruler and mobile controls;
  walking/sprinting/jumping, sword actions, lying/crawling and horse mounting remain.
- New scene entry uses a fixed bounded settlement; ruler travel allocates no open-world
  terrain. Separate scene saves preserve legacy global position/horse records.
- One persistent primary settlement per account; five integer resources with server
  production/storage/spending and timestamped construction/research/training queues.
- Eighteen building definitions/levels/prerequisites, thirteen expandable unit types,
  eleven research categories and configurable nonlinear level 1–100 requirements.
- Real clan creation at level 15, region/capital/member plots, applications/invitations,
  roles, leadership transfer, join/leave/kick, lossless relocation and clan treasury.
- Empire colors/approved emblems on ruler/soldier cloth and settlement flags; persistent
  strategic ownership map and LOW/BALANCED/HIGH/ULTRA graphics profiles.
- Existing secure accounts/sessions and PostgreSQL data; additive checksum-verified
  migrations, transaction locks and payload-bound idempotency. Unresolved mobile
  purchases survive restarts with the same request UUID.

The original eight NPC soldiers retain their identities and map once into an expandable
army inventory. Production, warehouse capacity, keep/facility gates, training and research
work now. Effects depending on combat/equipment/healing remain partial. Hostile battles,
occupied territory conquest, commanders/inventory, complete clan wars, quests/social and
physical-device performance validation are still required. Shared medium character art
is not a claim of final AAA production art.

The v2 API must deploy before distributing the new APK. Railway hosts state and timers;
all 3D graphics render on the device. Production deployment remains unchanged while
this branch is developed. [Architecture](docs/ARCHITECTURE.md) · [Database](docs/DATABASE.md)
· [Economy](docs/ECONOMY.md) · [Clans](docs/CLANS.md) · [Graphics](docs/GRAPHICS.md).

## Controls

| Action | Desktop | Android |
| --- | --- | --- |
| Walk | WASD / arrow keys | Left virtual stick |
| Look | Hold right mouse and drag | Drag the right side |
| Sprint | Shift | RUN toggle |
| Jump | Space | JUMP |
| Draw / sheathe | F | SWORD |
| Practice strike | Left mouse | ATTACK |
| Lie / stand | X | LIE / UP |
| Mount / dismount | E | RIDE |
| Settlement/army/clan management | UNITS | UNITS |
| Camera distance | Mouse wheel | Default third-person distance |
| Strategic map | M / Tab / WORLD | WORLD |
| Graphics / camera settings | Escape / SETTINGS | SETTINGS / device Back |

## Client development

```sh
npm ci --prefix tools/assets
npm run --prefix tools/assets prepare:models
# Open client/project.godot in Godot 4.7.2, then run the project.
```

The asset pipeline downloads pinned CC0 data and photographic textures, verifies Git/SHA-256 checksums, fits a clothed human and generates separate NPC/player rigs and animations as Godot-compatible GLBs. Models are embedded in the APK; no model download is required during gameplay. [Asset credits](client/assets/ATTRIBUTION.md).

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
