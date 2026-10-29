# 建筑贴图分布与虚线修复 · 2026-10-29

此记录属于先前的全墙随机散布试放，其美术分布已被否定。后续以[单墙美术原型](WALL_FOLIAGE_ART_PROTOTYPE_1029.md)探索顶部密集、向下稀疏的构图；下文的虚线修复与渲染数据仅保留为技术记录。

本轮只修改现有材质试放，不推进曲面巨构的参数化造型。

## 叶片

- 从每个大格子放一簇、吸附接缝，改成独立的随机位置、旋转、等比大小和左右翻转。分布坐标不再依赖接缝网格。
- 同一位置可以叠加第二簇叶片。采样相邻分布单元，跨格的叶簇不会被格子边界切断。
- 每个分布点最多增加八片随机的程序化尖端单叶，保持平涂、无茎、无叶脉；大小接近图集中的叶片。轻微的逐叶/逐簇纯色差使重叠形状可读。
- 四格图集都按正方形采样，取消旧版窄叶簇的横向压缩和低矮叶簇的高度压缩。独立实验室手工矩形也改成居中等比放置。
- 密度默认 0.9，分布单元为 9×9 米，叶簇基准 7×7 米，重叠概率 0.65；局部概率有变化，保留疏密差异。
- 原始 PNG 未修改。叶簇仍使用批准的 v2 alpha 遮罩；新增单叶直接用着色器绘制简单轮廓。

## 接缝

格子由 8×4.5 米放大到 **32×18 米**，宽高各为原来的四倍；接缝本身的宽度仍为 0.018 米。

原先先对坐标 `mod()`，再以跳变后的距离计算 `fwidth()`。在每个面板中线处，周期坐标由正半周期跳到负半周期，导数突然变大，把中间原本空白的部分误判成抗锯齿接缝，产生虚线。

现改用未取模的连续建筑坐标计算像素覆盖宽度，再用于周期接缝。叶片边缘也使用在循环和分支之外计算的连续坐标覆盖宽度。

## 验证

使用实际生产着色器的片段函数，在 1536×864、无 UV 正交测试墙上做 D3D12 渲染。测试时仅改为不受光照，便于测量真实接缝以外的伪影。

- [旧版中线虚线](architecture_detail_revision_1029/seams_old_bug.png) / [修复后的大格子](architecture_detail_revision_1029/seams_fixed.png)：距离真实接缝 0.5 米以外的额外暗像素，由 6,926 降为 **0**。
- [旧叶片](architecture_detail_revision_1029/plants_old.png) / [新叶片](architecture_detail_revision_1029/plants_new.png)：绿色覆盖率由 1.99% 增至 **8.36%（约 4.2 倍）**。该倍数是固定测试墙的测量值，不代表地图每一面的覆盖率。
- 同种子重渲染完全一致；换种子改变分布；密度零没有残留叶片；重叠叶簇和新增单叶都有独立可见贡献。
- 把叶簇设置的宽高交换，渲染结果完全一致，确认不会挤压叶片。
- [完整检查结果](architecture_detail_revision_1029/shader_checks.json)。脚本：`tools/verify_architecture_detail_revision_1029.gd` 与 `tools/validate_architecture_detail_revision_1029.py`。

正式地图同时验证原材质恢复、两层开关、水面倒影更新、源模型与碰撞不变、草地缓存签名，以及 E 键召唤完整流程。见 [正式地图报告](architecture_detail_trial_1029/report.json)。

## 实机与配置

- [修改前近景](architecture_detail_revision_1029/map_previous_near.png) / [当前近景](architecture_detail_revision_1029/map_current_near.png)
- [修改前整体](architecture_detail_revision_1029/map_previous_overview.png) / [当前整体](architecture_detail_revision_1029/map_current_overview.png)
- [当前洞窟外视角](architecture_detail_revision_1029/map_current_walkway.png)

参数仍集中在 `assets/world/architecture_details_1029/trial_settings.json`。新增 `plant_overlap`、`plant_loose_leaves`；原菜单的颜色、密度、独立开关、重新读取配置和整体取消继续有效。
