# Licensed assets in version 0.4

The game embeds CC0 assets. No runtime asset service or paid account is required.

## Anatomical humans — MakeHuman Community

- Core body mesh, male morph target, 19-bone reduced rig derived from the default rig, and skin weights: https://github.com/makehumancommunity/makehuman
- Skin, short hair, eyebrows, eyes and fitted male_casualsuit01 garment geometry/textures: https://static.makehumancommunity.org/assets/assetpacks/makehuman_system_assets.html
- Asset license: https://static.makehumancommunity.org/about/license.html and https://github.com/makehumancommunity/makehuman/blob/master/LICENSE.md

These graphical assets are CC0 1.0, separately from the application source code license. This project uses only data files, and its converter is original project code. Each selected core data file has its immutable Git object checksum. Each archive member has a pinned compressed byte range and decoded SHA-256; only selected members are transferred. The original copyright notices remain in source assets.

The pipeline fits garments/eyes/hair to the male morph, preserves UV seams and weights, removes helper geometry and hidden body faces, and emits one shared GLB. Eight original, in-place motion clips are generated with limb IK: idle, walk, run, jump, fall, land, guard and work. These are procedurally authored skeletal motions, not captured human performances. Role-specific materials and crown, helmet, armor, boots and wind-animated cape are made in project code.

## Photographic materials and HDR sky — Poly Haven

Powered by Poly Haven: https://polyhaven.com

Assets: grass_ground, brown_mud, rocky_terrain_02, stone_wall_02, wood_planks, grey_roof_tiles, rough_plaster_03, rough_linen, bark_brown_02, and kloofendal_48d_partly_cloudy_puresky. Asset pages and original download URLs are recorded individually in tools/assets/sources.json.

License: https://polyhaven.com/license — CC0 1.0. The build verifies SHA-256 for every downloaded diffuse, OpenGL normal and roughness map and the HDR panorama. Textures use 1K source maps; the engine imports mipmaps and Android texture compression.

## Original project geometry

Timber-and-stone architecture, props, vegetation silhouettes, armor and shader animation are authored in this repository. Geometry is batched by material and scenery is streamed within finite quality-dependent budgets. Quaternius models from releases 0.2/0.3 are no longer part of the current app. Previous versioned releases and their original credits remain available.

CC0 legal text: https://creativecommons.org/publicdomain/zero/1.0/legalcode

Run npm ci --prefix tools/assets and npm run --prefix tools/assets prepare:models to reproduce assets. Generated binary graphics stay outside git and are embedded in each APK.
