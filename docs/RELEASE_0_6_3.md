# PRIME KINGDOMS 0.6.3 — Character materials and fitted wardrobe review

This is a character art development build, not acceptance of the photorealistic
reference. Android metadata is 0.6.3 / code 9. Existing releases stay intact.

## Character changes

The production player retains the 49-joint rig, sixteen human motion clips,
one continuously drawn sword, finger IK and swept blade contact. The face uses
the existing checksum-pinned CC0 Aksel diffuse/normal assets, a revised jaw and
cheeks, one whole-head smoothing step and a second bounded nose/mouth detail
step. A fitted licensed alpha-card root layer removes the opaque forehead band;
126 authored wave/flyaway locks provide the animated groom silhouette.

A retained fitted mail shoulder underlayer and resized folded mantle reduce
neck/shoulder holes. A repositioned leather chest strap sits above the tabard.
Rolled armor surfaces have smooth vertex shading, aged-metal roughness and
continuous carved lion reliefs. Geometry is counted across indexed and
unindexed surfaces; missing indices cannot abort the mobile-budget traversal.

## Evidence and actual limits

`character-front.png`, `character-face.png`, `character-profile.png`,
`character-back.png`, `character-sword.png` and `character-review.mp4` are
captures of the actual production player under neutral inspection lighting.
The wardrobe, materials, model and sword code are the same as the playable
client. SHA256SUMS covers the APK and evidence. The review report continues to
say `reference_match: not_certified`.

Photorealistic likeness, photographic hair, fully physical cloth contact and
physical Android performance remain unverified. The face and garment assets
still differ from the reference and the film is software-rendered evidence,
not measured phone FPS. A successful automated workflow does not certify the
visual reference. No world, terrain, account, resident or migration changes
are part of this iteration. Railway remains on the existing production source
until a separately reviewed merge. Keep the character PR in draft.
