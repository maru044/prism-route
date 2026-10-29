# 正式地图表面贴图试放 · 2026-10-29

F5 正式地图默认启用。试放包含洞窟与外侧崖壁、中央开孔巨构、临水围壁这三个结构网格，以及初始遗迹的前墙、柱廊、高墙共 62 个网格。其余地形材质继续使用原来的种植与地表遮罩，不覆盖整张地图。

## 查看与取消

运行 `tools/run_architecture_detail_trial.ps1`，直接进入正式地图的遗迹整体机位。常规 F5 仍从原来的洞窟出生。

地图原有面板新增「表面贴图 · 试放」菜单：

- 「启用试放」：关闭即恢复每个网格原来的材质对象；再次开启恢复试放。
- 「结构接缝」「纯色叶片」：独立开关。
- 四个机位查看临水巨构、遗迹近景、洞窟外角色视角及遗迹整体。
- 「调整叶片颜色与密度」：本次运行即时生效，水面倒影同步。
- 「重新读取配置」：重新载入 JSON，包括新增/移除试放宿主。

H 仍隐藏界面，F 仍切换自由相机。没有占用新的游戏快捷键。

持久参数集中在 [trial_settings.json](../assets/world/architecture_details_1029/trial_settings.json)。设置 `enabled: false` 可取消默认启用；启动参数 `--no-architecture-details` 可仅对本次运行禁用。界面调整不会自动写回文件。

## 实现

[architecture_detail_trial.gd](../scripts/world/architecture_detail_trial.gd) 只在运行时替换白色建筑的材质，并保留原引用。原始 GLB、建筑材质资源、UV、碰撞、树木布局与草地烘焙不变。

接缝由建筑坐标生成，目前格子为 32×18 米。叶簇读取批准的 v2 图集 alpha，再用 #66bb6a 平涂，另有程序化轮廓的零散单叶；不使用图集 RGB、茎、叶脉或写实明暗。固定种子控制随机位置、旋转、等比大小与重叠，密度目前为 0.9；通过相邻单元采样保留跨格叶簇的完整轮廓。叶片随距离在 240–300 米淡出。本次没有新增垂出墙面的立体叶片网格。见[分布与虚线修复](ARCHITECTURE_DETAIL_REVISION_1029.md)。

使用主轴投影，不要求宿主 UV。规则接缝和叶片位置是初次通用铺设，尚未逐面美术调整；叶片不会自动识别已有真实破缝或模拟生长。

水面倒影沿用同一个材质着色逻辑，运行时切换材质/颜色/密度会刷新反射代理。

## 验证与截图

由 `tools/verify_architecture_detail_trial_1029.gd` 在正式地图、RTX 5070 Ti / D3D12 / Forward+ 下渲染。

- [临水巨构](architecture_detail_trial_1029/view_0_after.png) / [关闭试放](architecture_detail_trial_1029/view_0_before.png)
- [遗迹近景](architecture_detail_trial_1029/view_1_after.png) / [关闭试放](architecture_detail_trial_1029/view_1_before.png)
- [洞窟外角色视角](architecture_detail_trial_1029/view_2_after.png)
- [遗迹整体](architecture_detail_trial_1029/view_3_after.png)
- [验证报告](architecture_detail_trial_1029/report.json)

检查包括 65 个宿主材质启停、原对象恢复、独立图层开关、65 个倒影宿主的颜色更新和恢复、原网格身份与碰撞数、源资产哈希、草地缓存签名，以及原有 E 键召唤的一次性打印、完整实体碰撞与状态保留。
