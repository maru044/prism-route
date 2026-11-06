# 沙滩材质与源素材

更新：2026-11-07。两套纹理来自 Poly Haven，许可 CC0-1.0。正式地图的四个 Sand 对象已使用 `beach_sand.tres`，在 shader 中重设为浅米色，并降低实拍对比度与法线强度。

- `sand_03/`：Charlotte Baglioni，约 2 m 的细沙；建议作为浅米白沙地的颗粒来源。
- `aerial_beach_01/`：Rob Tuytel，约 30 m 的沙纹；建议低强度用于较大尺度变化。
- [来源与校验清单](sources.json)：下载链接、作者、尺度、分辨率、官方 MD5、SHA-256 和文件大小。
- [美术方向与接入注意事项](../../../docs/BEACH_MATERIAL_PLAN_20261107.md)：现有沙地没有 UV，且包含 Y=0 平面，需世界坐标映射和沿岸湿度遮罩。
- [缓坡、材质实施与验收](../../../docs/beach_slope_1107/README.md)：Rhino 修改范围、Godot 替换方式、碰撞验收及重建步骤。

官方许可：[Poly Haven](https://polyhaven.com/license)；[CC0 1.0 法律文本](https://creativecommons.org/publicdomain/zero/1.0/legalcode)。

纹理保留原始下载字节。项目调色在 `shaders/environment/beach_sand.gdshader` 中完成，原始图片的棕灰色不是最终配色。当前使用 Sand 03 的颜色／法线／粗糙度及 Aerial Beach 01 的颜色图，共四张源贴图；后者的法线与粗糙度已下载留作候选，没有接入正式材质。OpenGL 法线与粗糙度按数据解释。
