# 单墙叶片贴图与视差 · 2026-10-29

**此单叶实例方案已被用户否定，不作为后续实现方向。** 运行预览已停止；下文保留为试验记录。后续回到[叶团贴图草稿](FOLIAGE_CLUSTER_REVISION_1029.md)，先判断美术，再讨论实机还原。

本轮沿用此前单墙原型的 1084 片叶片布局，重点增加贴图中的折面明暗，并验证轻微的横向视差。仍为独立原型，正式地图材质、模型、草地缓存与交互未修改。

## 新图集

[leaf_volume_atlas_v3.png](../assets/world/wall_foliage_art_prototype_1029/leaf_volume_atlas_v3.png) 由内置 image_gen 绘制。实际 1254×1254 RGBA，2×2 四种单叶，每格 627×627。源 PNG 直接复制使用，无后续像素修改；无损导入，带 mipmap 与透明边缘修复。

叶片采用宽叶轮廓、浅折面和大块柔和明暗，保留无茎、无枝条、无细密叶脉的简化风格。材质现在读取图集 RGB 与 alpha，避免上一版把图案全部涂成单色而丢失体积。源图四种叶片都含实际颜色变化，透明度裁剪阈值为 0.50。

[完整提示词与来源](wall_foliage_art_prototype_1029/texture_v3_prompts.json)、[原图尺寸、透明度与颜色检查](wall_foliage_art_prototype_1029/texture_v3_report.json)。

## 实机

- [整面墙](wall_foliage_volume_1029/textured_front.png)
- [新贴图近景](wall_foliage_volume_1029/textured_close.png) / [相同布局、形状、光照下的平色对照](wall_foliage_volume_1029/flat_color_close.png)
- [斜视](wall_foliage_volume_1029/textured_oblique.png) / [关闭额外视差](wall_foliage_volume_1029/oblique_without_parallax.png)

单叶使用带中心分段的正方形卡片，按原比例采样图集；浅几何折面和三层少量离墙距离增强交叠，裁剪叶片可投射实际轮廓阴影。

`leaf_textured.gdshader` 在顶点阶段，沿墙面世界横轴施加位移。位移取决于观察方向和实例的前后层，近层多动、远层少动；转换回每片旋转/缩放后的局部坐标，对整片叶子的所有顶点施加相同平移。没有时间驱动的叶片漂移。

额外虚拟深度默认上限 0.10 米，且有角度限幅。正视时位移为零；从左右观察，位移方向相反。正交相机使用其观察方向，透视相机使用视点方向。阴影阶段同样取主相机方向，依据 [Godot 空间着色器文档](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html) 中 `MAIN_CAM_INV_VIEW_MATRIX` 的语义实现。

这属于小幅模拟视差。侧视时卡片仍有方向性，当前不代表真正厚实的立体枝叶，也尚未解决通用曲面上的自动生长布局。

## 查看与调整

本节仅描述历史单叶版本。当前的 `tools/run_wall_foliage_art_prototype.ps1` 与 `scenes/wall_foliage_art_prototype.tscn` 均已转到[当前叶团统一入口](FOLIAGE_PREVIEW_ENTRY.md)。旧单叶场景与验证脚本保存在 `archive/foliage_previews_1029_rejected/`。

底部「近看叶片」用于检查贴图；「新贴图」只切换颜色内容，保持同一 alpha 轮廓、几何、布局和光照；「左右视差」独立切换顶点位移；「自动摆镜」缓慢左右观察。右键也可手动转动，H 隐藏界面。

参数仍在 `assets/world/wall_foliage_art_prototype_1029/layout.json`：`parallax_depth_m`、`fold_height`、`layer_separation_m`。全墙程序化散布试放尚未采用此版本。

## 验证

Godot 4.7.2 / D3D12 / Forward+ / RTX 5070 Ti 实际渲染，无场景或着色器错误。原叶片位置、大小、旋转、色调标号与 v1 布局逐项比较一致。

固定角度的单叶开关对照中，左视额外横移约 +36.69 像素，右视约 −36.69 像素，正视为 0；高度不变，宽度差不超过 1 像素，符合整片平移。该测试采用放大的正交近景，用于确认方向与形状，不表示全墙观察时的移动幅度。

贴图近景和平色对照有 56.4% 像素产生可见差异；斜视开关视差有 20.9% 像素变化。[渲染报告](wall_foliage_volume_1029/render_report.json)、[像素检查](wall_foliage_volume_1029/pixel_check.json)。

历史验证脚本已归档。常用的同名验证入口现在转发到当前叶团版本的检查，避免继续把旧截图当成最新实机。
