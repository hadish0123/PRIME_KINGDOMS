# PRIME KINGDOMS / Royal Dawn

The 0.9.5 interface pairs ivory and champagne panels with forest ink, sage accents
and the original crown-and-keep identity. Native controls share semantic text
colors, illustrated icons, focus/hover/pressed/disabled states and scalable skins.
Building plates are original editable vector architecture, rather than generic
castle photos. The native 3D scene separately uses cream plaster, warm tile roofs,
sage glass, colored shutters, planted window boxes and sheltered entries.

## Figma status

The existing file is https://www.figma.com/design/ENUteLxvRgApkWKUmrYQ5w.
It remains the previously created Royal Frontier 0.9.4 design. During this
milestone, `use_figma` rejected even the initial inspection with the Starter
MCP call-limit message. No Royal Dawn write executed. The connected account
reports a Starter plan. Do not describe the live file as updated or verified.

`figma-import.js` is a resumable source importer for the existing authorized file
after that quota is available. Its JavaScript syntax is checked; execution,
editable-layer inspection, Figma rendering and component-layout fidelity still
require a successful Figma session. It creates a dedicated Royal Dawn page,
semantic color variables, artwork components, six button states and native text
layers without modifying the previous Royal Frontier page. A supplied world
image hash must refer only to `village-world.png`, which contains no interface.
Never substitute a full-screen UI bitmap for the native layers.

## Reproducible delivery

- `tokens.json`: shared palette, type, spacing and viewport specifications.
- `assets.json`: exact original artwork checksums and provenance.
- `../../client/assets/ui/dawn`: SVG skins, brand crest, icons and building plates.
- `../../tools/assets/build_dawn.py`: original vector authoring source.
- `../../client/tests/ui_design_snapshot.gd`: actual visible native layout, text,
  artwork references, clipping rectangles and server-populated clan membership.
- `../../tools/assets/package_dawn.py`: packages all 17 layout exports, editable
  SVG overlays, source files, licensed fonts and separately labeled native PNGs.

Run the existing native kingdom and presentation tests before packaging. The
kingdom test captures all 15 council sections from a disposable authenticated API
and checks the layouts at three viewport sizes. The presentation test captures
login/settings and checks the semantic body/status palette at 4.5:1 or higher
against the shared light surface. The design ZIP is a release asset; generated
screenshots, SVG layouts and compiled outputs stay out of git.

The SVG overlays retain text and vector paths and can be edited as source or
imported as vector artwork. Their wrapped text is a portable approximation of
native font metrics. Use the JSON layouts and the importer for semantic Figma
text/components; use the native PNGs to review actual game rendering. Preview
images are evidence, not editable interface substitutes.

Local source generation:

```sh
python3 tools/assets/build_dawn.py
python3 tools/assets/check_ui.py
node --check design/royal-dawn/figma-import.js
python3 tools/assets/package_dawn.py
```

For import, supply the layout JSON array and the source SVG map keyed by
`res://assets/ui/dawn/<filename>.svg`, plus any referenced existing heraldry SVGs.
Invoke `importRoyalDawn(tokens, layouts, svgSources, worldImageHash)` through the
authorized Figma plugin context after reading the Figma use/design/library skills.
