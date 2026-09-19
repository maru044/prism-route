# Prism Route — vegetation rendering prototype

This Godot 4.6 Forward+ project is a small, runnable test scene for the game's
stylized grass, tree, wind and sky. It is **not** the full game or the Rhino
terrain. The prototype deliberately uses a circular ground and one tree so
rendering decisions can be judged in-engine.

## Open and inspect

Open `project.godot` in Godot 4.6 and run the main scene, or open
`scenes/vegetation_test.tscn`. Right-drag / A,D rotates the camera; mouse wheel
/ W,S changes distance. The two curated captures are
`screenshots/vegetation_test.png` and `screenshots/vegetation_test_top.png`.
Always judge changes in the actual Godot Forward+ scene, not solely in Blender.

## Project layout

- `scenes/` — Godot scene files.
- `scripts/` — scene generation and orbit camera scripts.
- `assets/vegetation/models/` — the current grass and tree GLBs.
- `assets/vegetation/textures/` — mostly flat-color cutout textures.
- `assets/vegetation/shaders/vegetation_wind.gdshader` — foliage lighting,
  grass wind field and tonal wave.
- `assets/environment/hdri/` — the Rosendal Park Sunset Pure Sky panorama.
- `docs/RESEARCH_CONTEXT.md` — current art direction, tested decisions and
  guidance for research tasks.

The original Rhino terrain and Blender source files live outside this small
Godot repository. Do not assume they are available to a GitHub-only reader.
The HDRI is included so the test scene remains runnable; check its source
license before any public redistribution of the repository.

## Current test, 2026-09-19

The 24 m radius ground has 63,000 grass instances in 4 m MultiMesh chunks,
preserving the density of the earlier 8 m / 7,000-instance test. One grass
instance has three crossed cards with double-sided geometry, approximately
0.83–1.10 m tall after instance scaling. The tree crown uses 480 foliage
cards. The grass color is restrained straw yellow; the underlying ground is a
slightly darker and greyer related hue (`#968A55`).

The grass uses one continuous world-space noise field for small vertex sway
and moving light/dark wind bands. A separate slow temporal noise modulates the
overall wind intensity. See `docs/RESEARCH_CONTEXT.md` for the exact tested
choices and rejected visual approaches.
