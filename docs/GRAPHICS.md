# Mobile rendering

Godot 4.7.2 GL Compatibility remains the verified Android path. Do not switch to
Vulkan without export/device testing and a compatible fallback. Server deployment
does not render models or raise device graphics quality.

The new strategy settlement uses four fixed terrain pieces and physical boundaries
at ±128 metres. Moving the ruler cannot allocate additional terrain/nature chunks.
Legacy terrain code stays available for v1 fixture regression checks. Persistent army
size is independent of bounded visible actors (currently at most 40 settlement soldiers).

LOW/BALANCED/HIGH/ULTRA vary MSAA, shadows, visibility/scenery budgets and targets.
Targets are not measured FPS promises. The near ruler keeps its medium production
rig/cloth/armor detail; all players share the same base ruler and unit-quality tiers.
Commanders and class-specific cavalry/ranged/siege visuals remain unfinished.

Empire primary/secondary colors and approved emblem textures are shader parameters on
ruler cloth, soldier capes and settlement flags. Actor meshes/skeletons are reused;
models are not regenerated for a color change. Map ownership displays empire/clan
colors. Banner style persists now; full geometric banner variants remain future work.

Existing distance culling is preserved. Further production work includes mesh LOD,
animation LOD for large formations, MultiMesh for suitable static/remote units,
texture/particle budgets, occlusion and a physical Android device test matrix.
Do not instance independently animated near combatants with a static MultiMesh and
claim skeletal animation support.

Assets remain pinned, licensed and checksum-verified. Actual-render screenshots/videos
come from Godot CI. Placeholder/catalog data cannot create final AAA art. Compare real
captures and measure memory/frame time before calling a graphical tier production-ready.
