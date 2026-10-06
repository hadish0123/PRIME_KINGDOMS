# PRIME KINGDOMS 0.3 — Reliable village foundation

Install `PRIME-KINGDOMS-0.3.apk` on Android 7 or newer. The APK supports ARM64
and ARMv7 and connects to the existing Railway world. Create an account or
sign in with your existing email and password. Your existing home and residents
are preserved.

## Completed in this milestone

- Account creation, returning sessions and one permanent village with exactly
  eight soldiers and five villagers. Registration and login responses are
  assembled inside their database transactions. Passwords use salted scrypt;
  bearer tokens are stored only as hashes. Expired sessions are removed and an
  account keeps at most five active sessions.
- Native rigged third-person character, walking, running, buffered jumping,
  adjustable orbit camera and touch controls. Building/fence and character
  collision layers keep scenery and camera behavior separate from residents.
- One deterministic 65.536 × 65.536 km world with bounded terrain streaming,
  permanent villages, a world atlas and nearby player snapshots.
- Recovery after failed or rejected movement saves. The client resumes from
  server-confirmed state with bounded retry intervals. Menus, Android pause,
  resume and late responses cannot bypass movement freezes or change a later
  login. Sign-out waits for a successful position save and session revocation.
- LOW/BALANCED/HIGH graphics profiles and persisted camera sensitivity/invert
  settings. Distant scenery is unloaded; distant residents stop animation and
  physics until the player returns. The terrain rebuilds only settlement tiles
  affected by newly discovered villages.
- Actual rendered 3D login scenery, village, settings and atlas. Screenshot
  fixtures are only used for validation; they never create production accounts.
- Movement validation uses a finite jitter reservoir instead of a new allowance
  on every request. Out-of-bounds, arbitrary underground/sky saves and excess
  horizontal travel are rejected. This is basic movement protection, not a
  finished authoritative combat/physics server.

## Validation and present limits

The release workflow exercises disposable PostgreSQL accounts, session limits,
restart persistence and request-spam movement protection; native Godot account
entry/sign-out, reconnect/lifecycle regressions, animations, actual walking,
jumping, touch input, NPC processing limits, rendering, APK export and signature
verification. SHA256SUMS.txt covers the APK and the real renderer screenshots.

Graphics are currently stylized. Photorealistic AAA fidelity, measured phone
performance, combat, economy, settlement upgrades, independent server NPC minds,
PRIME powers and seven Legends are not part of this release. Residents currently
use local presentation patrols. Forced process termination can lose movement
since the last acknowledged save; the existing account and village remain.

The workflow supports production signing using private repository secrets. If
they are absent, this is a development APK with a test certificate. Installing
it over a differently signed older test build can require uninstalling that app
first. Sign back in to the same account to restore your server-held village.
Do not treat the development certificate as the final Play Store signing key.
