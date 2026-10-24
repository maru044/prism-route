# 西侧岸路：路基、高架与平台搭接

2026-10-22。已在 `D:/Prism Route/map/map_current.3dm` 完成用户选中西侧岸路的承托，保留上一轮重建的路面、路线、宽度和纵横坡。里程从北侧低端起算，整段约 1,325 m。

| 区间 | 完成内容 |
| --- | --- |
| 0–70 m | 下部埋入原地面的连续路基 |
| 70–190 m | 路基逐渐收起，过渡到低高架 |
| 190–690 m | 连续曲面梁腹与倾斜 Y 形桥墩 |
| 690–830 m | 高架渐降，与原台地重新接合 |
| 830 m 至终点 | 梁腹横向展开，接入两侧已有平台，保留下方中层隧道 |

最高处实际路面至台地约 19.74 m。上段部分中心向下射线没有地形命中，但两侧台地接近路面高度，未把这类缺面误判为需要通到底层的高墩。

共 11 座墩，位于 150、208、266、324、382、440、498、556、614、672、716 m；常规墩距 58 m。两端较低处采用紧凑外展单墩，中段采用倾斜 Y 形墩。墩脚埋入实际台地约 0.9 m，肩部展开承托梁腹，主段梁腹约 2.25 m 深。

路基、梁腹、全部桥墩及平台搭接部分布尔为**一个连通、闭合、朝外的 NURBS 实体，共 49 面**。直接替换原承托 `d348f4df-9b88-42a1-b57e-64023ce5f1ad`，名称为 `西侧岸路_连续路基_11墩高架与平台搭接_NURBS`，仍在 `交通::小桥岸路`。原路面 `305479e8-59d9-4a89-bcf6-204f69186e51` 不变。主文档仍为 265 个对象、33 个有效图层；其余 264 个对象的几何 CRC 不变，临时试墩已删除。保存后回读主文件核对通过。

## 验证记录

- CAD：全线横纵抽样 2,403 条路面向上射线，新承托侵入为零；11 处墩脚在现有地面高度处均位于实体内。附近其他道路上方 0.25、1、3、5 m 的抽样未检出新结构侵入。
- 导出：仅替换上述承托网格，其他 200 个导出对象的原始顶点和索引字节保持一致。导出仍为 201 件，合计 9,877,306 个三角形，继续使用导入 LOD 与完整基础网格碰撞。
- Godot：东西两路各两个方向连续驾驶通过，最长连续离地帧数均为零；1,725 个路面检查点没有草根、地形遮挡或道路碰撞缺口。
- 场景：8 个出生点、C 切换、行走、房车行驶及轮胎接触回归通过；中层开放隧道四向移动通过。19,605 棵固定树布局未改，全部树根检查通过。
- 草地：按新网格重新烘焙并校验全部 11,321 格；GPU 截图使用匹配的完整烘焙，待加载可见格数为零。

网格 SHA-256：`56e1cb6bcd010a81b5bb095d1d07825598129647abede94868535ca40fe38789`。

草地签名：`7b9abac380b381e3caeb7c6437a5293c6c7170bf7483ebac6cbe8ee931df0b17`。

这些是游戏几何、抽样净空和行驶验证，未覆盖每一处面之间的精确相交。

## 编辑与复现

- CAD 配方：`tools/rhino_west_road_supports_1022.py`。`prepare()` 使用上一轮岸路和净高检查的会话缓存；重开 Rhino 后需先重新获取实际路面横断面和台地网格，不能直接重跑发布步骤。
- CAD 分阶段调用：`prepare` → `build_body` → 各里程 `build_pier` → `assemble` → `verify` → `publish_final` → `save` → `export_patch`。不重复使用旧试墩发布函数。
- 游戏导出：`tools/apply_west_supports_1022_export.py` → `tools/build_current_map_validation.py` → Godot 重新导入。仅导出替换当前承托，不重新切割地形。
- 检查：`tools/verify_outer_roads_1022.gd`、`tools/verify_map_1021.gd`、`tools/capture_west_supports_1022.gd`。草地使用 `tools/build_grass_1021.ps1` 重建。
- 回退检查点仅放在忽略目录 `.current_map_build/west_supports_1022_before.3dm`（单件原承托）和 `.current_map_build/west_supports_1022_game_before/`（当前步骤前的游戏数据），不新增完整场景版本。

报告位于 `assets/world/current_map_validation/review/`：`west_supports_1022_cad.json`、`west_supports_1022_publication.json`、`west_supports_1022_export_preservation.json`、`outer_roads_1022.json`、`validation.json`、`issue13_full_bake.json`、`west_supports_1022_render.json`。

实际 Godot 截图：[中段高架](../assets/world/current_map_validation/review/west_supports_0498.png)、[低段过渡](../assets/world/current_map_validation/review/west_supports_0110.png)、[回接台地](../assets/world/current_map_validation/review/west_supports_0725.png)。带 `_structure` 的截图是同一引擎关闭植被后的结构检查。
