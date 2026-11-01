# 浅水薄壳庭院 · 2026-11-01

按用户选择的 A 方案建模，落位于西侧浅水湾。靠坡道的薄壳横跨既有泻湖出口缓坡，形成可通行的桥洞；保留原路面，不另造桥面。建筑采用两片高低不同的卷曲薄壳、局部曲面玻璃、少量外露金属肋和破损檐口。中心保留现有水面，仅设置局部干燥廊台及逐渐没入水中的残台。

- 主地图：`D:/Prism Route/map/map_current.3dm`，已保存并回读确认。
- 图层：`建筑::浅水薄壳庭院`；31 个闭合网格对象，同一分组。
- 原生组件：`water_court.3dm`。
- 体量包围盒约 105 × 80 m；最高处约高于零米水面 14.4 m。
- 原坡道宽约 14 m。沿坡道采样检查中，92 个采样点位于薄壳下方，最小净高约 8.295 m；新构件与原坡道无网格相交。
- 51 个壳体落脚采样均嵌入实测湖底。没有修改水面、湖底、地形或原坡道；没有放置植物。
- 其余 1,392 个原有对象的几何与属性完全保留；中间几何只在内存暂存，主文档中没有失败版本或隐藏备份。

检查视图：`WaterCourt_overview_1101`、`WaterCourt_court_1101`、`WaterCourt_underpass_1101`、`WaterCourt_site_1101`。Rhino 当前停在整体近景。对应截图为 `model_overview.png`、`model_court.png`、`model_underpass.png`、`model_site.png`。

`concept_A.png` 是概念参考；实际尺寸、位置和曲面以原生模型为准。`site_check.json` 包含坡道净高、湖底落脚和交叉检查；`model_report.json` 包含对象审计。生成数学关系和参数保留在 `tools/rhino_water_court_1101.py` 及 `parameters.json`，可以继续修改。

## 正式游戏接入

已接入 F5 的 `scenes/map_1021.tscn`，保留当前 Rhino 模型的 31 个构件、原位置及比例。场景下拉菜单新增 **浅水庭院 · 弧形展廊**，默认洞穴出生位置不变；上层环庭依然是菜单最后一项。`--water-court-preview` 只定位检查镜头。

- 资源：`assets/world/water_court_1101/court.glb`，86,504 三角形，2,333,312 字节。
- 运行时：`scripts/world/water_court.gd`。13 个实体碰撞覆盖薄壳、廊台、玻璃及基础；细小框架和接缝仅显示，避免绊脚。
- 暖白薄壳、廊台和金属保留原生 PBR 参数。6 片玻璃采用独立菲涅尔透明着色器 `shaders/environment/water_court_glass.gdshader`，不投不透明阴影；25 个不透明构件接入现有水面反射。
- 82 个廊台表面碰撞采样通过，最大误差约 0.000058 m。其中连接廊台与薄壳落脚的两个交接点保留原生模型关系，局部抬高小于现有角色 0.18 m 的踏步能力；校验分别核对廊台和落脚碰撞，不把交接误判成丢失的廊台。
- 92 个桥洞上方采样通过，运行时最小净高约 8.295 m。原坡道/湖底 41 个中心线采样最大误差约 0.000375 m；真实角色双向通过，均无无支撑帧。庭院内涉水状态正常。
- 15 项既有地图、建筑、植物与草地缓存输入哈希保持不变。222 条树木编辑和 221 条删除记录保留，未重新布置植物或重烘焙草地。H 对玩法提示的既有修正保留。

当前实机图：`game/overview.png`、`game/court.png`、`game/underpass.png`。完整检查见 `game/verification.json`，图形检查见 `game/capture_review.json`。

复现工具：`tools/rhino_export_water_court_1101.py`、`tools/build_water_court_1101.py`、`tools/verify_water_court_1101.gd`。导出只读，未改写 Rhino 文档。
