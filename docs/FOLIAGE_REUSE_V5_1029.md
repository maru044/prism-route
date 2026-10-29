# V5：恢复旧叶团，复用现有植被做法

> 本页为 V5 历史记录；当前入口与默认设置已转为 [V6](FOLIAGE_GROWTH_V6_1029.md)。
找回的是 `assets/world/architecture_details_1029/foliage_leaf_mask_v2.png`：1254×1254、四格无茎叶团，SHA256 为 `adb7676259be551fca92978aa3478b77b8a99d76ee2918154f71035c8f2e03c8`。本轮保留原 PNG 像素，不再绘制一张带固定垂挂构图的整幅彩色图。

## 对照与实现

已检查 `tools/prepare_species_textures.py`、`scripts/foliage_style.gd`、小树过滤配置和现有树木 shader。已有植被主要以简化 alpha 轮廓、统一涂色和整体受光形成风格；源图不是写实照片。

独立预览直接复用 `assets/vegetation/shaders/vegetation_wind_soft_backlight.gdshader`，不修改该共享 shader 或现有树木。颜色取 `STYLE.GREEN_VALUES`，贴图只提供轮廓；每团卡片使用向外展开的法线。不能把整面墙当成一个扁平树冠，否则叶团又会合并为大块纯色。原型仅调整自己的灯光和材质参数，墙边贴近排列的卡片将 `foliage_shadow_relief` 设为 0.35，保留墙上投影并缓解相互遮挡过黑。

一面 12×6.3 米的墙上放置 43 个完整叶团，按种子 731 固定：几个不等大小的生长区域、顶部较密、向下衰减、边缘留白。每团随机选择四格、镜像、角度和等比尺寸；没有横向压缩或逐叶实例。三种资产切换时保持同一布局和灯光，目的是比较轮廓，不是把树冠贴图直接选为墙藤最终方案。

- [恢复 V2 · 整墙](foliage_reuse_v5_1029/restored_v2_wall.png)
- [恢复 V2 · 近景体积受光](foliage_reuse_v5_1029/restored_v2_close.png)
- [同一轮廓 · 平面法线对照](foliage_reuse_v5_1029/v2_flat_card_lighting.png)
- [现有灌木对照](foliage_reuse_v5_1029/existing_shrub_wall.png)
- [现有树冠对照](foliage_reuse_v5_1029/existing_tree_clump_wall.png)
- [单个完整叶团](foliage_reuse_v5_1029/restored_v2_single.png)

## The Witness 参考的边界

Luis Antonio 的[植被美术说明](https://www.artofluis.com/3d-work/the-art-of-the-witness/agricultural-area-and-birch-forest/)强调概括植物生长形态，让叶片可读而不过于嘈杂；[纹理制作说明](https://www.artofluis.com/3d-work/the-art-of-the-witness/soon-texture-creation-workflow/)介绍近乎平涂、依赖形体的总体风格。这个方向支持复用本项目现有轮廓与受光方法，但这些文字并不能确认其墙藤使用完全相同的图集、法线或 shader。

## 验证与范围

Godot 4.7.2 / Forward+ / D3D12 实际运行并检查默认入口、三种源资产一致性、等比缩放、别名入口和截图。体积受光开关在同一近景下有可见差异；检查只用于防止功能回归，美术效果仍交由用户判断。[运行报告](foliage_reuse_v5_1029/entry_verification.json)。

原型确认后已按要求开启大世界 V5 试放，见 [大世界检查](WORLD_LEAF_CLUSTERS_V5_1029.md)。小场景与地图共用 `scripts/world/wall_leaf_clusters.gd` 的贴图、网格、材质与布局生成方法；地形、碰撞、角色召唤与既有植物纹理不改动。卡片仍是浅层几何，尚未解决大角度侧视、曲面自动贴合和真正悬垂枝叶。统一启动方式见 [当前预览入口](FOLIAGE_PREVIEW_ENTRY.md)。
