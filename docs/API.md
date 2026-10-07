# API v1 compatibility and v2 kingdom strategy

Base URL: `https://prime-kingdoms-api-production.up.railway.app`

All responses are JSON. Write requests require `Content-Type: application/json` and an object body of at most 16 KiB. Authenticated endpoints require `Authorization: Bearer <session.token>`. API errors return `{ "error": "code" }` with a request ID header.

## v2 contract

These endpoints ship on the strategy branch; deploying this API precedes using the
new APK. Every v2 POST requires a UUID `requestId`. Its identity is
scoped to the authenticated account, operation and exact normalized payload; retries
return the original committed response. Reusing it for a different action returns
409 `request_id_conflict`. Unknown extra actor IDs never change session identity.

| Endpoint | Request | Persistent result |
| --- | --- | --- |
| `GET /v2/kingdom` | Session | Settles production/due queues; profile, resources/rates/capacity, buildings, research, units, tasks, quotes, catalogs, level requirements |
| `GET /v2/scene` | Session | Compatible read DTO plus bounded settlement scene and decorative ruler/horse |
| `GET /v2/world/map` | Session | Persistent 7×7 frontier around the current strategic plot, empire/clan colors, protected deadlines and region roster |
| `POST /v2/buildings/upgrade` | `requestId`, `key` | Pays server price, validates prerequisites and creates construction queue; `{taskId,kingdom}` |
| `POST /v2/research/start` | `requestId`, `key` | Academy/prerequisite-validated research queue; `{taskId,kingdom}` |
| `POST /v2/units/train` | `requestId`, `key`, `quantity` (1–100) | Facility/capacity-validated unit training; `{taskId,kingdom}` |
| `POST /v2/empire/customize` | `requestId`, `name`, `primaryColor`, `secondaryColor`, `emblem`, `bannerStyle` | Approved identity; `{kingdom}` |
| `GET /v2/clans` | Session | Directory, own clan/roles/treasury/region, applications, invitations and cooldowns |
| `POST /v2/clans/create` | `requestId`, `name`, `tag`, colors, `emblem`, `admission` (`open`/`approval`) | Level-15/500-gold gate; atomic region, capital, membership and settlement relocation |
| `POST /v2/clans/join` | `requestId`, `clanId` | Open/invited membership or approval application |
| `POST /v2/clans/application` | `requestId`, `clanId`, `playerId`, `decision` (`accept`/`reject`) | Leader/officer-only applicant decision and safe relocation on acceptance |
| `POST /v2/clans/invite` | `requestId`, `clanId`, `playerId` | Leader/officer invitation, expires after seven server days |
| `POST /v2/clans/role` | `requestId`, `clanId`, `playerId`, `role` | Leader-only promotion/demotion/leadership transfer |
| `POST /v2/clans/leave` | `requestId` | Cooldown/war-checked starter resettlement; leader must transfer first |
| `POST /v2/clans/kick` | `requestId`, `playerId` | Permission/cooldown/war-checked removal and safe resettlement |
| `POST /v2/clans/donate` | `requestId`, `resource`, `amount` (1–1,000,000) | Atomic own-wallet spending and clan treasury credit |

Clan POSTs return `{clans: <same snapshot as GET>}`. Player IDs on clan administration
are validated targets, never substitutes for the authenticated actor. Below-level
creation returns 403 `clan_level_15_required`; unauthorized administration returns
403 `clan_permission`. Queue/resource/prerequisite conflicts return 409. No endpoint
accepts client XP, balance, completion deadline or battle victory.

Names reject control/format characters and markup. Colors require `#rrggbb`.
Emblems: lion/eagle/crown/stag/sun/wolf. Banners: square/swallowtail/pennant.
Authenticated per-process limits per server minute: 240 reads
and 120 writes per player. Distributed limiting is future deployment work.

## Preserved v1 contract

| Endpoint | Request | Result |
| --- | --- | --- |
| `GET /health` | Public | Process liveness |
| `GET /ready` | Public | Database readiness |
| `GET /v1/world` | Public | Persistent world ID, seed, size, terrain version |
| `POST /v1/auth/register` | `email`, `password`, `displayName` | 201 with session and game state; creates exactly one player, village, 8 soldiers and 5 villagers in one transaction |
| `POST /v1/auth/login` | `email`, `password` | Session and existing game state; no new village or NPC grant |
| `POST /v1/auth/logout` | Authenticated, `{}` | Revokes the current session |
| `GET /v1/game` | Authenticated | Own player, world and village with persistent NPC identities |
| `GET /v1/world/nearby` | Authenticated | Nearby villages with residents and nearby other players seen within 15 seconds |

Passwords require at least 10 Unicode characters and at most 256 UTF-8 bytes. Ruler names contain 2–24 characters. Emails are normalized to lowercase; email verification and password recovery are not implemented in this milestone. Sessions expire after 14 days and are stored as SHA-256 token hashes. An account retains at most five active sessions; the oldest is revoked when the limit is exceeded. Expired sessions are cleaned when creating a session. Authentication is rate-limited; expensive password hashing has a bounded concurrency limit. Registration and login assemble their game-state response inside the same transaction that creates the session.

Horizontal movement is bounded at 12 metres per second using server time, with a finite four-metre jitter reservoir. Successful travel consumes the reservoir; repeated requests cannot renew it. Elapsed accumulation is capped at 30 seconds. Saved Y must lie between settled terrain height minus 1.5 metres and plus 16 metres, covering current rooftop/jump geometry. Rejected movement returns 409 `movement_rejected` or `height_rejected`; the client fetches `/v1/game` and resumes from the server-confirmed position. The client has an eight-second request timeout, a one-MiB response limit, no authenticated redirects and response-shape validation.

The world spans coordinates `-32768..32768` metres on X and Z; player movement uses a 20-metre edge margin. Starter village slots follow a unique square spiral at 512-metre spacing. All players share the existing world seed. The same versioned terrain height function is implemented in JavaScript and GDScript and tested against common reference points.

Game state includes `player.armyOrder`, `player.mount: {mounted,position}` and `territories: {owned,cells}`. Each nearby cell contains integer `x/z`, `ownerPlayerId` and `home`. A movement save returns eight confirmed army positions when following; mounted saves also update the own horse position. Neither army commands nor repeated saves reset the movement-credit reservoir.

Land cell centers are X/Z multiples of 512 m, indices -63..63. Claims require follow order, the saved player within 90 m of the center and all eight soldiers within 40 m. Occupied cells are never transferred. Home-cell registration and claims share a transaction lock; new registrations skip already owned cells. At 4/12/32 owned plots the saved village stage becomes city/country/empire. This stage is a land-count progression field, not a completed building/economy simulation.

Mounting requires this account's parked horse within 3.2 m. Dismounting places the player 1.35 m to the side at canonical ground height. Client collision checks refuse unsafe dismount space. The server persists mount state and horse coordinates; a client cannot select another account's horse by sending IDs.

Movement replication uses HTTP snapshots with client interpolation. Patrols are local presentation; following soldier positions advance by at most 5.4 m/s on saves. This milestone does not provide final authoritative combat, independent NPC thought or continuous offline army simulation. Client-supplied player IDs never select the account being moved, ordered or granted land.

## Experience endpoints in 0.9.0

GET endpoints: /v2/commanders, /v2/goals, /v2/inbox, /v2/rankings, /v2/wars
and /v2/chat?channel=global or clan. Map requests can supply a bounded x/z
survey center; player presentation uses location names.

Idempotent POST endpoints: /v2/commanders/recruit, /v2/units/heal,
/v2/goals/claim, /v2/inbox/read, /v2/chat/send, /v2/chat/block,
/v2/chat/report, /v2/wars/declare and /v2/clans/describe.
Clan invitations accept a rulerName without exposing player IDs to players.

Obsolete direct-character write endpoints are removed. Historical read records
remain available; older action clients must upgrade to the strategy client.
