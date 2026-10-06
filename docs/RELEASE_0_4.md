# PRIME KINGDOMS 0.4 — Human proportions and PBR world

This release replaces the cartoon character and village appearance in the existing playable foundation. It preserves production accounts, the world ID/seed, owned villages, the exact eight soldiers/five villagers per account and saved positions. There are no database migrations or resets.

## Graphics and animation

- Anatomical CC0 human mesh with textured face, eyes, eyebrows, hair and fitted garments; one shared model and texture set for all roles.
- Original 19-bone motion rig with eight clips: idle, walk, run, jump, fall, land, guard and work. Locomotion speed follows measured controller movement; air and landing poses follow physics. Crossfades preserve smooth transitions. Walk speed is 2.4 m/s and sprint speed 6.4 m/s.
- Crown/cape for the ruler, helmets/armor for soldiers, leather boots and distinct role clothing. Clothes use their matching texture and normal maps. The cape has a tapered, folded silhouette and shader wind; banners, grass and leaves also move in wind.
- Rebuilt stone-and-timber houses, village hall, blacksmith, well, market stands, cart and solid fences. Meshes are batched by material and use photographic diffuse/normal/roughness maps.
- HDR photographic sky, adjusted sunlight, ambient fill, distance fog and shadows. Ground and paths have photographic surface detail. Terrain height and village flattening remain identical to the server.
- Deterministic visual trees/grass with finite streaming budgets: LOW up to 25 grass tiles/9 groves, BALANCED 49/25, HIGH 81/49; each grove has at most three trees. Distant residents still stop processing. These are scenery counts, not a performance benchmark.

## Verified output

GitHub Actions checks backend/unit/PostgreSQL integration, native accounts and saved state, reconnect/Android lifecycle, physics/touch controls and all shader/script imports. It renders the actual village, ruler, login, settings and atlas. The animation.mp4 file is recorded from native controller-driven idle, walking, sprinting, jumping and landing, rather than an illustrated mockup. Native visual checks verify skeletal deformation, every motion clip and all three scenery budgets.

The published APK has version name 0.4.0/version code 4, with signature verification and SHA256SUMS.txt. Existing releases remain unchanged. Without configured private production signing secrets it uses a development certificate; Android may require uninstalling an older differently signed app, then signing into the same saved server account.

## Actual scope

This is a tested graphics upgrade for the implemented village foundation. It is not photorealistic AAA art or PUBG-level production quality. Motion is authored using IK curves, not motion capture; garment/wind animation does not simulate full cloth physics. Architecture currently supplies exterior scenery and collision. The world has hills and visual vegetation, and NPC guard/work/patrol clips are local presentation rather than independent server AI.

Combat, economy, growth/conquest, cities/countries, PRIME powers and seven Legends remain separate game systems. The APK has not been benchmarked on physical Android hardware; profile 30/60 FPS values are targets.
