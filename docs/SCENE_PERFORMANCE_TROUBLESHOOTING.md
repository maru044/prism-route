# Godot 场景性能排障指南：建筑、玻璃与草地

更新：2026-11-05。供后续 agent 排查正式场景使用。已验证案例是 [孤顶教堂](church_performance_1105/README.md)，不是对所有场景瓶颈的预先判断。

## 先记住本次的主要问题

**新教堂的地板和步道已经导入，但旧烘焙草地仍保留了覆盖区域内的根点。** 建筑碰撞不会自动重写既有草缓存。草从地板中穿出，既造成画面错误，也增加近景 GPU 开销。

该区域没有接入建筑植被排除的完整链路：CPU 种植判定、草着色器排除，以及实际草根缓存的局部更新。必须检查三者，而不能只看建筑已存在、遮罩文件已生成或游戏里暂时看不到草。

实测证据（1920×1080、RTX 5070 Ti、Forward+ / D3D12）：

| 对照 | 平均帧时间 | 说明 |
| --- | ---: | --- |
| 教堂入口原场景 | 19.18 ms | GPU 约 18.86 ms，主要受 GPU 限制 |
| 临时隐藏全部草地 | 2.67 ms | 用来定位草渲染开销，不是最终修复方案 |
| 临时隐藏教堂 | 21.78 ms | 没有改善；减少遮挡后可能更慢 |
| 临时隐藏五片玻璃 | 19.28 ms | 玻璃不是该视角的主要瓶颈 |
| 清理铺装下草根并局部重烘焙 | 12.97 ms | 入口帧时间降低约 32% |

教堂原有 93 个网格、130,072 个三角形、43 个碰撞体不变。移除 10,871 个根点、43,484 个实例后，中殿画面恢复；受影响范围之外的草和用户树木存档不变。

## 排查顺序

1. 确认实际入口和当前运行的场景。正式入口是 `scenes/main.tscn` → `scenes/map_1021.tscn`。不要拿空场景的帧率代替正式世界。
2. 固定镜头、分辨率和渲染器，等待草块加载稳定；记录 CPU / GPU 时间、帧时间、草块队列、绘制调用和图元数。检查帧率上限与 VSync，避免把锁帧当作瓶颈。探针可临时解除上限，正式项目设置不随之修改。
3. 每次只改变一项，分别测量隐藏草地、隐藏建筑、隐藏玻璃等对照，并恢复基线。隐藏草地只用于归因；不要将关闭植被作为交付结果。不同视角分别记录。
4. 结合实际画面判断：地板下的草、重复实例、透明排序和无效烘焙回退等。图元数较多不等于建筑必须减面；透明材质存在也不等于透明材质就是主因。
5. 如果主要是 CPU 开销或隐藏草地没有明显改善，转查其他系统。[2026-11-02 排障记录](performance_cpu_1102/README.md) 已有水面反射对象管理造成 CPU 瓶颈的另一案例，不能一律套用教堂结论。

## 去哪里查代码

| 文件／入口 | 作用与检查重点 |
| --- | --- |
| `scripts/world/church_ruins.gd` | `blocks_grass`、`bind_grass`、`install_grass_cells`：CPU、GPU、缓存替换的三个接入点 |
| `scripts/map_1021.gd` | `architectural_band` 调用建筑排除；初始化时绑定材质并安装局部烘焙 |
| `assets/vegetation/shaders/vegetation_wind_common.gdshaderinc` | 使用同一高度遮罩排除草，默认关闭的局部参数不能漏绑定 |
| `scripts/grass_volume_streamer.gd` | 正式草采样、分格与加载，草格大小为 24 m |
| `scripts/grass_baked_store.gd` | 缓存签名、磁盘读取和异步解码；检查是否回退在线生成或出现损坏数据 |
| `assets/world/church_ruins_1105/ground_grass.json` | 覆盖范围、真实铺装来源 ID、受影响格和几何指纹 |
| `assets/world/church_ruins_1105/grass_cut.rf` | 共享高度遮罩，CPU 与 GPU 必须一致 |
| `assets/world/church_ruins_1105/grass_bake/manifest.json` | 实际重打包数据索引；运行时格条目的 `resource_path` 必须指向局部新文件 |
| `shaders/environment/church_stained_glass.gdshader` | 通透彩玻璃、拼接线和掠角反射，不增加折射／反射视口 |

## 怎样修复建筑覆盖的草

从实际地板、入口与步道的三角形生成覆盖范围，保留坡度、高差与空隙。不要用整座建筑的外包矩形清空附近山坡，也不要默认所有地板都是同一高度。本案例使用 0.2 m 遮罩、0.8 m 边界余量，并限制生效高度范围，避免误删同一 XZ 下其他楼层的植被。

将同一遮罩接入 CPU 排除与草材质。仅在 shader 中隐藏草会保留无效数据及部分 GPU 成本；仅更新 CPU 判定也不会清理已烘焙根点。

对受影响的完整草格重打包。本案例几何和全图采样规则未改，因此可以从原始根点中剔除覆盖部分，保留其他根点的位置、法线、顺序及随机状态，再重建实例缓冲并压缩。读取来源时必须尊重既有局部覆盖的优先级，不能误用较旧的全图格覆盖先前修复。

运行时用新格替换对应缓存条目，校验全图生成签名、遮罩及建筑几何 SHA-256。签名失效时先查原因；不能手改签名，让失效缓存假装有效。若修改了全局采样规则，应重新评估受影响范围，不能直接沿用本案例的“仅 12 格”结论。

最后补齐 `export_presets.cfg` 及 `tools/configure_export_1021.gd` 的非资源文件包含规则。JSON、`.rf` 和 `.grass` 通过 `FileAccess` 读取，不能只因编辑器能运行就认定导出包也包含它们。

## 本案例的执行命令

在项目根目录执行。改动 Rhino 铺装后，先更新导出缓存和 `church.glb`，再运行：

```powershell
python tools/prepare_church_grass_cut_1105.py
$godot = '.current_map_build/runtime/Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path . --script res://tools/bake_church_grass_1105.gd
& $godot --headless --path . --script res://tools/verify_church_1105.gd

# GPU 测量必须实际渲染；使用新 tag 保留本次基线。
& $godot --path . --script res://tools/profile_church_1105.gd --rendering-driver d3d12 --resolution 1920x1080 --disable-vsync -- --church-preview --tag=recheck
```

这三个工具适用于当前教堂资产。处理别的建筑时复用方法，按实际几何生成该建筑的范围和草格，不直接照搬教堂 ID、坐标或高度。

## 交付前怎么判断真的修好了

- 正式场景确实安装局部烘焙。本次日志应有 `CHURCH_GRASS_BAKED_CELLS 12`；不是仅有文件生成成功。
- 铺装覆盖区域残留根点为 0；保留根点与随机状态逐字节一致。本次 12 格、53,624 个保留根点。
- 全图草地清单和用户树木存档指纹不变；建筑原网格和碰撞没有被性能试验误删。
- 实际碰撞与可见地板吻合。本次沿中殿检查 8 处，按真实有高差的地板测量。
- 玻璃内外可见性、阴影和实际截图正确。本次五片玻璃调整属于美术修正，不应将性能改善归功于玻璃。
- 相同镜头复测性能，区分入口与俯视收益。保留探针条件、前后报告及截图，不把当前开发机的结果当作所有设备的保证。

本次证据：[验收报告](church_performance_1105/validation.json)、[草地重烘焙](church_performance_1105/grass_bake.json)、[性能对照](church_performance_1105/performance_comparison.json)。
