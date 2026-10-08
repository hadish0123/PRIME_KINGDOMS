# PRIME KINGDOMS

An online medieval realm strategy game for Android, built with Godot 4.7.2,
GL Compatibility, Node.js 24 and PostgreSQL. The ruler is a visual court
representation. Players command settlement development, armies and territory.

The current 0.9.3 candidate is developed on feature/starter-realm-093.
Production readiness remains subject to the gates and open items in
[HANDOFF](docs/HANDOFF.md). Existing player identities, worlds, villages, resident
identities, resources and queues are preserved.

[Android checks and artifacts](https://github.com/hadish0123/PRIME_KINGDOMS/actions/workflows/android-build.yml)
· [Backend checks](https://github.com/hadish0123/PRIME_KINGDOMS/actions/workflows/backend-ci.yml)
· [Versioned downloads](https://github.com/hadish0123/PRIME_KINGDOMS/releases)

## Current implementation

- Independent strategy camera: drag, pinch, two-finger rotation, building selection,
  capital focus, smooth transitions and settlement bounds.
- Server-owned five-resource economy, fractional offline production, storage,
  construction, research and training; 24 buildings, 16 units and 11 research areas.
- Five army presets, six formations, three stances, commanders, defensive armies,
  authoritative combat, casualties, wounded treatment, conquest and persistent reports.
- Server-result-driven 3D battle presentation. All victory and reward decisions
  occur on the server.
- Village → Town → City → Country → Kingdom → Empire advancement with economic,
  military, research, prestige and territory gates. Level 100 has no global quota.
- Clan creation at Level 15 for 500 Gold; applications, invitations by ruler name,
  roles, lossless transactional relocation, treasury, progression and activity.
- Clan wars with preparation, active combat, scoring, contribution rewards and cooldown.
- Real objectives/reward claims, inbox, rankings, global/clan chat, block/report hooks.
- Shared royal interface theme, English text catalog, safe player error messages,
  durable request IDs, reconnect and Android suspend/resume handling.

Legacy direct-control scripts, inputs, action UI, movement writes, avatar-follow
conquest and their tests are removed. Historical data and migration history remain.
Old action APKs require an upgrade; retained authentication and read DTOs preserve
existing accounts.

## Controls

| Action | Android | Desktop |
| --- | --- | --- |
| Survey settlement | One-finger drag | Left drag |
| Zoom | Pinch | Mouse wheel |
| Rotate | Two-finger twist | Right drag |
| Inspect building | Tap | Click |
| Focus capital | Focus Capital | Focus Capital |
| Open world | World | World / M |
| Close council/settings | Return to Realm / Back | Return to Realm / Escape |

## Development

Run npm ci --prefix tools/assets and npm run --prefix tools/assets prepare:models,
then open client/project.godot in Godot 4.7.2. Pinned licensed sources and generated
asset credits are in client/assets/ATTRIBUTION.md. Generated models and audio are
reproduced by the pipeline; release builds embed them.

Run npm ci in backend, configure a local DATABASE_URL and start node src/main.js.
Use npm run check, npm test and npm run test:integration with a disposable
TEST_DATABASE_URL. Integration tests use isolated schemas and remove them afterward.
Never register automated test accounts on production.

The Android workflow gates export on real PostgreSQL authority checks, native account,
strategy, lifecycle and bounded actual-render checks. It verifies APK signatures and
publishes unique candidate versions without deleting earlier releases. Production
signing uses private ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD and
ANDROID_KEY_ALIAS secrets. Without them, builds use a development certificate.

The v2 backend must be deployed before the new APK can enter a kingdom.
[Release notes](docs/RELEASE_0_9_0.md) · [Architecture](docs/ARCHITECTURE.md)
· [API](docs/API.md) · [Deployment](docs/DEPLOYMENT.md)
