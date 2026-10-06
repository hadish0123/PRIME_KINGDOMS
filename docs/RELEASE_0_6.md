# PRIME KINGDOMS 0.6 — Lion King character final

Native Android character milestone: client version 0.6.0, version code 6, ARM32/ARM64, Android 7.0+. The persistent world, accounts, villages, army, horse and territory data remain compatible with the 0.5 API.

## Final PRIME ruler direction

This milestone turns the approved lion-emblem knight reference into the native in-game ruler presentation rather than substituting a prerendered character. The existing anatomical 19-bone human rig and sixteen gameplay clips remain the source of motion.

- Bare-headed ruler silhouette with layered dark wavy hair and a trimmed beard instead of the earlier crown-like head detail.
- Brighter articulated steel plate with denser gilded borders, rivets, raised center rib, royal breastplate emblem and layered waist plates.
- Crimson front tabard and a longer wind-reactive crimson cape, both carrying gold lion heraldry and woven-cloth shading.
- Dark woven under-armor to increase contrast beneath the silver/gold plate.
- Double royal belt, gilded clasp, leather pouches and more readable shoulder lion clasps.
- Longer diamond-section sword with expanded gilded crossguard, terminals, leather grip bands and royal pommel.
- Refined PBR metal response with fine grain, brushing, controlled scratches, higher metallic response and tighter gold highlights.
- Refined royal cloth response with micro-weave variation, richer crimson, gold heraldry and a longer tattered hem.

## Real runtime evidence

GitHub Actions records 300 frames (10 seconds) from the actual Godot client at a fixed 30 fps. Gameplay correctness remains covered by the separate action/physics/pose tests; the final movie is a clean full-body character presentation with the HUD and practice prop hidden, a slow three-quarter hero orbit, warm royal key light, draw/strike/walk/recovery motions and BALANCED graphics.

The workflow encodes:

- `PRIME-KINGDOMS-character-final.mp4` — canonical final character movie.
- `animation.mp4` — byte-for-byte compatibility copy for existing links/tools.
- `PRIME-KINGDOMS-0.6.apk` — installable Android build from the same commit.
- Runtime screenshots and `SHA256SUMS.txt` covering the APK, movie and screenshots.

The movie and APK are uploaded together in the `PRIME-KINGDOMS-Android-0.6` Actions artifact. On a verified push to `main`, the same files are attached to prerelease `v0.6.0`.

## Scope

This milestone is a real-time character presentation upgrade. It does not replace the current body topology with an offline cinematic sculpt and it does not add facial blendshapes, hair cards, full cloth physics or a new combat system. Those can be layered on later without changing account/world persistence.
