# 崩坏：星穹铁道花火：MMD → Blender → VRM → Godot 验证

日期：2026-10-09。沿用刻晴的普通动作技术测试流程，新增独立花火配置和测试场景。

## 样本与处理

使用用户目录 `D:\模型\20261008` 中的 `花火3.0.pmx`，不导入同目录的剑玉附件。
模型附带说明记载版权为 miHoYo、模型编辑为神帝宇；导出的 VRM 保留对应署名和使用限制。本轮为本地普通动作转换测试，测试模型不能据此视为已获准用于商业或成人作品的正式资产。

- Blender 5.1.1，沿用安装的 mmd_tools 与 VRM 插件；Godot 4.7.2。
- 实际审查发现腿部权重位于 `足D / ひざD / 足首D / 足先EX`；对应标准组没有非零权重。
- 六对 D 骨与标准骨关节位置一致，位置差全部为 0。
- 左右 D 组分别转移到标准组；EX 权重逐顶点加到脚踝，不覆盖已有脚踝权重。
- 清除 MMD IK 和附加姿态约束。Hips 映射到 `腰`；袖口辅助骨的挂接修正见后续袖尾记录。
- 使用与刻晴一致的 MToon 材质参数，基础色、阴影纹理和主贴图均随 VRM 内嵌。
- 分别生成处理前和处理后 VRM。处理后额外包含袖尾物理和袖口挂接修正；比较腿部时可关闭服饰物理。
- 从花火在 Godot 中的静止骨架重新烘焙全部 42 段动作；不复用刻晴或甘雨的骨架轨道。

## 已完成的转换数值检查

- Blender 网格：29,094 顶点、766 根导入骨骼、40 个材质。
- 权重转移前后逐顶点总权重最大误差：0；没有新增零权重顶点。
- 左脚踝旋转 25°：处理前网格移动顶点数为 0；处理后 1,506 个顶点位移超过 0.1 mm，最大位移约 6.58 cm。
- 左右足先 EX 分别转移 1,085 / 1,083 条顶点权重；左右脚踝处理后均有实际权重。
- Godot 修复版静止骨架：719 根骨骼。Blender 导出时会处理内部辅助骨，数量不要求与导入骨架相同。
- 源 PMX 的 SHA-256 在转换前后相同，没有覆盖源文件。

Godot 动作验证结果保存在 `MMD_VRM_HUAHUO_TEST_REPORT.json`；实机检查与当前结论见该文末的验收记录。

## 检查入口与操作

场景：`res://scenes/character_huahuo_import_test.tscn`。

左侧动作目录与甘雨、刻晴一致，包括全部 42 段动作，可搜索、筛选、暂停、调速、拖动时间轴和调整参考椅。顶部切换处理前后模型，保持当前动作、播放速度和暂停位置。右键旋转，滚轮缩放。

原刻晴入口 `res://scenes/character_model_import_test.tscn` 保留，主项目入口不变。

## 文件位置

- VRM 和动作：`assets/characters/import_tests_local/huahuo/`。
- Blender 副本、静止骨架、日志和实机截图：`.model_import_build/huahuo/`。
- 实机动作总览：`.model_import_build/huahuo/huahuo_contact_sheet.png`。
- 小体积验证报告：`docs/MMD_VRM_HUAHUO_TEST_REPORT.json`。

## 复现

在项目根目录运行 PowerShell：

```powershell
$blenderExe = 'D:\blender\blender.exe'
$godotExe = 'D:\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
$pythonExe = 'C:\Users\PC\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $blenderExe --background --python tools/build_mmd_vrm_review.py -- --profile huahuo
& $godotExe --headless --editor --path . --quit
& $godotExe --headless --path . --script tools/inspect_motion_skeleton.gd -- --model=res://assets/characters/import_tests_local/huahuo/huahuo_fixed.vrm --output=res://.model_import_build/huahuo/huahuo_rest.json
& $pythonExe tools/build_motion_review.py --target .model_import_build/huahuo/huahuo_rest.json --dest assets/characters/import_tests_local/huahuo/motions
& $godotExe --headless --path . --script tools/verify_model_import.gd -- --model=huahuo
& $godotExe --headless --path . --script tools/verify_model_import.gd
& $godotExe --headless --path . --script tools/verify_motion_review.gd *> '.model_import_build/ganyu_regression.log'
& $godotExe --path . --script tools/capture_model_import.gd -- --model=huahuo
& $pythonExe tools/summarize_model_import.py --model huahuo
& $godotExe --path . res://scenes/character_huahuo_import_test.tscn
```

仅检查已生成资源时，运行最后一条即可。

## 当前范围

衣袖已配置 VRM 弹簧，详见 [袖尾动态记录](MMD_VRM_SLEEVE_DYNAMICS.md)。头发和裙摆尚未配置动态；保留的形变目标尚未绑定表情、眨眼和口型。MToon 沿用刻晴测试参数，后续仍需调色。场景没有新增足部 IK、接地修正或道具约束。

验证通过代表骨架、权重转移、导入和动作播放流程可运行；最终接地、手部和服装效果仍需人工逐动作检查。

## 本轮验收记录

- 两份 VRM 均包含实际网格、718 个蒙皮关节、40 个 MToon 材质、5 张内嵌主贴图和 66 个形变目标。
- Godot 对处理后 → 处理前 → 处理后的三次切换，分别验证全部 42 段动作：所有轨道能找到目标骨骼，五个时间采样点姿态均有限，失败项为空。
- 搜索、上一段／下一段、暂停、重播、时间轴和循环控件通过；版本切换保留当前动作、暂停时间和播放速度。
- 刻晴全部 42 段动作及处理前后切换回归通过；甘雨原有全部 42 段动作回归通过。
- Forward+ / D3D12 / RTX 5070 Ti 渲染检查了步行处理前后，以及待机、跑步、蹲姿、坐姿、冥想、睡眠、俯卧撑、驾驶、看手机、喝水的代表帧。
- 实机可见处理后腿部屈伸与脚部运动。衣袖动态已在后续测试中补齐；裙摆、头发及地面和坐姿的布料穿插仍需处理，材质颜色仍偏亮。
