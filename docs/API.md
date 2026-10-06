# API 0.2

Base URL: `https://prime-kingdoms-api-production.up.railway.app`

All responses are JSON. Write requests require `Content-Type: application/json` and an object body of at most 16 KiB. Authenticated endpoints require `Authorization: Bearer <session.token>`. API errors return `{ "error": "code" }` with a request ID header.

| Endpoint | Request | Result |
| --- | --- | --- |
| `GET /health` | Public | Process liveness |
| `GET /ready` | Public | Database readiness |
| `GET /v1/world` | Public | Persistent world ID, seed, size, terrain version |
| `POST /v1/auth/register` | `email`, `password`, `displayName` | 201 with session and game state; creates exactly one player, village, 8 soldiers and 5 villagers in one transaction |
| `POST /v1/auth/login` | `email`, `password` | Session and existing game state; no new village or NPC grant |
| `POST /v1/auth/logout` | Authenticated, `{}` | Revokes the current session |
| `GET /v1/game` | Authenticated | Own player, world and village with persistent NPC identities |
| `POST /v1/player/move` | Authenticated, `position: {x,y,z}`, `yaw` | Saves only the authenticated player's position; rejects invalid coordinates, world-boundary violations and excessive horizontal travel |
| `GET /v1/world/nearby` | Authenticated | Nearby villages with residents and nearby other players seen within 15 seconds |

Passwords require at least 10 Unicode characters and at most 256 UTF-8 bytes. Ruler names contain 2–24 characters. Emails are normalized to lowercase; email verification and password recovery are not implemented in this milestone. Sessions expire after 14 days and are stored as SHA-256 token hashes. Authentication is rate-limited; expensive password hashing has a bounded concurrency limit.

The world spans coordinates `-32768..32768` metres on X and Z; player movement uses a 20-metre edge margin. Starter village slots follow a unique square spiral at 512-metre spacing. All players share the existing world seed. The same versioned terrain height function is implemented in JavaScript and GDScript and tested against common reference points.

Movement replication uses HTTP snapshots with client interpolation. This milestone does not provide a final authoritative combat or NPC simulation. NPC patrol animation is local presentation; NPC identity, role, home and initial population are persisted by the server. Client-supplied player IDs never select the account being moved.
