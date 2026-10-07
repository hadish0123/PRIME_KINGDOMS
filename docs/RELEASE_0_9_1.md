# PRIME KINGDOMS 0.9.1 — Campaign candidate

Army orders now march through persistent server-timed routes. Forces stay reserved
until surviving soldiers return home. Recall, allied reinforcements, defensive
participation, casualty ownership, reports and safe clan relocation are connected
through the same authoritative transaction path. An offline worker resolves arrivals
without requiring login. Current target eligibility is checked again on arrival.

The Army and World pages show active orders, routes, arrival countdowns, incoming
forces, recall and report actions. Settlement garrisons reflect available soldiers.
Construction previews explain prerequisite levels, shortages and an occupied queue.
Defensive architecture follows actual completed building levels: survey sites,
timber defenses and later stone walls, towers and gatehouses.

Additive migration 010 creates campaign records and troop reservations and extends
battle reports. Migrations 001–009 remain unchanged. Existing healthy troop totals,
world identity, residents, permanent villages and all player progress are preserved.

App/backend version is 0.9.1 and Android version code is 15. Earlier APK releases
remain available. This is a prerelease candidate, not the completed production game.

Local Node.js 24 syntax checks and 13 unit tests passed. Eight integration suites
passed with supplementary serialized PGlite SQL execution. Native PostgreSQL CI,
Godot rendered validation, Android export and signature evidence must be reviewed
for this exact source commit before those gates are reported as passed.

Production Railway remains on 0.5.0. This candidate has not applied production
migrations or deployed its v2 API. The embedded production URL cannot yet serve the
new strategy client. Premium art, battle choreography, final balance, equipment,
seasons, moderation operations, physical Android performance/lifecycle and final
release signing remain blockers for the master production scope.
