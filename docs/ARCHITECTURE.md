# Strategy architecture

The player commands the kingdom. There is no production avatar controller.
Godot renders a bounded settlement, decorative ruler, local worker/patrol
presentation and army aggregates. Twenty-four building sites project persistent
server development and active construction onto batched original architecture.
Camera input is blocked by council panels, connection recovery and application pause.

HTTPS connects the client to Node.js 24 and PostgreSQL. The server owns identity,
wallets, queues, research, inventory, combat, progression, clans, territory and rewards.
Client clocks and requested XP/victory/balances never authorize changes.

All player writes serialize on authenticated player/kingdom rows. Cross-player
battle/clan/war operations acquire advisory lock 73462712 first. Cached write
results are bound to authenticated player, request UUID, operation and canonical
payload hash. Mobile requests save that identifier before transmission; timeout,
suspension, reconnect and restart retry the original request.

Settlement positions in historical tables are retained for compatibility.
New scene entry projects a decorative ruler and autonomous residents into a fixed
128-metre half-size presentation. It allocates four terrain chunks. Physical scene
positions have no strategic authority. Strategic plots/tiles track regional position
and ownership independently. Clan relocation is atomic and never replaces a village.

Combat locks participants and target, validates composition/adjacency/protection/
war state, computes shared troop stats with formations, stances, research,
commanders and fortifications, then commits casualties, plunder, rewards, territory,
war score and reports in one transaction. The client receives persistent replay
input and presents the recorded outcome.

Queues and war phases settle against database time. Due work and rewards are
unique, persistent events. Inbox notifications deduplicate by event key. Chat
checks channel membership, rate, message length, block/report scope and database
constraints. Operational moderation remains a release gate.

Pipeline-generated humans, motions, photographic materials, horse and environmental
geometry use recorded licensed/checksummed sources. Quality tiers bound scenery,
active residents, army aggregates, replay actors, shadows and antialiasing.
Physical-device performance must be measured before final release.
