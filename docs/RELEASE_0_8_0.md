# PRIME KINGDOMS 0.8.0 — Online strategic command and conquest

This checkpoint changes the v2 game from direct ruler steering into a strategy-first
online kingdom game while keeping the existing bounded 3D settlement, ruler, soldiers,
horses, heraldry and high-end mobile presentation.

## Player experience

- The ruler remains physically represented inside the settlement, but the player no
  longer drives that character with a joystick in v2 strategy mode.
- A dedicated command camera pans, rotates and zooms over the living 3D settlement.
  Touch uses drag/pinch; desktop uses mouse/WASD/Q/E.
- The management surface is now **REALM COMMAND**: economy, construction, research,
  army composition, empire identity, clan, strategic map and battle reports.
- Legacy v1 direct third-person controls remain only for compatibility/regression.
  New strategy entry does not depend on saving a manually moved ruler position.

## Realm growth

Realm rank is server-authoritative and cannot be changed by the client. Growth is:

Village → Town → City → Country → Kingdom → Empire

Promotion requires a combination of Keep level, ruler level, controlled territory and
verified conquests. The initial server table is:

| Rank | Keep | Ruler level | Territory | Conquests |
| --- | ---: | ---: | ---: | ---: |
| Village | 1 | 1 | 1 | 0 |
| Town | 4 | 8 | 3 | 1 |
| City | 8 | 20 | 8 | 4 |
| Country | 12 | 35 | 18 | 12 |
| Kingdom | 18 | 55 | 35 | 30 |
| Empire | 24 | 75 | 64 | 60 |

These values are initial balancing data and can be changed in a forward migration or
configuration pass without trusting client state.

## Army command and battles

- Up to five persistent army presets can be saved.
- A preset contains exact unit quantities, formation and stance.
- One preset may be marked as the offline home-defense army.
- Strategic attacks are permitted only against connected map tiles.
- Battle power includes unit stats, research, formation, stance and defensive
  fortification. A server-created seed makes the bounded variance deterministic and
  auditable.
- Casualties are persisted as alive/wounded/dead counts.
- Victories can capture neutral/resource/NPC territory; a player's home settlement is
  raided/occupied rather than permanently deleted or stolen by one request.
- Clan forts require an active clan war before attack.
- Both attacker and defender receive persistent battle reports. The defender does not
  have to be online at the moment of the attack.
- Successful legal conquest grants bounded resources, prestige, conquest progress and
  event-bound XP. Clients cannot submit victory, casualties, rewards or ownership.

## Online presence

Authenticated v2 traffic updates server presence. The game periodically shows the
number of active rulers in the player's strategic region and the map can indicate
recently-online territory owners. This is online persistent strategy—not a fake local
simulation—but it does not claim to be a high-frequency realtime MMO battle server.

## Data safety

Migration 008 is additive. Existing v0.5–0.7 accounts, primary villages, NPC identities,
horse state, sessions, resources, construction/research/training queues, clans and clan
relocations are preserved. No production table is reset.

## Still not final

0.8.0 is a development checkpoint, not the finished full game. Full clan-war
declaration/scoring/rewards, commander/equipment inventory, healing, quests,
achievements, mail/chat/rankings, seasons, endgame ascension awards, richer battle
presentation and physical-device performance/art polish remain production work.

Railway production is not changed by this branch. Deploy API migrations before
distributing a client that depends on the v2 command endpoints.
