# 单墙植物美术原型 · 2026-10-29

本文仅记录已归档的 v1 单叶平涂构图阶段，下方截图均为历史对照。当前检查请使用[当前叶团统一入口](FOLIAGE_PREVIEW_ENTRY.md)。

本轮围绕一张效果图还原独立场景，用来讨论美术构图。重点是顶部连续覆盖、向下逐渐稀疏、叶片相互叠放、底部留白。四条下垂区域由明确的构图引导控制，局部位置和朝向才加入变化。

## 对照

- [AI 平涂效果图](wall_foliage_art_prototype_1029/art_target.png)：内置 image_gen 绘制，提示词见 [prompts.json](wall_foliage_art_prototype_1029/prompts.json)。图中个别叶片仍有轻微折面表现，实机将每片统一为一个纯色。
- [Godot 正视还原](wall_foliage_art_prototype_1029/prototype_front.png)
- [Godot 斜视还原](wall_foliage_art_prototype_1029/prototype_oblique.png)

这是构图和形状的还原，尚未声称逐像素复刻或通过用户的美术确认。

## 打开

当前常用启动脚本与场景均指向[当前叶团统一入口](FOLIAGE_PREVIEW_ENTRY.md)。旧单叶场景保存在 `archive/foliage_previews_1029_rejected/wall_foliage_single_leaf_rejected.tscn`，仅用于回看被否定的实验。

## 当前实现与范围

墙面约 12×6.3 米，只有两条很大的构造接缝。1084 片固定比例的尖端椭圆叶片组成顶部覆盖与四组逐渐收窄的下垂叶簇。三种绿色都是单片纯色；没有茎、叶脉或叶片内部纹理明暗。固定种子仅扰动艺术引导内的位置和旋转。

原型采用独立平面单叶网格的 MultiMesh 和纯色着色器，以便直接检查轮廓、遮挡与构图。此时尚未将布局迁移到正式地图的通用投射材质，也没有把生成的整张效果图贴到墙上。参考 PNG 只出现在标明 AI 效果图的界面图层中。

布局参数：[layout.json](../assets/world/wall_foliage_art_prototype_1029/layout.json)。形状与摆放：[wall_foliage_art_prototype.gd](../scripts/world/wall_foliage_art_prototype.gd)。单叶涂色：[leaf_paint.gdshader](../assets/world/wall_foliage_art_prototype_1029/leaf_paint.gdshader)。

## 检查

Godot 4.7.2 / D3D12 / RTX 5070 Ti 实际渲染；无场景或着色器错误。正视图按墙面由上到下每 20% 高度统计绿色面积：

| 图像 | 顶部 20% | 第二段 | 第三段 | 第四段 | 底部 20% |
| --- | --- | --- | --- | --- | --- |
| 效果图 | 91.6% | 38.9% | 13.9% | 2.9% | 0% |
| 独立还原 | 92.5% | 37.1% | 16.7% | 3.5% | 0% |

这些数据只检查整体疏密关系，不能代替对具体叶形与构图的美术判断。见 [composition_check.json](wall_foliage_art_prototype_1029/composition_check.json)。

本轮单墙原型步骤未改动正式地图脚本、原有模型、植被烘焙或角色交互。之前的全墙随机散布试放不作为本轮美术标准。
