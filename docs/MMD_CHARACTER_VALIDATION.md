# MMD 实际角色验证

**阶段记录：本页是原始 PMX 网格的回归对照。最终现有 VRM 重定向与实时物理流程见
[重要制作指南](MMD_TO_VRM_PRODUCTION_GUIDE.md)，最终场景为 `scenes/character_mmd_vrm_validation.tscn`。**

2026-11-03，在独立场景 `scenes/character_mmd_validation.tscn` 中验证。
打开此场景按 F6，或运行 `tools/run_mmd_character_validation.ps1`。

## 本次使用

- 刻晴原始 PMX 网格和相同静止姿态的完整 MMD 骨架。
- 先前已烘焙的 `Loop 03/Izumi.vmd`，0–480 帧、30 FPS、16 秒。
- 输出完整资产：`assets/characters/mmd_validation/keqing_loop03.glb`。
- 316 根骨骼、15,934 个原始顶点、20,103 个三角形、20 个材质、5 张内嵌纹理。
- Godot 导入后为 15,985 个顶点（包含 UV/法线拆分）及 133 条有效动画轨道。

这里采用“原始 PMX 网格 + 同一套已烘焙骨架”，没有将动画套到现有 `keqing_fixed.vrm`。
后者的静止姿势已经转换为 T 姿势，骨名、骨轴和部分关节位置均有变化，需要单独重定向。
本次没有修改现有 VRM、角色控制器和游戏主场景入口。

## 场景操作

- 自动播放一次；播放按钮可以暂停和继续。
- 拖动时间轴可按 30 FPS 逐帧检查；到结尾后点击播放会从头开始。
- 正面、侧面、背面按钮切换视角；右键拖动旋转，滚轮缩放。
- 骨架开关用于检查身体关节与模型的关系。
- 单次播放保留原始整体位移，没有强制首尾循环或逐角色居中。

## 转换与验证

网格和已烘焙骨架的全部 rest 矩阵完全一致，直接重绑蒙皮，不改变原始 D/EX 骨权重。
导出骨架没有约束。GLB 仅导出当前场景和选定角色，避免把其他场景的动画一并打包。
材质转成带原始贴图的标准 PBR，透明孔洞用 Alpha Scissor；本次不复现 MMD Toon/Sphere 效果。
动画采用逐帧采样；Godot 导入时关闭动画优化和压缩。

自动检查：

```powershell
& '.current_map_build/runtime/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tools/verify_mmd_character_validation.gd
```

检查内容包括：

- 11 个时间点、143 个骨骼位置与 Blender 求解参考值的比较。
- 11 个时间点、175,835 次蒙皮顶点计算，检查权重、骨骼绑定和有限值。
- Godot CPU 蒙皮后模型的包围盒与 Blender 最终变形网格的包围盒比较。
- 模型顶点确实随动画移动；不是只有骨架数据在变化。
- 4 个时间点和侧视图的实际 GPU 渲染人工检查。

结果通过：最大骨骼位置误差约 0.000794 毫米，最大变形包围盒误差约 0.0146 毫米。
网格顶点在抽查帧间的最大位移约 11.9 厘米。
包围盒比较不等同于逐顶点逐一对应的误差比较；顶点检查是在 Godot 中按实际导入权重计算。
实际结果见 `D:/Prism Route/research/mmd_validation_20261103/character_validation.json`。

## 仍待适配

本次验证骨骼烘焙、网格绑定、材质导出和引擎播放。
头发、裙摆、飘带和袖子没有启用物理，极端姿势下会有静态服饰穿插，尚未做手工修形。
没有导入表情、相机、道具或另一个角色。
原 VMD 有 3 条动态腕部辅助轨道在此 PMX 中找不到对应骨骼，仍沿用骨架样本的映射限制。

这证明动画格式和蒙皮链路可用，不代表此动作已经达到完整角色适配或游戏成品标准。

Blender 工程：`D:/Prism Route/research/mmd_validation_20261103/mmd_keqing_character_validation.blend`。
重建时先打开早先骨架验证工程，再依次运行同目录下
`blender_character_import.py`、`blender_character_export.py`。
