# CueDex AI Bell Logo

Production-oriented redraw of the selected `03-ai-bell.png` concept.

## Files

- `cuedex-ai-bell.svg`: primary two-color logo on warm off-white.
- `cuedex-ai-bell-appicon.svg`: macOS rounded-rectangle icon master with transparent outer corners and optical padding.
- `cuedex-ai-bell-monochrome.svg`: simplified one-color mark for menu-bar and template use.
- `AppIcon.appiconset/`: macOS PNG exports from 16 px through 1024 px.
- `MenuBarIcon.imageset/`: 18 px and 36 px template-image exports.
- `preview/primary-preview.png`: raster preview of the primary vector master.
- `preview/appicon-preview.png`: macOS rounded-rectangle icon preview.
- `preview/appicon-size-check.png`: rounded icon QA at representative sizes.
- `preview/menu-bar-preview.png`: monochrome template preview on white.
- `preview/size-check.png`: visual QA at representative sizes.

## Palette

- Graphite: `#111317`
- Completion blue: `#3D94FF`
- Cool off-white: `#F5F7FA`
- Border: `#E1E6ED`

The macOS AppIcon uses a high-visibility branded freeze-frame of CueDex's runtime breathing effect: four directional edge gradients plus four matched corner gradients, using `1.00` static intensity with a `1.80` icon-only visual gain. It preserves the runtime `0 / 0.42 / 1` stops while widening the band and strengthening the border/shadow for small-size recognition. The monochrome menu-bar asset intentionally omits the glow.

The project `AppIcon.appiconset` is generated from this geometry by `script/generate_app_icon.swift`. The SVG remains the source of truth for later optical refinements.
