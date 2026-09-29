# Godot 4.7.2 migration and product rendering review

Reviewed and migrated on 2026-09-29. The main project now targets Godot 4.7.2 Forward+.

## Migration fix

The initial 4.7.2 import of the bundled VRM 2.5.1 add-on produced a plain glTF scene. Its `GLTFDocumentExtension` scripts lacked `@tool`, so the editor did not execute their import callbacks. The imported character therefore lost its `GeneralSkeleton` name, `AnimationPlayer`, and `VRMSpringBoneController`; the character scene rendered with both arms extended. Two material extension scripts also needed explicit `Error` returns because Godot 4.7 inherits typed return requirements for overrides.

The migration adds `@tool` to the VRM 0.0 and 1.0 import extensions, aligns two import callback signatures with `GLTFDocumentExtension`, and returns `OK` from the material callbacks. A fresh VRM 1.0 import in an isolated checkout now recreates `GeneralSkeleton`, `AnimationPlayer`, and `VRMSpringBoneController`. The migrated main project also loads all 45 character animations and renders the character in its normal pose.

## Validation

- Godot executable: `D:\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`, reporting `4.7.2.stable.official.ed1daf0bf`.
- Main-project editor import completed with exit code 0 and no script errors or warnings.
- Main, vegetation grove with VRM character, and world LOD scenes completed headless smoke tests with exit code 0 and no warnings.
- The VRM scene rendered on the NVIDIA RTX 5070 Ti using D3D12 Forward+. A capture is at `D:\Prism Route\review\godot-472-ganyu-repaired.png`.
- The world LOD scene rendered in the isolated checkout with no obvious visual regression. The earlier single frame is not a performance benchmark.
- No VRM 0.0 asset is present in this project, so that import path was not visually checked.

## Product viewport check

- A 768 × 768 `SubViewport` with `own_world_3d`, Forward+, 4× MSAA, a metallic test mesh, and two `AreaLight3D` nodes rendered successfully on the NVIDIA RTX 5070 Ti. The rectangular lights produced distinct broad highlights. `AreaLight3D` is new in Godot 4.7 and is useful for a separate product inspection stage.
- A second test with a transparent refractive shell and an opaque blue inner mesh also rendered. The result did not reproduce the reference image's deep layered crystal/glass appearance. Godot's refraction remains a screen-space effect and cannot refract itself or other transparent materials; alpha-blended surfaces also have ordering and reflection limits. These are material/rendering constraints, not problems fixed by a version bump.
- Review captures are in `D:\Prism Route\review\`: `godot-472-product-stage-smoke.png`, `godot-472-glass-smoke.png`, and `godot-472-world-lod.png`.

## Decision and next step

For the next product rendering step, test one representative model in the separate viewport at its target resolution and frame budget. Use a controlled real-time approximation for glass, or render catalog-quality images offline if the reference's layered crystal depth is required.

## References

- [Godot 4.6 to 4.7 migration guide](https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.7.html)
- [Godot 4.7 release](https://godotengine.org/releases/4.7/)
- [Running code in the editor](https://docs.godotengine.org/en/4.7/tutorials/plugins/running_code_in_the_editor.html)
- [AreaLight3D](https://docs.godotengine.org/en/4.7/classes/class_arealight3d.html)
- [StandardMaterial3D transparency and refraction](https://docs.godotengine.org/en/4.7/tutorials/3d/standard_material_3d.html)
- [3D transparency sorting limitations](https://docs.godotengine.org/en/4.7/tutorials/3d/3d_rendering_limitations.html)
