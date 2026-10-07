# Combat authority and implementation status

Current client preserves ruler walking/sprinting/jumping, sword draw/sheathe/strike,
lying/crawling, riding and legacy follow/guard presentation. Sword sweeps still damage
local practice targets. This is not yet authoritative hostile army combat.

The next vertical subsystem is a server-created battle instance. Reserve owned units,
snapshot catalog stats/research/equipment, bind participants and target tile/version,
record server seed/configuration/commands, and produce deterministic verifiable results.
Reserve first so one army cannot fight two simultaneous battles. Results atomically
apply alive/wounded/dead counts, rewards, XP, territory consequences and reports once.

Local third-person battle movement and animation remain responsive. Important ruler
actions need legal command sequencing, cooldown/range checks and server state. A
modified APK cannot submit victory, casualty counts, equipment stats or damage totals.
Clients render confirmed units and interpolate snapshots; replay visual approximation
must be distinguished from synchronous authoritative combat.

Implement infantry, ranged, cavalry, commanders and siege using shared definition
tables and class-appropriate visuals/animations. Army presets and follow/hold/attack/
defend/retreat/formation commands must connect to reservations/simulation. Add block,
dodge, hit reaction and defeat input/presentation without changing the saved settlement
controller's established behavior.

Persist attacker/defender armies, seed/version, commands, casualties, result, rewards,
time, tile impact and clan/war context. Later dedicated servers can replace simulation
workers without changing battle identifiers or result authority. Railway HTTP is not
treated as a high-frequency UDP MMO server.
