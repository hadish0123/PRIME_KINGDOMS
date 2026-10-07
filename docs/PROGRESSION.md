# Ruler progression

kingdom_level_requirements stores every cumulative requirement for levels 1–100.
The initial curve is floor(100*(level-1)^2.5*1.18^max(level-20,0)); level 1 needs zero.
Requirements are database configuration, not client authority. Every consecutive
level must meet every gate; XP alone cannot bypass a missing achievement requirement.

| Level range | Design difficulty | Additional initial gate |
| --- | --- | --- |
| 1–20 | Accessible | XP |
| 21–50 | Progressively slower | XP |
| 51–75 | Difficult | XP |
| 76–90 | Extremely difficult | 100 prestige per level above 75 |
| 91–95 | Elite | Also 100 conquests per level above 90 |
| 96–99 | Legendary | Also 20 seasonal medals per level above 95 |
| 100 | Ascended Sovereign | Also 3 rare ascension tokens |

Production completion grants source/event-bound XP once. Training is capped at
1,000 XP per UTC server day and research at 3,000; unique completed building events
cannot be claimed repeatedly. There is no client XP/level setter.

Prestige, conquest, seasonal medal and ascension award pipelines are not yet
implemented. Therefore the current progression cannot legitimately attain level
100. Do not add an administrative/public shortcut and call progression complete.
Future rewards need verified achievements, diminishing farmable sources and
season/event provenance before these gates become reachable.

The goal of only a tiny handful of level-100 players in an enormous population
requires simulation, retention data and telemetry. The curve alone does not prove
that rarity. Tune configuration using observed time-to-level/XP-source distributions;
never enforce an arbitrary fixed account quota or sell ascension bypasses.
