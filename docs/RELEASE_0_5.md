# PRIME KINGDOMS 0.5 — Rider, sword and persistent army

Native Android test milestone: version 0.5.0, version code 5, ARM32/ARM64, Android 7.0+. Previous releases remain available.

## Playable behavior

- Native third-person movement through streamed terrain across the existing 65.536 km world. The fractional PostgreSQL parameter bug that caused movement saves to fail and snap the player back is fixed.
- Visible draw/sheathe actions, sword strikes against a practice target, jumping, lying down, crawling and standing up. Standing and dismounting check physical clearance. There is no player-versus-player or hostile-army damage system yet.
- One own anatomical horse, idle/walk/trot/gallop/jump clips and a riding pose. Mount/dismount is authenticated and range-checked. Mounted position and parked horse position survive login.
- Follow/hold orders for the same eight soldiers. Their formations are updated by the server on movement saves; five villagers stay with their home. This is a saved formation simulation, not independent NPC thinking.
- Claim unoccupied 512 m land cells while within 90 m of the center and accompanied by all eight soldiers within 40 m. Ownership is exclusive and persistent. Other players' land and villages cannot be taken by this system. Owned plot count changes the saved stage at 4/12/32 plots to city/country/empire; it does not yet construct a larger city or simulate an economy.
- Actual circular 3D minimap and an army/resident panel with commands and owned plot count. Actions work through keyboard and native onscreen buttons.

## Graphics and animations

Sixteen original human skeletal clips, articulated steel/gold armor, red lion cape and a visible sword/scabbard; a nineteen-bone horse with five original gait clips; improved stone/timber village enclosure, photographic materials, streamed grass and pine twigs, shared photogrammetry rocks, mountain scenery and Cinzel HUD typography. Mipmaps and finite scenery budgets are checked.

The client renders mountains in an art projection while retaining the exact terrain-version-1 save coordinates and world seed. Native checks cover projection round trips; network saves use canonical coordinates. Buildings still have simple exterior collision and no playable interiors.

**This does not match the supplied photorealistic reference or PUBG/AAA production art.** Surface quality, scenery density, environments, faces, hands, weapon transitions, cape simulation and gait blending still need specialist art and animation work. PRIME powers, seven Legends, full warfare, conquest of occupied homes, advanced weather, wildlife, crafting and economy remain unfinished.

## Validation and evidence

The release workflow runs backend checks and disposable PostgreSQL integration; native account/fractional save/re-entry, reconnection/late response/Android lifecycle, movement/physics/touch, action collision, rig/scenery budgets, UI bounds and real-render checks. Upgrade tests compare the existing world, accounts, home villages, resident records and saved positions before and after the two new migrations. Production data is not reset and no test accounts are created there.

`animation.mp4` contains 600 actual Godot-rendered frames at a fixed 30-frame recording cadence, showing controller-driven sword actions, lying/crawling, foot movement/jumps and riding through the village gate. The software-rendered recording uses LOW graphics and labels that setting onscreen; the installed client still defaults to BALANCED. Rig and allocation checks exercise LOW/BALANCED/HIGH separately, and the posed screenshots use BALANCED. It is recorded in a local test village; the camera, parking position and cut to the horse are arranged by the test. Mount persistence is proven separately by API integration tests. The video cadence is not measured Android performance. Screenshots are runtime captures; generated art is used only as a source texture.

No physical Android device was available for performance, thermal, memory or touch calibration measurements. LOW/BALANCED/HIGH frame rates remain targets. Signing uses private repository secrets when configured; otherwise the APK is a development-signed test build. A different development signing certificate can require uninstalling the old APK before installing; the saved server account/home remains available after login.

## Controls

WASD/arrows move; Shift runs; Space jumps; hold right mouse to orbit; F draws/sheathes; left mouse attacks; X lies down/stands; E mounts/dismounts nearby. Mobile uses the left stick, right-side camera drag and six action buttons. UNITS opens follow/hold/claim commands; WORLD shows known settlements and nearby owned land.

Asset sources and licenses: `client/assets/ATTRIBUTION.md`. Original grass source prompt/checksum: `docs/GRASS_ATLAS_PROVENANCE.md`.
