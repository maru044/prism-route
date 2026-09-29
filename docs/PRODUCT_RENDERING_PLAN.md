# Collectible product rendering study

## Goal and scope

Build a rotatable, self-contained product inspector in a Godot 4.7.2 Forward+
`SubViewport`. The current reference is the classic drop form with a clear outer
shell and blue gel core. This study does not depend on the island scene, roads,
vehicle scale, or world lighting.

## Current first pass

- `tools/build_product_preview.py` builds an editable Blender source, a runtime
  GLB, and a 2:1 OpenEXR virtual studio. The studio contains only soft rectangular
  lighting regions on a neutral base; no photographic walls or equipment.
- `scenes/product_preview.tscn` shows the imported product in its own 3D world.
  Its visible background is a flat light gray, while reflections and ambient
  lighting sample the synthetic EXR. Three `AreaLight3D` instances add direct
  rectangular highlights. Drag the viewport to inspect; Space toggles rotation.
- The Blender asset has separate clear shell, gel core, base, and bubble meshes.
  Godot applies independent materials. The gel shader uses translucent pale
  ice blue and slowly moving, locally denser blue regions. The bubble meshes
  remain separately animated and visible through the gel.
- `tools/capture_product_preview.gd` records front, side and later motion views
  from the real Forward+ renderer into `screenshots/`.

## Quality gates and next steps

1. **Shape and composition:** compare front, profile, tip, neck and base to the
   reference. Keep one continuous roundover on the tip and a stable, wide base.
2. **Glass and light:** tune EXR panel positions, widths and luminance while
   rotating the object. The shell should keep a transparent center, readable
   edges and controlled long highlights at every useful inspection angle.
3. **Gel motion:** judge whether the slowly drifting density regions read as
   suspended gel from all inspection angles. If they still look like surface
   marks, build a layered or volumetric treatment. Judge motion in video and
   at rest.
4. **Material variants:** only after the classic drop is accepted, reuse the
   preview stage for the elongated, faceted, double shell and thermal color
   concepts. Keep geometry and material variants separate from the stage.
5. **Performance:** measure frame time and memory at the intended inspector
   resolution while the main game is running. The isolated stage currently
   renders continuously for convenient testing.

## Known rendering limits

This is a first real-time approximation, not a physical glass simulation.
Godot's normal screen-space refraction cannot reliably sample another
transparent layer inside a clear shell, so the current shell uses a Fresnel
transparency shader and the core uses a translucent surface shader. The
changing areas of density approximate moving gel; they are not a physical
volumetric fluid simulation. More convincing internal depth, refraction and
liquid motion remain the main visual risks to resolve before calling the
product look final.

The source `.blend` sits under `source/.gdignore` so Godot imports the exported
GLB only. Rebuild with Blender 5.1.1 or later using:

```powershell
& 'D:\blender\blender.exe' --background --factory-startup --python tools/build_product_preview.py
```
