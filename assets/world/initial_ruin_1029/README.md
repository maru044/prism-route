# 初始三角遗迹 · 2026-10-29

来自当前 Rhino `map_current.3dm` 中的 `建筑::初始三角遗迹`。只读导出 328 件对象、6,904 个三角形；原全图 GLB 保持原样。本目录是正式 F5 地图加载的附加资产。

- `ruin.glb`：保留源对象 GUID 的独立建筑网格。
- `manifest.json`：坐标转换、召唤台锚点、局部种植避让、碰撞抽样及源对象记录。
- Rhino `(x,y,z)` → Godot `(x-1450,z,1150-y)`；所有网格已在全图坐标内，实例根节点保持原点。
- 构建：`tools/rhino_export_initial_ruin_1029.py` → `tools/build_initial_ruin_1029.py`。
- 运行：`scenes/world/initial_ruin.tscn`；材质与碰撞由 `scripts/world/initial_ruin.gd` 按对象元数据建立。
- 刻晴来自现有 VRM 和 A01 待机动作，以独立 NPC 实例放置；源模型、动作及材质资源不作覆盖。

详细操作与验证见 `docs/INITIAL_RUIN_GODOT_1029.md`。

## 平滑台阶碰撞

`walk_collision.glb` / `walk_collision.json` 为独立角色碰撞层资产。六个 `-colonly` 节点由参数化台阶配方派生并实际建模保存于 Rhino；Godot 导入为静态碰撞体，不包含显示网格。原始建筑 GLB 和种植 manifest 保留。详见 `docs/INITIAL_RUIN_SMOOTH_COLLISION_1029.md`。
