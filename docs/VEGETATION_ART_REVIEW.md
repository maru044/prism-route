# Vegetation art review

## Current decision, 2026-10-01

The image-generation retry succeeded, and the painted clump atlas and three
matching eight-view canopies were compared at four real island viewpoints.
The user rejected the new version: the added internal detail made the overall
landscape more cluttered. The project keeps the original models and artwork.

The painted assets, exact prompt, integration source snapshots and comparison
captures are archived under `archive/painted_foliage_trials_2026-10-01/`.
A `.gdignore` keeps that directory outside Godot resource import.
No new painted textures remain at their runtime resource paths.

The subsequent authorized simplification test adds optional continuous crown
shading and alpha-coverage-preserving mip derivatives to the accepted small
tree. These are enabled in the playable world and focused grove. Near and middle
shading strengths are 0.62 and 0.35; the distant impostor keeps its original
shading. See `FOLIAGE_SIMPLIFICATION_RESULTS.md` for measurements and limits.

## Review controls

Run `scenes/vegetation_art_review.tscn` in Godot 4.7.2.
It uses the original close models, LOD clumps and distant single-tree impostors,
with the same production terrain, sunlight, deterministic planting and grass.

- 1–4: forest edge, autumn hillside, distant ridge, coastal overlook.
- F: original / filtered small trees; the initial selection is filtered.
- Right-drag: look around; WASD / QE: fly; Shift: move faster.
- Escape: return to the playable world.

Both F selections use the original tree geometry and artwork. The former B
toggle remains removed, so the rejected painted version cannot be activated.

## Future direction

Preserve calm crown masses, restrained color and simple distant silhouettes.
Do not add more small leaf marks as a default solution to LOD appearance.
Any later refinement should first improve whole-crown shading, geometry
continuity and silhouette consistency at the existing four observation sites.

Forest-group HLOD remains unimplemented. The current distant cards are
individual-tree LOD2 impostors with spatial MultiMesh batching.

## Capture

`tools/capture_vegetation_art_review.gd` captures the four old-version views and
records measurements in `screenshots/vegetation_art_metrics.json`.
The pre-trial baseline captures remain tracked in `screenshots/`.
Historical painted comparisons are retained only in the archive.

`tools/capture_small_tree_world_review.gd` captures matched original / filtered
views at the same four sites. The comparison is saved as
`screenshots/foliage_filtering_world_comparison.png`, original on the left.
`tools/capture_foliage_simplification.gd` and
`tools/summarize_foliage_simplification.py` reproduce the isolated diagnostic
comparison in `screenshots/foliage_filtering_small_tree_comparison.png`.
