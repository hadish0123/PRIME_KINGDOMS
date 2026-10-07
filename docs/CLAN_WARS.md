# Clan wars — architecture and current status

The schema currently records attacker/defender, preparation/battle/result/cancelled
phase, deadlines and scores. Active rows block unsafe clan relocation. No declaration,
score/reward or phase-transition API is implemented yet; this is not a playable war.

Implement next as server-time preparation → battle → result, with unique participation
and attack reservations. Leader/officer declaration validates cooldowns, legal targets,
protection, roster snapshots and treasury requirements. Asynchronous attacks use
server-created battle instances and immutable reports; clients never submit scores.

Objectives reference capital, fort or settlement tiles. Attack caps, repeat-target
limits, occupation and defender recovery rules must be explicit database configuration.
Atomic result transactions settle score, rewards, ownership impacts and war history
once. Leave/kick/relocate remain blocked while relevant war state is active.

Acceptance tests must cover illegal transitions, duplicate attacks/results, concurrent
declarations, offline defenders, surrender rules, protected capital attacks and
win-trading signals. Reward eligibility should use roster tenure and attack provenance
to prevent last-minute membership swapping or alternating-clan farming.

Dedicated synchronous servers may later own battle ticks; war IDs, participant
snapshots, commands and result transactions remain the same. A hundred-player realtime
UDP battle is not required for the initial Railway architecture.
