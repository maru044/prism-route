# 东侧大台地建筑概念 · 2026-11-02

用户要求为新台地探索更大占地的建筑。此目录记录实测与 A/B/B2/B3 效果图。随后已按 B3 完成 Rhino 模型，见 `../east_earth_pavilion_1102/README.md`；尚未接入游戏。

## 当前场地实测

当前选中对象 `920c8a45-b23e-4260-9aab-86333f61b992`，名称 `Macroterrain_01_EastLongRidge`，位于 `手工地形` 图层。

- 原生边界：`(1775,605,13.9148)` 至 `(2155,1255,88.8317)`。
- XY 包围盒 380 × 650 m；选中顶部曲面的三角形水平投影面积约 171,078.9 m²。
- 该面积不是平整可建设面积；曲面整体高差约 74.92 m，需按具体建筑位置继续测高、顺坡错层。

## 效果图

- `A_flowing_pavilion.png`：两道错位流线屋顶围合一个主要露天庭院，屋面集中缺失，暴露少量曲梁。入口朝现有道路分叉，整体轮廓更集中。
- `B_terraced_courtyard.png`：顺着坡地形成两层错台，连续屋顶与露台围合纵向庭院；更强调屋顶漫游和观景。

两图用于比较体量和空间关系。提示词探索尺度为长约 180–220 m、宽约 100–130 m、最高点相对局部地面约 18–24 m；图像生成不能保证这些数值精确，实际建模仍需测量落位。使用内置 image_gen，并以用户提供的 Rhino 截图作为场地参考。

## 绘图提示词摘要

### B2 地形包裹修订

用户选定两层地景方向，并要求建筑更被地形包裹。新增 `B2_earth_enclosed_courtyard.png`：将大部分屋顶覆土，使后侧及两端连续埋入土丘；通过两道错层庭院开口、凹入入口和局部观景立面显露建筑。保留一个集中破损处露出曲梁。参考 MAD 衢州体育公园及 ZHA Corones 山地博物馆的地形融合原则，原建筑占地与道路关系不变。提示词及来源见 `B2_prompt.md`。仍仅为效果图，没有修改模型。

### B3 明亮中庭修订

用户要求增加适中中庭以提供明亮视觉引导及物品放置空间。新增 `B3_daylit_atrium.png`，保留 B2 覆土、两层错台、道路入口及局部破损关系，增加中央露天庭院。中庭探索尺度约 30 × 22 m，底部以平整浅色铺地为主，植物靠边，侧边坡道连接上下层；中央不放置固定雕塑、水池或大型树木。动线意图为道路入口—阴影门廊—明亮中庭，未来道具类型尚未确定。具体提示词见 `B3_prompt.md`。仍为效果图，未修改 Rhino 或 Godot。

### 初版 A/B

Common: Wide elevated oblique architectural concept for Prism Route. Preserve the selected rolling plateau, shoreline, road fork and foreground sculptural bridge from the supplied Rhino image. Remove UI, selection wires and gumball. Large but low coherent building, substantial minority footprint on the 380 x 650 m terrain. Near-future manufactured curved architecture after abandonment: warm ivory shells, grey floors, sparse weathered steel at broken edges, partial blue-grey glazing, gently reclaiming grouped vegetation. Bright sunny stylized game concept. Adapt with slope-following foundations and broad ramps. Avoid ancient temples, scattered rubble gardens, tall towers, neon, dense lattices, another circular ring or dome.

A: One elongated exhibition/research pavilion around an asymmetrical open garden. Two broad streamlined roof wings sweep past at different heights, joined by a small lobby. Soft boomerang plan with an entrance notch toward the fork. One intact wing and one large missing central roof sector expose sparse curved steel beams. Lifting entrance roof settles into the hill; terraces overlook the lower basin. Single discreet A label.

B: Long hillside archive with two offset terraced levels. Three unequal gently curved horizontal slabs around a linear sunken garden, connected by a sculpted folded wall. Walkable lower roof grows out of the slope. Deep recessed entrance toward the fork. One upper end sheared off to reveal a few weathered steel box beams; other portions retain coherent glazing and shaded rooms. Calm cantilevers and broad slope-following ramps. Single discreet B label.
