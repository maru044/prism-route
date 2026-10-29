# 叶团 V6：生长关系、尺度与环境

本轮按已讨论的计划制作实机美术原型，默认叶团尺度为 **1.35 倍**，保留 1.00 / 1.60 倍现场切换。入口与自动检查继续共用同一场景，详见 [当前检查入口](FOLIAGE_PREVIEW_ENTRY.md)。大世界窗口为 `Prism Route | 大世界 · 叶团 V6`。

当前默认仅显示初始遗迹植物；按后续反馈，崖壁植物已关闭。`trial_settings.json` 中 `cliff_plants_enabled=false`、`ruin_plants_enabled=true` 分别控制两类宿主，公共植物开关不会重新开启崖壁植物。建筑材质和环境试调保持当前设置。

## 新图集与组织关系

[四格无茎叶团](../assets/world/architecture_details_1029/foliage_leaf_clusters_v6.png) 由内置 image_gen 绘制，再由同一工具修正透明留边。1254×1254 RGBA，四格为密集主体、连接、渐稀末端、主体变体。源 PNG 像素未经脚本修改；导入启用 mipmap 与透明边缘修复。旧 V2 及树木资产保留不变。[完整提示词](ruin_art_direction_1029/leaf_atlas_v6_prompts.json)。

`scripts/world/wall_leaf_clusters.gd` 为小场景与地图共同的生成代码：先生成大小不同的生长来源，再沿弯曲路径延伸和分叉，根据路径位置选择主体、连接与末端模块。记录保留 colony、path_id、parent 和 role，便于调整。仅渲染整团卡片，不生成可见茎或单叶实例。路径长度、弯曲和分叉位置随种子变化。

这是可控路径与分叉的美术近似，尚未实现完整的空间殖民算法或植物生物模拟。参考：[空间殖民研究](https://algorithmicbotany.org/papers/colonization.egwnp2007.html)、[RHS 墙面常春藤说明](https://www.rhs.org.uk/prevention-protection/ivy-on-buildings)、[The Witness 植被美术说明](https://www.artofluis.com/3d-work/the-art-of-the-witness/agricultural-area-and-birch-forest/)。

## 材质与环境

V6 的墙面专用 shader 派生自已采用的树木 shader，保留新图集平涂叶片的明度层次。叶团法线改为较缓的整体外展，调色板压缩明暗跨度，减少每团独立鼓包的感觉。原共享树木 shader 不修改。正式地图在植被初始化后绑定同一套区域染色参数。

试放墙面纹理从原小尺度调整为 6 米，另加约 8 米尺度的低对比色差；水痕受各宿主顶部高度限制，向下衰减。暖白颜色、材质、接缝和植物仍由可撤销试放管理。全局环境仅在试放开启时调整：曝光 0.74（原 0.82）、日光能量 0.68（原 0.72）、轻微暖色日光。关闭整个试放恢复原环境；也可单独关闭环境试调或墙面材质。

该轮保留现有天空、树木、草地与地形资源，未直接把效果图贴入游戏。实际画面与效果图仍有差距，侧视卡片厚度、重复组合轮廓和材质强度仍可继续讨论。

## 查看与比较

运行 `tools/run_architecture_detail_trial.ps1`，从「表面贴图 · 叶团 V6」菜单切换遗迹近景、遗迹整体、崖壁近景和步道角色视角。菜单提供三档叶团尺度、环境试调、墙面材质与植物开关。当前可见植物仅在初始遗迹；崖壁生成数据保留但不渲染，供后续美术重做。

小场景打开 `scenes/wall_foliage_art_prototype.tscn` 按 F6，或运行 `tools/run_wall_foliage_art_prototype.ps1`。底部可切换尺度、源图集与主体/连接/末端模块。

- [小墙 1.00 倍](foliage_growth_v6_1029/scale_1.00.png)
- [小墙 1.35 倍](foliage_growth_v6_1029/scale_1.35.png)
- [小墙 1.60 倍](foliage_growth_v6_1029/scale_1.60.png)
- [遗迹近景](world_leaf_clusters_v6_1029/ruin_close.png)
- [相同机位的原墙面与原光照对照](world_leaf_clusters_v6_1029/ruin_original_surface_light.png)
- [遗迹整体](world_leaf_clusters_v6_1029/ruin_overview.png)
- [崖壁近景](world_leaf_clusters_v6_1029/cliff_close.png)

## 实机验证

Godot 4.7.2 / Forward+ / D3D12 / RTX 5070 Ti：小场景与实际地图入口均运行通过。检查主体/连接/末端角色、生长分叉、三档等比尺度、原资产哈希、透明 mipmap、材质与环境染色、开关恢复、草地缓存，以及 E 键打印角色。小场景默认 33 团、8 条路径；地图为崖壁 1452 团、遗迹 436 团，40 个 MultiMesh 批次。

- [小场景报告](foliage_growth_v6_1029/entry_verification.json)
- [大世界报告](world_leaf_clusters_v6_1029/report.json)

这些检查用于确认功能和入口一致，美术质量仍以实际观察为准。地形、遗迹 GLB、平滑台阶碰撞、草地缓存、原共享树木 shader、地图脚本与 project.godot 的哈希不变。
