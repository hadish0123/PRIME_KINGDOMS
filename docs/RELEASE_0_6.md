# PRIME KINGDOMS 0.6 — player and ground iteration

This is an installable development milestone, **not the requested reference-matching final release**. The actual images and controller video are recorded from Godot; they do not use the concept image as a background or replace a moving model with a generated character picture.

## Player and sword

- Separate anatomical player model with 49 joints, including fingers; residents keep the lighter 19-joint model.
- Crimson woven lion tabard, skinned lower cloth, moving cape, scarf, leather belts/pouch, layered steel shoulders, articulated forearms, knee/shin plates and boots. The player has no crown.
- Checksum-pinned face diffuse/normal maps, fitted beard and shaped neck-length hair. The cloth texture is original generated art; provenance is recorded separately.
- A single sword stays inside an open scabbard, moves through its mouth during the 1.5-second draw and remains in the hand. Sheathing reverses that path. Post-animation two-bone arm IK and finger poses position the grip.
- The 0.9-second strike tests the blade and swept tip/midpoint against actual collision geometry. Only local practice equipment receives damage in this milestone, once per strike. Obstructions between the body and contact prevent hitting through a wall.

## Ground

- 2K photographic cobblestone diffuse, OpenGL normal, roughness and height maps, with bounded eight-step close-range parallax, dirt edges and wet joints.
- Grass/earth macro variation and finer photographic sampling; bounded grass instance counts and distance-dependent detail.
- Terrain version 1, the canonical height function, world ID/seed, account/village ownership and resident identities remain unchanged. No migration resets or recreates existing data.

## Controls

Android: left stick moves, drag on the right looks, **SWORD** draws/sheathes, **ATTACK** strikes when drawn. **RUN**, **JUMP**, **LIE/UP**, **RIDE**, **UNITS**, **WORLD** and **SETTINGS** remain available.

Desktop: WASD, right mouse look, F sword, left click strike, Shift sprint, Space jump, X lie/stand, E ride.

## Validation and actual evidence

The release workflow checks import errors, disposable PostgreSQL/native accounts, reconnection and Android lifecycle, native physics/actions, 49-joint player deformation, bounded LOW/BALANCED/HIGH scenery, one-sword identity, palm-to-hilt error, finger closing/releasing, blade contact, rear misses and wall-blocked hits. It renders player front/back/face, draw phases, sword and ground images at 1280 × 720 and records a 600-frame, 20-second controller movie at 30 capture frames per second.

The evidence is produced with Mesa software OpenGL. The controller movie uses LOW scenery; player review images use the default BALANCED scenery. This is not measured Android frame rate or a phone benchmark. `SHA256SUMS.txt` records the APK, images and movie.

## Remaining visual work

The reference is a highly detailed still image. This iteration does **not** reproduce its face, individual hair strands, sculpted ornamental armor, physical cloth/contact behavior or cinematic lighting exactly. Animations are authored procedurally, not motion capture. Cloth movement is shader animation with approximate gravity, not a physical cloth simulation. Further custom character sculpting, texture/groom work and device testing are required before calling the requested player/ground graphics final.

Full server combat, hostile NPCs, occupied-village conquest, autonomous resident decisions, economy, PRIME powers and seven Legends are not implemented by this release.

## Installation

Package `com.prime.kingdoms`, version `0.6.0`, Android version code `6`, ARM64 and ARMv7. Build verification checks APK metadata and signatures. When release-signing secrets are unavailable the build uses a development certificate; upgrading from a differently signed development APK may require uninstalling it. Sign in to the same account to restore its server-saved village and confirmed position. Previous versioned downloads remain available.

Asset credits: `client/assets/ATTRIBUTION.md`. Royal texture prompt/dimensions/checksum: `docs/ROYAL_TEXTILE_PROVENANCE.md`.
