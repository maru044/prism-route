# 配套动作验证：同一场景、两个既有 VRM、共同时间轴

更新：2026-11-03。此文是 [MMD → VRM 重要制作指南](MMD_TO_VRM_PRODUCTION_GUIDE.md) 的双人补充规范。

## 结论与入口

之前的 `Loop 03/Izumi.vmd` 不是完整的独立单人作品；同目录还有配套的 `Kaat.vmd`。
两条角色轨道都覆盖 0–480 帧、30 FPS、16 秒。此前只验证了角色 A，不能据此认定整组配合已经通过。

仍运行 **`scenes/character_mmd_vrm_validation.tscn`**，场景路径没有更换。
它现在是带搜索、人数分类、分组列表和共同时间轴的动作库；“验证样本”中的 `Loop 03` 保留以下专属基线，组内选择整组 / A / B。当前默认是已选库的 Loop 02；11 组中包含已验证的三人组，见 [已选库制作指南](MMD_SELECTED_LIBRARY_GUIDE.md)。

| 角色槽 | 源轨道 | 实际模型 | 源求解骨架 | 实时物理 |
| --- | --- | --- | --- | --- |
| A | `Loop 03/Izumi.vmd` | 现有刻晴 VRM 的物理派生版本 | 刻晴原始 PMX，316 骨 | 21 条链 |
| B | `Loop 03/Kaat.vmd` | 现有甘雨 VRM 的物理派生版本 | 甘雨自己的原始 PMX，315 骨 | 20 条链 |

本文历史配套基线有 **1 组动作、3 个检查项**：双人同步、角色 A 单独检查、角色 B 单独检查；当前列表另有共享动作检查入口。
两个拆分项用于排查，不能把它们登记成两段独立单人动作。
切换拆分视图只改变显示、模拟和相应的碰撞代理，不分别移动角色到原点。

## 本次已验证的内容

以下为程序检查和实际渲染检查的结果：

- 两个模型确实不同，使用不同 Skeleton3D 和各自的重定向动画。
- 主时钟差为 0，播放、暂停、拖动、跳到开头/结尾及大跨度时间步后保持同一时刻。
- 242 次源关节位置比较，最大差异约 0.000878 毫米。
- 121 次两人之间的关节相对向量比较，最大差异约 0.001291 毫米。
- 60 FPS 完整 16 秒，234,240 次物理骨骼/帧检查无非有限值；30、120 FPS 也通过。
- 3 个库检查项及隐藏角色的物理/碰撞停用检查通过。
- 对方碰撞的空间查询：开启时有命中，关闭后为空。
- 固定姿势下比较对方碰撞开/关，60 FPS 链末端最大变化约 0.226 米，证明确实有响应。
- 此响应数值只证明机制生效，不表示变化越大越好。不同帧率下的瞬态结果并不完全相同。
- 原有刻晴单角色重定向与 PMX 网格回归仍通过。

报告位于 [validation/mmd_pair_loop03_20261103](validation/mmd_pair_loop03_20261103/verification.json)，
同目录保存 30、120 FPS 结果、甘雨原资源保留检查和旧网格回归结果。

**接触适配没有标记为成品通过。** 实际双人画面已经查看，局部服饰仍有重叠。
当前通过的是成组加载、时序、坐标和物理机制检查；不等于两套新体型的网格接触已经完全拟合。
场景说明和报告 `contact_fit` 都保留了这一状态。

## 数据与实现

| 文件 | 用途 |
| --- | --- |
| `assets/characters/mmd_validation/paired/catalog.json` | 动作组、角色槽、源轨道、模型/动作/配置绑定及检查视图 |
| `assets/characters/mmd_validation/paired/source_inventory.json` | 多角色轨道候选目录清单，尚未逐组判定 |
| `assets/characters/mmd_validation/paired/ganyu_role_b.tres` | B 轨道，重定向至现有甘雨的实际骨架 |
| `assets/characters/mmd_validation/paired/ganyu_physics.vrm` | 甘雨物理派生版本，保留原网格/蒙皮/材质和二进制数据块 |
| `assets/characters/mmd_validation/paired/ganyu_report.json` | 甘雨映射、物理链、源 VMD 范围及哈希 |
| `assets/characters/mmd_validation/paired/role_b_blender_reference.json` | B 的 Blender 独立求解参考及全帧烘焙误差 |
| `assets/characters/mmd_validation/paired/role_b_vmd_coverage.json` | 原始 B 轨道到甘雨 PMX 的覆盖审计 |
| `tools/build_mmd_paired_validation.py` | 本次第二角色构建、候选扫描和目录生成 |
| `scripts/characters/mmd_partner_colliders.gd` | 对方身体的查询碰撞代理 |
| `tools/verify_mmd_paired_validation.ps1` | 带新报告校验和运行帧数上限的验收入口 |

原有角色实现 `scripts/characters/keqing_mmd_vrm.gd` 增加了
`model_resource`、`motion_resource`、`profile_resource`、`environment_mask` 参数，
因而能用于两种模型；文件名保留以兼容原有刻晴样本。

甘雨 B 轨道的 149 个源 VMD 骨名中有 86 个在目标 PMX 中匹配；32 个多关键帧骨骼全部匹配。
未匹配项主要是源角色专有的静态骨骼，仍应保留清单审计，不能把“动态全匹配”解释为完整原角色还原。
刻晴 A 原有的 3 条动态腕部辅助轨道缺失限制仍然存在。

甘雨使用自己的 20 条头发/服饰链；原 VRM 中无关的单节点人体链没有计入本次衣物验证。
它的网格、蒙皮、材质、纹理、节点和原二进制块保持一致，详见
[甘雨保留性检查](validation/mmd_pair_loop03_20261103/ganyu_preservation.json)。

## 共同时间与共同坐标：后续每组都要遵守

1. 每个角色在自己的控制骨架上求解和烘焙。不能把刻晴的已烘焙骨长直接当成甘雨。
2. 全组使用一致的单位、导入比例、FPS、起始帧和世界轴。本次均为 0.08 比例、30 FPS、0 起始。
3. 由场景计算一次绝对时间 `t`，对每个角色调用 `sample_time(t)`，不分别累积各人的 delta。
4. 不将各段动作分别归一化为 0–1 时长；短轨道应按组定义保留前后静止段或停在末帧。
5. 不对每个角色分别去掉中心位移、旋转或原点偏移。相机可以重新取景，身体坐标不能随诊断视图改变。
6. 不使用原单人世界控制器的 `_center_clip()` 处理成对动作；它会分别移除角色的水平锚点。
7. 场景需要整体摆放时应移动共同父节点，而不是独立重新居中两个人。
8. seek 或明显时间跳跃同时重置两人的模拟历史，避免旧的头发/服饰速度带到另一姿势。

另外，两个人的 **Hips 不一定是同一解剖枢轴**：刻晴映射到 `腰`，甘雨映射到 `センター`。
配对检查采用同语义的源骨骼和 `下半身`、头、手、膝、脚等共同关节；
对方身体的骨盆代理使用左右腿根中点，而不是盲目比较两个 Hips。

## 对方碰撞：作用范围与物理帧时机

此场景用以下专用位：地面 1、角色 A 查询代理 2、角色 B 查询代理 4。
A 的服饰环境查询掩码为 `1|4=5`，B 为 `1|2=3`，不会把自己的查询代理当成对方。
每位角色有 11 个头、躯干及四肢球/胶囊代理，跟随同一时刻的身体骨骼。

这些代理不执行角色移动，也不把两人的身体推开；它们只供头发和服饰的环境查询使用。
身体动作的手部接触、支撑、体型差和穿插，仍需要单独做 IK、姿势修正或其他适配。
骨链碰撞也不等于全布料自碰撞。

Jolt 的运动学目标要经过物理步提交。测试不能在刚发出 `physics_frame` 信号时就假定新位置已经进入空间查询。
本次等待物理步后的 process 帧，再查询空间；同时比较开关前后的链末端响应。
只检查 Node3D 的显示坐标、掩码数值或 UI 勾选状态不够。

层 2/4 是这个独立场景的约定。接入主游戏时需选择未占用的专用层，
并让普通游戏刚体排除这些查询代理，不能不检查就照搬层号。

## 候选目录不是已确认角色数量

扫描得到 **67 个包含多个身体轨道候选的直接子目录**。这不是“已经确认 67 组双人动作”。
其中可能有替代人物、不同模型版本、衣物姿势、道具或额外角色。

例如 `Loop 01` 的多个模型文件不能未经核对就全部实例化为三个参与角色。
后续应给每组建立固定角色槽，再把同槽的替代版本放入变体集合，不能按文件数决定人数。
本次只把已核对的 `Loop 03 / Izumi + Kaat` 登记为完整双人组。

推荐将配套关系与播放视图分开保存：

```text
pack：共同时间轴、共同坐标、源文件哈希、角色槽 A/B、每槽的变体
entry：完整双人、角色 A 诊断、角色 B 诊断
profile：每个实际模型的 rest、映射、物理链、碰撞配置
```

后续每组分开记录：源覆盖审计、时序通过、空间保真通过、接触适配状态、服饰物理状态。
发现穿插应登记待适配；不要因为数值转换误差很小就把接触质量也记成通过。

## 复现与验收

在项目根目录执行；工具路径可用脚本 `-GodotPath` 参数覆盖。

1. A 沿用原始刻晴转换结果。
2. 在 Blender 新场景先运行 `tools/mmd_pipeline/blender_pair_role_b_import_reference.py`，
   再运行 `blender_pair_role_b_reference.py`，生成甘雨自己的 B 轨道骨架 GLB。
3. 用 `tools/inspect_motion_skeleton.gd` 导出原有甘雨 VRM 的实际 rest 到
   `assets/characters/mmd_validation/paired/ganyu_rest.json`。
4. 运行构建与 Godot 重导入，然后验收：

```powershell
python tools/build_mmd_paired_validation.py
$engine = '.current_map_build/runtime/Godot_v4.7.2-stable_win64_console.exe'
& $engine --headless --path . --log-file .godot/mmd_pair_import.log --editor --import --quit
./tools/verify_mmd_paired_validation.ps1
./tools/verify_mmd_paired_validation.ps1 -TestFps 30
./tools/verify_mmd_paired_validation.ps1 -TestFps 120
./tools/run_mmd_vrm_validation.ps1
```

原有启动脚本继续打开同一个场景；没有另建一个替代主入口。
源工程保存于工作区 `D:/Prism Route/research/mmd_pair_validation_20261103/mmd_loop03_roles.blend`。
本构建脚本仍针对当前这一组；新增组时应扩展数据和相应剖面、重新验收，而非假定所有 VMD 都已可用。
