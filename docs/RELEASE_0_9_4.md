# PRIME KINGDOMS 0.9.4 — Royal Frontier candidate

The settlement interface now uses original emerald and brass SVG frames, larger resource values in the body font, a readable ruler profile and vertical icon navigation. Council controls leave a clear gap above navigation. Wide army, map and clan panels use their space for their content, while the persistent header retains resources and identity. Transient messages appear above panels in a readable framed overlay.

The village guide displays the server-confirmed settlement stage and the fulfilled requirements for its next stage. Its bar averages bounded progress across the actual nonzero gates. Tapping the guide opens the existing realm overview. Village → Town → City → Country → Kingdom → Empire progression remains server-owned; cosmetics do not grant advancement or resources.

Starter villages retain their completed low wooden perimeter, open gate, eight persistent soldiers and five civilians. Warm wooden roofs, greener ground tones, fuller bounded trees and brighter lighting distinguish early settlements from mature architecture. Terrain coordinates, population identities, resource production and construction levels are unchanged.

The real 64-plot clan map has a larger readable region, a continuous double brass perimeter, plot variation, member settlement details and owner/online highlights. Clan creation still requires Level 15 and 500 Gold. Selecting member plots and surveying the region continue through the existing authoritative flows.

The editable [Figma file](https://www.figma.com/design/ENUteLxvRgApkWKUmrYQ5w) contains Village HUD, Royal Council and Clan Region screens, semantic variable aliases, typography styles and shared component states. Interface controls remain editable; only discrete existing artwork and the separate HUD-free 3D world are raster images. Source blueprints and the created-node ledger are in design/royal-frontier. Structural creation succeeded. Figma's Starter tool quota blocked final screenshot retrieval, so visual comparison inside Figma remains unverified. Native Godot images are reviewed separately.

App/backend version 0.9.4; Android version code 18. This change adds no database migration or production-data reset. It builds on the 0.9.3 starter-realm candidate. The v2 backend must be rolled out separately before the APK can enter a production kingdom.

Validation gates include backend checks and 13 unit tests, real PostgreSQL integration, GDScript import/parse, native fresh-account/clan flows, reconnect/lifecycle, bounded actual-render checks, Android export and APK signature verification. Starter-village, clan-region, council and HUD-free world images are captured from native API flows. CI publishes a unique candidate download after the authority and Android gates pass.

This is an installable review candidate. Physical Android installation/FPS, final production signing, production rollout, premium class-specific units, advanced battle choreography and final economy balance still need separate evidence. The candidate does not certify the whole game as production complete.
