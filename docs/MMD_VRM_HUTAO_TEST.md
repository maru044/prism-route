# 胡桃 MMD → Godot 转换测试

2026-10-11。采用 `D:/模型/20261008/胡桃_by_原神_cd0c876a7e431f6ee7f8cfe74b7a2dda/胡桃.pmx`，沿用刻晴、花火的 PMX → Blender → VRM 1.0 → Godot 流程。

## 使用入口

打开 `res://scenes/character_hutao_import_test.tscn`，在 Godot 中按 F6 运行当前场景。左侧有全部 42 段动作，可搜索、筛选、调速、暂停及拖动时间轴。顶部可切换处理前后模型，并保留当前播放位置和速度。右键拖动旋转，滚轮缩放。

模型与内嵌贴图位于 `assets/characters/import_tests_local/hutao/`，42 段重定向动作在该目录的 `motions/` 下。主游戏入口维持原设置。

## 本次处理与检查

- 导入 18,609 顶点、294 根 Blender 骨骼、21 个材质；VRM 在 Godot 中形成 251 根骨骼。
- 确认左右普通腿骨没有直接权重，D 骨与相应普通骨位置完全一致，执行六组 D → 普通骨权重转移；左右 EX 权重分别有 311 / 334 条，累加到脚踝。
- 所有顶点的总权重最大变化为 0，没有新增零权重顶点。源 PMX 转换前后 SHA-256 相同。
- 左脚踝旋转 25°：修正前 24 个顶点位移超过 0.1 mm，修正后 559 个。胡桃原本有 24 个顶点绑定普通脚趾子骨，因此不能照搬另外两个模型“修正前移动顶点为零”的检查条件。
- Hips 映射至 `腰`；清除 MMD 编辑用 IK 和附加姿态约束，转换为 VRM 人形骨架。材质使用 MToon，保留透明裁切，内嵌三张主贴图和 59 个形变目标。
- 从胡桃的 Godot 静止骨架重新烘焙 A01–A42，保留已有步行枢轴与循环接缝修正。
- Godot 骨架轨道、有限数值姿态、动作目录和界面操作检查通过：处理后 → 处理前 → 处理后的 126 次动作检查，失败为 0。甘雨、刻晴、花火的 42 段动作回归检查通过。
- 使用 Forward+ / D3D12 实际渲染 12 张截图，抽查处理前后步行、站立、跑步、弯身、坐地、躺卧、俯卧、坐姿、拿手机和喝水。材质与身体变形正常；这是抽样视觉检查，尚未逐帧验收全部动作。

数值报告：`docs/MMD_VRM_HUTAO_TEST_REPORT.json`。截图总览：`.model_import_build/hutao/hutao_contact_sheet.png`。独立场景截图：`screenshots/character_hutao_import_test.png`。

## 当前边界

胡桃没有刻晴、花火式的独立袖尾骨链，未套用其他角色的袖子弹簧配置；测试界面不显示未配置的服饰物理开关。头发、帽饰、衣摆和腰带仍随挂接骨刚性运动，坐卧时会出现穿插。59 个形变目标已保留，但没有完成 VRM 表情绑定。手腕扭转辅助骨的 MMD 附加旋转没有另行重建，手部特写仍需进一步验收。

坐姿动作要按镜头调整参考椅；拿手机、喝水动作目前没有对应道具。地面接触、IK、布料碰撞和完整角色控制器尚未接入。

## 复现命令

从项目根目录运行 PowerShell，使用已安装的 MMD Tools 与 VRM 插件：

```powershell
$blenderExe = 'D:\blender\blender.exe'
$godotExe = 'D:\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
$pythonExe = 'C:\Users\PC\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $blenderExe --background --python tools/build_mmd_vrm_review.py -- --profile hutao
& $godotExe --headless --editor --path . --quit
& $godotExe --headless --path . --script tools/inspect_motion_skeleton.gd -- --model=res://assets/characters/import_tests_local/hutao/hutao_fixed.vrm --output=res://.model_import_build/hutao/hutao_rest.json
& $pythonExe tools/build_motion_review.py --target .model_import_build/hutao/hutao_rest.json --dest assets/characters/import_tests_local/hutao/motions
& $godotExe --headless --path . --script tools/verify_model_import.gd -- --model=hutao
& $godotExe --path . --script tools/capture_model_import.gd -- --model=hutao
```

Blender 中间文件、骨架检查数据和日志位于 `.model_import_build/hutao/`，源模型目录没有被覆盖。
