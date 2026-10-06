# Original meadow atlas — provenance

The PNG is an original generated game texture, not a rendered game scene. It contains four transparent grass cutouts for the native foliage shader. The runtime places these on streamed 3D meshes; actual game screenshots and movies are rendered by Godot.

- Source: `client/assets/textures/meadow_alpha.png`
- Generated on: 2026-10-06, using the imagegen skill.
- Canvas: 1536 × 1024 RGBA, transparent background.
- Source SHA-256: `91934ee9fd80b4d1b8595d019e656bd712e79d1403d82eb7f49b749050fd2659`
- Git blob: `4e4768f0ea3247b8e3422e8940e5b31f6f89df22`
- The build checks the original bytes before importing mipmaps and mobile texture compression.

## Generation prompt

Use case: photorealistic-natural
Asset type: original game vegetation alpha atlas for a native 3D medieval landscape, 1536x1024 landscape image, transparent RGBA background.
Primary request: exactly four separate, realistic small clusters of meadow grass, arranged as a 2 by 2 texture atlas. Each quadrant has one entire isolated grass tuft with transparent margins, roots at the bottom center of that quadrant, no overlapping quadrants. These are actual plant cutouts for crossed 3D grass cards, NOT a scene, not a screenshot, not an illustration of a game.
Subject: fine natural grass blades, slightly bending, many thin blades per tuft and a few delicate seed heads, wild temperate European meadow, mixed fresh muted olive green and some dry wheat-colored tips. Two broader thick tufts, one fine thin tuft, one little wild grass tuft with tiny white meadow flowers.
Style/medium: photoreal plant photography, physically detailed leaves, diffuse overcast neutral studio light, no hard baked directional highlights or cast shadow, straight-on side view at ground level. Realistic variation and irregular silhouettes.
Constraints: genuinely transparent background, no dirt or ground plane, no labels, no text, no frame, no scenery, no watermark, no checkerboard drawn in, no painted look, no neon green. Every quadrant is one complete centered plant tuft; keep all blades inside its quadrant with 8 percent transparent padding. Remove soil from the roots. Designed as a game albedo alpha texture lit later by a 3D game engine.

