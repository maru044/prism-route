# 东西两段岸路重建（2026-10-22）

主文件为 `D:/Prism Route/map/map_current.3dm`，265 个对象、33 个有效图层。Godot 主场景仍为 `scenes/map_1021.tscn`（F5）。

用户选中的两段旧岸路分别约 1.45 km 和 1.33 km，原来由四片薄路面拼接，并有重合或高于路面的土层。现在沿用原路线、宽度、横坡和两端接点，重建为连续 NURBS 闭合路面实体，并增加暖白路肩和承托底面。路面厚度 0.46 m，路肩每侧约 1.5 m，承托厚度约 1.3 m。

原路面 UUID 保留，各增加一件路肩，仍在对应交通图层，没有在 CAD 中隐藏或叠加旧版。七个相关地形对象在道路附近让位：实体使用布尔差，开放曲面分割后保留切割体外部。切割体随道路高程变化，保留其他楼层。

| 部件 | UUID |
| --- | --- |
| 东侧岸路路面 | `ee277b2d-e4eb-4d39-80e6-c5d8a5d87d70` |
| 东侧路肩与底面 | `e4060746-a264-469e-a672-b7e6e5883133` |
| 西侧岸路路面 | `305479e8-59d9-4a89-bcf6-204f69186e51` |
| 西侧路肩与底面 | `d348f4df-9b88-42a1-b57e-64023ce5f1ad` |

双向驾驶测试发现西侧与既有双层桥引道 `5182ccac-8e3b-4322-8826-976a9254271b` 的接头一侧高出约 0.362 m。仅在引道开始约 45 m 内平顺校正，接往双层桥的另一端保持原位，随后通过反向行驶。

验证：

- CAD：5,013 处路面采样未检出上方土体侵入；路面网格相对原高程最大误差约 6.3 mm，两端 NURBS 接点误差小于 1 mm。保存后回读核对修改对象。
- Godot/Jolt：1,725 处抽样，道路碰撞缺失、路面附近可种植草根、侵入路面上方的地形均为零。房车最高 18 m/s 双向连续行驶，四趟均完成，没有失去地面支承。
- 8 个现有出生点的步行、C 切换、房车行驶及轮胎接地回归通过。
- 保留 19,605 棵树的固定布局，仅校准碰撞面高度，没有移除树木，最大调整约 6.2 mm。
- 游戏导出有 201 个对象、9,605,606 个三角形。12 个对象参与补丁（10 个既有、2 个新增），其余 189 个可见几何对象的导出坐标、索引和分类属性与修改前逐字节一致。LOD 导入与完整网格碰撞策略保持。
- 草地使用原程序布置规则，11,321 格离线数据已按新网格签名重新烘焙并逐文件校验。实际 GPU 画面分别加载了 203 / 117 个草块，画面内待加载块均为零。

[东侧实机画面](../assets/world/current_map_validation/review/outer_roads_east.png) · [西侧实机画面](../assets/world/current_map_validation/review/outer_roads_west.png)

证据在 `assets/world/current_map_validation/review/outer_roads_1022.json`、`outer_roads_1022_cad.json`、`outer_roads_1022_preservation.json`、`validation.json`。完整草地缓存合并后由 `issue13_full_bake.json` 记录完整性和签名。

配方为 `tools/rhino_rebuild_outer_roads_1022.py`，补丁合并为 `tools/apply_outer_roads_1022_export.py`，游戏验证为 `tools/verify_outer_roads_1022.gd`。恢复检查点在忽略目录 `.current_map_build/outer_roads_1022_*`，不作为额外模型版本。
