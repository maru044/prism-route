# 刻晴与花火：袖尾动态修正

日期：2026-10-09。Godot 4.7.2 / Blender 5.1.1。

## 原因与处理

两套 PMX 都有袖尾骨链和实际蒙皮权重。原转换仅导出骨架与蒙皮，没有将 MMD 服装物理转换成 VRM 弹簧，所以袖尾随手臂整体旋转，呈现硬板状。

- 刻晴使用左右 `袖_0_1` 链；花火使用 `yx__1` 与 `zx_0_1` 链。
- 保留各链首段为固定连接，从下一段开始配置 `VRMC_springBone`。每个模型各两条动态链；刻晴每链 7 个关节，花火每链 15 个关节，均包含原有末端骨。
- 袖尾受重力下垂，并通过阻尼产生延迟摆动。首个动态关节较硬，后续关节较软。
- 每个模型添加 9 个身体胶囊碰撞体，跟随骨盆、躯干、上臂、前臂和大腿，缓解袖尾穿入身体。
- 花火 20 个袖口分支根骨原先挂在肩部辅助骨上，现改挂到对应上臂；保留袖口网格和权重，让它跟随手臂运动。袖口短分支没有加入自由摆动，以保持结构。
- 导出的修复版 VRM 自带弹簧与碰撞定义。模型骨骼名称、数量、人体静止姿态和原 42 段动作轨道不变，不需要重新烘焙人体动作。
- 修正物理开关：原开关只禁用控制节点，无法停用挂在 Skeleton3D 下的原生模拟器；现在同时控制模拟器的 `active`。
- 切换动作、重播和拖动时间轴时重建袖尾初始状态，避免沿用上一姿势的惯性。

`tools/mmd_sleeve_springs.py` 是经这两套模型核对的转换配置，不按模糊名称自动处理未知模型。

## 检查入口

- 刻晴：`res://scenes/character_model_import_test.tscn`。
- 花火：`res://scenes/character_huahuo_import_test.tscn`。

两场景默认开启左侧“服饰物理”，可关闭以比较同一个修复模型的僵硬袖尾。上方“处理前”仍使用原始腿部权重版本，不含袖尾修正；“处理后”包含腿部和衣袖修正。版本切换保留物理开关状态。

甘雨原动作场景仍默认关闭物理。主场景入口未改动。

## 已完成验证

- 两套模型各 42 段动作，以及处理后 → 处理前 → 处理后的切换回归通过。
- 甘雨原 42 段动作回归通过。
- 待机、女性步行、女性跑步、A25 和坐姿，分别模拟 180 帧，检查模拟后的关节姿态有限、链段没有拉长、袖尾相对关闭物理确实改变姿态。
- 额外连续运行步行和跑步，各 240 帧；检查循环过程中姿态有限。
- 关闭物理与切换模型后的关闭状态通过；人体静止骨架和动作路径检查通过。
- Forward+ / D3D12 / RTX 5070 Ti 实机截图和连续步行对比已生成。

报告：`docs/MMD_VRM_SLEEVE_TEST_REPORT.json`。关节长度误差小于 0.001 mm，这是数值长度约束检查，不代表布料碰撞精度。报告中的袖尾位移是相对僵硬姿势的距离，不能当作摆动振幅。

本地对比文件：

- `.model_import_build/sleeves_comparison_labeled.png`：站立、步行、坐姿，两模型左右对照。
- `.model_import_build/keqing_sleeves_walk.gif`。
- `.model_import_build/huahuo_sleeves_walk.gif`。

## 实际限制与备用方案

当前为骨链模拟，不是完整布料模拟。袖子有下垂和随动作摆动，但宽布面没有自碰撞；坐姿、贴身手势和大幅转身仍可能出现局部穿插。身体胶囊只能缓解，不能保证所有 42 段动作完全没有穿模。头发、裙摆、地面和座椅的布料碰撞仍未配置。

目前保留完整袖子用于检查。如果后续某些动作无法通过参数和碰撞调整满足效果，再使用用户授权的袖尾隐藏方案：按袖尾骨权重划分自由布片、保留连接处与袖口，将隐藏做成可切换变体；保留完整动态版本供后续替换。

## 复现

先按原模型文档构建和导入两份修复 VRM，再运行：

```powershell
$godotExe = 'D:\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
$pythonExe = 'C:\Users\PC\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $godotExe --path . --fixed-fps 60 --disable-vsync --script tools/verify_sleeve_dynamics.gd -- --capture
& $godotExe --path . --fixed-fps 60 --disable-vsync --script tools/capture_sleeve_motion.gd
& $godotExe --headless --path . --script tools/inspect_motion_skeleton.gd -- --model=res://assets/characters/import_tests_local/keqing/keqing_fixed.vrm --output=res://.model_import_build/keqing_sleeve_rest.json
& $godotExe --headless --path . --script tools/inspect_motion_skeleton.gd -- --model=res://assets/characters/import_tests_local/huahuo/huahuo_fixed.vrm --output=res://.model_import_build/huahuo_sleeve_rest.json
& $pythonExe tools/summarize_sleeve_review.py
```

静止骨架回归比较使用本轮调整前保存的 `keqing_rest.json` 与 `huahuo/huahuo_rest.json`。新检出环境可以运行动态验证和截图；要复现历史骨架比较，应先从上一提交导入并保存对应静止骨架。
