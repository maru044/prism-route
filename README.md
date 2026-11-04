# Prism Route — world and vegetation prototype

## 孤顶教堂性能与玻璃修复 · 2026-11-05

教堂铺装下已清除 43,484 个草实例并重烘焙 12 格；入口视角实测约 19.18 → 12.97 ms。五片玻璃改为通透彩玻璃，教堂原几何与用户树木保留。见 [修复记录、截图与验收](docs/church_performance_1105/README.md)。

**Agent 排障入口：** [场景性能排障指南](docs/SCENE_PERFORMANCE_TROUBLESHOOTING.md)，说明为什么新增建筑不会自动清理旧草缓存、如何定位瓶颈、局部重烘焙与验收。根目录 `AGENTS.md` 也已登记。

## 米家角色两批入库 · 2026-11-04

首批八重神子、雷电将军、芙宁娜、镜流、星见雅，第二批申鹤、夜兰、优菈、丽莎、凝光已完成无武器 VRM 导入、MToon、衣发物理和共享中性动作检查，现有角色共 14 个。
打开 `scenes/character_roster_review.tscn` 按 F6，或运行 `tools/run_character_roster_review.ps1`。
沿用同一个检查场景，菜单累计展示两批 10 个新模型；原动作预览器的角色选择包含全部 14 个角色。
基础动作统一使用正式甘雨的 A01 待机 / A05 步行 / A06 跑步。已修正预览骨盆抵消、A06 骨盆与循环接缝，并将跑步纳入验收；详见 [共享移动动作最终验收](docs/character_locomotion_1104/README.md)。历史共享走路样本不是地图 A05。
后续模型制作优先参考 [角色批量导入指南](docs/CHARACTER_BATCH_IMPORT_GUIDE.md)，含配置、编码与权重修复、物理链、重建命令和验收边界。

## 重要制作指南：MMD 动作 → 现有 VRM，2026-11-03

后续转换 MMD 动作优先参考 [MMD → VRM 制作指南](docs/MMD_TO_VRM_PRODUCTION_GUIDE.md)。
其中记录了最终重定向方法、头发/服饰实时物理、碰撞配置、踩坑经验、验收命令和批量制作规范。

**烘焙前先选片：** 双击 `tools/run_mmd_source_preview.cmd`，在独立 Blender 的“动作选片”侧栏直接看源 VMD。
已收录 86 个目录候选、212 条人体轨道，支持配套选择、播放和片段保留；见 [源动作选片器指南](docs/MMD_SOURCE_PREVIEW_GUIDE.md)。
当前选片优先级与需要制作的片段汇总，记录在 [选片 README](docs/motion_selection/README.md)。
最终独立验证场景为 `scenes/character_mmd_vrm_validation.tscn`，可复用角色为
`scenes/characters/keqing_mmd_vrm.tscn`；在 Godot 中打开测试场景后按 F6。

同一场景现已加入 **刻晴 + 甘雨的双人配套验证**，有动作列表、分类、共同时间轴和单角色诊断视图。
双人动作须按整组验收；见 [配套动作验证规范](docs/MMD_PAIRED_MOTION_VALIDATION.md)。

全库批量化前先读 [动作库批量移植调研与实施计划](docs/MMD_BATCH_FEASIBILITY_20261103.md)。
该报告覆盖全部 285 个 VMD，记录常规候选、特殊 IK、多人配套、资源成本和分阶段验收边界。

**已选动作库已导入 Godot**：11 组 KEEP、22 条共享角色轨道全部通过刻晴、甘雨、胡桃、花火检查；20 条新增、2 条复用，两个 MAYBE 暂不导入。
原验证场景默认打开已选库的 Loop 02；主列表每组只显示一次，提供人数筛选、整组/单角色查看和模型选择。
制作流程、物理复用、实测报告与后续增补方法见 [已选库重要指南](docs/MMD_SELECTED_LIBRARY_GUIDE.md)；共享机制见 [共享人形动作规范](docs/MMD_SHARED_HUMANOID_VALIDATION.md)。

## Accepted character material: MToon, 2026-10-26

F5 opens the current map directly with the accepted MToon appearance on all
19 Ganyu surfaces (the reviewed option 2 / B). The formal HUD has no shader
switcher or laboratory link. Source materials, animations and spring bones
are preserved. See [the adoption and validation record](docs/CHARACTER_MTOON_1026.md).

As of 2026-10-27, formal Ganyu materials use audited opaque/cutout paths so
submerged parts receive the existing water absorption and scattering. Blush
retains continuous transparency. See [the water integration record](docs/CHARACTER_WATER_1027.md).

Local moisture and gradual drying are also active in F5. Immersed height bands
retain restrained darkening and wet-film highlights, then dry over roughly 14 seconds.
The dry appearance matches the accepted MToon baseline. See [wetness validation](docs/CHARACTER_WETNESS_1027.md).

## Current game entry: map 1021, 2026-10-22

F5 opens `scenes/map_1021.tscn`, the current map with nineteen validation spawns,
character / camper switching, fixed tree placement, predictive 3D grass streaming,
and a transparent performance monitor at the bottom left. See the
[scene and asset guide](assets/world/current_map_validation/README.md).
The full-map mesh uses Git LFS; run `git lfs pull` after cloning.

End-of-October release materials and the itch.io upload-limit inquiry are tracked
in the [upload preparation plan](docs/ITCH_IO_UPLOAD_LIMIT_PLAN.md).

## Current Rhino model, 2026-10-18

Edit [map_current.3dm](../map/map_current.3dm). The scene has been cleaned and
organized by asset; file locations, retained sources and pending work are listed
in [the current model guide](docs/CURRENT_MODEL.md).

## 旧整图测试已移出项目 · 2026-11-04

9 月旧岛、1009、1012、Cliff B、旧道路投影和地形遮罩测试，以及历史 Rhino 试验稿，
现已移到 `D:/Prism Route/archive/legacy_world_tests_20261104/`。
专用场景、脚本、生成工具、模型和导入缓存均已移出；历史 README 与逐文件校验清单也在归档中。
共 224 个文件、约 325 MB；Git 中记录为移除，外部归档保留原文件。
项目内的 [归档清单](docs/legacy_world_archive_1104_manifest.json) 保存原路径、归档路径和 SHA-256。
现用的建筑材质、水着色器、车辆与植被共享代码保留，详见
[检查与归档记录](docs/LEGACY_WORLD_SCENE_AUDIT_1104.md)。

## Open and inspect

Open `project.godot` in Godot 4.7.2 and press F5 to run `scenes/map_1021.tscn`.
`scenes/main.tscn` is an alias for the same current world. Use C to switch between
the character and camper; use the current HUD for locations and free view.
Dedicated character, material and vegetation scenes remain available for F6 review.
Tab in the vegetation test returns to the current world.

## Project layout

- `scenes/map_1021.tscn` — the current playable world, continuously updated.
- `scenes/main.tscn` — alias for the current world.
- `scripts/map_1021.gd` and `scripts/world/` — current world loading and local architecture repairs.
- `assets/world/current_map_validation/` — current map, authored mask and baked grass.
- `scripts/map_1012_camper.gd`, `scripts/map_1012_vegetation.gd` and
  `scripts/vegetation_lod_streamer.gd` — shared runtime code retained by the current map.
- `assets/world/cliff_b_test/architecture.tres` and its texture dependencies — shared current architecture material.
- `assets/world/map_1012_test/water.gdshader` — shared current water fallback.
- `scenes/characters/`, `assets/characters/` — shared VRM actors, materials and motion libraries.
- `scenes/character_mmd_vrm_validation.tscn` — selected MMD motion review.
- `assets/vegetation/`, `assets/vehicles/` — shared vegetation and camper resources.
- `docs/CURRENT_MODEL.md` — current Rhino model and modeling records.

## Reimport generated assets

After Blender rewrites a GLB or a tool rewrites a texture, refresh Godot's
import cache explicitly before capturing results. On this Windows workspace,
use the same headless editor import command used throughout the vegetation
prototype:

```powershell
& '.current_map_build/runtime/Godot_v4.7.2-stable_win64_console.exe' `
  --headless --editor --path 'D:\Prism Route\prism-route' --import --quit
```

Running the game with ordinary `--headless` does not perform an editor import
and can therefore render a stale resource from `.godot/imported`.

## Character motion review

Open `scenes/character_motion_test.tscn` and press F6 to review all 42 downloaded CC0 clips on the current VRM character. The scene provides a searchable list, category filter, previous/next, pause, seek, playback speed, orbit camera, in-place viewing and an adjustable reference chair. See [the motion test guide](docs/CHARACTER_MOTION_TEST.md) for controls, rebuild instructions and known retargeting limitations. These are review candidates; the main game character animations are unchanged.
