# Kingdom strategy architecture

Direction: a strategic empire map plus bounded settlements and battle instances,
with a directly controlled third-person ruler. There is no continuous open-world
travel in the new client mode. Godot renders locally; Railway hosts HTTP state,
authority, economy, timers and deterministic battle services.

## Compatibility and authority

Base main: 7532eb31187009c699fe0b6cd7017116431ddef7 (v0.5).
Keep v1 accounts, sessions, village IDs, residents, positions, horse records and
territory claims. Add v2 tables and adapters; do not edit migrations 001–005.
Exactly one v2 settlement references each existing primary village. Legacy
coordinates stay archival/compatible; strategic plots are separate identities.
An existing army's eight soldier identities map to initial v2 unit inventory.

Every v2 write authenticates the existing opaque session, locks the player's
kingdom row, settles server-timestamped production/timers, validates catalog
requirements, spends resources and commits one transaction. Client-generated
request IDs are scoped to player and operation, bound to payload digests and
replay the original response. They do not provide authority. Mutations never
accept a subject player ID, balances, rewards, completed timestamps or XP.

## Vertical delivery order

1. Additive migration, catalogs, economy, building/research/training queues,
   configurable level requirements, empire customization, strategic plots and
   bounded persistent settlement entry. Connect Godot management and map UI.
2. Clan creation gate, roles, region/capital/member-plot allocation and safe
   transactional relocation; expose actual clan controls in Godot.
3. Army presets, deterministic battle instances, casualty/report persistence,
   connected conquest and protections; directly controlled battle presentation.
4. Equipment/commanders, quests/social, complete clan wars and progression gates.

Each checkpoint must include integration/anti-replay tests and an exact HANDOFF.
Configuration/art tables do not mean unfinished gameplay is implemented.

## Rendering

Reuse the pinned MakeHuman rig, shared actor meshes, touch controls, scenery and
materials. New settlement terrain allocates a fixed bounded set; legacy streaming
remains only as compatibility code exercised by historical tests. Army display
is bounded independently of persistent army size. LOW/BALANCED/HIGH/ULTRA are
allocation/shadow targets; retain GL Compatibility and do not promise device FPS.

Future synchronous battle workers use the same battle IDs, participants,
commands, snapshots and result transactions; no UDP service is assumed on Railway.
