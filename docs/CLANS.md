# Clan membership and relocation

Implemented: creation, browse, open join/application, leader/officer decisions,
invitations, role changes, leadership transfer, leave, kick and resource donations.
Godot exposes the same actions; requests authenticate and commit real SQL state.

Creation requires level 15, 500 gold, a 3–32-character name and a unique 3–6-character
ASCII alphanumeric tag. Names are normalized and reject control/format characters
and markup. Tags normalize to uppercase. Colors and emblems use approved libraries.
The creation transaction registers a real strategic region and capital fort.

Plot 0 is the capital; plots 1–63 hold member primary settlements. A player belongs
to exactly one clan. Open joining or accepting an invitation immediately allocates
a legal free plot; otherwise joining creates an application. Officers/leader can
accept or reject. Only the leader can change officer roles or transfer leadership;
an officer can kick members but cannot kick officers/leader. Leaders transfer before
leaving. Founder history remains intact after leadership changes.

Joining changes strategic placement, not the primary village ID or physical legacy
coordinates. Buildings, resources, timers, units, scene/horse state and progression
are untouched. Leaving/kicking allocates a legal starter plot and records relocation
history. An abandoned clan member plot returns to that region. A released starter
holding remains a fort; there is never a second primary settlement.

Join, leave and relocation have server-time 24-hour cooldowns. Active preparation or
battle wars prohibit relocation/joining. Relocation preserves the original starter
protection deadline and cannot renew immunity. Unique indexes and transaction locks
prevent concurrent double membership or plot allocation.

Treasury supports five resources and replay-safe donations. Clan XP/perks/technology,
chat, capital upgrades, large-region expansion and full clan wars remain unfinished.
Current region capacity is an explicit initial rule, not a permanent army-size
restriction. Clan region ownership/member plots appear on the world map;
a separately explorable capital scene remains future work.
