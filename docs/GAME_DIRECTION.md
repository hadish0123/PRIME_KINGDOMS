# Game direction

These are design requirements, not claims that the features are implemented.

## Player experience

- Every player controls their own character in third person and physically walks
  and fights inside settlements and the surrounding world.
- Every new player receives a small starter village belonging to them.
- The starting village grows into a city. Multiple governed settlements form a
  country; control over multiple countries forms an empire.
- Other villages and cities can come under a player's rule. Conquest, negotiated
  vassalage and the consequences of ownership need explicit game rules.
- PRIME is the god character accompanied by seven unique Legends.

## Persistent world

- A large world with regions, countries, cities, castles and natural environments.
- Weather, water, animals, day/night and environmental variety.
- NPC personalities, memory, needs, loyalty and autonomous decisions.
- Recruitment through interactions in the world, plus economy and warfare.
- Ownership and persistent simulation are server-authoritative. Clients load and
  display nearby world regions with detail appropriate to their hardware.

## Delivery

- Source control and build automation on GitHub; backend and PostgreSQL on Railway.
- The primary release platform remains to be selected. Android requires content
  and performance budgets from the start; PC allows a higher graphics ceiling.
- First gameplay milestone: a controllable third-person character in one small
  village, with persistent ownership, before expanding world size or content.
- Final art quality requires production models, textures, rigging, animation and
  device testing. Backend deployment alone is not a completed game.
