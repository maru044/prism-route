# 两处地形接缝修补 · 2026-11-02

已保存至 `D:/Prism Route/map/map_current.3dm`，并于 2026-11-03 接入正式游戏场景 `scenes/map_1021.tscn`。

- 东侧：沿弧形岸坡补齐接缝，并用连续 SubD 衔接原有高差。
- 西侧：补齐缺失的三角岸坡，向浅水方向平缓收口。
- 图层：`地形::丘陵与局部衔接::局部修补_1102`。两块均为有效、封闭的原生 SubD，可独立编辑或移除。
- 命名视图：`TerrainRepair_East_1102`、`TerrainRepair_West_1102`。

`east_final.png`、`west_final.png` 为第一阶段模型视口；`terrain_repairs.3dm` 包含最终两块补片及随后调整的滨水地面，共三个对象，供后续导入使用。未复制整份历史模型。

`model_report.json` 记录最终对象 ID、包围盒和检查结果。原有 1456 个对象的几何 CRC 和属性均未改变；两处末端贴合点的 SubD 细分曲面高于旧地形约 0.44 m、0.30 m。

`edge_constraints.json`、`sample_request.json`、`control_samples.json` 是测量输入，`control_nets.json` 是最终控制网。离线脚本 `tools/prepare_terrain_seams_1102.py` 可重算控制网；`tools/rhino_terrain_seams_1102.py` 用于在 Rhino 中生成补片，已有同名补片时禁止重复创建。

## 滨水场地接缝微调

随后按用户选中的滨水地面 `e7a0e133-f284-4cd4-8796-349bb8638efc` 修整其外侧与岸带的衔接：将外缘向岸带内部延伸约 12 m，通过约 35 m 的局部过渡范围消化高差，消除暴露的竖直台坎。与内侧地面相接的原始边界 1、2、10 保持原曲线，避免引入另一条内侧接缝。最终采用两块边界曲面封闭为有效实体，几何内存约 1.17 MiB。没有保留高密度试算模型。

`walk_seam_final.png` 为该阶段视口，`walk_seam_profile.json` 为测量输入，`walk_seam_report.json` 为原生检查结果：258 个外缘检查点均落在相邻岸带内部或与之齐平。38 条截面检查包含原场地范围之外的临水采样点，不能将外围无地面采样解读为实体存在孔洞。该阶段其余 1457 个对象的几何及属性未变。最新实机检查见下。

`tools/rhino_lakeside_walk_seam_1102.py` 记录最终曲面构建方法，避免使用自适应空间变形生成大量多余控制点。

## 正式游戏、草地与树木 · 2026-11-03

通过 `assets/world/terrain_repairs_1103/terrain.glb` 增量加载三个 Terrain 网格，共 254,132 个三角形。基础地图中旧的滨水地面同 ID 网格及其碰撞被移除；新网格使用现有地形材质、连续三角面碰撞和原有种植查询层，并接入水面反射。基础大地图 GLB 和其他建筑资源未重写。

实际角色穿越暴露出东侧 SubD 在旧 NURBS 岸墙边缘约 1 m 的下沉。已在原补片的中央平滑抬起控制网，保留埋入旧地面的外侧边缘，消除这个卡点。原生主地图、最终组件与游戏导出均已同步。`native_import_state_1103.json` 记录最终三个原生对象。

草地使用原有生产采样器、随机种子、模型和根缓存格式，重烘焙 621 个完整受影响分块，共 15,446,160 片草；这些完整分块也包含补片附近未移动地面的草。压缩文件约 71.7 MiB，覆盖原缓存对应分块，不改变全局烘焙及其他局部缓存。16 个分块的根缓存重建与原生成缓冲逐字节一致，重新加载后检查全部 621 个文件哈希，抽样 260 个草根的最大地面误差约 0.000008 m。

检查了 485 棵受影响候选树，其中 439 棵写入高度覆盖（369 棵升高、70 棵降低）。只改变高度和所属支撑表面；X/Z、朝向、缩放、树种、色板、删除记录均保留。重新加载后有效树木总数保持 19,328。最终各阶段调整树木的最大地面误差约 4.02 cm，小于落地计划的 8 cm 微小变化容差；原有人工布置仍可通过 F4 继续编辑。`tree_grounding_report.json` 记录前后存档哈希及逐树高度变化。

`game_verification.json`：四条关键地形接缝路线由正式角色控制器双向穿越，共八次，均无卡住、空中或失去地面支撑帧。路线在正式世界几何中检查，未加载树干碰撞；检查范围为补片与岸带衔接，不包含范围外已有的沥青路沿。137 个其他资源的哈希保持一致，未调整树木的记录亦保持一致。

`game_review.json`：正式大世界完整加载植物、草地和水面反射后检查通过。实机截图为 `waterfront_game.png`、`east_game.png`、`west_game.png`。启动 `tools/run_terrain_repairs_1103.ps1` 可直接从正式入口预览滨水接缝；普通 F5 仍从原出生点开始。

复现顺序：Rhino 中执行 `tools/rhino_export_terrain_repairs_1103.py` 的 prepare/export_one/finish；运行 `tools/build_terrain_repairs_1103.py`，Godot 导入资源；`prepare_terrain_repair_trees_1103.gd` 生成落地计划，`apply_terrain_repair_trees_1103.py` 校验存档后原子写入；`bake_terrain_repair_grass_1103.gd` 重建局部缓存；最后执行 `verify_terrain_repairs_1103.gd` 和 `review_terrain_repairs_1103.gd`。导出配置包含局部高度场及草缓存，避免打包后缺失。
