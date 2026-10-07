# Authoritative strategic combat

The current command is an army preset and strategic target. The server validates
ownership, available troops, contiguous territory, target protection/occupation,
clan eligibility, preparation phase and fort siege capability. Client victory,
casualties, timestamps and reward values have no authority.

Shared catalogs define fundamental troop quality. Research, commander leadership,
formation, stance, composition counters, blacksmith and fortification modify power.
The committed battle seed controls bounded variation and casualty allocation.
Wounded units enter real paid hospital treatment. Defenders lose actual plunder
above protected stores; NPC holding rewards come from fixed server rules.

A transaction commits casualties, rewards, XP, target version/ownership or occupation,
war contribution and both participants' reports. Duplicate requests return the exact
cached result. Daily battle XP is capped. A battle replay never awards currency
and never decides who won.

Recorded replay composition, phases, outcome and loss totals drive the bounded 3D
presentation. This is visual presentation of an authoritative result, not a
synchronous tactical simulation. Class-specific ranged/cavalry/siege choreography,
equipment and class-specific choreography remain final-release work.

## Campaigns in 0.9.1

Orders create persistent outbound marches. Available troops exclude outbound,
returning and stationed units; their healthy totals retain their original meaning.
Formation, stance, commander and composition are frozen at departure. Logistics and
the slowest unit determine travel duration. Leadership unlocks up to three march slots.
Recall reverses the remaining route toward the current settlement without teleporting
soldiers or resetting an existing return timer.

A bounded background worker and authenticated read catch-up share the same locked
arrival transaction. Current connectivity, ownership, protection, war and siege rules
are revalidated on arrival. Invalid orders return safely without creating a battle.
Only a committed arrival can produce casualties, reports, rewards and territory changes.
The worker does not mark an offline ruler online. Duplicate resolution is harmless.

Clan reinforcement orders station troops at an ally's settlement. Each force uses
its own technology, commander and losses, with the host's fortifications. A report is
persisted for every participating reinforcement owner. Troops and commanders abroad
cannot also defend their home. Relocation requires own armies to return; incoming
allied guards return safely when their host moves. A conquered former starter home
uses a free replacement strategic plot, preserving the village and existing conquest.
