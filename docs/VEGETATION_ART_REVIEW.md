# Vegetation art review

## Current decision, 2026-10-01

The image-generation retry succeeded, and the painted clump atlas and three
matching eight-view canopies were compared at four real island viewpoints.
The user rejected the new version: the added internal detail made the overall
landscape more cluttered. The project continues with the stable original LOD.

The painted assets, exact prompt, integration source snapshots and comparison
captures are archived under `archive/painted_foliage_trials_2026-10-01/`.
A `.gdignore` keeps that directory outside Godot resource import.
The active shader and vegetation streamer are restored to their pre-trial
versions. No new painted textures remain at their runtime resource paths.

## Review controls

Run `scenes/vegetation_art_review.tscn` in Godot 4.7.2.
It uses the original close models, LOD clumps and distant single-tree impostors,
with the same production terrain, sunlight, deterministic planting and grass.

- 1–4: forest edge, autumn hillside, distant ridge, coastal overlook.
- Right-drag: look around; WASD / QE: fly; Shift: move faster.
- Escape: return to the playable world.

The review scene explicitly selects the original LOD. The former B toggle is
removed, so the rejected version cannot be activated from this scene.
The playable world's default also remains the original LOD.

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
