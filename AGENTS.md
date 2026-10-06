# PRIME KINGDOMS development contract

The product owner wants each implemented section delivered completely within
its agreed milestone. Finish the behavior, error handling, persistence,
relevant validation and installable output before marking a section complete.
Do not label a placeholder, mock screen or untested feature as finished.

- Preserve the existing Railway project, world ID, world seed, accounts,
  village ownership and resident identities. Never reset production data.
- Applied SQL migrations are immutable. Add a new numbered migration for
  schema changes and verify it against a disposable PostgreSQL database.
- The native client is Godot 4.7.2; the API uses Node.js 24 and PostgreSQL.
  Terrain version 1 must remain identical between JavaScript and GDScript.
- Account creation grants one village with exactly eight soldiers and five
  villagers once, atomically. Signing in again must not grant new residents.
- The server decides account identity. Never trust a client-supplied player ID.
  Interrupted saves must recover from the last server-confirmed position.
- Keep touch input, menus, application pause and network loss coordinated.
  Late requests from an earlier world must not mutate a later login.
- Keep scenery, terrain allocation and NPC processing bounded on mobile.
  Quality profiles contain frame-rate targets, not measured hardware promises.
- Use only licensed, pinned, checksum-verified assets. Keep large generated
  models and build outputs out of git; reproduce them through the asset pipeline.
- Run the backend checks, real PostgreSQL integration checks, native account,
  resilience, physics and actual-render tests appropriate to the change.
  Do not register test accounts on production.
- Publish a unique versioned APK after checks pass. Preserve existing release
  downloads. Bump app, backend, APK version code and release workflow together
  when a code change requires a new downloadable build.
- Release signing uses private repository secrets. Never commit a signing
  keystore or password. Development certificates are suitable for test builds.
- AAA graphics, physical-device performance, combat, economy, empire growth,
  autonomous server NPC simulation, PRIME powers and seven Legends are separate
  milestones. Report their actual status; do not call the entire game finished
  when only the village foundation is complete.
