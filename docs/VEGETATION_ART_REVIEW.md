# Painted LOD / HLOD art review

## Status, 2026-09-30

The built-in image generator failed twice with a network error. The user asked
to retry it later. No newly painted foliage assets have been generated or
accepted. The playable world continues to use its existing vegetation.

The review infrastructure is ready: `scenes/vegetation_art_review.tscn` reuses
the production island, deterministic 50,000-tree population, existing sunlight
and grass streamer. Four locations provide a forest-edge slope, autumn hillside,
distant ridge and coastal overlook. Sites are selected on real planted terrain;
camera positions are raised above terrain when necessary.

- 1–4 select the observation sites.
- B switches old / painted foliage when all four new atlases are available.
- Right-drag looks around; WASD / QE flies; Shift moves faster.
- Escape returns to the playable world.
- The HUD explicitly says that painted assets are pending until they exist.

The optional shader branch preserves a restrained intrinsic painting detail
through seasonal palette lighting. It is disabled on the existing assets.
This branch has compiled and rendered with the existing assets; its painting
strength and transparency still need visual validation after generation.

## Planned art assets

The two landscape references supplied by the user guide the brushwork, foliage
mass structure and edge density. Preserve the accepted close-tree silhouettes
and color relationships across representations.

Expected project paths:

- `assets/vegetation/painted_lod/painted_clumps_v1.png`: 2 x 2 transparent
  clump atlas, irregular gouache leaf clusters in muted neutral sage/olive.
- `painted_small_canopy_8view_v1.png`
- `painted_broad_canopy_8view_v1.png`
- `painted_upright_canopy_8view_v1.png`

Each canopy atlas has eight aligned azimuth views. A coherent option is to
bake the accepted Blender trees with the newly painted clump texture, producing
matching silhouettes and consistent detail across all directions. Evaluate
trunk presence, alpha coverage, mip behavior and direction changes in the game.
Forest-group HLOD remains a subsequent implementation step; the current branch
only prepares clump LOD and individual-tree distant impostor comparisons.

## Reproducible captures

```powershell
& 'D:\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tools/capture_vegetation_art_review.gd
```

The tool records `screenshots/vegetation_art_site_1_baseline.png` through site 4.
When new atlases exist it also records the matching `_painted.png` images.
Both variants share their exact camera, sunlight, planting and grass meshes;
LOD wind is disabled during capture. Measurements are saved to
`screenshots/vegetation_art_metrics.json`. Tree transforms are exported into
the ignored `.vegetation_art_build/` directory for a future exact forest-group
bake. The snapshots are real Godot Forward+ renders, not generated landscapes.

Initial observations: repeated clump shapes and tiers remain visible in the
middle distance; distant seasonal crowns lose internal contrast. These are
baseline findings. A new-versus-old aesthetic conclusion is pending generation.

## Image generation prompt used

Built-in `image_gen` mode; requested true transparency. Both attempts failed,
and CLI/API fallback has not been authorized.

The simplified retry requested a square 2 x 2 atlas with four separate broadleaf
clumps: a broad asymmetric oval, a taller irregular crown, a wide multi-lobed
cluster and a loose branched cluster. Muted sage/olive RGB around 110/130/90,
gentle intrinsic tone variation, gouache landscape brushwork, cohesive leaf
masses, small air gaps and wide transparent gutters. No trunks, directional
light, rim light, cast shadows, text, ground or checkerboard background.

After successful generation, save the original source and the exact prompt in
the project, then judge integration and art direction at all four sites before
making it the default.
