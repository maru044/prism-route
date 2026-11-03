# MMD 骨架动画验证样本

**最终流程与验收规则见 `docs/MMD_TO_VRM_PRODUCTION_GUIDE.md`。**

同一场景目前默认播放 `paired/catalog.json` 中的完整双人组合（刻晴 A / 甘雨 B）。
`paired/source_inventory.json` 是多轨候选清单，不代表全部已转换或已确认双人关系。
时序/空间检查与最终接触适配分开验收，见 `docs/MMD_PAIRED_MOTION_VALIDATION.md`。
实际 VRM 场景为 `scenes/character_mmd_vrm_validation.tscn`，角色为 `scenes/characters/keqing_mmd_vrm.tscn`。
`keqing_physics.vrm` 保留现有 VRM 的网格/材质，仅补充物理元数据；
`keqing_vrm_loop03.tres` 是重定向到实际 GeneralSkeleton 的身体动画，头发和服饰由实时物理控制。
后面的 `loop03_baked.glb` 等内容保留作早期骨架对照，不是最终 VRM 的直接播放资源。

样本：Loop 03 / Izumi.vmd。30 FPS，0–480 帧，16 秒。
GLB 包含 316 根骨骼和用于保留蒙皮骨架的微小标记网格，没有人物外观。
`loop03_baked.tres` 是单个 Animation；`loop03_library.tres` 是含 `loop03` 的 AnimationLibrary。

动画路径依赖 `MMD_Baked/Skeleton3D` 及原始 MMD 骨名、静止姿态。
现有 VRM/GeneralSkeleton 需要另行重定向，不能直接套用。
本样本未烘焙表情和物理，未修正跨模型体型，未强制循环。
导入设置已关闭 AnimationPlayer 的动画优化，以保留逐帧精度。

完整说明、Blender 文件、可运行预览和验证脚本：
`D:/Prism Route/research/mmd_validation_20261103/README.md`。

## 实际角色场景

`keqing_loop03.glb` 是带原始 PMX 网格、贴图和同骨架动画的完整角色验证资产。
在 `scenes/character_mmd_validation.tscn` 中按 F6 运行。
详细范围和验证结果见 `docs/MMD_CHARACTER_VALIDATION.md`。
此角色 GLB 使用原始 PMX 骨架，没有重定向到现有 `keqing_fixed.vrm`。
