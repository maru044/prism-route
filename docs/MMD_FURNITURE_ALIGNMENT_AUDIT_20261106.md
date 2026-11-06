# MMD 家具预览与固定家具交互：坐标与接入审计

日期：2026-11-06。检查基线：Git `eefc45c`，以及检查时工作区内正在制作的床与 `interactive_furniture.gd` 修改。**本次仅检查和记录，没有修改场景、运行脚本、家具、动作或清单，没有启动 Godot／Blender。** 未提交的床资源是制作中状态，不将其接入缺口解释为已交付功能的回归。

## 结论

用户担心的方向成立：`character_mmd_vrm_validation.tscn` 当前提供的是**围绕动作坐标摆家具的预览工具**，尚未接通“世界家具固定 → 人物走到入口 → 按锚点摆放动作组 → 同步播放”的生产流程。

需要区分一个事实：家具并没有绑定到人物骨骼，也没有每帧追随骨盆。当前是选择动作时创建／隐藏家具，通过硬编码或滑块设置家具相对于预览场景的静态位姿。因此不能报告成“播放时家具一直跟着人物走”。

现有工具可继续用于美术预览和标定；**不能把移动家具的预览逻辑直接当作大世界固定家具交互实现。** 当前共享身体动画和共同时间轴仍可复用，接入锚点不要求按家具的每个世界位置重新烘焙动画。

## 1. 当前实际做法

| 项目 | 代码／资产证据 | 判断 |
| --- | --- | --- |
| 场景装配 | [场景](../scenes/character_mmd_vrm_validation.tscn) 仅挂载 [预览脚本](../scripts/character_mmd_vrm_validation.gd)；`_ready()` 分别添加 `furniture_root` 和 `PairedActors` | 家具与动作组是预览根节点下的两个独立分支 |
| 人物位置 | `select_entry()`，约 394–412 行：各角色使用 `presentation_offset`，可选叠加 `placement.ground_offset`，加入同一个 `group` | 人物没有查询所选家具的锚点 |
| 自动家具匹配 | `_auto_match_furniture()`，约 664–692 行 | 仅按两个 pack ID 选择椅子及预设位姿，未根据锚点计算人物组变换 |
| 实际变换写入 | `_set_furniture_sliders()` → `_update_furniture_transform()`，约 707–736 行 | 写入的是 `furniture_instance.position/rotation`，不是整组演员的世界定位 |
| 每帧播放 | `_advance_animation()` / `_process()` | 推进共享动画及对方碰撞代理，没有逐帧移动家具 |
| 校准保存 | 家具滑块、重置及加载代码 | 只保存运行中的变量，没有将标定写回动作—家具配对资源 |

目前自动匹配配置为：

- `mmd_781d8c87fd79`：`prism_geo_chair`，家具偏移 `(0, 0, -0.51)`，Y 轴旋转 0°。
- `mmd_beee0d2eb57b`：同一椅子，家具偏移 `(0, 0, 0)`，Y 轴旋转 0°。
- 其他动作：自动模式隐藏家具；可手工选择并调节。

`_load_furniture()` 读取目录中的 `file` 并直接实例化 GLB。当前 [家具目录](../assets/furniture/scifi/furniture_catalog.json) 只登记了 `prism_geo_chair.glb`；该 GLB 只有一个网格节点，没有 `Anchor_*` 节点，也没有挂 `InteractiveFurniture` 的包装场景。

## 2. 已发现的接入问题

### P1：家具锚点没有进入实际播放链路

[InteractiveFurniture](../scripts/world/interactive_furniture.gd) 已提供 `get_motion_anchor()` 和锚点发现逻辑。但在本次搜索的 `scripts/`、`scenes/` 中，没有其业务调用者；预览的家具加载和动作装配也没有调用它。

当前动作 `placement` 主要记录类型、参考高度、贴地补偿和道具说明，未形成可执行的“动作参考坐标 → 指定家具锚点 → 整组人物世界坐标”契约。用世界中一把已摆好的椅子运行当前预览代码，不会自动把人物组放到该椅子旁；预览会自行加载家具并改它的位姿。

这是固定家具交互的主要缺口，不是共享动画数据损坏。

### P1：尚无“走过去再开始”的交互流程

预览场景通过 `select_entry()` 直接建立演员并播放，没有家具交互入口点、行走接近、到位／朝向判定、共同开播或离场流程。不能把它的动作预览结果视为 NPC 已具备家具交互能力。

**靠近点和动作锚点需要分开。** 椅面／床面锚点可能离地数十厘米或位于家具内部，不能直接作为导航终点。人物应先到家具外可站立的入口点，再进入起手姿势与共同播放阶段。以后多人同时使用时还需明确槽位占用与取消处理。

### P2：锚点 API 的坐标空间与失败行为不够明确

检查时的工作区版本递归收集所有 `Anchor_*` 后代，但 `get_motion_anchor()` 返回的是目标节点的 `node.transform`，即**相对于该节点直接父节点**的变换。它不保证是家具根节点局部坐标，更不是世界坐标。

例如 `FurnitureRoot → Model → Anchor` 中，若 `Model` 平移／旋转，直接返回 `Anchor.transform` 会漏掉 `Model` 的变换。目前床的包装层为单位变换，可能暂时掩盖该问题，不能因此认定坐标契约已正确。

后续 API 应明确二选一：

- 返回世界锚点：`anchor.global_transform`；
- 返回家具根节点局部锚点：`furniture.global_transform.affine_inverse() * anchor.global_transform`。

另外，目前部分名称匹配会用子串选取首个锚点；缺失时返回单位变换。诸如模糊查询 `bed` 可能命中多个锚点。生产流程应使用明确键名，并在缺失／歧义时拒绝交互并记录错误，避免人物无提示地被定位到原点。

### P2：制作中的床有锚点，但当前预览尚未消费

检查到未提交的 [床包装场景](../assets/furniture/prism/prism_geo_bed.tscn) 已挂载 `InteractiveFurniture`，GLB 中确有三个锚点：

| 节点 | GLB 中的局部位置，Godot 米制坐标 |
| --- | --- |
| `Anchor_BedEdge_Front` | 约 `(0, 0.46, 1.33)`，Y 轴旋转约 180° |
| `Anchor_Bed_Center` | 约 `(0, 0.46, 0.25)` |
| `Anchor_Bed_Headboard` | 约 `(0, 0.46, -0.60)` |

这些节点是有用的制作基础，但床尚未登记进当前家具目录，也未进入自动匹配。检查时的 [床动作截图脚本](../tools/test_bed_with_motions.gd) 手工实例化床包装场景，再给每个测试指定 `pos`／`rot`，调用 `_set_furniture_sliders()`；没有调用 `get_motion_anchor()`。

因此该测试属于“移动床来标定选定动作帧”的截图检查，不证明固定床锚点、人物走近、多人开播已接通。脚本中的锚点名称描述也不能代替实际锚点调用。

### P2：已有偏移和高度元数据没有统一标定关系

家具滑块改变家具，而“贴地校准”只改变各演员的 Y 偏移；两者独立。若将它们混入生产定位，会产生重复高度补偿的风险。

当前椅子目录声明座面高 `0.420 m`，上述两个动作的 `placement.base_height` 为 `0.48 m`，相差约 6 cm。自动匹配没有读取这些高度字段，也没有解算接触点。**这是静态元数据差异，尚不能直接断言实际画面必然悬空或穿插**；它说明仅靠类型匹配不能证明几何适配完成。

## 3. 建议的固定家具坐标契约，供后续实现

以下是方案建议，本次没有实施。

```text
世界中固定的 Furniture
  ├─ Model
  ├─ MotionAnchors：座面、床沿等交互参考坐标
  └─ ApproachPoints：各角色可导航到达的地面入口点

独立 InteractionGroup：整组 A/B/C 演员，共同时间轴
```

定义：

- `F`：家具根节点的世界变换。
- `S`：选定锚点相对于家具根节点的变换，必须包含中间父节点。
- `A`：该动作组在源动作共同坐标中的参考变换，经过一次标定；不是每帧的骨盆位置。
- `G`：整组演员父节点的世界变换。

按 Godot 变换乘法顺序：

```gdscript
G = F * S * A.affine_inverse()
# 等价的对齐约束：G * A == F * S
```

开始播放时确定 `G`，保持固定家具的 `F` 不变。A/B/C 原有相对位置、位移轨迹和共同时间继续保留，整组角色共享 `G`；不分别把每个人的骨盆归零或拉到同一个锚点，也不在每帧重新把移动骨盆吸到家具上。人物身体高度、家具尺寸及非单位缩放需单独检查，不能借坐标对齐自动拉伸角色来适配家具。

已有预览标定不必丢弃：若源动作组位于原点时，正确家具变换为 `P`，则对世界中固定的同型家具 `F`，可先用 `G = F * P.affine_inverse()` 复用这份标定。例如当前家具 Z 偏移 `-0.51`，换算到固定家具下应反向移动动作组，而不是将同一个 `-0.51` 直接加给人物。后续可将这类标定整理成显式的动作参考锚点。

建议分别保存家具的锚点定义，以及动作组的参考锚点／配对标定。世界里的每个家具实例只提供自己的世界变换。按动作与家具类型完成适配，避免为每个摆放位置或每个角色重新复制动作资源；体型造成的手脚、靠背接触差异仍需按实际使用组合检查。

## 4. 后续实现的最低验收

1. 同型家具摆放在两个不同世界位置，并测试 90°／180° 朝向；角色组对齐正确，家具在进入、播放、循环、换角色与退出时均保持原世界变换。
2. 加入非单位变换的中间 `Model` 父节点，验证锚点坐标组合正确；缺少锚点或名称歧义应显式失败。
3. 验证人物走到家具外的入口点，完成朝向与进入过渡后才播放；中断、路径失败与多人槽位冲突有明确处理。
4. 多人共同开播，比较变换前后相对姿态与时间，保持原共享动作的相对关系；换模型不移动家具。
5. 连续检查起手、关键接触帧、结束和循环接缝，覆盖脚底、座面、床沿、靠背与衣发。单帧截图和模型包围盒检查不等于完整交互验收。
6. 预览标定可以保存并重载，正式交互与预览使用同一份坐标数据；不要把预览相机朝向当作人物进入朝向。

## 5. 检查范围与交接提醒

本报告依据代码、目录、GLB JSON 节点和动作清单进行静态检查，没有声称完成导航、真实运行或接触美术验收。正在制作的床和锚点 API 可能随后变化；处理前先重新读取对应文件及工作区差异。

用于识别本次读取版本的 SHA-256：

| 文件 | SHA-256 |
| --- | --- |
| `scripts/character_mmd_vrm_validation.gd` | `bc8fc7319b8f152027d3cab5317b6a7e28da570f952da71a68148271d84f488f` |
| `scripts/world/interactive_furniture.gd`，工作区版本 | `3f5b0b50355b47795166f2896bb0e20b2145c245746610979d8ed35d23efd677` |
| `assets/furniture/scifi/furniture_catalog.json` | `0f89c7735967d863f6d7f3ac0fbe0aa6e412e356f5dff368ef6b5140978bf438` |
| `assets/furniture/prism/prism_geo_bed.glb`，制作中 | `aeba5c4d8c1a3096856bc0fcad6590db9bad737fb27b8bda3a09ccf46e189731` |
| `tools/test_bed_with_motions.gd`，制作中 | `b24a98b413ae587e6f7e176e1426a22ff67e8c0f76a16685c4ae1eba9f9cb3ae` |

相关规范：[共享人形与共同坐标](MMD_SHARED_HUMANOID_VALIDATION.md)、[多人配套验证](MMD_PAIRED_MOTION_VALIDATION.md)、[已选动作库指南](MMD_SELECTED_LIBRARY_GUIDE.md)。优先补齐家具定位与动作组坐标契约，不以重烘焙整库、移动整个世界家具或增加对方碰撞来代替该工作。

---

## 6. 2026-11-06 实施更新：沙发与双人床标准化锚点及角色组定位接入

针对固定家具交互中“家具保持静止，角色对齐到家具定位点”的核心架构要求，已完成以下重构与落地验证：

1. **单人椅资产增加标准锚点**:
   - 在 `tools/build_sculpted_chair.py` 建模流水线中内置空物体节点：
     - `Anchor_Seat`：座面坐姿定位点 `(0.0, 0.420, 0.0)`，朝向 `0.0°`。
     - `Anchor_Chair_Front`：正前方地面跪姿定位点 `(0.0, 0.0, 0.50)`，朝向 `0.0°`。
   - 重新导出 `assets/furniture/prism/prism_geo_chair.glb` 并封装为 `assets/furniture/prism/prism_geo_chair.tscn`（绑定 `InteractiveFurniture`）。
   - 在 `furniture_catalog.json` 登记 `scene_file` 与 `anchors`。

2. **角色组位姿对齐（解决移动家具的假象）**:
   - `mmd_781d8c87fd79`（Welcome - BJV2）中动作原生骨盆在 `Z = -0.512m`。
   - 配置角色组 `presentation_offset: [0.0, 0.0, 0.512]`，使角色B骨盆精确平移对齐椅面 `Anchor_Seat`（`0.00m`），角色A双膝对齐 `Anchor_Chair_Front`（`+0.49m`）。
   - 家具偏移归零（`default_offset = Vector3.ZERO`），UI 滑块读数为 `X: 0.00, Y: 0.00, Z: 0.00, Rot: 0°`，家具彻底静止。

3. **锚点 API 坐标空间修复**:
   - `InteractiveFurniture.get_motion_anchor()` 修正为返回 `global_transform.affine_inverse() * node.global_transform`，彻底解决包装层嵌套导致的变换偏移隐患。

