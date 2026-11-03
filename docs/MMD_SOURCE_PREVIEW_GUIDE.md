# Blender 源动作选片器：先浏览，再决定烘焙

2026-11-03。用于查看现有 VMD 源库、记录要制作的片段，不执行正式动画烘焙。

## 1. 打开与使用

**双击项目中的 `tools/run_mmd_source_preview.cmd`。** 它会打开独立 Blender 窗口，加载项目内侧栏插件和已保存的预览工程，不依赖 Codex/MCP 持续在线。

也可以在项目根目录的 PowerShell 运行：

```powershell
./tools/run_mmd_source_preview.ps1
# Blender 路径不同的机器：
./tools/run_mmd_source_preview.ps1 -BlenderPath 'D:/blender/blender.exe'
```

预览文件为工作区 `research/mmd_source_preview_20261103/mmd_source_browser.blend`。
窗口标题为 `mmd_source_browser`。原来的 `mmd_loop03_roles` 窗口和 Godot 验证场景无需关闭。

在 3D 视图右侧选择 **“动作选片”** 标签；侧栏隐藏时，鼠标放在 3D 视图按 N。可拖动侧栏左边缘加宽。建议只开一个选片窗口，避免同时修改同一份清单。

使用顺序：

1. 搜索或选择目录。列表包含 **86 个目录候选、212 条人体动作/姿态轨道**。
2. 检查角色 A/B/C 的源文件。默认建议通常是一个主角色和一个伙伴普通版；不需要的槽位选“不加载”。
3. 点击 **“加载预览”**，再点击 **“播放／暂停”**。底部使用 Blender 原生时间轴，可以拖动、逐帧或跳到首尾。
4. 长动作只想保留一段时，在满意位置点“当前帧→开始／结束”，或输入起止帧。播放器按此范围循环，**没有删改原 VMD**。
5. 填写备注，点击 **“保留／待定／跳过”**。它只写入选片记录，不会立即烘焙。

同一组轨道可以记录多个不同范围，不互相覆盖。侧栏“本目录已记录片段”可点击召回最近五条；完整记录保存在 JSON 中。目录上的 ✓ / ? / × 是该目录记录的汇总：某片段保留并不表示该目录所有版本都入选。

选到新目录或改了角色轨道后，必须重新加载，才能给它作记录；面板同时显示“画面当前加载”的素材，避免用旧画面误标新素材。

## 2. 记录存在哪里

正式清单：[motion_selection/mmd_source_selection.json](motion_selection/mmd_source_selection.json)。

筛选优先级、用户预览反馈及可读名单见 [选片 README](motion_selection/README.md)。选片后运行 `python tools/update_mmd_selection_readme.py` 更新 README 汇总，不修改正式选择。

记录包括源目录、角色位与 VMD 相对路径、源 SHA256、帧率、起止帧、备注、保留/待定/跳过状态，以及是否允许过特殊骨架粗略预览。默认清单为空，没有替用户预选任何动作。

选片按钮立即以临时文件加原子替换方式保存 JSON，不必保存 `.blend` 才能保住选片结果。Blender 的 Ctrl+S 用于保存当前布局、播放头和已载入场景；即使不保存场景，选片 JSON 仍在，下次可点击记录召回。

后续批量转换读取 `takes` 中 `decision == "KEEP"` 的条目；`rough_special_preview == true` 不能直接当作技术验收通过。批量转换读取端尚未接入本清单，不会因为点击保留就启动后台工作。

## 3. 预览的实际含义

这是 **VMD 关键帧直接导入参考 PMX，由 Blender 实时求解 IK 和追加变换**。没有调用 NLA Visual Bake，没有导出 GLB，没有生成每目标角色的 Godot 动作。载入 VMD 产生的临时 Action 是原生播放所需，切换时清理自己的旧 Action。

- 蓝 A、橙 B 使用现有刻晴、甘雨 PMX 参考模型；紫 C 按需复用第一种参考体型，便于检查额外角色位。
- 双人/多人保留共同的源帧号、坐标和 30 FPS，不分别居中、拉伸时长或删除第三人。
- 短轨到结束后保持末姿态。不同轨长会提示，不能据此认定一定是正确配套。
- 只预览身体动作。**不加载原相机、道具、Morph 表情、衣发物理**；视图采用简化颜色，方便看动作和角色位。
- 含道具轨道的目录会提示。家具、车辆等未加载时，悬空或接触缺支撑可能来自原场景依赖，不能因此判断动作本身错误。
- 目录是候选容器，不是已确认演出组。Short Loops、替代模型、普通/IK 版可能混放；下拉选择需人工确认。

全库共有 285 个 VMD；未进入人体列表的 73 个文件包括相机、道具/辅助、服装姿态和独立 Morph，不能把它们作为人体动作加载。

Loop 27 标为三人候选并提供第三槽位建议；Motorcycle Photoshoot 2nd pose 另有第 0 帧固定人体姿态，需要确认第三人或替代安排。第三槽位不会因为零时长自动删除。

有必要控制骨缺失的文件默认阻止载入，优先选择普通版。若手动勾选“允许粗略预览特殊骨架”，只用于了解大体姿势；控制器、外部父级缺失可能使手臂等明显错误，记录会保留此标记。没有对本库特殊控制器做自动还原。

参考体型并非原作者全部模型，**选片通过不等于最终 VRM 的接触与服装质量通过**。入选后才走 [共享人形动作流程](MMD_SHARED_HUMANOID_VALIDATION.md) 并作最终角色检查。

## 4. 本次验证结果

程序报告：[validation/mmd_source_browser_20261103/verification.json](validation/mmd_source_browser_20261103/verification.json)。

| 检查 | 结果 |
| --- | --- |
| 目录与人体轨道 | 86 / 212，来源为已审计的 285 VMD 全库 |
| Loop 03 A 源参考位置 | 143 次比较，最大误差 0 |
| Loop 03 B 源参考位置 | 121 次比较，最大误差 0 |
| 首次双轨加载（模型已载入） | 本次约 0.72 秒；不代表所有长动作耗时 |
| 原 MMD 约束 | A 50、B 52，载入/切换后保持 |
| 多个片段保存与召回 | 测试清单通过 |
| 非 480 帧片段 | 610 帧范围通过 |
| 第三角色固定姿态 | 第 0 帧姿态保持，不删除 |
| 特殊控制器预检 | 修改当前动作之前阻止不支持的源 |
| IK 状态变化后重载 | 约束与默认状态正确恢复 |
| 连续重复加载 | 自有 Action 数量为 2、2、2、2，没有持续累积 |
| 范围越界 | 自动限制到源长度 |
| 输入文件保留 | 参考 PMX 与测试源 VMD 哈希未变 |
| 正式烘焙 | 0 次 |

独立窗口已实际检查侧栏显示、加宽、播放、暂停和复位；示例播放时界面显示 30 FPS。未声称所有 212 条素材均已逐条播放或达到同样性能。

测试用的保留/待定记录仅在 `validation/mmd_source_browser_20261103/selection_fixture.json`，不会写进正式选片清单。

## 5. 制作与维护要点

| 文件 | 用途 |
| --- | --- |
| `tools/run_mmd_source_preview.cmd` | 本机双击入口 |
| `tools/run_mmd_source_preview.ps1` | 可传 Blender 路径的启动入口 |
| `tools/mmd_preview/blender_source_browser.py` | 侧栏、参考模型、原生载入、切换清理和记录 |
| `tools/mmd_preview/catalog.json` | 轻量源库索引，无几何或动作烘焙结果 |
| `tools/mmd_preview/preview_config.json` | 源模型、目录、清单、预览工程路径 |
| `tools/build_mmd_preview_catalog.py` | 从完整审计重建源库索引，不修改选片结果 |
| `tools/mmd_preview/verify_source_browser.py` | 独立 Blender 测试，使用隔离的选片清单 |

新增/移动/修改源动作后，先更新完整审计，再更新索引：

```powershell
python tools/audit_mmd_motion_library.py
python tools/build_mmd_preview_catalog.py
```

然后在侧栏点击“刷新目录与记录”。如果源文件 SHA256 与索引不一致，工具会拒绝静默加载旧版本；更新索引后，旧选片还保留旧哈希，后续转换需重新确认。

修改 Python 工具代码后关闭并重新启动**选片窗口**，无需关闭原工程窗口。只直接打开 `.blend` 不保证加载侧栏；应使用上述启动入口，或在可信的本机 Blender 中执行对应项目脚本。

本机复测：

```powershell
& 'D:/blender/blender.exe' --background --factory-startup --python-exit-code 1 --python 'tools/mmd_preview/verify_source_browser.py'
```

此测试读取源文件，使用独立决策 fixture，最后重建预览 `.blend`；不要在另一选片窗口存在未保存场景更改时重建同一预览文件。正式选片 JSON 不会被测试修改。

关键经验：MMD Tools 会把当前播放头叠加到 VMD 帧号；`margin=0` 不足以保证源零点。**每次加载双方前必须回到第 0 帧**。否则第一次从默认第 1 帧导入会产生一个帧位移，从长动作末尾切换时甚至会错后整段。

清理仅解除当前参考模型的 Action/NLA、复位姿态和 IK；不能提前移除 MMD 约束，也不能随意 `animation_data_clear()` 清掉约束驱动。只回收本工具标记且无用户的 Action，不运行全局 orphan purge。

## 6. 启动权限与原工程保留

MCP 当前安全模式不允许远程注册类/面板或加载外部脚本。经用户明确授权，本工具通过**常规 Blender 启动脚本在独立进程运行**，没有关闭或修改 MCP 安全模式，也没有把脚本注入原工程。

原 `mmd_loop03_roles.blend` 窗口保留；源 VMD 和 PMX 只读。预览 `.blend` 是独立缓存；正式选片 JSON 是需要长期保留的重要制作输入。
