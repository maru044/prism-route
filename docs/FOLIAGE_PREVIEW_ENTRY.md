# 当前叶团检查入口

当前版本：**叶团 V6 · 生长与尺度**，内部标识 `cluster-v6-growth`。窗口标题为 `Prism Route | 叶团 V6 · 生长与尺度`。

## 打开

统一场景：[wall_foliage_art_prototype.tscn](../scenes/wall_foliage_art_prototype.tscn)，Godot 中打开后按 F6。

F5 仍运行正式游戏地图；本页的小场景请使用 F6 或下方启动脚本。

统一启动脚本：`tools/run_wall_foliage_cluster_preview.ps1`。

旧的 `tools/run_wall_foliage_art_prototype.ps1`、`tools/run_architecture_detail_lab.ps1` 均转发到这个启动脚本。旧场景名 `scenes/wall_foliage_cluster_preview.tscn`、`scenes/architecture_detail_lab.tscn` 继承统一场景，不再各自加载不同的实验。

默认使用 `foliage_leaf_clusters_v6.png`：主体、连接、末端和主体变体四格无茎叶团，保留平涂叶片内部的明暗分层。以隐藏生长路径组织覆盖区域，整团等比缩放、旋转与镜像；不生成枝条或单叶实例。墙面使用较大尺度的低对比色差和局部顶部水痕。

底部可选择 1.00 / 1.35 / 1.60 倍叶团尺度，默认 1.35；可切换新图集、旧 V2、现有灌木和树冠，并查看主体、连接、末端模块。可切换整墙、近景、斜看，右键旋转，滚轮缩放，H 隐藏界面。墙面材质与体积受光可独立关闭。侧面仍为浅层卡片。

大世界共用同一生成代码，当前仅开启初始遗迹植物，崖壁植物已按反馈关闭。菜单另有尺度、环境试调和墙面材质开关。详见 [V6 制作与检查](FOLIAGE_GROWTH_V6_1029.md)。V5 记录及截图保留为历史对照。

## 自动检查使用同一入口

```powershell
& ./tools/run_wall_foliage_art_prototype.ps1 -Verify
```

`-Verify` 仍按普通预览流程启动上述主场景，仅追加检查开关。检查器加入已启动的真实场景，在切换机位前先记录默认画面、窗口标题、场景、脚本、着色器、贴图路径与文件哈希；不会另建一面测试墙。

- [默认启动截图](foliage_growth_v6_1029/game_startup_current.png)
- [入口核对报告](foliage_growth_v6_1029/entry_verification.json)
- [普通预览与自动检查身份对照](foliage_growth_v6_1029/manual_entry_match.json)

入口与默认设置仅在 [preview_entry.json](../assets/world/architecture_details_1029/preview_entry.json) 定义。自动检查会确认实际脚本与整团贴图符合配置，且兼容场景没有残留单叶脚本。

历史双墙与单叶实验的场景、检查脚本已存放于 `archive/foliage_previews_1029_rejected/`。历史效果图仍可参考，但不代表当前检查窗口。所有常用检查入口现在检查当前叶团版；归档脚本仅用于回看旧实验。
