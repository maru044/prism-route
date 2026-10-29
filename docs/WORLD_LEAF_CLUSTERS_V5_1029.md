# 大世界叶团 V5 试放

> 本页为 V5 历史记录；当前入口与默认设置已转为 [V6](FOLIAGE_GROWTH_V6_1029.md)。
按用户要求将确认过的小场景做法接入真实 `scenes/map_1021.tscn`。F5 默认启用初始遗迹和指定初始崖壁；窗口标题为 `Prism Route | 大世界 · 叶团 V5`。直接检查可运行 `tools/run_architecture_detail_trial.ps1`，启动后停在遗迹整体机位。

「表面贴图 · 叶团 V5」菜单可切换遗迹整体、遗迹墙面近景、初始崖壁叶团近景、洞窟外步道角色视角，也可关闭叶团或整个试放。修改 `assets/world/architecture_details_1029/trial_settings.json` 后可重新读取配置。

## 本次接入

小场景与地图都调用 `scripts/world/wall_leaf_clusters.gd`，共用原 V2 四格 alpha 图集、现有树木 shader、平涂色板、体积法线及不规则生长区域布局。卡片维持原型的 1.45～2.2 米等比尺寸，不把整张植物图放大成巨幅花边。地图沿真实墙顶边界取样；各片区域用不同随机种子和不等间隔，绕曲面改变朝向，无需改原始网格或 UV。

当前初始崖壁 2065 团、初始遗迹 553 团，合计 40 个 MultiMesh 批次。叶团只在原来限定的试放宿主与区域生成。使用反射层让水面摄像机也能看到叶团。原来的 V4 Decal 生成已替换，旧逐叶散布仍关闭。

- [遗迹整体](world_leaf_clusters_v5_1029/ruin_overview.png)
- [遗迹近景](world_leaf_clusters_v5_1029/ruin_close.png)
- [崖壁近景](world_leaf_clusters_v5_1029/cliff_close.png)
- [崖壁关闭对照](world_leaf_clusters_v5_1029/cliff_without_clusters.png)
- [角色步道视角](world_leaf_clusters_v5_1029/cliff_walkway.png)
- [实际地图运行报告](world_leaf_clusters_v5_1029/report.json)

## 验证

`tools/run_architecture_detail_trial.ps1 -Verify` 使用同一地图入口，确认贴图与原型一致、共享 shader 与生成代码、等比尺度、开关恢复、草地缓存及 E 键打印角色。Godot 4.7.2 / D3D12 / RTX 5070 Ti 实际运行通过。地形与遗迹 GLB、平滑台阶碰撞、树木布局、草地缓存、正式地图脚本和共享树木 shader 的源文件哈希不变。

截图确认两类宿主都有可见叶团。美术仍为试放，侧视时浅层卡片仍可能暴露厚度不足；本轮没有新增真正垂悬枝叶，也未调整现有草地的步道遮挡。
