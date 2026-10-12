# Cliff B：实体侧错层台地 NURBS 第一版

日期：2026-10-13。依据 `docs/concepts/cliff_b_solid_side_2026-10-13/solid_side_layered_v01.png` 重做实体侧体量。目标是建筑曲面台地，而不是自然崖壁或沿同一轮廓等距退台。

## 打开与编辑

- Rhino 当前文档中的新图层：`崖壁B_错层台地_NURBS_v01`。
- 工作文件：`D:\Prism Route\map\map_cliffB_solid_nurbs_v01.3dm`。
- 仓库归档：`assets/world/cliff_b_solid_nurbs_v01_source/cliff_b_solid_nurbs_v01.3dm`。
- 生成前备份：`D:\Prism Route\map\map_before_cliffB_solid_nurbs_v01.3dm`。
- 前一版规则网格台阶及旧道路侧版本保留在隐藏图层内。

实体侧九个体块分别设置长度、位置、展开深度、高度和顶面坡度，用原生 NURBS 曲线、放样曲面与平面封口制作；并非把多边形网格转成 NURBS。它们与退后的实体内核逐个布尔合并。顶部屋盖改用直线斜切收口，并与主实体合并为一个闭合的 84 面 Brep。中央增加宽约 107 米、高约 19 米的凹入拱形空间及亲水平台。

独立台地、屋盖原件仍保留为隐藏对象，ID 记录在 `generation_state.json` 的 `editable_hidden_ids` 中。需要修改单体时，可先显示这些原件，再重新处理合并后的展示实体。道路侧沿用上一版的不规则开口网格，本次没有将那一侧转换成 NURBS。

## 验证结果

- 主实体有效、闭合，边线自交检查为零。
- 将主实体临时三角化为 77,191 个三角形，BVH 检查未发现非相邻、非共面的三角形穿插；这项检查不覆盖共面重叠和相邻面的全部缺陷。
- 新实体与亲水平台未与七组周边岛屿、地形墙体相交。主实体抽样最近距离约 29.3 米，该值是抽样结果，不是严格最小距离。
- 原道路通行体积与九处底层步行检查无相交。
- 七组原墙体及四块邻岛顶面与生成前备份的原生几何比较一致。
- `docs/cliff_b_solid_nurbs_v01/` 中的四张 PNG 是实际 Rhino 几何视口截图；预览时临时隐藏参考线、切换对象显示方式，随后恢复周边对象的显示属性。

## 当前边界与下一步

这是体量验证稿。布尔合并消除了体块内部的重复面，并形成共享修剪边界，但不代表所有交接均已达到 G1/G2 连续。台地渐隐处仍有局部尖角和突然转折，上层屋盖也仍偏平。下一步先调整这些交接和台地坡向，再细化凹厅内部、台地之间的步行连接与亲水阶梯；植被、门窗和材质细节尚未制作。

## 参数与生成顺序

脚本：`tools/rhino_cliff_b_solid_nurbs.py`；参数：`tools/cliff_b_solid_nurbs_v01.json`。

在包含原 v03 对象的生成前 Rhino 文档内，使用 UTF-8 加载脚本。每一步独立执行，检查结果后再进行下一步，避免重复添加：

```python
import io
p = r'D:\Prism Route\prism-route\tools\rhino_cliff_b_solid_nurbs.py'
ns = {'__file__': p, '__name__': 'cliff_b_recipe'}
exec(compile('\n'.join(io.open(p, encoding='utf-8').read().splitlines()[1:]), p, 'exec'), ns)
# 分次调用：begin；pod_0 至 pod_8；roof；show；
# union_0 至 union_8；final_recess；porch；join_roof；audit；preview。
ns['run']('begin')
```

脚本会拒绝重复阶段及文档序号不匹配。重新生成时使用新的工作状态文件，并从备份文档开始；归档模型已经包含生成结果，无需再执行 `begin`。原生封闭性、邻岛和通行检查在 Rhino 中执行；三角形穿插检查使用 `tools/audit_cliff_b_shell_mesh.py` 在 Blender 后台执行。
