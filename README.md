# Prism Route — vegetation rendering prototype

This Godot 4.6 Forward+ project has one active scene for testing the game's
stylized grass, trees, wind, sky, color transitions and landscape composition.
It is **not** the full game or the Rhino terrain. Actual game planting points
will be designed and previewed in CAD; these positions only test the look.

## Open and inspect

Open `project.godot` in Godot 4.6 and run the main scene,
`scenes/main.tscn`. WASD moves freely across the scene, Q/E moves vertically,
Shift accelerates movement, right-drag freely looks in every direction, and
the mouse wheel moves along the view direction. The current captures are
`screenshots/vegetation_grove.png`,
`screenshots/vegetation_grove_top.png`, and
`screenshots/vegetation_grove_ground.png`.
Always judge changes in the actual Godot Forward+ scene, not solely in Blender.

The scene uses the accepted broadleaf baselines, current species studies and
the current grass.
An uneven back/right grove, smaller groups, a continuous grass bay and two
larger seasonal trees test spacing and negative space. The root inspector exposes grass, tree and ground
colors, boundary position, transition width, contour warp and per-blade color
overlap. Older scene files were removed; earlier screenshots remain as visual
references, and the v8 tree model remains available as an asset.

## Project layout

- `scenes/main.tscn` — the only active Godot scene.
- `scripts/` — scene generation and orbit camera scripts.
- `assets/vegetation/models/` — the current grass, shrub and tree GLBs, including
  the v8 regression baseline, accepted broadleaf trees and species studies.
- `assets/vegetation/source/` — editable Blender sources for the current
  vegetation models (excluded from Godot import).
- `tools/build_vegetation_assets.py` — deterministic Blender asset generator.
- `assets/vegetation/textures/` — mostly flat-color cutout textures.
- `assets/vegetation/shaders/vegetation_wind.gdshader` — foliage lighting,
  grass wind field, tonal wave and optional foliage palette.
- `assets/vegetation/shaders/biome_ground.gdshader` — ground palette using the
  same world-space boundary as the grass and tree shader.
- `assets/environment/hdri/` — the Rosendal Park Sunset Pure Sky panorama.
- `docs/RESEARCH_CONTEXT.md` — current art direction, tested decisions and
  guidance for research tasks.

The original Rhino terrain and earlier Blender sources live outside this small
Godot repository; editable sources for the accepted trees are included here.
The HDRI is included so the test scene remains runnable; check its source
license before any public redistribution of the repository.

## Current test, 2026-09-27

The 24 m radius ground has 63,000 grass instances in 4 m MultiMesh chunks,
preserving the density of the earlier 8 m / 7,000-instance test. One grass
instance has three crossed cards with double-sided geometry, approximately
0.83–1.10 m tall after instance scaling. The tree crown uses 480 foliage
cards. The grass color is restrained straw yellow; the underlying ground is a
slightly darker and greyer related hue (`#968A55`).

Stable tree assets use descriptive names. `tree_small_broad_canopy.glb` is the
accepted approximately 6 m broad-crown tree formerly tested as v10. It retains
240 crossed-card pairs (480 cards total), inner fill, the v11 texture and one
straight trunk. `tree_medium_broad_clustered_canopy.glb` is the accepted large
spreading broadleaf baseline. `tree_medium_upright_asymmetric_canopy.glb` is
the accepted approximately 16 m, 30-group upright baseline with a low skirt,
unequal shoulders and offset apex. Numbered experiments and the former layered
upright model have been removed from the asset library.

The grass uses one continuous world-space noise field for small vertex sway
and moving light/dark wind bands. A separate slow temporal noise modulates the
overall wind intensity. See `docs/RESEARCH_CONTEXT.md` for the exact tested
choices and rejected visual approaches.

The current scene uses 11 landscape placements of the small broad-canopy tree
in an 8-tree main group, a 2-tree back-left group and one right-edge tree.
Four small trees form the A3 flower/autumn palette study; the accepted large
spreading tree is the cherry-flower test and the upright tree is the orange
autumn test. Grass uses MultiMesh custom data for per-blade color overlap;
tree foliage uses per-instance shader uniforms. This only tests appearance,
not large-world placement, LOD or forest performance at production scale.

The first species-expansion study adds three birches, three columnar cypresses
and one four-plant rounded shrub-ball group.
The birch is a separate 24-group, 1,152-card model with a restrained pale bark
texture; the cypress is a separate 28-group, 1,108-card model whose foliage
reaches close to the ground. The shrub ball uses five independently pivoted
Y-billboard lobes. Each lobe depicts a complete porous leaf mass rather
than one leaf or a small sprig; it rotates around its own center, so the shrub
keeps parallax without exposing fixed crossed planes. Generated texture art
contributes alpha silhouettes only:
`tools/prepare_species_textures.py` replaces all RGB with controlled flat
colors so lighting remains in Godot, and can recover alpha when a generator
has painted a neutral checkerboard background.

Current complete-mesh budgets are 1,956–2,108 triangles for the accepted
broadleaf trees, 4,796 for the birch and 4,620 for the cypress. These are
reasonable near LOD0 budgets; large forests will still require spatially
chunked MultiMeshes, distance LODs and eventual tree impostors because alpha
overdraw matters more than raw triangle count. The birch is a usable first
species asset. The cypress is retained only as a performance-valid silhouette
study: its current modeling is not accepted final art and should not be used as
the visual reference for production trees.

## Reimport generated assets

After Blender rewrites a GLB or a tool rewrites a texture, refresh Godot's
import cache explicitly before capturing results. On this Windows workspace,
use the same headless editor import command used throughout the vegetation
prototype:

```powershell
& 'D:\Godot\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' `
  --headless --editor --path 'D:\Prism Route\prism-route' --import --quit
```

Running the game with ordinary `--headless` does not perform an editor import
and can therefore render a stale resource from `.godot/imported`.
