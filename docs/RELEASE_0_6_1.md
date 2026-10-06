# PRIME KINGDOMS 0.6.1 — character detail review

The player character remains on the 49-joint 0.6 model, with continuous physical
sword extraction, hand/finger IK and swept blade collision. This change adds
original raised gold acanthus ornament and curved plate edges, sculpted lion
shoulder clasps, separate fleur-de-lis skirt artwork, corrected hair shading,
neck-length hair shaping and adjusted player skin material. Residents are not
given the new player wardrobe. No terrain or production identity/state changes
are introduced by this iteration.

`character_review.gd` instantiates the actual production player controller and
wardrobe in a neutral inspection environment. It saves front, face, back and
drawn-sword images and optionally a real 240-frame orbit/action movie. It is a
studio inspection of the game model, not a generated movie or a replacement
for the existing world/weapon/physics tests.

This iteration is **not certified as a final reference match**. The face sculpt,
hair topology, articulated plate silhouette, garment contact and animation
quality still require actual visual inspection against the supplied reference.
Code checks do not establish photorealistic similarity or Android performance.
Do not describe this milestone as final or equivalent to the reference image.

Android version 0.6.1, version code 7, package `com.prime.kingdoms`. Existing
releases and accounts remain intact. The original ornament geometry and SVG
are project artwork; generated models still use the pinned licensed pipeline.
