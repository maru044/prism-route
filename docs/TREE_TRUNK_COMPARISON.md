# 细树干对比

## 大地图正式接入

已接入 F5 主场景 `scenes/map_1021.tscn`，共享模块为 `scripts/tree_trunk_assets.gd`。
1021 继承的 `map_1012_vegetation.gd` 在建立树木 MultiMesh 之前替换木质网格：
小圆冠使用轻弯单干，宽冠及竖冠使用确认后的连续分叉。近/中景使用同一个树干资源，
远景保留原有的纯树冠 impostor。既有树冠几何、材质、色板及世界遮罩不变。

主地图现有种植为这三类树，19,604 棵；未额外散布白桦或柏树。
游戏内种植编辑器也调用同一木质替换模块，五种已知树型均可匹配，未来自定义树型保持自身模型。
原始 GLB / Blender 模型仍保留，用于小场景原版对照及生成时读取原始截面。

布局文件原本已为每棵树保存 0–360° 的随机 Y 轴旋转和 0.82–1.20 的随机缩放，
本次直接沿用这些稳定参数，不在每次启动时重新随机。位置、数量、布局文件及其哈希未改动。
`tools/verify_world_tree_trunks.gd` 已实际运行主场景，核对全部 78,416 个树木绘制变换：
近景树冠/树干、中景树冠、远景树冠均与对应源树位及朝向一致；同时核对原树冠数据、
世界颜色遮罩、五种编辑器可用木质资源，以及现有草地烘焙继续命中。
报告与截图在 `.vegetation_art_build/trunk_comparison/world/`，`validation.json` 为通过。

## 当前检查版 v2：按树型区分树干

在 `scenes/vegetation_grove_test.tscn` 按 F6，左侧“树干检查”默认定位普通小圆冠树，
显示“新版 · 轻弯单干 / 无分叉”。第一个下拉框选择五种树型，第二个下拉框切换
该树型的原版/新版；大型圆冠树额外保留上一版相交细枝。
各树型独立记住本次运行内的对比选择，重新运行默认全部为新版。
默认隔离一棵代表树，避免其他树冠遮挡；取消“隔离当前树”可恢复整片树林。
“查看整树”观察原树冠；“查看木质结构”临时隐藏这一棵树的树冠并重新取景。
右键拖动观察方向，WASD / Q、E 移动，滚轮前后移动。

小植物检查场景交换木质网格，覆盖 23 棵树、五种基础树型。
原有 81 个树冠网格、补洞、材质和配色均保留。原始 GLB、Blender 源和 v1 对比资产保留，
主地图已按上节接入同一套木质资源；灌木不作修改。

| 树型 | 小场景实例 | 木质三角形 | 造型区别 |
| --- | ---: | ---: | --- |
| 大型圆冠 | 1 | 1094 | 已确认的连续主分叉与两根错落侧枝 |
| 普通小圆冠 | 15 | 116 | 轻弯单干、无分叉，保持原高度和截面尺寸；包含复用此模型的四种花树配色 |
| 竖冠大树 | 1 | 1022 | 较直立的生长线、较窄的上伸分枝 |
| 白桦 | 3 | 950 | 轻微弯曲与细上伸侧枝，圆柱 UV 保持原树皮纹理密度 |
| 柱形柏树 | 3 | 1092 | 克制的弯曲、四根短枝，保持窄柱轮廓 |

四种扩展参数在 `assets/vegetation/source/tree_trunk_species_comparison_v2.json`。
小圆冠版按用户要求直接覆盖此前的复杂分叉版，未新增版本文件：高度恢复为原来的
3.25 m，中心线顶端偏移约 0.11 m，不加粗、不增加分枝或向树冠内部延长。
运行 Blender 后台脚本 `tools/build_tree_trunk_connected_comparison.py -- --species small`，
其余参数为 `upright`、`birch`、`cypress`；不传参数只生成下述大型圆冠版。
每种输出独立的 `tree_<species>_trunk_connected_comparison_v2.blend` / `.glb`，
源文件在 `assets/vegetation/source/`，模型在 `assets/vegetation/models/`。

`tools/capture_tree_trunk_species.gd` 已用实际 Forward+ GPU 运行验证：五种树型旧/新切换、
23 个对应实例、81 个树冠网格和材质未改变、白桦 UV 与原树皮纹理、隔离与树冠显示恢复。
截图及结果位于 `.vegetation_art_build/trunk_comparison/species/`，`validation.json` 为通过。

### 大型圆冠版的原始记录

- 保持原主干各截面的径向尺寸，仅调整中心线；不增加粗根或分叉凸环。
- 主分叉位于 2.0 m，两根较短侧枝分别位于 4.18 / 5.42 m，枝条弧度、方向和长度错开。
- 主干延续到树冠内部的 8.6 m，新增上段从原顶端半径渐细至 0.009 m。
- 每个分叉替换主干的一小块面，使用共享顶点桥接枝条；是单个连通的封闭表面，
  未采用相交管段合并或可能使树干膨胀的体素重建。
- 木质部分 1094 三角形，一个网格、一个原材质。

参数：`assets/vegetation/source/tree_trunk_connected_comparison_v2.json`。
可编辑源：`assets/vegetation/source/tree_broad_trunk_connected_comparison_v2.blend`。
游戏模型：`assets/vegetation/models/tree_broad_trunk_connected_comparison_v2.glb`。
生成脚本：`tools/build_tree_trunk_connected_comparison.py`，读取原 `.blend`，只输出独立木质资产。
连接算法在本项目独立实现，未复制调研资源的源码。

验证：生成阶段检查单一连通分量、零非流形边、零自相交、零退化三角形，
并逐点核对原主干截面未缩放。Godot 实际 GPU 运行
`tools/capture_tree_trunk_comparison.gd`，验证三版本切换、原树冠网格、材质和可见性恢复，
截图与报告存放于忽略的 `.vegetation_art_build/trunk_comparison/`，不参与正式导出。

## 保留的上一版 v1

在当前三项下拉框中选择“上一版 · 相交细枝”即可检查 v1。

只交换大型圆冠树的木质网格，原版模型、树冠、补洞、材质和配色保持。
主干每个原有截面只平移中心，截面尺寸不缩放、不加粗、不增加根部或分叉凸环。
弯曲参数为 0.22 m，三个细侧枝的起始半径分别约 0.084 / 0.057 / 0.034 m。
原主干 188 三角形，对比木质网格 428 三角形，保持一个网格和原木质材质。

参数：`assets/vegetation/source/tree_trunk_thin_comparison_v1.json`。
可编辑 Blender 源：`assets/vegetation/source/tree_broad_trunk_thin_comparison_v1.blend`，只含木质部分。
生成脚本：`tools/build_tree_trunk_comparison.py`，读取原 `.blend`，仅输出独立对比资产。
参数修改后重新运行 Blender 脚本并让 Godot 导入即可；未重建草、正式树木 LOD 或主地图。
