# Prism Route — vegetation rendering prototype

This Godot 4.6 Forward+ project contains small, runnable tests for the game's
stylized grass, trees, wind, sky and palette transitions. It is **not** the
full game or the Rhino terrain. The accepted single-tree baseline remains
separate from the new forest color experiment.

## Open and inspect

Open `project.godot` in Godot 4.6 and run the main scene, or open
`scenes/vegetation_test.tscn`. Right-drag / A,D rotates the camera; mouse wheel
/ W,S changes distance. The current captures are
`screenshots/vegetation_test_refined.png` and
`screenshots/vegetation_test_refined_top.png`.
Always judge changes in the actual Godot Forward+ scene, not solely in Blender.

The scene currently opens with a conservative v8-derived refinement. The
unchanged v8 baseline remains in `assets/vegetation/models/`; pass
`--baseline-tree` as a Godot user argument to load it instead. Its original
captures remain at `screenshots/vegetation_test.png` and
`screenshots/vegetation_test_top.png`.

Open `scenes/vegetation_biome_test.tscn` for the separate grove experiment.
It uses the same grass and tree meshes to test dry yellow to muted green grass,
a shared ground transition, and differently tinted tree crowns. Its captures
are `screenshots/vegetation_biome.png` and
`screenshots/vegetation_biome_top.png`. The palette is a test, not an accepted
art-direction decision. In the scene inspector, the root node exposes grass,
tree and ground colors, boundary position, transition width, contour warp and
per-blade color overlap.

## Project layout

- `scenes/` — Godot scene files.
- `scripts/` — scene generation and orbit camera scripts.
- `assets/vegetation/models/` — the current grass and tree GLBs, including the
  v8 baseline and its refined v10 test.
- `assets/vegetation/source/` — editable v10 Blender source (excluded from Godot import).
- `tools/build_vegetation_assets.py` — deterministic Blender asset generator;
  run with `--tree-refined-v10` after Blender's `--` separator to rebuild v10.
- `assets/vegetation/textures/` — mostly flat-color cutout textures.
- `assets/vegetation/shaders/vegetation_wind.gdshader` — foliage lighting,
  grass wind field, tonal wave and optional foliage palette.
- `assets/vegetation/shaders/biome_ground.gdshader` — ground palette using the
  same world-space boundary as the grass and tree shader.
- `assets/environment/hdri/` — the Rosendal Park Sunset Pure Sky panorama.
- `docs/RESEARCH_CONTEXT.md` — current art direction, tested decisions and
  guidance for research tasks.

The original Rhino terrain and earlier Blender sources live outside this small
Godot repository; the editable v10 tree source is included here.
The HDRI is included so the test scene remains runnable; check its source
license before any public redistribution of the repository.

## Current test, 2026-09-20

The 24 m radius ground has 63,000 grass instances in 4 m MultiMesh chunks,
preserving the density of the earlier 8 m / 7,000-instance test. One grass
instance has three crossed cards with double-sided geometry, approximately
0.83–1.10 m tall after instance scaling. The tree crown uses 480 foliage
cards. The grass color is restrained straw yellow; the underlying ground is a
slightly darker and greyer related hue (`#968A55`).

The accepted v10 prototype starts from the v8 layered crown, retaining its 240 crossed-card
pairs (480 cards total), inner fill, v11 texture, single straight trunk and
lighting. It gently broadens the silhouette and enlarges each foliage card by
25% in both dimensions to create more overlap. It is the current test-scene
baseline, not a final production asset; grass and lighting remain unchanged.

The grass uses one continuous world-space noise field for small vertex sway
and moving light/dark wind bands. A separate slow temporal noise modulates the
overall wind intensity. See `docs/RESEARCH_CONTEXT.md` for the exact tested
choices and rejected visual approaches.

The grove uses the same 63,000 grass instances and a jittered 6 × 6 layout of
the v10 tree, excluding edge positions. Grass uses MultiMesh custom data for
per-blade overlap in the transition; tree foliage uses per-instance shader
uniforms. Neither requires new textures or species meshes. This only tests
color variation and spatial transitions, not large-world placement, LOD or
forest performance at production scale.
