# Prism Route

近未来废墟与自然复苏主题的 Godot 3D 项目。当前已搭建可探索的大世界、角色与房车控制、植被编辑和流加载，并建立 Rhino 建筑同步、VRM 角色入库及共享 MMD 动作的制作流程。

**当前状态：2026-11-10。** 本 README 提供现用入口和制作导航；详细验收数据保留在对应文档中。

## 启动项目

使用 **Godot 4.7.2、Forward+**。当前 Windows 配置使用 D3D12、Jolt Physics，默认窗口 1920×1080、帧率上限 60 FPS。

1. 首次克隆后执行 `git lfs install` 和 `git lfs pull`，下载完整地图及角色大文件。
2. 在 Godot 中导入本目录的 `project.godot`，等待资源导入完成。
3. 按 **F5** 运行正式世界；独立检查场景在打开后按 **F6**。

**唯一正式入口是 `scenes/main.tscn`。** 它实例化 `scenes/map_1021.tscn`，地图实现为 `scripts/map_1021.gd`。`map_1021` 是持续维护的正式内容，日期命名不表示它已废弃。默认出生点为「南部 · 初始洞穴」。

| 场景 | 用途 |
| --- | --- |
| `scenes/main.tscn` | F5 正式世界入口 |
| `scenes/character_roster_review.tscn` | 累计角色入库检查：待机、步行、跑步和衣发物理 |
| `scenes/character_mmd_vrm_validation.tscn` | 已选 MMD 动作库、多人同步及共享模型替换验证 |
| `scenes/character_motion_test.tscn` | 独立 CC0 动作候选预览与筛选 |

角色检查也可运行 `tools/run_character_roster_review.ps1`，共享动作检查可运行 `tools/run_mmd_vrm_validation.ps1`。脚本支持 `-GodotPath`；默认本地运行时位于不入库的 `.current_map_build/runtime/`，新机器需要自行指定 Godot 路径。

## 正式世界现状

现有 **22 个定位点**，覆盖道路、洞穴、多层平台及新增建筑。已接入初始三角遗迹、椭圆下行中庭、岛顶曲面遗址、台地曲面遗构、浅水庭院、东侧覆土庭院、上层环庭、下沉环庭与孤顶教堂等区域。2026-11-09 新增 [沙洲度假遗址](docs/SANDBAR_PAVILION_1109.md)：中央双翼亭与四栋单层木饰面度假建筑，海绿屋面、木格栅／露台及完整玻璃窗面已导入；侧背立面补齐内退窗洞、窗套与短挑檐。少量座椅、桌面及躺椅已预留独立定位点，1,087项模型与实际行走检查通过，交互状态为 anchors_ready。

2026-11-10 新增 [海岬小镇](docs/CAPE_TOWN_1110.md)：中央车行环岛、十四栋低层建筑（含近岸神社）、海上鸟居，**只有周边一圈是沙滩，镇内及建筑之间是草地**。复用项目墙面／屋面／木材及植被，保留五个家具槽位；当地形、入口或楼梯变化时，按同页流程重建模型并重新生成单文件局部草包。

- **探索与自由视角控制：** 甘雨角色、房车驾驶与切换，多层出生点和落脚面校验；第三人称大世界控制器（scripts/world_character_controller.gd）支持高自由度视角，视距放宽至 0.45m～10.0m（支持近距腰臀/服饰特写），俯仰角支持 -77.3°（垂直俯瞰）～ +71.6°（贴地大仰角裙底视点），旋转中心对齐角色腰臀（0.95m），并支持鼠标中键瞬间一键复位（4.0m 标准视距）；初始神殿现为普通 NPC 庭廊，配有三角石凳、案桌和楔形休息台及交互定位点。
- **植被与视线消融：** 固定树木布局、人工种植与保存、树木 LOD、按三维草格加载的离线草缓存、预测预取及草风动画。新增建筑采用局部种植排除与草格覆盖。草地着色器（assets/vegetation/shaders/vegetation_wind_common.gdshaderinc）内置纯 GPU 视线遮挡点阵半透明（Screen-Door Dither），在大仰角观赏裙底时自动将阻挡视线的前景草与贴脸草无损消融，消除遮挡且保留深度预阶段与抗锯齿。
- **渲染与环境：** 暖白建筑材质、建筑接缝与叶团细节、沙滩斜坡与海滩着色器、分区水体与平面反射（多分辨率视口自适应，详见 [窗口缩放说明](docs/WINDOW_SCALING_20261107.md)）、角色 MToon、涉水吸收及局部湿润／干燥表现。
- **声音与诊断：** 岸边、风、树叶、鸟声、涉水和车辆启动音效；场景内性能面板显示帧时间、渲染、草加载及反射指标。

| 操作 | 功能 |
| --- | --- |
| WASD / Shift / Space | 人物移动 / 跑步 / 跳跃 |
| 右键拖动 / 滚轮 | 人物镜头旋转 / 缩放（0.45m～10.0m，支持大仰角裙底视角） |
| 中键单击 | 人物镜头瞬间一键复位（4.0m 标准视距与舒适仰角） |
| C | 人物与房车切换，需要附近有足够空间 |
| 左上定位菜单 / 1–9 | 切换区域 / 前九个定位点 |
| F / V | 自由相机 / 全景 |
| 自由相机 WASD、Q/E、Shift、右键 | 平移、升降、加速、转向 |
| F4 | 植物编辑器 |
| H | 隐藏／恢复测试界面 |
| F6（运行世界时） | 开关额外的草加载细分计时 |

声音设置和建筑表面设置位于场景内菜单。具体系统见 [世界音效](docs/WORLD_AUDIO_1030.md)、[建筑叶团 V6](docs/FOLIAGE_GROWTH_V6_1029.md)、[初始遗迹](docs/INITIAL_RUIN_GODOT_1029.md) 和 [水面系统](docs/WATER_1026.md)。这些文档中的历史入口、数量与性能数据应按记录日期理解；当前入口以上表和 `project.godot` 为准。

## 角色与共享动作

### 角色入库

当前累计 **47 个可选角色**：原有刻晴、甘雨、胡桃、花火，加 `assets/characters/roster/catalog.json` 中的 **43 个新增角色**。新增角色使用 PMX → VRM → Godot 流程，按配置移除武器与独立道具；大部分目标角色已入库，剩余主角个别模型暂缓制作。

角色检查继续沿用同一个 `character_roster_review.tscn`，支持模型和动作切换、时间轴、速度、头发／服饰物理开关，并可进入共享动作验证场景。正式地图当前控制的仍是甘雨；入库清单用于角色资源管理与预览。

基础动作统一引用正式甘雨的 **A01 待机、A05 步行、A06 跑步**。骨盆侧移抵消、回绕重置物理及 A06 循环接缝已有专项修复。早期批次文档中的「14 个角色」「跑步仅诊断」是历史阶段状态；当前数量以累计清单为准，专项报告的验收范围以其记录为准。

制作入口：[角色批量导入指南](docs/CHARACTER_BATCH_IMPORT_GUIDE.md)、[共享移动动作修复与验收](docs/character_locomotion_1104/README.md)。每个角色／服装需要一次骨架、材质与衣发配置检查，之后跨动作复用自己的物理配置。

### 已选 MMD 动作库

当前已导入 **20 组、40 条角色位轨道**并通过全量验证。character_mmd_vrm_validation.tscn 支持第一人称（竿役视角，带防穿模眼部偏置与鼠标注视微调），并配套定制发光低台平台床 prism_geo_bed、折纸办公桌 prism_geo_desk 以及通用互动小条凳规范（[长方体条凳规范](docs/GENERIC_BENCH_INTERACTION_SPEC.md)）。身体动画资源合计约 **94.7 MiB**，不含角色、报告与可再生缓存。

先通过独立 Blender 源动作选片器筛选，再烘焙为共享人形资源。每条来源轨道保存一份身体动作，由目标 VRM 按自身骨架应用；多人组使用共同坐标和时间轴。头发与服饰在目标角色实例上实时模拟。

`character_mmd_vrm_validation.tscn` 的已选列表每组只列一次，提供搜索、人数筛选、整组／单角色查看、模型替换、时间轴与物理开关；当前预览台还支持实时曝光调节。已入库模型不等于全部模型与全部动作组合均已完成接触美术验收；体型接触、道具、表情和个别循环仍按实际使用场景调整。

| 制作步骤 | 指南 |
| --- | --- |
| 浏览原始 VMD 并选片 | [源动作选片器](docs/MMD_SOURCE_PREVIEW_GUIDE.md)、[人工选片清单](docs/motion_selection/README.md) |
| 转换、重定向及衣发物理 | [MMD → VRM 生产指南](docs/MMD_TO_VRM_PRODUCTION_GUIDE.md) |
| 增补已选库、重建和验收 | [已选动作库制作指南](docs/MMD_SELECTED_LIBRARY_GUIDE.md) |
| 跨模型复用与多人同步 | [共享人形规范](docs/MMD_SHARED_HUMANOID_VALIDATION.md)、[多人验证规范](docs/MMD_PAIRED_MOTION_VALIDATION.md) |
| 了解全库范围与批量化边界 | [动作库批量移植调研](docs/MMD_BATCH_FEASIBILITY_20261103.md) |

## Rhino 建模与最近修复

当前建模源文件是工作区的 [map/map_current.3dm](../map/map_current.3dm)。Godot 使用已导出的 GLB、语义清单和局部建筑资源；Rhino 中修改或删除对象后，需要同步相应导出并刷新 Godot 导入缓存。

2026-11-05 已完成：

- **孤顶教堂：** 彩玻璃、七个 `-colonly` 平滑斜坡；清理铺装下 43,484 个草实例并更新 12 格局部烘焙。详见 [教堂性能与草地验收](docs/church_performance_1105/README.md)。
- **建筑灰色平台：** 同步 Rhino 已删除的三块共面深色基座，该次同步后初始遗迹保留 325 个网格（后续神殿家具修订见当前说明）；教堂 43 个石材构件复用现有建筑材质，着色器和碰撞检查通过。详见 [Rhino 同步与灰面排障](docs/floor_materials_1105/README.md)。

建筑新增或地形更新后，应同时核对可见几何、碰撞、CPU 种植排除、草着色器与实际烘焙数据。性能比较要固定镜头并等待加载稳定；诊断实例串行运行、完成后退出。排障先读 [AGENTS.md](AGENTS.md) 和 [场景性能排障指南](docs/SCENE_PERFORMANCE_TROUBLESHOOTING.md)，不要直接套用某个历史案例的原因或帧率。

## 本地重建与资源管理

地图 GLB 和新增角色 VRM 使用 Git LFS。`.godot/`、`.current_map_build/` 及全图基础草烘焙是本地缓存，不随普通克隆提供。缺少草缓存时运行时会回退生成；需要完整预烘焙体验时，按 [草流加载与烘焙说明](docs/GRASS_STREAMING_ISSUE13.md) 重建：

```powershell
& tools/build_grass_1021.ps1 -GodotPath '你的 Godot 控制台程序完整路径'
```

GLB 或纹理被制作工具重写后，先在编辑器完成重新导入，再做画面验收。命令行也可执行：

```powershell
& '你的 Godot 控制台程序完整路径' --headless --editor --path . --import --quit
```

单纯以 `--headless` 运行游戏不会执行编辑器导入。批量角色和动作重建还需要相应原始素材、Blender／MMD Tools 及各制作脚本要求的 Python 依赖，具体命令见制作指南。

用户种植存档位于 `assets/world/tree_planting/world_edits.json`，应保留并审阅其变动。外部模型、动作与音频的来源及使用条件按各素材记录管理。

旧整图测试已移到工作区外部归档 `D:/Prism Route/archive/legacy_world_tests_20261104/`。项目仍使用名称中带旧日期的部分共享材质与脚本，清理前要检查实际引用。参见 [旧场景归档记录](docs/LEGACY_WORLD_SCENE_AUDIT_1104.md) 和 [逐文件归档清单](docs/legacy_world_archive_1104_manifest.json)。

## 目录导航

| 路径 | 当前用途 |
| --- | --- |
| `scenes/main.tscn`、`scenes/map_1021.tscn` | 正式入口与世界内容 |
| `scripts/map_1021.gd`、`scripts/world/` | 世界加载、建筑与局部修复 |
| `assets/world/current_map_validation/` | 基础地图、材质分区、树布局及草缓存索引 |
| `assets/world/*/` | 各建筑导出、清单、局部遮罩与烘焙 |
| `assets/world/cliff_b_test/architecture.tres` | 现用共享建筑材质，仍在正式世界使用 |
| `scripts/water/`、`assets/water/` | 现用水体与反射；旧 `map_1012_test/water.gdshader` 仍作为回退使用 |
| `assets/characters/roster/`、`scenes/characters/roster/` | 累计角色清单、VRM 成品与角色场景 |
| `assets/characters/mmd_selected/`、`scripts/characters/` | 已选共享动作与人形播放器 |
| `assets/vegetation/`、`scripts/tree_planting/` | 植被资源、编辑器及种植存档 |
| `tools/` | 导出、转换、烘焙及专项验收工具 |
| `docs/` | 制作指南、设计记录与验收证据；[当前建模记录](docs/CURRENT_MODEL.md) 保留历史演进 |

发布准备与上传事项见 [发布准备计划](docs/ITCH_IO_UPLOAD_LIMIT_PLAN.md)。开发目录中的最新资源与历史构建包应分别核对，构建包状态以其导出记录为准。
