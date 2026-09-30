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

The user accepted the subsequent continuous crown shading and
alpha-coverage-preserving mip derivatives as the new small-tree baseline.
All live entries, including `scenes/main.tscn`, the review and focused grove,
use this version directly. Near and middle
shading strengths are 0.62 and 0.35; the distant impostor keeps its original
shading. See `FOLIAGE_SIMPLIFICATION_RESULTS.md` for measurements and limits.

The old shading baseline, historical screenshots, A/B tools and comparison
source snapshots are archived in `archive/small_tree_baseline_2026-10-01/`.
Its `.gdignore` excludes these resources and scripts from Godot import.
The historical reproducible comparison commit is `9f6ff16`; the unfiltered
baseline before implementation is `f75fc7f`. Original PNGs and models needed
for rebuilding the accepted derivatives or shared by other trees remain as
source dependencies; they are not an alternate small-tree runtime version.

## Review controls

Run `scenes/vegetation_art_review.tscn` in Godot 4.7.2.
It uses the original close models, LOD clumps and distant single-tree impostors,
with the same production terrain, sunlight, deterministic planting and grass.

- 1–4: forest edge, autumn hillside, distant ridge, coastal overlook.
- Right-drag: look around; WASD / QE: fly; Shift: move faster.
- Escape: return to the playable world.

The review shows `ACCEPTED BASELINE`. Historical F/B switches are removed.

## Future direction

Preserve calm crown masses, restrained color and simple distant silhouettes.
Do not add more small leaf marks as a default solution to LOD appearance.
Any later refinement should first improve whole-crown shading, geometry
continuity and silhouette consistency at the existing four observation sites.

Forest-group HLOD remains unimplemented. The current distant cards are
individual-tree LOD2 impostors with spatial MultiMesh batching.

## Capture

`tools/capture_vegetation_art_review.gd` captures the four accepted-version views
as `screenshots/vegetation_art_site_1_accepted.png` through
`vegetation_art_site_4_accepted.png`, with wind frozen. Measurements are saved
in `screenshots/vegetation_art_accepted_metrics.json`.

Historical A/B captures and their tools remain in the small-tree archive.
To rerun the former comparison, use a separate checkout of `9f6ff16`; archived
scripts are reference snapshots rather than a standalone executable project.
