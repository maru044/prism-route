# 环庭建筑与中庭树木 · 正式大世界

2026-10-30。正式入口为 `scenes/map_1021.tscn`。F5 出生点菜单增加「上层环庭 · 中庭入口」；`tools/run_upper_ring_1030.ps1` 使用相同正式场景，并直接从环庭入口开始。

## 场地与建筑

Rhino 的 539 个带标记对象以独立、世界对齐的资产导入，共 120,878 三角形，包括圆环、破损屋顶骨架、中庭、步道和三处缓丘。位于 `assets/world/upper_ring_1030/`。原始全图 GLB、固定树布局文件、初始遗迹和台阶平滑碰撞保持不变。

新土丘沿用正式地形和草地材质。地形高度场保留 Rhino 网格使用的三角形对角线，供植被贴地与旧地面避让共用。附近原有树只在运行时调整根部高度，并避开圆环轮廓；水平位置、树种、原始布局和其他区域保留。

建筑外皮采用暖白半哑光材质。窗面已使用透光玻璃，池面使用独立的水面光学材质，具体参数见下方。新建筑实体部分和四棵中庭树加入已有海面反射流程，中庭树位置也加入环境音的树林判断。

## 材质更新 · 2026-10-30

正式 F5 场景和入口启动脚本共用 `scripts/world/upper_ring_materials.gd`，可调参数集中在 `assets/world/upper_ring_1030/materials.json`。

- 玻璃：IOR 1.5，正面 F0 = 0.04，粗糙度 0.075；正面通透，掠射角增加反射，不再使用不透明蓝色板材。
- 水池：IOR 1.333，正面 F0 ≈ 0.02037，粗糙度 0.085；按池底深度与视角近似吸收，叠加两组低幅度法线波纹，保持平静浅水池的感觉。
- 光学材质使用预乘透明混合：PBR 反射保持完整，背景按 `(1−Fresnel) × transmittance` 衰减。吸收采用标量近似，水色由少量散射补足。没有启用屏幕颜色折射，避免当前渲染器中叶片覆盖材质在玻璃后呈黑色；深度纹理只用于池水深度。
- 局部 ReflectionProbe 只影响玻璃与池水，关闭环境光覆盖，捕捉中庭建筑和树木；一次捕捉、盒投影，属于静态近似，人物移动与树叶摆动不会实时更新倒影。
- 白色外皮：粗糙度 0.48，轻微清漆；基础混凝土 0.83、铺地石材 0.86；锈钢 0.78 / 金属度 0.04，以氧化层为主；深色框架 0.32 / 金属度 0.72。三平面微法线与细微粗糙度复用现有贴图，不需要新增 UV。
- 池水仅提取原模型顶面用于绘制；原始闭合网格生成的碰撞保持一致。模型、地形、树木、草地缓存与崖壁植物开关均未改动。

材质验证见 [materials_report.json](materials_report.json)。实机截图：[中庭](materials_courtyard.png)、[外观](materials_exterior.png)、[玻璃正视](materials_glass_front.png)、[玻璃斜视](materials_glass_grazing.png)、[水池俯视](materials_pool.png)、[水池低视角](materials_pool_grazing.png)。这些截图来自正式 `scenes/map_1021.tscn`，已检查 D3D12 shader 编译与实际画面。

实现参考：[Godot 预乘透明与 PBR shader 接口](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)、[ReflectionProbe](https://docs.godotengine.org/en/stable/classes/class_reflectionprobe.html)。

## 树池配置

- 主树：现有 `tree_medium_broad_clustered_canopy.glb` 阔冠大树，严格按原模型 **1.5 倍**，使用现有正式树干、叶片、调色与 LOD。主树向树池内侧留出余量，完整树冠包围范围位于中庭开口内。
- 陪衬树：三棵现有 `tree_small_broad_canopy.glb`，缩放分别 0.85、0.80、0.90，分布在另外两处树池。
- 四棵树的根均在各自土池多边形内部，落在 70.45 米土面上，并设置树干碰撞；前后贯通的主要通道保留。
- 具体坐标、角度、树池编号和缩放集中在 `assets/world/upper_ring_1030/manifest.json` 的 `trees`。

## 草地更新

本次只重新采样环庭及新土丘影响的 **230 格**，复用其余 **11,206 格**。已核对未影响区域的缓存元数据和压缩文件 SHA-256 均与导入前一致。合并后为 11,436 格、206,855,300 个草实例，当前签名 `ba956502a5277980535f7cf593721cb5134809971f52bead4c27ffa765ecd70a`。原始缓存清单和受影响的旧格备份保存在 `.current_map_build/upper_ring_import_1030_before/`。

## 实机验证

验证使用正式场景、D3D12 / RTX 5070 Ti。结果见 [report.json](report.json)。

- 709 个源网格样本与 Jolt 碰撞比对，最大高度差约 6.6 毫米。
- 角色分别跑过前后入口约 53 米、接路段约 18 米，均到达目标，悬空坠落帧为 0。
- 四棵树的实际渲染变换、树根落点、树池包含关系和树冠包围范围全部通过；主树实际缩放为 1.5。
- 正式草缓存签名匹配、完整，未发现损坏缓存；受保护的源资产哈希保持一致，崖壁植物继续关闭。
- 材质更新后导出依赖共 237 项，缺失 0，并显式包含环庭模型、运行脚本、材质配置、清单和高度场。

实际图片：[中庭树木](courtyard.png)、[建筑外观](exterior.png)、[场地总览](overview.png)、[出生洞口地标](cave_landmark.png)。这些是游戏运行截图。

复验命令：

```powershell
& '.current_map_build/runtime/Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tools/verify_upper_ring_1030.gd --log-file 'D:/Prism Route/prism-route/.current_map_build/upper_ring_runtime_1030.log'
```

验证进程会静音自己的 Master 总线；正常 F5 与入口启动脚本仍按游戏音量设置播放。
