# Godot 4.7.2 migration and product rendering review

Reviewed on 2026-09-29 against project commit `9ee66a6`. The production project remains on Godot 4.6.2 Forward+.

## Migration check

- Installed executable: `D:\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`; it reports `4.7.2.stable.official.ed1daf0bf`.
- Tested a detached Git worktree at `D:\Prism Route\tmp\godot-47-migration-check`, leaving the production checkout and its existing uncommitted screenshots intact.
- Initial editor import exposed three return-type parse errors in the bundled VRM add-on. Godot 4.7 now requires overrides of typed methods to return the inherited type. Adding `-> Error` and `return OK` to `_import_post` / `_export_post` in the two affected VRM scripts cleared the import errors in the test worktree. These changes have **not** been applied to the production project.
- `scenes/main.tscn` and `scenes/world_lod_test.tscn` ran in 4.7.2; a GPU capture of the world had no obvious visual regression. A single capture is insufficient to claim a performance change.
- `scenes/vegetation_grove_test.tscn` emitted inherited-node warnings for `GeneralSkeleton`, `Head`, `AnimationPlayer`, and `VRMSpringBoneController` in `scenes/characters/ganyu.tscn`. Its 4.7.2 GPU capture showed the character with both arms extended instead of the existing idle pose. The same scene emitted no such warnings under 4.6.2. This remains a migration blocker; the precise cause needs investigation before resaving or rebuilding the character scene.

## Product viewport check

- A 768 × 768 `SubViewport` with `own_world_3d`, Forward+, 4× MSAA, a metallic test mesh, and two `AreaLight3D` nodes rendered successfully on the NVIDIA RTX 5070 Ti. The rectangular lights produced distinct broad highlights. `AreaLight3D` is new in Godot 4.7 and is useful for a separate product inspection stage.
- A second test with a transparent refractive shell and an opaque blue inner mesh also rendered. The result did not reproduce the reference image's deep layered crystal/glass appearance. Godot's refraction remains a screen-space effect and cannot refract itself or other transparent materials; alpha-blended surfaces also have ordering and reflection limits. These are material/rendering constraints, not problems fixed by a version bump.
- Review captures are in `D:\Prism Route\review\`: `godot-472-product-stage-smoke.png`, `godot-472-glass-smoke.png`, `godot-472-world-lod.png`, and `godot-472-character-ganyu.png`.

## Decision and next step

Keep the main project on 4.6.2 for now. A separate 4.7.2 product viewer prototype is reasonable because it can use `AreaLight3D` without depending on the world scene. Before migrating the whole game, resolve the VRM inherited-node/animation issue, repeat character and world screenshots, and validate representative product models at the intended viewport size and frame budget. For transparent products, use a deliberate real-time approximation, or produce high-quality catalog images offline if the reference image's glass depth is a requirement.

## References

- [Godot 4.6 to 4.7 migration guide](https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.7.html)
- [Godot 4.7 release](https://godotengine.org/releases/4.7/)
- [AreaLight3D](https://docs.godotengine.org/en/4.7/classes/class_arealight3d.html)
- [StandardMaterial3D transparency and refraction](https://docs.godotengine.org/en/4.7/tutorials/3d/standard_material_3d.html)
- [3D transparency sorting limitations](https://docs.godotengine.org/en/4.7/tutorials/3d/3d_rendering_limitations.html)
