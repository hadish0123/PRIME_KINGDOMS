# Royal Frontier 0.9.4

[Editable Figma file](https://www.figma.com/design/ENUteLxvRgApkWKUmrYQ5w)

| Screen | Node | Purpose |
| --- | --- | --- |
| Village HUD | 5:10 | Settlement, profile, five resources, stage guide and navigation |
| Royal Council | 5:110 | Construction card, requirements, costs and actions |
| Clan Region | 5:244 | Clan identity, editable plots, continuous border and region action |

`tokens.json` documents the shared palette, typography, spacing and inventory.
`assets.json` pins the original SVG frame checksums used by the asset pipeline.
`figma-state.json` records the actual created nodes, collections, component IDs,
properties, image hashes and structural inspection returned by Figma.

The JavaScript files are creation blueprints for Figma's supported Plugin API:
foundations first, artwork in bounded batches, then composed screens. Transport
placeholders such as `__STATE__`, `__ASSET_BYTES__` and `__WORLD_BYTES__` are
substituted before execution. Do not run these files in Node or execute them
against the existing page unchanged: doing so would duplicate nodes. Consult
the ledger and reuse existing IDs for later edits.

Existing licensed game artwork is placed only as discrete image assets. The
3D world background is captured with the native interface hidden. All counters,
navigation, buttons, headings, labels, cards and clan plot geometry are editable.
No interface screenshot is used as the delivered design.

Figma accepted all three screens and returned their layer/font inventory.
Its Starter tool-call quota then blocked screenshot retrieval. Final Figma
visual QA remains pending; no pixel-perfect match is claimed. Native rendering
and layout are checked through Godot and the versioned CI evidence.

The Godot client uses the palette in `scripts/royal_ui.gd` and original scalable
frames in `assets/ui/frontier`. Runtime world state always comes from the API;
Figma's example values are design content only.
