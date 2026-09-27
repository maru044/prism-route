# Prism Route — world and vegetation prototype

This Godot 4.6 Forward+ project now uses the complete Rhino island draft for a
first playable scale, driving and vegetation LOD test. It is still a prototype:
roads, final planting points, terrain chunks and production vehicle physics are
not implemented. Actual planting points will eventually be designed and
previewed in CAD; the current deterministic scatter only tests appearance and
rendering cost.

## Open and inspect

Open `project.godot` in Godot 4.6 and run `scenes/main.tscn`. W/S
accelerates or reverses the camper, A/D steers, Space brakes and R resets it to
the starting point. Right-drag orbits the third-person camera and the mouse
wheel changes its distance. L toggles the LOD stress comparison and V toggles
all streamed vegetation. Tab switches to the restored Ganyu vegetation grove;
Tab in that scene returns to the playable world. The basic single-tree and
biome scenes remain internal specialist tests rather than player-facing
shortcuts. The current world captures are
`screenshots/world_lod_drive_test.png` and
`screenshots/world_lod_drive_stress.png`; the earlier vegetation captures are
retained as art references.
Always judge changes in the actual Godot Forward+ scene, not solely in Blender.

The main scene uses the accepted small broadleaf and current grass. Dedicated
vegetation test scenes remain available for inspecting species, palettes and
composition without loading the island.

## Project layout

- `scenes/main.tscn` — entry point for the playable world LOD prototype.
- `scenes/world_lod_test.tscn` — complete island, camper and streamed
  vegetation test.
- `scenes/vegetation_grove_test.tscn` — restored full-scale vegetation test
  with Ganyu, the composed grove, seasonal trees, shrubs and dense grass.
- `scripts/camper_controller.gd` — intentionally simple kinematic third-person
  driving controller.
- `scripts/vegetation_lod_streamer.gd` — deterministic grass streaming, grass
  density LOD, tree chunking and distance culling.
- `scripts/world_lod_test.gd` — terrain collision, spawn selection,
  environment, diagnostics and captures.
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
- `assets/world/terrain/models/island_draft_rhino.gltf` — project copy of the
  complete `map.gltf` exported from Rhino. The higher 175.6 m surface is used
  for rendering and collision; its open boundary also generates the temporary
  coast cliff skirt at runtime.
- `assets/world/terrain/shaders/terrain_draft.gdshader` — temporary
  height/slope world-space terrain colors.
- `assets/vehicles/` — the simple 6.2 m camper placeholder and Blender source;
  `tools/build_camper_van_placeholder.py` rebuilds both.
- `assets/characters/` — character models. All character models in Prism Route
  use VRM as the standard runtime format so they share one import and animation
  pipeline.
- `scenes/characters/` — Godot character scene wrappers for imported VRM models.
- `docs/RESEARCH_CONTEXT.md` — current art direction, tested decisions and
  guidance for research tasks.

The editable Rhino document remains outside the Godot repository; its exported
draft is included so this scene stays reproducible. Editable sources for the
accepted trees and camper placeholder are included here.
The HDRI is included so the test scene remains runnable; check its source
license before any public redistribution of the repository.

## Current test, 2026-09-27

The playable island is approximately 2.57 × 2.99 km and 175.6 m high. The
first pass intentionally keeps the visual terrain as one complete mesh. It
creates a double-sided triangle collision at runtime because the open Rhino
surface may face away from downward physics rays. Its boundary is extended to
sea level as a generated rock skirt: low northern edges remain beach-height,
while elevated southern edges become visible cliffs.

Grass streams around the camper in 24 m MultiMesh chunks at approximately the
same 35 instances/m² used by the focused 63,000-instance sample. LOD0 uses the full
three-card grass up to 52 m; LOD1 retains a larger, one-in-five subset from 52
to 96 m; chunks are kept within 120 m so driving does not expose an empty ring.
After the cards end, the terrain shader continues the meadow with the same
world-aligned, feathered straw/green biome mask and restrained moving tonal
bands, so distant ground does not revert to a bare neutral surface.
Trees are scattered deterministically across the complete island, stored in
96 m chunks and culled after 900 m. For this first version trees rely on
Godot's imported automatic Mesh LOD. Low-contrast flower, cherry, gold-autumn
and orange/red-autumn palettes occur as groves rather than isolated noise. A
small number of the accepted broad and upright large trees punctuate those
coloured groves; the small broad-canopy tree remains the forest majority. A
deliberately cheap solid-canopy far
proxy was tested and rejected because it produced visible floating color
shapes against high terrain. A real multi-view tree impostor remains future
work rather than being represented by an incorrect placeholder.

The focused vegetation test's 24 m radius ground has 63,000 grass instances in 4 m MultiMesh chunks,
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

The focused vegetation scene uses 11 landscape placements of the small broad-canopy tree
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

Current complete-mesh counts are 1,956–2,108 triangles for the accepted
broadleaf trees, 4,796 for the birch and 4,620 for the cypress. These numbers
record the current assets rather than fixed targets or a conclusion that their
budgets are already appropriate. The birch is a usable first species asset. The
cypress is retained only as a silhouette study: its current modeling is not
accepted final art and should not be used as the visual reference for
production trees. Mesh density and LOD budgets will be evaluated again when
representative terrain and forest placements exist.

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
