# Settlement economy

Food, wood, stone, iron and gold use bigint balances, bounded to 10^12. A server
catalog owns every price. Requests cannot supply a balance, price, reward or deadline.
Production carries integer fractional remainders so repeated polling cannot farm
rounding gains. Storage starts at 5,000 plus 5,000 per warehouse level.

| Producer | Resource | Base hourly output per level |
| --- | --- | --- |
| Farm | Food | 80 |
| Lumber Mill | Wood | 60 |
| Quarry | Stone | 50 |
| Iron Mine | Iron | 30 |
| Market | Gold | 15 |

Economy research adds 5% per level; Agriculture adds another 5% for food. Values
are initial tuning, not a calibrated live-service balance. Production effects are
implemented in the economy module; migrate those rates to configuration before
frequent live balance changes.

Each player has one construction, one training and one research queue. Costs are
paid atomically when starting. Construction/research prices scale by 1.45^(level-1),
durations by 1.6^(level-1); Construction research shortens durations. Training accepts
1–100 units, requires its facility level and respects barracks capacity.

Server clock_timestamp establishes deadlines. Offline snapshots process due tasks
chronologically: accrue old rates to the deadline, apply its effect/XP once, then
continue to now. A backwards clock observation never re-accrues elapsed time. There
is no public task-completion or resource-grant endpoint.

All eighteen requested buildings have levels, costs, durations and prerequisites.
Production, storage, facility unlocks, keep gates and training capacity work now.
Hospital healing, equipment crafting, defense/siege combat and other dependent
effects require their domains; catalog entries do not claim those effects are done.

Clan creation costs 500 gold; treasury donations atomically spend owned resources
and credit the clan. No premium currency or paid XP shortcut exists.
