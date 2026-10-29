# 初始遗迹平滑台阶碰撞 · 2026-10-29

可见台阶保留，角色改为沿独立、隐藏的连续坡面行走。建筑和地形显示网格不变，刻晴的 E 打印交互保留。

## 数学关系与 CAD

沿用 `plans/architecture_concepts_1028/rhino_model_1029/build_state.json` 和原建模脚本的局部坐标、路径与踏步参数：

- 连接步道中心线长度 171.4303175 m，宽 3.2 m，131 个原始台阶里程和每级 0.15 m 的标高；同样的局部圆角中心线，按踏步前缘高度建立单调 PCHIP 剖面，并保留周期休息平台的水平段。
- 入口两段各 18 级、宽 7.2 m，踏步 0.35 m、升高 0.15 m；碰撞坡面从第一级前一踏步距离开始，衔接最后踏步与水平平台。
- 室内两段各 4 级，横向宽度沿建筑三角形边界变化。
- 圆形召唤台使用连续锥形裙面和水平顶面。

六个闭合 Mesh 保存到 Rhino 图层 `建筑::初始三角遗迹::09_平滑碰撞`，默认隐藏、锁定。辅助体包含边侧和底部，便于保留侧向阻挡。建模配方为 `walk_collision_recipe.json`，对象编号为 `walk_collision_state.json`；后续调整可继续按参数派生。

主模型为 `D:/Prism Route/map/map_current.3dm`；对比副本 `D:/Prism Route/plans/architecture_concepts_1028/rhino_model_1029/initial_triangle_ruin_smooth_collision_review.3dm`。保存回读核对原 603 件文件对象的编号、几何、语义图层及属性；仅新增 6 件辅助体。备份为 `map/backups/map_before_ruin_walk_collision_1029.3dm`。

## Godot 接入

`assets/world/initial_ruin_1029/walk_collision.glb` 来自实际 Rhino Mesh 回读，6 个节点使用 `-colonly` 后缀；导入后仅有静态碰撞体，没有显示网格。资产约 238 KB、9,692 个三角形。附加到正式 F5 地图，206 个原始踏步 / 圆台碰撞体退出角色碰撞层；建筑墙体、栏板等仍有阻挡。

原始几何碰撞保留在查询层 1，平滑辅助体只在角色层 32 工作。草地表面、建筑暴露和种植避让仍查询原几何，因此没有改写或重烘焙草缓存，也没有更改树木布局。

跨阶辅助继续服务于零散障碍；增加正常坡面投影判断，避免把上坡的水平位移减少误认为台阶受阻。人物动画代码没有通过掩盖离地状态来处理楼梯。

## 查看

- F5：原洞窟出生；可经菜单选择「初始遗迹 · 召唤台」。
- `tools/run_initial_ruin_1029.ps1 -Stairs`：直接在入口楼梯前开始。
- Rhino 开启并解锁 `09_平滑碰撞` 可查看或编辑辅助体；正式游戏不显示这些 Mesh。
- [实际游戏画面](initial_ruin_1029/smooth_stairs_gameplay.png)
- [仅供验证的绿色碰撞面叠加](initial_ruin_1029/smooth_stairs_collision_overlay.png)

## 验证

[完整接地与动画测试](initial_ruin_1029/smooth_collision_logic.json)：连接步道全程与各段楼梯 / 圆台，1.6 m/s 步行和 4.2 m/s 跑步，上下行共 24 组，另加正式跨阶辅助开启的全程测试。全部要求离地帧数、坠落 / 落地动画帧数及跨阶辅助调用次数为 0；不能只以“能到达终点”为标准。

430 个平滑顶面抽样无缺失，最大高度误差约 0.0000573 m；原 649 个显示几何碰撞抽样继续核对。逻辑测试使用 `--fixed-fps 60` 取消墙钟同步，每个物理步长仍严格为 1/60 秒，未放大时间缩放或单步位移。

[实际 GPU 与 E 打印回归](initial_ruin_1029/smooth_collision_render.json)、[楼梯接地截图检查](initial_ruin_1029/smooth_stair_capture.json)。共享辅助仍通过原有小台阶上下行、低顶、高坎、空隙回归。导出清单已包含新的 GLB 和 JSON；本次未制作 Windows 发布包。

重建流程：`python tools/build_ruin_walk_collision_1029.py recipe` → Rhino 执行 `tools/rhino_ruin_walk_collision_1029.py` → 只读 `export_saved()` → `python tools/build_ruin_walk_collision_1029.py package` → Godot 重新导入。已生成的辅助体使用记录中的 GUID，勿重复运行初建阶段。
