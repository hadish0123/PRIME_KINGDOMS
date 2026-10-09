# Licensed assets in version 0.6

The game embeds CC0 graphical assets, the OFL-licensed Cinzel font and original project art. No runtime asset service or paid account is required.

## Anatomical humans — MakeHuman Community

- Core body mesh, male morph target, 19-bone reduced rig derived from the default rig, and skin weights: https://github.com/makehumancommunity/makehuman
- Skin, short hair, eyebrows, eyes and fitted male_casualsuit01 garment geometry/textures: https://static.makehumancommunity.org/assets/assetpacks/makehuman_system_assets.html
- Asset license: https://static.makehumancommunity.org/about/license.html and https://github.com/makehumancommunity/makehuman/blob/master/LICENSE.md

These graphical assets are CC0 1.0, separately from the application source code license. This project uses only data files, and its converter is original project code. Each selected core data file has its immutable Git object checksum. Each archive member has a pinned compressed byte range and decoded SHA-256; only selected members are transferred. The original copyright notices remain in source assets.

The pipeline fits garments/eyes/hair to a young/old male morph blend, preserves UV seams and weights, removes helper geometry and hidden body faces, and emits an NPC GLB and a separate player GLB. The player rig has 49 bones including finger joints; NPCs also use 49 joints. Nineteen original, in-place motion clips are generated with limb IK: idle, walk, run, jump, fall, land, guard, work, draw, sheathe, attack, lie_down, prone, crawl, stand_up, ride, death, block and hit. These are procedurally authored skeletal motions, not captured human performances. Role-specific armor, boots, scabbard, sword and wind-animated cape are made in project code. The player's single sword is positioned continuously by the post-animation IK modifier.

Additional player assets, with checksum-pinned selected archive members (the beard is trimmed and the CC0 long01 hair is shortened and shaped into waves in the converter):

- Aksel Skin by Mindfront, diffuse and normal maps: https://static.makehumancommunity.org/assets/assetpacks/skins02.html — CC0, as listed in that pack.
- WDG Scruffy Beard by WDG: https://static.makehumancommunity.org/assets/assetpacks/bodyparts05.html — CC0, as listed in that pack.

## Photographic materials and HDR sky — Poly Haven

Powered by Poly Haven: https://polyhaven.com

Assets: grass_ground, brown_mud, rocky_terrain_02, stone_wall_02, wood_planks, grey_roof_tiles, rough_plaster_03, rough_linen, bark_brown_02, pine_twig, rock_moss_set_02, cobblestone_floor_01 (Rob Tuytel) and kloofendal_48d_partly_cloudy_puresky. Asset pages and original download URLs are recorded individually in tools/assets/sources.json. Seven individual photogrammetry rocks share one texture set. Pine geometry is original project geometry; only the twig texture atlas is restored.

License: https://polyhaven.com/license — CC0 1.0. The build verifies SHA-256 for every downloaded diffuse, OpenGL normal and roughness map and the HDR panorama. Most textures use 1K source maps; the new cobblestone diffuse, normal, roughness and displacement maps use 2K sources; the engine imports mipmaps and Android texture compression.

## Original project geometry

Timber-and-stone architecture, props, vegetation silhouettes, armor and shader animation are authored in this repository. Geometry is batched by material and scenery is streamed within finite quality-dependent budgets. Quaternius models from releases 0.2/0.3 are no longer part of the current app. Previous versioned releases and their original credits remain available.

The original photographic grass alpha atlas is generated artwork. Its exact prompt, dimensions and checksum are in `docs/GRASS_ATLAS_PROVENANCE.md`. It is a texture source, never a substitute for a game screenshot. The original SVG lion and control icons are project art. The generated royal cloth texture is documented in `docs/ROYAL_TEXTILE_PROVENANCE.md`.

## Anatomical horse — OpenGameArt

`riggedHorse.blend`: https://opengameart.org/content/rigged-horse — CC0, model/textures by Lyndon Daniels, rig by ChadM. The build downloads only the pinned data file and opens it with embedded script execution disabled. `tools/assets/horse.py` reweights accessories, restores photographic materials and authors five new in-place clips: idle, walk, trot, gallop and jump. Saddle, blanket and stirrups are original project geometry. The source contains the model/rig; these gait animations are project-authored, not motion capture.

Blender 4.5.9 LTS is a checksum-pinned build dependency used to convert the source to GLB. Android runs Godot and does not require Blender or the original .blend file.

## Cinzel — SIL Open Font License

Cinzel by Natanael Gama is restored from an immutable google/fonts commit recorded in `tools/assets/sources.json`. The embedded license and copyright are in `client/assets/fonts/Cinzel-OFL.txt`.

CC0 legal text: https://creativecommons.org/publicdomain/zero/1.0/legalcode

Run npm ci --prefix tools/assets and npm run --prefix tools/assets prepare:models to reproduce assets. Generated binary graphics stay outside git and are embedded in each APK.

## Original interface audio

select.wav and complete.wav are deterministic original synthesized cues produced by tools/assets/audio.py. No external samples or recordings are used.

## Royal interface artwork · 0.9.2

The realistic ruler portrait, sixteen resource/navigation icons and sixteen architectural previews were generated originally for PRIME KINGDOMS using OpenAI image generation. Source PNGs are preserved without pixel editing. Frames, action symbols and minimap ornaments are original SVG/code artwork. The user-supplied design reference informed layout; its raster artwork was not extracted or used as a game background.

Exact paths, SHA-256 hashes, atlas order and generation provenance are recorded in `docs/ROYAL_ART_0_9_2.json`. UI uses shared atlas textures; production balances, building levels and action requirements come from the server.
