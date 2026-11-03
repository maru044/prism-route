# 重要制作指南：MMD → 现有 VRM → Godot 动作与实时物理

**当前标准流程，更新于 2026-11-03。后续处理本项目 MMD 动作时优先参考此文件。**

**已执行的当前批次：[已选动作库导入与批量制作指南](MMD_SELECTED_LIBRARY_GUIDE.md)。** 用户确认的 11 组 KEEP、22 条角色轨道已进入 Godot；20 条新增、2 条复用，全部通过四模型共享检查。该文记录生产命令、范围、物理复用、三人组验证和后续增补方法。本文以下专属烘焙数据继续作为历史回归基线。

**烘焙前先选片：** 使用 [Blender 源动作选片器](MMD_SOURCE_PREVIEW_GUIDE.md) 直接查看原 VMD，只将正式清单中保留的片段送入后续制作。预览无需正式烘焙。

**全库批量化前必读：[动作库批量移植调研与实施计划](MMD_BATCH_FEASIBILITY_20261103.md)。**
已完成全部 285 个 VMD 的静态调查与本机 MMD Tools Reader 复核；报告区分常规候选、特殊控制器、多人组、存储成本和待验证内容。

**几十角色的正式方向：共享人形动作库 + 每角色一次适配。** 当前专属烘焙资源是验证基线，不能直接视为跨角色通用库；正式方案与待验收门槛见上述调研第 11 节，不继续按“每角色 × 每动作”生产。

**上述共享层现已实现并完成四模型样本验收。** 新动作优先使用 [共享人形动作规范](MMD_SHARED_HUMANOID_VALIDATION.md)；本文件后续专属流程继续作为转换回归基线。物理配置仍按角色/服装复用，双人接触适配仍需单列审核。

**多人补充：同一场景保留历史刻晴 A + 甘雨 B 的配套入口；当前默认打开已选动作库的 Loop 02。** 主列表每组只显示一次，整组/角色拆分和模型选择移到组内；中性四角色共享走路在“验证样本”。
`Loop 03` 实际包含两条配套轨道，早先单角色结果只是其中一条的转换基线。
完整的共同时间轴、共同坐标、候选/替代版本判断、对方碰撞和接触适配状态，见
[配套动作验证规范](MMD_PAIRED_MOTION_VALIDATION.md)。以下刻晴参数与历史数据仍作为每角色制作基线保留。

本次已完成刻晴现有 VRM 的动作重定向，并启用头发、侧发、裙摆、袖子、飘带和流苏物理。
最终验证入口是 `scenes/character_mmd_vrm_validation.tscn`；可复用角色是
`scenes/characters/keqing_mmd_vrm.tscn`。此前的 PMX 场景作为转换回归对照保留。

这份指南记录已实际执行并验证的流程、判断依据、失败经验和复测方法。
它是制作规范和历史样本参考；本文原始脚本固定为刻晴 / Loop 03。当前批次已有独立的清单驱动生产脚本与检查点，见上述已选库指南；特殊控制器、专有形变仍不在本批通用范围内。

## 1. 先理解最后采用的方案

```text
VMD + 对应 PMX 控制骨架
  → Blender 求解 IK / 追加变换 / 约束
  → 无约束骨架逐帧烘焙
  → glTF/GLB 中间动画
  → 针对现有 VRM 的骨名、骨轴、静止姿势重定向
  → Godot Animation (.tres)

现有 VRM 的原网格 / 原蒙皮 / 原材质
  → 添加 VRMC_springBone 元数据的派生 VRM
  → Godot 原生 Spring Bone 模块实时模拟头发和服饰
```

身体动画与实时物理分开制作。物理骨骼不再同时写入身体动画轨道。
最终角色继续使用既有 VRM 的网格、材质和蒙皮；不需要为了每个动作再导出一份完整人物网格。

`keqing_physics.vrm` 是 `keqing_fixed.vrm` 的物理配置派生文件。
比较确认二进制数据块完全相同，nodes、meshes、materials、skins、images、textures、accessors、bufferViews 均保持一致。
改变的是 Spring Bone 元数据。具体证据见 [保留性检查](validation/mmd_vrm_keqing_20261103/vrm_preservation.json)。

## 2. 最终文件入口

| 文件 | 用途 |
| --- | --- |
| `scenes/character_mmd_vrm_validation.tscn` | 最终独立测试场景，F6 运行 |
| `scenes/characters/keqing_mmd_vrm.tscn` | 可复用角色实例，组合 VRM、动作和物理 |
| `scripts/characters/keqing_mmd_vrm.gd` | 动作加载、物理初始化、开关和跳帧复位 |
| `assets/characters/mmd_validation/keqing_physics.vrm` | 保留原网格和材质的物理派生 VRM |
| `assets/characters/mmd_validation/keqing_vrm_loop03.tres` | 重定向到实际 GeneralSkeleton 的身体动画 |
| `assets/characters/mmd_validation/keqing_vrm_rest.json` | 从 Godot 实际导入结果导出的静止骨架 |
| `assets/characters/mmd_validation/keqing_vrm_build_report.json` | 映射数量、物理链、参数、输入/输出 SHA256 |
| `tools/build_mmd_vrm_validation.py` | 本次重定向与 Spring Bone 元数据构建脚本 |
| `tools/mmd_pipeline/blender_*_reference.py` | 本次 Blender 导入、烘焙、导出的参考步骤 |
| `tools/run_mmd_vrm_validation.ps1` | 启动最终场景 |
| `tools/verify_mmd_vrm_validation.ps1` | 带超时与新报告检查的自动验证入口 |

完整的本机源工程仍保存在工作区 `D:/Prism Route/research/mmd_validation_20261103/`。
其中 `mmd_loop03_validation.blend` 是骨架验证，`mmd_keqing_character_validation.blend` 是完整 PMX 网格对照。
源 PMX、VMD 和既有 VRM 都有本机依赖；不能假定只复制上述脚本就已经具备全部人物源资产。

## 3. 本次样本与验收结果

- 工具：Blender 5.1.1、MMD Tools 4.5.11、Godot 4.7.2、项目 VRM 插件 2.5.1。
- 动作：`Public R-18 Motions/Loop 03/Izumi.vmd`，0–480 帧，30 FPS，16 秒。
- MMD 源骨架 316 根；现有 VRM 在 Godot 中是 277 根。
- 映射 276 根，另外一根为导入器增加的 Root；144 根写入身体动画，共 288 条旋转/位置轨道。
- 132 根归入物理链；21 条链包含 4 条头发链和 17 条服饰链。
- 13 个身体碰撞体，按用途分成 4 个碰撞组；场景还有真实地面碰撞。

验收数据均来自实际运行，不是只检查文件存在：

| 检查 | 结果 |
| --- | --- |
| 11 个时间点 × 144 根动画骨骼 | 1,584 次位置/旋转检查通过 |
| 与初次 Blender 求解独立参考值比较 | 143 个关节位置，最大差异约 0.000878 毫米 |
| Godot 与重定向目标矩阵比较 | 最大位置差异约 0.001288 毫米 |
| 60 FPS 完整 16 秒 | 126,720 次物理骨骼/帧检查，无非有限值 |
| 物理段长度约束 | 最大差异约 0.000196 毫米 |
| 身体碰撞体采样重叠 | 30 / 60 / 120 FPS 约 1.94 / 1.70 / 1.37 毫米 |
| 帧率敏感性 | 30 / 120 FPS 最后链尾相对 60 FPS 最大约 0.290 / 0.424 毫米 |
| 分组开关 | 只开头发 4 条，只开服饰 17 条，全关 0 条 |
| 跳到结尾、开头、中间再恢复 | 660 次物理骨骼检查通过 |
| 早先 PMX 完整网格对照 | 蒙皮及变形包围盒回归通过 |

原始报告保存在 [validation/mmd_vrm_keqing_20261103](validation/mmd_vrm_keqing_20261103/vrm_validation.json)，
同目录另有 30/120 FPS 报告、帧率比较、VRM 保留性检查和 PMX 蒙皮回归报告。

碰撞数值是每秒约 5 次的**骨链末端与球/胶囊碰撞体**检查，不能解释为全网格逐三角形无穿插证明。
Spring Bone 是骨链近似，不包含布料自碰撞。本次已启用并验证可用，但其他动作的极端姿势仍需独立审阅。

## 4. 重建本次最终成果

下面命令在项目根目录 `D:/Prism Route/prism-route` 执行。Python 需要 NumPy。

### 4.1 Blender：先把 MMD 控制结果烘焙出来

参考步骤按顺序执行：

1. `tools/mmd_pipeline/blender_import_reference.py`
2. `tools/mmd_pipeline/blender_bake_reference.py`
3. `tools/mmd_pipeline/blender_export_reference.py`

这些参考脚本保留了本次的 PMX/VMD 路径、对象名、480 帧范围和输出名。
换动作前必须修改它们，先读新 VMD 的实际范围；不要把每个动作都截成 480 帧。
应在新的 Blender 工作文件中运行，保留原场景及源骨架。

关键参数：模型和动作均用 `scale=0.08`；按 PMX 日文骨名导入；不镜像；30 FPS。
源骨架保留 IK 和追加变换。导出骨架从源骨架最终姿态取值，Bake Action 使用
Visual Keying、步长 1、清除**导出骨架**约束，保留源骨架作为比较基准。

GLB 仅导出当前场景、选中骨架和必要蒙皮；逐帧采样、Y Up、关闭曲线简化。
骨架中间资产使用小标记蒙皮，确保 Godot 将其识别为 Skeleton3D。
导出后必须确认只有预期场景和一段预期动画。

### 4.2 导出目标 VRM 的实际静止骨架

```powershell
$engine = '.current_map_build/runtime/Godot_v4.7.2-stable_win64_console.exe'
& $engine --headless --path . --log-file .godot/mmd_rest.log `
  --script res://tools/inspect_motion_skeleton.gd -- `
  --model=res://assets/characters/import_tests_local/keqing/keqing_fixed.vrm `
  --output=res://assets/characters/mmd_validation/keqing_vrm_rest.json
```

不能用另一个角色的 JSON，也不能以 Blender 中看起来相似的骨架替代 Godot 实际导入结果。
更换 VRM、VRM 插件或骨架导入设置后，应重新导出并复测。

### 4.3 生成动作与物理派生 VRM

```powershell
python tools/build_mmd_vrm_validation.py
& $engine --headless --path . --log-file .godot/mmd_import.log --editor --import --quit
```

脚本读取烘焙 GLB、现有 VRM、目标 rest JSON，输出 `.tres`、物理派生 `.vrm`、参考值和构建报告。
本脚本目前是刻晴配置；不是通用人体自动映射器，也不会直接读取一整目录 VMD。

### 4.4 自动验收与实际查看

```powershell
./tools/verify_mmd_vrm_validation.ps1
./tools/verify_mmd_vrm_validation.ps1 -TestFps 30
./tools/verify_mmd_vrm_validation.ps1 -TestFps 120
./tools/run_mmd_vrm_validation.ps1
```

可用 `-GodotPath` 指定另一份相同版本的引擎。
验证脚本在 `.godot/mmd_vrm_validation_60.json` 等位置生成新报告。
包装脚本会删除对应的旧报告、限制最大运行帧数，并检查退出码和新报告；避免失败后误读旧的成功结果。

自动检查当前门槛：位置误差 <0.1 毫米、旋转误差 <0.002 弧度、段长度误差 <0.1 毫米、
采样碰撞体重叠 <5 毫米，且所有开关组合和动态变化检查通过。
自动门槛通过后仍要看正面、侧面、背面及动作关键帧。

场景中暂停的是身体动作，物理继续自然收敛，便于观察某一姿势的悬垂效果。
拖动时间轴会重置模拟历史；渲染采样等待约 0.8 秒让物理稳定。

## 5. 重定向为什么不能只改骨名

本模型存在三套容易混淆的数据：

1. PMX 原始 A 姿势及源动作求解骨架。
2. 既有 VRM 的节点层级静止变换，其中包含导出时的姿势处理。
3. Godot VRM 导入器规范化后的 GeneralSkeleton 静止变换。

尤其要注意：VRM 的 inverse bind matrices 与其节点层级静止姿势不一定相同。
本次用 inverse bind matrices 读取时能看到原始 A 姿势信息，节点层级则包含 T 姿势。
若拿错数据直接乘目标 rest，手臂、脚踝的方向或位置会明显偏离。

本次针对**同一原始人物的 PMX 与既有 VRM 转换结果**使用：

```text
目标骨骼全局姿态
  = 源骨骼求解后的全局姿态
  × inverse(VRM 原节点层级全局静止变换)
  × Godot 实际导入骨骼的全局静止变换

目标局部姿态 = inverse(目标父骨全局姿态) × 目标骨全局姿态
```

先建立日文 PMX 骨名 ↔ VRM humanoid 骨名映射，再按目标实际父子关系计算局部姿态。
写入 Godot 4 的绝对位置和旋转姿态，播放时 `Skeleton3D.motion_scale = 1.0`，避免位移再次缩放。
物理骨骼不输出轨道，其余需要的位移也保留，不能一律只留 Hips 位移。

此公式及当前剖面不能直接保证任意不同体型、不同拓扑模型接触位置正确。
更换角色时需要重新检查静止姿势、比例、腿根枢轴、手脚 IK、D/EX 权重及辅助骨。
不要把全身骨骼改名后就视为重定向完成。

## 6. 头发和服饰物理配置

| 类型 | 链数 | 本次模拟节点范围 | 初始 stiffness / gravity / drag / hit radius |
| --- | --- | --- | --- |
| 头发 | 2 | `发_1_1` 到 `发_8_1`，左右各一条 | 0.9 / 0.35 / 0.70 / 0.012 m |
| 侧发 | 2 | `侧发_1_1` 到 `侧发_5_1` | 1.2 / 0.25 / 0.75 / 0.010 m |
| 袖子 | 2 | `袖_1_1` 到 `袖_7_1` | 0.7 / 0.35 / 0.75 / 0.014 m |
| 裙摆 | 12 | 每片 `スカート_1_n` 到 `スカート_6_n` | 1.2 / 0.45 / 0.80 / 0.018 m |
| 飘带 | 2 | `带_2_1` 到 `带_9_1` | 0.6 / 0.35 / 0.75 / 0.010 m |
| 流苏 | 1 | `流苏_1_1` 到 `流苏_4_1` | 0.5 / 0.35 / 0.75 / 0.008 m |

stiffness 沿链逐步降至起始值的 60%；数值是本角色的起点，不是其他模型的默认答案。
物理链须是经过验证的连续父子链，不能把所有名称相似的骨骼拼在一起。
连接身体的首段保留刚性；飘带保留两段刚性连接，避免连接点被身体碰撞体反复挤压。

碰撞按用途分组：头发使用头/颈/胸/手臂；普通服饰使用身体碰撞体；
裙摆只使用腿部碰撞体，避免与自身骨盆连接区冲突；流苏避开自身胸部连接区。
不能简单地将所有身体碰撞体分配给所有链。

最终使用插件正常的 SkeletonModifier IDLE 更新。动作先更新身体姿态，原生模块随后模拟物理。
没有手动循环调用原生 `step_simulation()` 来伪造 60 Hz；该安装版本的此接口没有 delta 参数。
实际验收用引擎 `--fixed-fps` 控制时间，而不是只改变脚本 for 循环步长。

## 7. 本次过程与最重要的经验

### 先分三层验证，问题更容易定位

先完成无网格骨架的 MMD 求解/烘焙误差检查；再绑定原始 PMX 网格检查蒙皮；
最后才接入既有 VRM 与实时物理。若三件事同时做，骨轴、权重、材质、物理问题会混在一起。
这些中间场景应保留为回归夹具，但后续制作以最终 VRM 场景为准。

### 不要过早删除源 IK 和约束

把 PMX 转成静态 VRM 时可以移除 MMD 控制器；把 VMD 转成动作时必须先求解，再烘焙。
最终导出骨架是无约束的，但源骨架应保留以便比较。

### Blender 导出要同时限制选中物体和当前场景

只设 `use_selection=True` 不足以限制所有场景。本次曾把另一场景的选中骨架也导出，
得到多个场景、重名动画，Godot 报 `Unable to find node ... for animation`。
最终设置同时使用 `use_active_scene=True`，并检查源 GLB 只有一段预期动画。

### 首轮保真验证不要先简化动画

本次 Godot 默认优化曾造成约 1.3 毫米关节偏差，关闭该样本 AnimationPlayer 的 optimizer 后消失。
后续动作先保真通过，再按实际误差上限有选择地优化；不要仅为了文件小就打开全部优化。
删除恒定轨道是另一回事：rest 能补足不变值，不代表动画丢失。

### 身体动作和物理骨骼必须有明确分工

若身体动画仍每帧写入头发/裙摆旋转，物理会被覆盖，表现为不动、抖动或忽然跳回。
本次剔除了物理链轨道，保留刚性连接段，并在 seek 时重置模拟历史。

### 复制 Spring Bone 资源时保留碰撞组身份

本次使用 `spring.duplicate(true)` 时，碰撞组资源被深复制，与传给原生模拟的组库失去对应。
看上去“碰撞开关已打开”，实际上关联不正确。最终改为 `duplicate(false)`，
只修改本实例的标量设置，保留共享碰撞组引用。
修复后配合分组和刚性连接段调整，采样重叠从厘米量级降低到约 1–2 毫米。

### 骨骼会动，还需要检查实际网格

本人物既有 VRM 已做过 D 骨权重转移和 EX 合并处理。不能只映射 humanoid 普通腿骨就假定脚会正确变形。
其他模型需要重新审计权重；不能盲目照搬转移规则或覆盖已有有效权重。
本次保留了 PMX 蒙皮回归检查，同时检查 VRM 网格/蒙皮数据未被物理元数据构建过程改变。

### 检查物理最终姿态要选对时机

SkeletonModifier 处理后可能恢复基础骨姿态，普通 get_bone_pose 读取未必代表渲染采用的物理结果。
本次在 `modification_processed` 信号中采样最终姿态，并读取原生模块的链尾位置。
只检查基础姿态可能误判物理没有变化。

## 8. 后续大量动作怎样处理

**同一目标角色**的骨名/骨轴映射、目标 rest、物理链与碰撞体可以复用；每段动作只生成动画资源和动作记录。
不要为每个动作复制一份完整 VRM。角色或导入设置变化后，原有映射需要重新验收。

建议为每段动作建立清单，至少记录：

```json
{
  "id": "unique_motion_id",
  "source_vmd": "原始文件路径",
  "source_sha256": "...",
  "target_profile": "keqing_vrm_v1",
  "frame_start": 0,
  "frame_end": 480,
  "fps": 30,
  "loop": false,
  "root_policy": "preserve_authored",
  "paired_group": null,
  "missing_bones": [],
  "morphs_status": "not_processed",
  "physics_mode": "runtime_spring",
  "validation_status": "pending"
}
```

处理顺序：

1. 识别角色、相机、道具、静态姿势、重复版本及多角色配套关系；`.mvd` 单独处理。
2. 读取真实帧范围，计算哈希，记录比例和源骨架配置。
3. 在完整控制骨架上导入并烘焙；记录缺骨和辅助骨映射情况。
4. 使用已验收的目标角色剖面重定向，排除实时物理链轨道。
5. 同时验证数据与实际网格：手、脚、骨盆、关节极限、服装、相机各角度。
6. 对短动作、长动作、快速运动、极端姿势、明显根位移分别取样；失败动作单独保留报告，不能静默跳过。
7. 检查循环首尾速度与姿态后，才设置循环。静态结束帧或有叙事进出的动作不自动循环。
8. 多角色动作保持共同时间轴和统一整体位置；不能逐角色分别归零，否则破坏接触关系。
9. 表情以目标 Blend Shape/VRM Expression 独立映射。缺失表情不能靠骨骼重定向恢复。
10. 通过后放入同一角色的 AnimationLibrary，以动作 ID 加载；最后再接入 AnimationTree 或游戏状态机。

当前验证动作有 3 条动态腕部辅助轨道在源 PMX 中没有对应骨骼，
`Wrist Twist 01_`、`Wrist Twist 02_`、`Wrist Twist 03_` 仍是已知源映射限制。
本次没有完成表情、相机、道具、多角色接触或全目录批量转换；不要将这些项目写成已完成。

## 9. 更换角色或升级工具时的检查

重新导出目标 rest；检查 humanoid 映射、所有物理链的父子关系和叶节点是否保留；
检查身体碰撞体局部坐标是否按新骨轴转换；重新跑 30/60/120 FPS 与跳帧测试。
场景参数可作为初始值，不能当作新角色已经验收的证据。

官方机制参考：[Godot 骨架重定向](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html)、
[Skeleton3D 与 Modifier 更新](https://docs.godotengine.org/en/stable/classes/class_skeleton3d.html)、
[VRMC_springBone](https://vrm.dev/en/vrm1/springbone/)。
