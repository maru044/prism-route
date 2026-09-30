# Painted LOD / HLOD art review

## Status, 2026-10-01

The built-in image generator succeeded on retry. Its original transparent
1254 x 1254 clump atlas is preserved as
`assets/vegetation/painted_lod/painted_clumps_v1.png`. The exact successful
prompt and reference paths are in that directory's `GENERATION.md`.

Blender baked three matching 1536 x 768 eight-direction canopy atlases from
the accepted small, broad and upright tree sources, with the painted clump
image substituted for their foliage texture. The tree geometry, UVs and source
Blender files are retained. Lighting is supplied by Godot, not baked sunlight.
All four new textures have mipmaps and alpha border correction enabled.

The painting branch uses alpha from the new image, normalizes its intrinsic
brightness against its own linear luminance, and retains the original palette
and lighting. Green trees use the alpha-weighted opaque average of their old
texture as their base color: reading the old texture outside its silhouette
had caused black edges during initial integration. The directional atlas index
is rounded before row selection: perspective interpolation around integer row
boundaries had caused horizontal holes in the first painted captures.
Both issues were corrected before the final captures.

The playable world still defaults to the existing vegetation. The review scene
starts with painting enabled and provides an immediate B toggle. This is an
art study, with no change to the accepted close tree meshes.

## Inspect in Godot

Run `scenes/vegetation_art_review.tscn` in Godot 4.7.2 Forward+.
It reuses the production island, deterministic 50,000-tree population,
existing sunlight and grass streamer. Four locations are selected on real
planted terrain; cameras are raised above terrain where necessary.

- 1–4: forest edge, autumn hillside, distant ridge, coastal overlook.
- B: switch original / painted foliage.
- Right-drag: look around; WASD / QE: fly; Shift: move faster.
- Escape: return to the playable world.

## Aesthetic comparison

The final comparison is `screenshots/vegetation_art_comparison.png`:
original on the left, painted on the right, one observation site per row.
These are actual Godot renders with the same camera, planting, grass and sun.

| View | Observation |
| --- | --- |
| Forest edge | Close geometry dominates, so the change is modest. The distant seasonal crowns gain internal texture. |
| Autumn hillside | Brushwork breaks up the flat green and coral clump patches. Existing small-tree card tiers and gaps remain visible from above. |
| Distant ridge | Yellow and pink crowns have more leaf-mass depth while preserving their large color areas. The direction-index fix removes the new horizontal holes. |
| Coastal overlook | The distant forest band is less uniformly smooth. Tree repetition and separate spherical crowns still limit the overall painted landscape effect. |

The new images improve the foliage surface, especially seasonal trees, but
cannot solve crown layout, planting density or a mismatch between LOD geometry
on their own. More detailed brush marks are not always better at very long
distance. Keep restrained painting contrast and simplify detail with distance.
The reference landscapes also rely on connected forest masses and designed
composition, which this deterministic scatter does not yet reproduce.

This round covers clump LOD1 and individual-tree eight-view LOD2 impostors.
Forest-group HLOD has not been implemented; spatial MultiMesh batching is not
a forest-group proxy. A subsequent study should bake connected forest groups
from the exact recorded planting, simplify their internal texture, and compare
transitions and silhouettes at these same observation sites.

## Reproduce

```powershell
& 'D:\blender\blender.exe' --background --factory-startup --python tools/build_painted_canopies.py
& 'D:\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --editor --quit --quiet
& 'D:\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tools/capture_vegetation_art_review.gd
```

The capture tool records eight full-resolution baseline/painted images and
assembles the comparison sheet. LOD wind is disabled; existing close foliage
wind still runs, so tiny close-leaf differences are not painting changes.
Measurements are saved in `screenshots/vegetation_art_metrics.json`.
Both variants used identical draw counts at each site (653, 491, 568, 463).
Single-frame FPS readings are not a performance benchmark. Painting adds four
textures with mipmaps and has not been validated with sustained GPU profiling.

Tree transforms are exported into the ignored `.vegetation_art_build/`
directory for an exact forest-group bake. Blender exits normally, Godot's
headless import succeeds, and all eight final screenshots render without
reported shader or script errors on D3D12 Forward+ / RTX 5070 Ti.
