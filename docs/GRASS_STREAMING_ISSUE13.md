# 1021 草流加载：异步加载、全图烘焙与 GPU 剔除

2026-10-22。保持草密度、随机分布、风、颜色、材质、树木布局和 CAD 几何，已从局部原型推进到全图静态分布烘焙。关联：https://github.com/maru044/prism-route/issues/13 。验收覆盖八个出生点和固定连续路线，不是对所有可能镜头最坏帧的保证。

## 实现

- `scripts/grass_volume_streamer.gd` 保留 24 m 三维 cell、当前/预测球和卸载滞回。优先处理相机视锥内 0–76 m、76–128 m，其次当前近处和预测区域，等待时间参与排序。优先级每次刷新预计算，比较器不重复做视锥查询。已采样但暂时离开需求的工作保留最多 8 块。
- 分离需求队列、在线生成队列、后台完成队列和上传状态。异步等待任务持续保留在需求队列中；不再因为暂时没有数据而被弹掉。5 / 9 ms 预算覆盖整个主线程 tick（含刷新、结果回收、提交），不再只覆盖采样循环。单次原生调用仍不可抢占，因此这不是绝对硬实时保证。
- 不修改共享树木/1012 的 MultiMesh 构造路径。1021 草专用 `grass_instance_buffer.gd` 将 transform 和 INSTANCE_CUSTOM 打包成 16-float 缓冲。打包、包围盒和离线数据重建在 WorkerThreadPool 上做；节点创建、缓冲提交和显隐留在主线程。每次最多提交 16,384 个实例，跨帧建立完整 cell，全部完成后才同时显示。
- 去除同一个根位置的第二次建筑遮罩查询；采样仍使用实际 Jolt 三角网格、原法线/层高/水面/顶部净空规则。
- `grass_baked_store.gd` 异步读取并校验 SHA-256、Zstd 解压、重建实例。CPU 缓冲 LRU 上限 96 MiB；GPU 活跃集仍按原空间滞回回收。后台任务尚未彻底结束时不在主线程等待，下一帧再收集。缺失、过期或损坏的烘焙数据回退在线生成。
- 分段计时覆盖 terrain / water / clearance 射线、mask、coverage、数学生成、pack、upload、commit、refresh、poll 和 unload。记录每块请求/首次可见/完成时间、实例数、取消/重建及排队情况。细分逐射线计时有开销，普通 F5 默认关闭；F6 可切换，`--grass-profile` 可直接启用。总 tick、上传、队列、缓存和帧率指标仍正常显示。
- 透明 HUD 增加近 5 秒进入/完成速率、排队 P95、最久可见缺口、视锥分段缺块、提交峰值、CPU 缓存和磁盘读数。待采样体积可能最终为空，故称“候选”；视锥计数是保守几何检查，不是假定所有候选都有草，也不等于逐像素遮挡可见性。
- 满草后补测 GPU：北部固定镜头中，关闭草的诊断与简化风、树、SSAO、阴影、MSAA、分辨率对照说明渲染是另一条独立成本。保持原画质设置，只为 1021 草材质启用 `skip_invisible_grass`：LOD 判定已为 0 的实例在顶点阶段退化为无面积三角形，跳过后续风/配色和无用光栅化。其它地图和树材质默认关闭。40,000 实例的真实草网格/材质、固定 shader 时间和光照下，开启/关闭优化逐像素完全一致。北部同镜头 GPU 对照约 16.85 → 15.49 ms；具体数据见 `review/issue13_gpu_ab.json`，诊断选项都未作为降画质默认值保存。

## 离线原型与全图数据

`tools/bake_grass_issue13.gd` 复用实际地图和同一 Godot/Jolt 采样器。覆盖固定 360 m 测试走廊及其预取区域，外加屋顶和桥下样本，共 1,152 个候选 cell；全地图索引为 11,321 个 cell。原型不改变默认出生点，按 8 可进入测试区域。

试验先保存完整矩阵，得到 1,086,746,942 字节。最终改为每个有效采样根的六个 float64（局部 x/z/y、法线）和 PCG 随机状态；同时记录 cell 的原始随机种子，在后台用相同函数重建四株草。保存 float64 是为了避免 x/z 和层高计算被量化；随机状态和种子必须同时保留。

最终 25,489,152 个实例的压缩原型为 **125,239,516 字节（119.44 MiB）**，约为完整矩阵文件的 11.5%。每一块在烘焙时都将重建缓冲与在线生成缓冲按字节核对，完全一致才写盘。烘焙约 225 秒，包含该额外重建校验；不是正式全图构建耗时预估。

原型验证后，两个独立 Godot/Jolt 进程继续生成全部 **11,321 个候选 cell**，复用已有正确原型。完整索引包含 1,620 个空格，共 **200,339,928 个实例**的分布；压缩文件总量 **982,218,801 字节（约 0.98 GB）**，展开成完整矩阵相当于约 12.82 GB。运行时只按需展开并保留 GPU 活跃集，CPU 缓冲 LRU 仍限制在 96 MiB。两个分片本次约 438 秒完成，包含每块精确重建校验；合并时再次检查候选集合完整性、分片签名、重复格一致性和每个文件 SHA-256，再原子发布完整索引。

本地生成数据在 `assets/world/current_map_validation/grass_bake/`，由 `.gitignore` 忽略，作为可再生构建缓存。源代码、报告和构建入口保留在项目。克隆项目或更新地图后运行 `tools/build_grass_1021.ps1`；不存在或过期的数据会回退在线生成，HUD 显示实际烘焙覆盖数。签名绑定网格、SDF、语义图层策略、生成函数/常量、算法格式和 Godot/Jolt 版本；纯队列、渲染剔除或 HUD 修改不触发几何重烘焙。游戏导出时需要将生成数据纳入分发构建；当前任务验证的是本地 F5 场景。

## 复现实验

本机结果汇总见 [实测对比表](../assets/world/current_map_validation/review/issue13_results.md)及[完整 JSON](../assets/world/current_map_validation/review/issue13_summary.json)。原型区域的收益与纯在线回退路径分别报告。

使用 Godot 4.7.2 / Forward+ / D3D12；报告设备 RTX 5070 Ti。先生成固定旧版本参考，再烘焙。示例中的 `godot` 替换为实际可执行文件：

```powershell
./tools/prepare_grass_issue13_baseline.ps1
./tools/build_grass_1021.ps1 -GodotPath 'C:/path/to/godot_console.exe' -Workers 2
godot --path . --script res://tools/verify_grass_issue13.gd
godot --headless --path . --script res://tools/verify_grass_bake_issue13.gd -- --grass-no-bake
godot --path . --script res://tools/benchmark_grass_issue13.gd -- --baseline
godot --path . --script res://tools/benchmark_grass_issue13.gd -- --grass-no-bake
godot --path . --script res://tools/benchmark_grass_issue13.gd
godot --path . --script res://tools/benchmark_grass_issue13.gd -- --uncapped
godot --path . --script res://tools/benchmark_grass_issue13.gd -- --grass-no-bake --grass-no-profile
godot --path . --script res://tools/verify_grass_issue13_delivery.gd
godot --path . --script res://tools/verify_grass_full_map_issue13.gd
godot --path . --script res://tools/profile_grass_gpu_issue13.gd
godot --path . --script res://tools/verify_grass_shader_issue13.gd
```

- `review/issue13_buffer_parity.json`：20,800 实例的矩阵/自定义数据、逐实例 vs bulk 画面逐像素相等、分帧上传显示原子性和画面相等。打包成本独立于上传，不能省略前者后宣称总体零成本。
- `review/issue13_bake_parity.json`：旧 `abfc7e4` 采样器与新采样器在八个实际 cell 上的完整实例数据比较，覆盖屋顶、桥下、坡地、水岸和空块；另测版本失效、损坏回退和 LRU 上限。
- `review/issue13_{baseline,online,baked,baked_uncapped,online_no_profile}.json`：相同 1920×1080、8 秒冷启动、18 m/s 相机走廊移动 360 m、90/180 度转镜头、回访 5 秒；60 FPS/VSync 和无上限两类。性能 HUD 关闭，但保留同一计时设施。tick 指标包括完整调用，不使用旧 HUD 中遗漏 refresh 的 last_build_ms 来冒充同口径比较。
- `review/issue13_baked_continuous.json`：额外逐帧检查视锥 0–76 m 候选缺块、最长缺失时间及首次近景就绪时间。该观察器在计时 tick 外运行，也有 CPU 成本。固定相机路线不是车辆碰撞测试。
- 原 `verify_grass_volume_streamer.gd` 和 `verify_map_1021_streaming.gd` 继续验证实际房车、多层、道路/水面排除和缓存身份，不能用相机路线代替这些测试。
- `review/issue13_full_bake.json`：全图数据校验；`issue13_full_spawns.json`：八个出生点可见 128 m 范围就绪、GPU、显存和 CPU 缓冲上限；`issue13_baked_full_continuous.json`：完整数据集上的逐帧连续路线；`issue13_shader_parity.json`：真实草 shader 的像素一致性。

CPU / GPU 耗时不可相加；完整草覆盖后 GPU 负载增加属于需要单独测量的结果。冷启动首帧、排队刷新和单次原生资源提交的极值仍可能超预算，报告保留这些峰值，不只取平均值。没有降低草密度、显示距离、MSAA、阴影或 SSAO 来获得默认配置的改善。更多道路和掉头路线、碰撞网格简化、资产发布打包及森林级 HLOD 仍可独立推进。
