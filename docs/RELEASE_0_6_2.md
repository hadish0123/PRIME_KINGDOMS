# PRIME KINGDOMS 0.6.2 — player sculpt and wavy groom review

The main playable character keeps the 49-joint rig, sixteen motion clips,
continuous extraction of the same sword, finger IK and swept blade contact.
Only the player asset and its visual inspection pipeline change.

The player now has a sculpted jaw, chin, cheekbones and eye folds using licensed
checksum-pinned morph data. A build-time subdivision pass smooths the face and
eyes while preserving UVs, the neck boundary and skeletal weights. The source
resident humans keep their original meshes. An original deterministic groom
replaces the straight long-hair proxy with 102 shaped waves and loose strands.
Fitted beard fibers and skin shading follow the actual jaw and lip opening.

The armor adds sculpted shoulder lames, fluted limb plates, pointed convex
joint guards, relief lions, curved articulated sabatons and bevelled soles.
Raised ornament follows the same new plate profile. Garment folds, leather
stitching and the neck mantle have been reshaped. Hair and beard geometry are
baked once; Android does not run subdivision or a particle-hair simulation.

The production-character inspection checks the rig, sword identity, draw and
sheathing, and a bounded total triangle budget. It records neutral front,
face, profile, back and sword views plus a real eight-second orbit/action film.
A focused review workflow makes those images available independently of the
full Android build; the existing account, physics and world checks remain.

This is a visual development build. It is **not certified as a final
photorealistic match** to the source concept. Render inspection, facial likeness,
garment contact and physical-device performance remain acceptance criteria;
passing code checks does not establish them. Existing accounts, world seed,
terrain, village ownership and resident identities are preserved.

Android 0.6.2, version code 8, package `com.prime.kingdoms`. Prior release
downloads remain intact. Generated models stay out of git and are rebuilt from
licensed pins plus the project-owned geometry in `hero_sculpt.py`.
