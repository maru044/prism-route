# 固定动作下载清单与覆盖表

日期：2026-10-08。当前基础动作测试固定使用下列 9 个文件；不再从整个仓库临时挑选。

文件合计 **14,118,476 字节（13.46 MiB）**；包含 **184 个源片段**，本轮明确选择 **42 个片段**。
每个选中片段已经从实际二进制中核对名字或唯一动画索引、非零时长与轨道；这不代表实机播放、美术风格或重定向已经通过。

## 1. 要下载的具体文件

| 编号 | 文件／下载直链 | 来源 | 大小 | 状态 |
| --- | --- | --- | ---: | --- |
| D01 | [human-addon-animations.glb](https://raw.githubusercontent.com/Mesh2Motion/mesh2motion-app/653a9698f5f315523072f1c3ff3496100401317b/static/animations/human-addon-animations.glb) | [Mesh2Motion](https://github.com/Mesh2Motion/mesh2motion-app/blob/main/static/animations/human-addon-animations.glb) | 5,292,804 字节 | 已取得并检查 |
| D02 | [human-base-animations.glb](https://raw.githubusercontent.com/Mesh2Motion/mesh2motion-app/653a9698f5f315523072f1c3ff3496100401317b/static/animations/human-base-animations.glb) | [Mesh2Motion](https://github.com/Mesh2Motion/mesh2motion-app/blob/653a9698f5f315523072f1c3ff3496100401317b/static/animations/human-base-animations.glb) | 5,656,648 字节 | 已取得并检查 |
| D03 | [human-mocap-animations.glb](https://raw.githubusercontent.com/Mesh2Motion/mesh2motion-app/653a9698f5f315523072f1c3ff3496100401317b/static/animations/human-mocap-animations.glb) | [Mesh2Motion](https://github.com/Mesh2Motion/mesh2motion-app/blob/653a9698f5f315523072f1c3ff3496100401317b/static/animations/human-mocap-animations.glb) | 2,025,372 字节 | 已取得并检查 |
| D04 | [idle-01.vrma](https://raw.githubusercontent.com/SanHsien/voxavatar/2a757396fe85b995630385794ad0b8c196a29b9f/public/assets/animations/idle-01.vrma) | [VoxAvatar 收录的作者 VRMA](https://booth.pm/ja/items/6412084) | 95,888 字节 | 已取得并检查 |
| D05 | [speaking-01.vrma](https://raw.githubusercontent.com/SanHsien/voxavatar/2a757396fe85b995630385794ad0b8c196a29b9f/public/assets/animations/speaking-01.vrma) | [VoxAvatar 收录的作者 VRMA](https://booth.pm/ja/items/6412084) | 37,208 字节 | 已取得并检查 |
| D06 | [walk.vrma](https://raw.githubusercontent.com/SanHsien/voxavatar/2a757396fe85b995630385794ad0b8c196a29b9f/public/assets/animations/walk.vrma) | [VoxAvatar 收录的作者 VRMA](https://booth.pm/ja/items/7861818) | 66,604 字节 | 已取得并检查 |
| D07 | [run-slow.vrma](https://raw.githubusercontent.com/SanHsien/voxavatar/2a757396fe85b995630385794ad0b8c196a29b9f/public/assets/animations/run-slow.vrma) | [VoxAvatar 收录的作者 VRMA](https://booth.pm/ja/items/7861818) | 48,864 字节 | 已取得并检查 |
| D08 | [review-phone.vrma](https://raw.githubusercontent.com/SanHsien/voxavatar/2a757396fe85b995630385794ad0b8c196a29b9f/public/assets/animations/review-phone.vrma) | [VoxAvatar 收录的作者 VRMA](https://booth.pm/ja/items/5527394) | 281,528 字节 | 已取得并检查 |
| D09 | [drink-water.vrma](https://raw.githubusercontent.com/SanHsien/voxavatar/2a757396fe85b995630385794ad0b8c196a29b9f/public/assets/animations/drink-water.vrma) | [VoxAvatar 收录的作者 VRMA](https://booth.pm/ja/items/5527394) | 613,560 字节 | 已取得并检查 |

GitHub 链接固定到提交，JSON 同时记录 SHA-256、完整动画列表、作者和授权地址。无需克隆仓库、安装桌面应用或下载整个 Sachi 包。

上述所选动作均按原作者／资产声明采用 CC0；Mesh2Motion 的代码 MIT 和资产 CC0 是不同的许可证。
[Mesh2Motion 资产条款](https://github.com/Mesh2Motion/mesh2motion-app/blob/653a9698f5f315523072f1c3ff3496100401317b/LICENSE-CC0.MD)。

VRMA 原作者来源：

- [sashii 待机／说话](https://booth.pm/ja/items/6412084)
- [sashii／JenJell 步行／慢跑](https://booth.pm/ja/items/7861818)
- [rerofumi 手机／喝水](https://booth.pm/ja/items/5527394)

## 2. 42 个片段的准确选取表

D01–D03 是多个动作放在一个 GLB 内；下载文件后按以下名字提取。D04–D09 每文件只有一个动画，使用 index 0，不猜测动作名。

| 编号 | 用途 | 文件编号 | 文件内精确片段名／索引 |
| --- | --- | --- | --- |
| A01 | 待机：放松站立 | D01 | `Idle_Subtle` |
| A02 | 待机：倾听站立 | D01 | `Idle Listening` |
| A03 | 待机：抱臂站立 | D02 | `Idle_FoldArms` |
| A04 | 待机：站立说话 | D02 | `Idle_Talking` |
| A05 | 移动：女性步行 | D01 | `Walk_Female` |
| A06 | 移动：女性跑步 | D01 | `Run_Female` |
| A07 | 移动：慢跑 | D02 | `Jog` |
| A08 | 移动：冲刺 | D02 | `Sprint` |
| A09 | 移动：后退步行 | D01 | `Walk_Backwards` |
| A10 | 移动：左横移 | D01 | `Strafe_left` |
| A11 | 移动：右横移 | D01 | `Strafe_right` |
| A12 | 转身：左转90度 | D03 | `Turn_Left_90` |
| A13 | 转身：右转90度 | D03 | `Turn_Right_90` |
| A14 | 转身：左转180度 | D03 | `Turn_Left_180` |
| A15 | 转身：右转180度 | D03 | `Turn_Right_180` |
| A16 | 蹲与跳：蹲姿待机 | D02 | `Crouch_Idle` |
| A17 | 蹲与跳：蹲走 | D02 | `Crouch_Walk` |
| A18 | 蹲与跳：起跳 | D02 | `Jump_Start` |
| A19 | 蹲与跳：空中阶段 | D02 | `Jump_air` |
| A20 | 蹲与跳：落地 | D02 | `Jump_Land` |
| A21 | 坐姿：坐下 | D02 | `Sitting_Enter` |
| A22 | 坐姿：坐姿待机 | D02 | `Sitting_Idle` |
| A23 | 坐姿：坐着说话 | D02 | `Sitting_Talking` |
| A24 | 坐姿：起身 | D02 | `Sitting_Exit` |
| A25 | 互动：招呼 | D01 | `Greeting` |
| A26 | 互动：一般交互 | D02 | `Interact` |
| A27 | 互动：桌面取物 | D02 | `PickUp_Table` |
| A28 | 互动：食用表现候选 | D02 | `Consume` |
| A29 | 互动：打电话 | D02 | `Idle_TalkingPhone` |
| A30 | 地面与运动：冥想 | D01 | `Meditate` |
| A31 | 地面与运动：疲倦跪姿 | D01 | `Kneeling Tired` |
| A32 | 地面与运动：睡眠 | D01 | `Sleeping` |
| A33 | 地面与运动：俯卧撑 | D01 | `Pushup` |
| A34 | 地面与运动：开合跳 | D01 | `Jumping Jacks` |
| A35 | 房车场景：驾驶 | D02 | `Driving` |
| A36 | 房车场景：跪姿修理 | D02 | `Fixing_Kneeling` |
| A37 | 对照与补充：另一种站立待机 | D04 | 唯一动画 index 0 |
| A38 | 对照与补充：另一种说话 | D05 | 唯一动画 index 0 |
| A39 | 对照与补充：另一种步行 | D06 | 唯一动画 index 0 |
| A40 | 对照与补充：另一种慢跑 | D07 | 唯一动画 index 0 |
| A41 | 对照与补充：看手机 | D08 | 唯一动画 index 0 |
| A42 | 对照与补充：喝水 | D09 | 唯一动画 index 0 |

## 3. 齐全范围与明确缺项

**基础测试片段已经覆盖待机、走跑、转身、蹲走、三段跳跃、坐下／坐姿待机／坐着说话／起身、互动与房车场景。**
只有 Walk_Female／Run_Female 明确以女性动作命名，其他动作是通用或风格对照；尚未证实整套符合用户希望的女性表现。
动作有进入／保持／退出的组合只在坐姿和跳跃等已列名的组内确认；不能扩大成所有状态过渡均已齐全。

之前讨论的柔韧动作仍作为必需缺项跟踪：

| 缺项 | 对应来源 | 状态 |
| --- | --- | --- |
| 下腰：进入／保持／退出 | [Morro Motion Yoga MoCap 02](https://www.fab.com/listings/baeb5207-7e6a-4d80-8468-5d34974e8332) | 商品说明包含后弯序列，但站姿到轮式及完整过渡未核实；付费，未下载 |
| 纵叉：进入／保持／退出 | [XSTAGE Yoga #2_Stretching](https://www.fab.com/listings/deed2056-a58d-4eac-91f8-2686b7afb4ae) | 商品清单列出 Front and Back Leg Split；具体过渡、独立 FBX 交付与用途条款需确认，未下载 |
| 横叉：进入／保持／退出 | 暂无核实的独立下载来源 | 未补齐；不以纵叉、站立抬腿或冥想代替 |

以上付费包是待核对来源，不是已确定购买清单。未获得文件前不填写虚构片段名、大小或校验值。
站立与蹲姿切换、睡眠／冥想进入退出、行走启停也没有确认独立过渡片段；后续需通过 AnimationTree 过渡验证或制作补充动画。
因此当前不能称为“全游戏完整动作库”或“柔韧动作已齐全”。

## 4. 本机位置与后续取用

`D:\Prism Route\research\motion_candidates\2026-10-08`

该目录当前已有上述 9 个文件；以前的 inspection.json 及仓库 INDEPENDENT_MOTION_SAMPLE_MANIFEST.json 保留上一轮 7 样本历史记录，本轮状态以 download_plan.json／MOTION_DOWNLOAD_MANIFEST.json 为准。

下一轮直接按 JSON 的 files 下载或核对 hash，再按 actions 的 file_id + clip_name／index 提取。
先预览 A05／A06／A01（女性走、女性跑、轻微待机），再验证 A21–A24 坐姿组合与 A12–A15 转身。
VRMA 如不能直接由现有导入器处理，再转为目标骨架上的标准 GLB；本轮不接入默认人物。
