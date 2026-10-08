# PRIME KINGDOMS 0.9.5 — Royal Dawn candidate

The native game now uses a light ivory/champagne design with forest text, sage
accents and an original crown-and-keep brand. All 15 council workspaces, the
settlement HUD, login and settings use the shared theme. Original illustrated
resource/action/navigation glyphs replace the old raster icon atlas in these
controls. Buttons, fields, dropdowns, checks, sliders, progress bars, scrollbars,
tooltips and battle panels receive readable light states. Building cards use
original architectural vector plates. The launcher and login carry the same crest.

Native homes use brighter cream plaster and stone, terracotta village roofs,
sage mature roofs, colored shutters, glass, window planters and entrance canopies.
Repeated three-storey homes use fewer roof strips to keep the district within its
existing geometry ceiling. Straight timber beams use a single axial ring without
changing their silhouette. Lighting remains bounded for the mobile renderer.
Settlement coordinates, ownership, NPC identities, construction gates, resources
and queues are preserved. Starter villages retain timber defenses, an open gate,
eight soldiers and five civilians. Village → Town → City → Country → Kingdom →
Empire remains earned through server milestones. Clan membership and the complete
64-plot enclosing border remain authoritative; clan creation still requires
Level 15 and 500 Gold.

The design ZIP includes original editable SVG artwork, semantic tokens, native
layout JSON for all 17 screens, SVG overlays, licensed fonts, an importer and real
native PNG previews. **Figma Starter MCP quota blocked writes.** The existing
Royal Frontier Figma file is unchanged. The supplied Royal Dawn importer has
passed syntax checks but awaits Figma execution and visual verification.

Versions: app/API 0.9.5, Android code 19. This adds no migration and performs no
production reset or Railway rollout. This is a stacked visual candidate on the
Royal Frontier branch. The v2 backend rollout remains separate from GitHub
publication. Production still needs that compatible API before kingdom entry.

Release gates: backend checks/unit tests, real PostgreSQL integration, native
import/parse, fresh account and actual clan/march flows, reconnect/lifecycle,
all 15 management screens at three viewport sizes, login/settings contrast,
bounded native district rendering, Android APK export and signature verification.
All-screen review increases the overall rendered test allowance; the bounded
network timeout and recovery requirements are unchanged.

The uniquely tagged release includes the installable APK, design ZIP, checksum
file and native images for the starter village, council, clan, login, settings,
architecture close-up and empire district. It is an installable review candidate;
physical-device FPS/installation, final production signing, final unit art, full
battle choreography and economy balance are separate outstanding validations.
