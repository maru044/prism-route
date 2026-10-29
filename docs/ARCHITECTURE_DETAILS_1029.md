# 建筑接缝与纯色叶片贴图 · 2026-10-29

本页为早期资产记录；当前独立预览和试放开关以 [统一入口](FOLIAGE_PREVIEW_ENTRY.md) 为准，正式地图已开启 V5 叶团面片试放，见 [大世界检查](WORLD_LEAF_CLUSTERS_V5_1029.md)。

当前采用 v2 叶片轮廓遮罩。只有简化的椭圆 / 尖端叶片，叶片相互叠放组成簇状形态；渲染没有茎、叶柄、枝条、叶脉或写实纹理明暗。接缝素材沿用上一轮。

## 采用项目已有做法

已检查原有 `tools/prepare_species_textures.py`、叶片贴图和 `scripts/foliage_style.gd`：生成图主要用于轮廓，RGB 做纯色处理，再由材质与调色板控制。旧小树纹理不透明部分的 RGB 为统一的 [91,120,75]，并非写实叶片照片。

本次重绘以现有 `shrub_leaf_lobes_billboard_flat_v3.png` 的叶片外形作为参考，使用内置 image_gen 生成新轮廓。材质完全忽略新图的 RGB，只读取 alpha；默认涂色直接取现用绿色调色板的 `GREEN_VALUES.species_mid_color`（#66bb6a）。叶片范围也不再使用墙面微法线，保留干净平涂。透明轮廓沿用现有植被的 0.42 裁剪阈值并做边缘过渡。

[检查记录](architecture_details_1029/style_audit_v2.json)、[生成提示词与来源](architecture_details_1029/leaf_mask_v2_prompts.json)。

## 资产

- [接缝灰度遮罩](../assets/world/architecture_details_1029/seam_wear_mask_v1.png)：RGB PNG，着色器按红通道读取细接缝、裂纹和磨损。
- [纯色叶片轮廓图集 v2](../assets/world/architecture_details_1029/foliage_leaf_mask_v2.png)：RGBA，四格分别为窄叶簇、宽叶簇、下垂叶簇、低矮叶簇。
- `foliage_atlas_v1.png` 保留为旧稿，预览已不再读取。

两张当前源图实际均为 1254×1254，未放大伪造分辨率。植物每格 627×627；图集使用无损导入、mipmap 和透明边缘修复。源像素没有经脚本重绘或调色，平涂发生在游戏材质中。

## 独立预览

本节是历史双墙预览记录。当前 `scenes/architecture_detail_lab.tscn` 与 `tools/run_architecture_detail_lab.ps1` 已统一转到[当前叶团检查入口](FOLIAGE_PREVIEW_ENTRY.md)。旧双墙场景保存在 `archive/foliage_previews_1029_rejected/architecture_detail_lab_historical.tscn`。

历史版本曾提供总览、近景、墙顶和深浅底色透明边缘对照。下方图片与报告均来自当时版本，不代表当前入口。

独立实验室阶段保持正式地图不变。后续已按要求增加[正式地图可撤销试放](ARCHITECTURE_DETAIL_TRIAL_1029.md)：F5 默认开启部分墙面，菜单可随时关闭，原材质和几何资源仍保留。没有增加墙外立体枝叶。

## 实际验证

- [总览](architecture_details_1029/overview.png)、[近景](architecture_details_1029/close_all.png)、[墙顶](architecture_details_1029/walltop.png)。
- [深浅底色边缘](architecture_details_1029/alpha_edges.png)、[改色检查](architecture_details_1029/leaf_recolor.png)、[远景](architecture_details_1029/far.png)。
- [GPU 报告](architecture_details_1029/render_report.json)与[资产 / 渲染差异检查](architecture_details_1029/asset_report.json)。

截图由真实 Godot 场景渲染；叶片遮罩由 imagegen 绘制。检查覆盖无 UV 宿主、图集留边、纹理加载、mipmap、层开关、实际改色以及正式文件哈希保持。

实现为 `shaders/environment/architecture_details_1029.gdshader` 与 `scripts/world/architecture_detail_lab.gd`；验证脚本 `tools/verify_architecture_details_1029.gd` / `tools/validate_architecture_detail_assets_1029.py`。
