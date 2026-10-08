# PRIME KINGDOMS 0.9.3 — Starter realm candidate

New realms begin with a completed low timber palisade and open wooden gate. Eight persistent starter guards occupy the gate, corners and barracks; deployed or wounded forces remain absent from the garrison. Five civilian identities remain intact. Unbuilt production sites are unobtrusive until construction begins.

Village → Town → City → Country → Kingdom → Empire now changes household count, roof materials, stories, lanes and civic architecture using the earned server rank. The realm screen shows the current progress against every next-stage requirement. Buildings and combat defenses still use their actual completed levels; cosmetic districts do not grant resources or soldiers.

Clan creation remains restricted to Level 15 and 500 Gold. Its real 64-plot region receives a continuous heraldic perimeter, capital crest, member settlements, own-plot highlight and online marks. World-map clan borders come from bounded authoritative region queries. Relocation preserves player records.

Settlement refresh now includes army orders and reports in the same authoritative transaction. A newly arrived battle cannot leave the council displaying an earlier territory count or garrison alongside a newer report. Older server releases retain their compatible command endpoint during rollout.

Initial scene rendering finishes before the settlement request begins, so first-use shader compilation cannot consume its network deadline. A missing first snapshot displays a retryable council, enters connection recovery and restores the same account without duplicating villagers or troops.

Additive migration 011 grants level-1 walls/gatehouse to missing initial defenses and changes new-account defaults. It preserves completed upgrades and unfinished defense queues, balances, XP, identities and all historical migrations. There is no reset. App/backend version 0.9.3; Android version code 17. Godot 4.7.2 GL Compatibility remains unchanged.

Validation gates: 13 backend unit tests, native PostgreSQL integration (including all six earned realm stages, boundary filtering and preservation on upgrade), GDScript import, actual native fresh-account and clan rendering, reconnect/lifecycle, bounded visual geometry, APK export and v2/v3 signature verification. Images starter-village.png and clan-region.png are captured through real API flows. CI publishes the candidate only after its authority and Android gates pass.

Local rendering uses a disposable serialized PostgreSQL WASM engine and complements native PostgreSQL CI. Physical Android installation/FPS, final release signing and production rollout require separate evidence. Production is still 0.9.1; this candidate's migration and new API fields have not been deployed. Premium class-specific unit assets, advanced battle choreography, final balance, equipment/season operations and moderation operations remain outside this completed milestone. This is a review candidate, not certification of the whole production game.
