# PRIME KINGDOMS 0.7.1

Strategy conversion checkpoint, Android version code 12. Development is continuing;
this is not the complete requested empire game.

Preserves v0.5 data, third-person movement, touch controls, horse, lying/crawling and
sword actions. Adds bounded settlement entry, persistent server economy, construction,
research, expandable training, configurable level gates and empire heraldry/map.

This checkpoint adds real clans: server-enforced level-15 creation, region/capital,
member plots, roles/applications/invitations, safe relocation/resettlement, cooldowns,
active-war protection and replay-safe treasury donations. Mobile unresolved requests
survive application restarts. CI validates actual native clan joining and map presentation
using a disposable API/database fixture and captures kingdom.png.

Deploy the v2 API before using this APK. Production Railway is unchanged during branch
development. Full hostile combat, conquest, equipment/commanders, clan wars, quests and
social systems remain unfinished. See HANDOFF.md for exact checks and remaining work.
