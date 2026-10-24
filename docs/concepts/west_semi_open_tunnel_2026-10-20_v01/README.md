# 西侧中层半露天隧道 B

2026-10-20。用户从两张生成效果图选择 B，重点是倾斜流线型拱肩；随后明确要求补齐底面。

本目录 `A_long_reveal.png`、`B_swept_gallery.png` 为 AI 概念图，提示词见 `PROMPTS.md`。

以下为现用 `map/map_current.3dm` 的真实 Rhino 截图，不是生成图片：

- `model_overview.png`：带原场地的外观总览。
- `model_gallery_detail.png`：倾斜拱肩、洞口、地形交接的近景。
- `model_open_interior.png`：开放段内壁、顶盖、侧向开口及路边底面。
- `model_closed_interior.png`：封闭段连续内壁、顶盖和道路。

实际模型由一个闭合 SubD 顶盖/墙体与一个闭合 NURBS 底板构成，使用原有 `交通::隧道` 图层及暖白材质。底板铺满路面与墙脚，和原路基、崖壁下部搭接。原道路几何不变。详细资产编号、检查范围和保存结果见 `../../CURRENT_MODEL.md` 对应段落、`validation.json`。

当前为 Rhino 模型成果，未做 Godot 驾驶与碰撞验收。修改应沿用同一模型中的两个资产，不叠加完整模型副本。
