# A1 桥：NURBS 拓扑与可复用代码调研

2026-10-20。用户认可 A1，要求避免把它做成一片片有雕刻图案的墙；倾向使用 NURBS。本文是造型解释、建模路线及实际检索结果，尚不是已建桥模型或曲面连续性验收报告。本轮没有修改 map_current.3dm。

## 对空间关系的解释

A1 图像只定义了意向，遮挡部分不能作为确切拓扑证据。建模时采用以下空间解释：

1. 上下两条道路连续跨越约 126 m 缺口，标高约 60 / 35 m。平面接点有约 2 m 量级错位，应独立拟合两层道路，再确定横向余量。
2. 上下层各有跨满桥宽的承托体，包括桥腹、边缘圆转和有厚度的底面。支承连接这些三维体量，不悬贴在道路边缘。
3. 近侧斜向壳体由下层桥腹的一段根部向上、向另一岸展开；远侧壳体反向斜贯，位于道路另一侧。前后壳体形成视线交织，实际实体不在车道中相交。
4. 壳体横断面随位置改变：根部、收束段、肩部有不同的纵向宽度与横向深度，不能用固定厚度平板完成整段。
5. 眼形空腔的边缘要通过圆转连接内外壳面，显露拱腹的深度。接近桥腹时，斜撑肩部逐渐展开，并与上下层承托体形成连续的外表面。
6. 道路面本身保持平顺，壳体曲线与前后空间错位承担造型变化。

## NURBS 分片路线

- 先以两层道路的实际边界和接点建立约束，避免用 Z=0 参考线替代真实道路。
- 先组织三维轮廓、关键横断面和四边曲面边界，再写扫掠或控制网代码。
- 斜撑中段、肩部过渡、桥腹、外侧圆转、开口回转分别划分合理的四边片区。复杂汇合处需要重新组织边界；不把多条支承强行收进同一个极点。
- 曲线方向、截面对应、节点参数一致后，采用原生 NURBS 控制网、双轨扫掠或放样构面；需要受控连接的位置再用相切/曲率衔接。
- 曲面 Join 只代表拓扑拼接；视觉上应连续的位置还需检查接缝偏差和法线，不能把 Join 或 IsSolid 当作 G1/G2 证明。
- 先验证一处斜撑汇入桥腹的节点，再扩展整体，验证桥底、近侧、远侧及下层驾驶视角。不能仅靠效果图或正立面判定造型成功。

## 实际找到的官方资源

1. McNeel Sweep2 完整 C++ 示例：包含轨线方向匹配、截面与轨线参数对应、容差与双轨扫掠调用。
   https://developer.rhino3d.com/samples/cpp/sweeping-surfaces-with-sweep2/
2. RhinoCommon 双轨扫掠接口，可通过 Python 调用；官方说明 SweepTwoRail 已由 Brep.CreateFromSweep 静态方法接替。
   https://developer.rhino3d.com/api/RhinoCommon/html/T_Rhino_Geometry_SweepTwoRail.htm
   https://developer.rhino3d.com/api/RhinoCommon/html/M_Rhino_Geometry_Brep_CreateFromSweep_2.htm
3. McNeel Loft 示例，含 C# 和 Python：
   https://developer.rhino3d.com/samples/rhinocommon/loft-surfaces/
4. CreateBlendSurface：以两侧面、边、参数范围、方向及各自的连续性选项创建衔接面。
   https://developer.rhino3d.com/api/rhinocommon/rhino.geometry.brep/createblendsurface
5. 直接从控制点网格构造 NURBS 的 API 与官方底层示例：
   https://developer.rhino3d.com/api/RhinoCommon/html/M_Rhino_Geometry_NurbsSurface_CreateFromPoints.htm
   https://developer.rhino3d.com/samples/cpp/create-nurbs-surface/
6. 官方开发示例仓库：
   https://github.com/mcneel/rhino-developer-samples

这些是基础构面例程和接口，不能描述为已找到整座 A1 桥的生成脚本。未复制或执行网上的第三方代码。本次通过当前 Rhino 会话核实版本为 8.5，CreateFromSweep、CreateBlendSurface、NurbsSurface.CreateFromPoints、CreateNetworkSurface 均存在；仅确认接口可用，不代表已完成节点或整桥验证。

## 验收边界

- 原生 NURBS 曲面组成的有效 Brep；闭合/流形情况和连通体数量明确记录。
- 应连续的接缝实际测量位置、法线及必要的曲率；不预先承诺整个汇合区域全域 G2。
- 横断面展示体积、内外表面、圆转及与上下桥腹的连接。
- 两层道路分别检查宽度、净空、支承位置、两岸接点与底面；保留西侧已完成的开放隧道及底板。
- 造型、局部几何检查与引擎碰撞验收分别报告。
