# 当前建筑与植物试放

当前版本为 **叶团 V6 · 生长与尺度**。统一入口 `scenes/wall_foliage_art_prototype.tscn`，旧启动脚本和别名场景均转到同一入口。默认使用 `foliage_leaf_clusters_v6.png`；V2 和既有灌木、树冠图集保留为对照。默认尺度 1.35 倍，另有 1.00 / 1.60 倍可选。

新图集由内置 image_gen 绘制并修正透明留边，源像素未经脚本编辑。四格依次为主体、连接、末端、主体变体。原始 V2 文件不替换。绘制提示词见 `docs/ruin_art_direction_1029/leaf_atlas_v6_prompts.json`。

分布由起点、隐藏生长路径和分叉组织，渲染仅有叶团面片，不显示茎或生成单叶。V6 使用墙面专用树木 shader 派生版保留平涂色阶，原共享树木 shader 不变。正式地图仅在原有限定试放区启用；菜单可关闭植物、墙面材质、环境试调或整个试放。

集中配置：`preview_entry.json` 与 `trial_settings.json`。说明与实机截图见 `docs/FOLIAGE_PREVIEW_ENTRY.md`、`docs/FOLIAGE_GROWTH_V6_1029.md`。V1/V2/V4/V5 资产与报告均保留作历史对照。

当前可见植物仅保留初始遗迹：`cliff_plants_enabled=false`，`ruin_plants_enabled=true`。崖壁材质与建筑效果不随植物开关改变。
