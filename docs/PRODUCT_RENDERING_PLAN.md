# Collectible product rendering study

## Goal and scope

Build a rotatable, self-contained product inspector in a Godot 4.7.2 Forward+
`SubViewport`. The accepted baseline is the classic drop form with a clear outer
shell and blue gel core, now joined by three shape studies. This study does not depend on the island scene, roads,
vehicle scale, or world lighting.

## Current shape and material study (2026-09-30)

- `tools/build_product_preview.py` builds an editable Blender source, a runtime
  GLB, and a 2:1 OpenEXR virtual studio. The studio contains only soft rectangular
  lighting regions on a neutral base; no photographic walls or equipment.
- `scenes/product_preview.tscn` shows the imported product in its own 3D world.
  Its visible background is a flat light gray, while reflections and ambient
  lighting sample the synthetic EXR. Three `AreaLight3D` instances add direct
  rectangular highlights. Drag the viewport to inspect; Space toggles rotation.
- The shape selector offers the accepted classic drop, a progressive five-bead
  chain with a round handle, an elongated oval plug, and a continuous three-lobe
  plug. The material selector independently switches clear shell / moving gel,
  pale frosted silicone, and polished steel. Reset view restores the front angle
  and automatic rotation. New shapes fit the same display height; these units
  describe concept proportions, not finished product dimensions.
- `tools/build_product_variants.py` creates separate `.blend` and `.glb` assets
  for the three new forms. The elongated form has an oval cross section. The
  three-lobe form uses a continuous rounded profile; the chain has separate
  shell and core meshes per bead, with short rounded connectors.
- The Blender asset has separate clear shell, gel core, base, and bubble meshes.
  Godot applies independent materials. The gel shader uses translucent pale
  ice blue and slowly moving, locally denser blue regions. The bubble meshes
  remain separately animated and visible through the gel.
- Each new core maps its local coordinates into the accepted density field,
  with staggered motion phases for the beads. The baseline shader defaults and
  its pale / dense colors remain unchanged. Thin connectors and the handle use
  slightly stronger face opacity so they remain readable in the clear preset.
- Opaque presets hide the cores and bubbles. Silicone uses a pale blue standard
  material with roughness 0.62; steel uses metallic 1.0 and roughness 0.11.
  These are appearance comparisons, without silicone scattering or a physics
  simulation. All four shapes can use all three presets.
- `tools/capture_product_preview.gd` records front, side and later motion views
  from the real Forward+ renderer into `screenshots/`.
- `tools/capture_product_variants.gd` captures nine new front comparisons,
  three clear side views, and a classic regression after returning from the
  opaque presets. It also assembles a labeled comparison using actual render
  textures, at `screenshots/product_variants_comparison.png`.
- Verified in Godot 4.7.2 on D3D12 Forward+ / RTX 5070 Ti: import and capture
  completed without script or shader errors. The front and side captures show
  connected geometry and readable opaque highlights. Clear side views still
  have weaker internal depth than front views; the current approximation is
  suitable for further art review, not a final KeyShot-equivalent result.

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
4. **Shape and material review:** review the nine comparisons in the inspector,
   especially thin transparent connectors and oval side profiles. Refine the
   three new shapes before extending to faceted, double shell or thermal color
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
& 'D:\blender\blender.exe' --background --factory-startup --python tools/build_product_variants.py
```

Run the isolated inspector or capture the comparisons with the console build:

```powershell
& 'D:\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --path . res://scenes/product_preview.tscn
& 'D:\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tools/capture_product_variants.gd
```
