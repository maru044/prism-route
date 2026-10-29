# 回到叶团贴图 · 待美术确认草稿

本文记录已停用的 V4 彩色叶团草稿，以下操作与截图属于历史版本。当前已经恢复旧 V2 轮廓并复用树木受光，请以 [当前统一入口](FOLIAGE_PREVIEW_ENTRY.md) 和 [V5 记录](FOLIAGE_REUSE_V5_1029.md) 为准。

单叶实例拼接、逐片贴图和逐片视差的方向已被用户否定，独立运行的单叶预览已停止。此前的功能测试结果不能证明美术方案成立。

本轮回到完整叶团作为绘制与后续摆放单位：先建立大中小轮廓、连贯暗部、中间色主体和少量集中的亮部，再通过边缘与焦点处的叶片交代形状。后续局部视差也应服务于叶团之间的层次。

[叶团重绘草稿](../assets/world/architecture_details_1029/foliage_cluster_color_v4_draft.png) 由内置 image_gen 绘制，并再次由 image_gen 修正留白边距。原图直接复制保存，未做脚本像素处理。

此图尚未获得美术确认。按后续要求已接入独立小场景供检查，正式地图尚未采用。

## 独立实机预览

统一入口为 `scenes/wall_foliage_art_prototype.tscn`，打开后按 F6；也可运行 `tools/run_wall_foliage_cluster_preview.ps1`。这些入口现已指向新版，当前窗口标题见[入口整理与一致性检查](FOLIAGE_PREVIEW_ENTRY.md)。

整墙使用三张完整叶团卡片；「单个叶团」模式只显示一张完整图。每张卡片按源图 1466×1073 的比例等比缩放，读取原图 RGB 和 alpha。没有单叶实例或单叶图集切片。墙面保留大片留白与两条大构造缝。

「整墙」「近景」「斜看」「单个叶团」切换机位；「贴图明暗」可切到同轮廓平色对照。「叶团视差」默认关闭，打开后仅使整团产生轻微的观察方向相关横移。「自动摆镜」或右键拖动可观察，滚轮缩放，H 隐藏界面。

- [整墙实机](foliage_cluster_revision_1029/game_wall.png)
- [实机近景](foliage_cluster_revision_1029/game_close.png)
- [单个叶团](foliage_cluster_revision_1029/game_single_cluster.png)
- [斜视](foliage_cluster_revision_1029/game_oblique.png)

Godot 4.7.2 / D3D12 / RTX 5070 Ti 已完成真实渲染检查，透明裁剪和 mipmap 正常，场景与着色器无运行错误。检查脚本为 `tools/verify_wall_foliage_cluster_preview_1029.gd`。这些检查仅确认实机加载与控制正常，贴图美术仍待判断。

[完整提示词及来源](foliage_cluster_revision_1029/prompts.json)、[资产状态](foliage_cluster_revision_1029/draft_manifest.json)。
