# MMD → Blender → VRM → Godot：刻晴流程验证

日期：2026-10-08。状态：本地中性技术验证完成，待人工检查动作与美术细节。

## 测试样本与范围

本次使用刻晴测试模型，与现有甘雨方便对照。

使用 Blender 5.1.1、已安装的 mmd_tools / VRM 插件，以及项目 Godot 4.7.2 和 VRM 导入插件。
独立入口：`res://scenes/character_model_import_test.tscn`。
它使用本地刻晴测试副本和六段现有 CC0 普通动作：

| 编号 | 动作 |
| --- | --- |
| A01 | 放松站立 |
| A05 | 女性步行 |
| A06 | 女性跑步 |
| A22 | 坐姿待机 |
| A39 | 另一种步行 |
| A42 | 喝水 |

顶部可以切换处理前后模型；左侧保留动作选择、播放速度、暂停、时间轴；右键旋转，滚轮缩放。
主项目入口未改变。甘雨的原有 42 段动作与测试控件回归通过。

## 转换操作流程（下次按此顺序执行）

自动化实现是 `tools/build_mmd_vrm_review.py`。以下记录本次实际操作，也可作为手动 Blender 处理的核对表。此配置只验证过刻晴，其他模型先检查权重与骨架。

### 1. 导入 PMX 与检查源文件

- 在独立 Blender 后台进程处理副本；工具会清空该进程的场景，不要直接在未保存的工作场景运行。
- 启用 `bl_ext.blender_org.mmd_tools` 与 `bl_ext.blender_org.vrm`。
- MMD 导入参数：`scale=0.08`，导入 `MESH / ARMATURE / MORPHS`，不导入 MMD 物理，不向源目录写导入日志。
- 核对骨架、贴图路径和实际权重分布；记录每个顶点的变形骨总权重。
- mmd_tools 默认清理未使用顶点；本次从 16,254 个顶点变为 15,934 个，不是转移权重导致顶点丢失。

### 2. 清理 MMD 姿态控制

- 清除导入骨架上的 IK、附加旋转等姿态约束，骨骼姿态归零，清除骨架与网格的动画数据。
- 所有形变值归零，保留形变目标供后续表情绑定。
- 保留骨骼及父子层级。空顶点组可以删除，但不能据此批量删除同名骨骼。

### 3. 修复两侧腿部顶点组

在网格的顶点组面板操作，左右两侧分别执行：

| 原实际控制组 | 标准控制组 | 操作 |
| --- | --- | --- |
| `足D.L / 足D.R` | `足.L / 足.R` | 删除空标准组，将 D 组重命名 |
| `ひざD.L / ひざD.R` | `ひざ.L / ひざ.R` | 删除空标准组，将 D 组重命名 |
| `足首D.L / 足首D.R` | `足首.L / 足首.R` | 删除空标准组，将 D 组重命名 |
| `足先EX.L / 足先EX.R` | `足首.L / 足首.R` | 把 EX 权重加到对应脚踝，再删除 EX 组 |

执行前确认目标标准组确实没有非零权重，D 骨和对应标准骨的关节位置一致。本次位置差为 0；工具在位置差超过 1 mm 或目标已有权重时中止，不直接覆盖。

EX 合并使用逐顶点相加，而不是仅重命名，也不是用 EX 覆盖脚踝原权重。处理后核对总权重与处理前一致、没有零权重顶点；本次总权重误差为 0。脚尖骨保留，但本次 EX 网格由脚踝控制，不依赖足尖 IK。

### 4. 转换材质与内嵌贴图

- 先用 mmd_tools 将 MMD 材质转换为 Blender Principled 节点，再启用 `material.vrm_addon_extension.mtoon1.enabled = True`。
- 基础色恢复为 PMX 的漫反射 RGB 和透明度；发光色设为 `(0, 0, 0)`。
- MToon 的 `shade_multiply_texture` 绑定同一张基础色贴图。只绑定基础色贴图会使阴影区域丢失贴图颜色。
- 本次试用参数：阴影色 `(0.72, 0.73, 0.80)`、`shading_toony_factor=0.75`。这些是测试参数，颜色偏浅的问题仍待美术校准。
- 带贴图且 PMX 材质透明度为 1 的材质使用 `MASK`，`alpha_cutoff=0.35`，保留头发、睫毛等贴图透明区域；材质自身半透明的情况不套用此规则。
- 所有图片先核对路径存在，再打包；导出 VRM 时内嵌图片。

踩坑记录：VRM 材质转换操作仅构建节点，后台导出还需要显式启用 MToon；插件的 MMD 分支可能将带贴图的基础色设为黑色，因此要恢复源 RGB，并确认导出文件确实包含 `VRMC_materials_mtoon`。

### 5. 设置 VRM 人形骨架并导出对照版本

- VRM 规格选 `1.0`，先自动分配 humanoid 骨骼，再人工覆盖 `Hips → 腰`。
- 刻晴的 `センター` 约在 0.70 m，而实际骨盆 `腰` 约在 0.92 m；使用较低中心骨会引入额外旋转杠杆，影响步行动作横移。
- 使用插件原生 `autoPose` 自动 T 姿势导出；本流程不额外手动做 Pose to Rest Pose。
- 每次导出前重新选择骨架和所有网格，骨架设为活动对象，仅导出选择对象。插件第一次导出会改变选择状态，不重新选中可能导出空模型。
- 工具在权重修改前导出 `keqing_before.vrm`，修改后导出 `keqing_fixed.vrm`；两份使用相同材质、骨骼映射与导出设置，仅比较腿部权重处理。
- Blender 副本另存到 `.model_import_build/`，不覆盖源 PMX。

### 6. Godot 导入与动作烘焙

- 让 Godot 编辑器导入两份 VRM，读取修复版 `GeneralSkeleton` 的静止姿态，输出 `.model_import_build/keqing_rest.json`。
- 用这份静止姿态把六段现有 CC0 动作烘焙到刻晴的 `motions/`，不要直接复用甘雨已烘焙的动作轨道。
- 测试场景中把 `Skeleton3D.motion_scale` 设为 `1.0`：动作平移已按该模型的米制尺寸烘焙，避免导入器再缩放一次。
- 在独立场景切换处理前后模型、暂停、拖动时间轴；检查屈膝、迈步和脚踝是否真正带动网格。

### 7. 验证与记录

- Blender：脚踝旋转 25°，确认修复后脚部网格发生位移；核对顶点总权重与输入文件未被修改。
- VRM：确认存在网格、蒙皮、20 个 MToon 材质、5 张内嵌主贴图和 61 个形变目标，避免只得到骨架文件。
- Godot：验证六段动作所有轨道路径有效，抽样姿态不出现无效数值，处理前后切换保留暂停位置与速度。
- 公共动作测试器有修改时，运行甘雨原有 42 段动作的回归检查。
- 最后看 Forward+ 实机截图，数值检查不能替代网格变形和材质的视觉检查。生成报告后把结果留在 `docs/MMD_VRM_IMPORT_TEST_REPORT.json`。

## 检查结果

- Blender 网格 15,934 顶点、20 个材质；VRM 包含 20 个 MToon 材质、5 张内嵌主贴图、61 个形变目标。
- 脚踝旋转 25°：处理前移动顶点数为 0；处理后 474 个顶点位移超过 0.1 mm，最大位移约 7.26 cm。
- 权重总量最大误差 0；输入文件未被修改。
- Godot 导入后 277 根骨骼；六段动作两种模型之间反复切换，所有轨道路径有效，抽样姿态有限，暂停位置与速度保持。
- Forward+ / D3D12 实机截图检查：处理前腿基本不响应动作，处理后屈膝和迈步可见。
- 详细数值：`docs/MMD_VRM_IMPORT_TEST_REPORT.json`。

## 测试资产与本地构建产物

- VRM：`assets/characters/import_tests_local/keqing/keqing_fixed.vrm`、`keqing_before.vrm`。
- 六段动作：同目录 `motions/`。
- Blender：`.model_import_build/keqing_fixed.blend`、`keqing_before.blend`。
- 截图：`.model_import_build/keqing_contact_sheet.png` 及各动作单图。
- 完整转换和验证日志：`.model_import_build/`。

两份 VRM（含内嵌贴图）、Godot 导入配置、六段动作与动作目录纳入版本管理，检出后可直接使用独立测试场景。Blender 构建文件、截图与诊断日志仍保存在 `.model_import_build/`。转换操作和检查记录保存在本文与测试报告中，资产目录只存放测试场景使用的资源。

## 复现（在项目根目录运行 PowerShell）

```powershell
Set-Location -LiteralPath 'D:\Prism Route\prism-route'
$blenderExe = 'D:\blender\blender.exe'
$godotExe = 'D:\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
$pythonExe = 'C:\Users\PC\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $blenderExe --background --python tools/build_mmd_vrm_review.py
& $godotExe --headless --editor --path . --quit
& $godotExe --headless --path . --script tools/inspect_motion_skeleton.gd -- --model=res://assets/characters/import_tests_local/keqing/keqing_fixed.vrm --output=res://.model_import_build/keqing_rest.json
& $pythonExe tools/build_motion_review.py --target .model_import_build/keqing_rest.json --dest assets/characters/import_tests_local/keqing/motions --ids A01,A05,A06,A22,A39,A42
& $godotExe --headless --path . --script tools/verify_model_import.gd
& $godotExe --path . --script tools/capture_model_import.gd
& $godotExe --headless --path . --script tools/verify_motion_review.gd *> '.model_import_build/ganyu_regression.log'
& $pythonExe tools/summarize_model_import.py
& $godotExe --path . res://scenes/character_model_import_test.tscn
```

这些命令会重新生成两份 VRM 与刻晴动作；如果只是检查已提交资源，直接运行最后一条场景命令即可。
工具是刻晴的具体配置，`--source` 用于明确指定该源文件，并非任意模型的通用转换器。

## 后续工作

- 人工检查两种步行、手指姿态和高跟鞋的接地。测试场景没有 IK 或碰撞修正，不宣称所有动作适配完成。
- 头发与裙摆尚未配置 VRM 弹簧，动作时会保持原骨架姿态，可能穿插。
- 保留了形变目标，但尚未绑定 VRM 表情、眨眼与口型。
- MMD toon / sphere 材质不保证逐像素还原；本轮 MToon 实机颜色仍偏浅，后续再做统一美术调色与阴影。
- 其他模型逐个核对骨架与权重。已有目标组权重或关节位置不同会中止，避免直接覆盖已有权重。
