# 湖畔局部黄绿配色遮罩 · 2026-10-30

当前版本由两张局部遮罩组成：上一张圈出的北湖畔低层区域，以及新红圈内补充的湖岸绿草。原局部遮罩完整保留，新增部分只在本次红圈内生效。初始地区、圈外及上层台地保留原色。正式入口仍为 `scenes/map_1021.tscn`。

## 当前规则

- 全图区域参数恢复原值：中心 X = 20，过渡半宽 135 米，噪声尺度 0.00135，边界扰动 210 米，草叶个体扰动 35 米。
- `lake_green_sdf.res` 保留上一版局部轮廓；`shore_green_sdf.res` 增补本次湖岸。两者均为 384×384 线性浮点有符号距离场，原点和范围保存在资源元数据中，通过最大权重合并，不会减弱之前已调整的绿色。
- 羽化宽度 80 米，完全放在轮廓内部，圈外不增加绿色。40 米及以下完整生效，40–60 米平滑减弱；60 米及以上使用原配色，避免染到上层台地。
- 地表、草和绿色树木各级 LOD 共用配色函数与遮罩；粉、金、橙、红等人工选定树色保留。
- 这是颜色遮罩，不改种植密度、地形、建筑避让、水位或人工树位，无需重新烘焙草。

原遮罩配方为 `tools/build_lake_meadow_mask_1030.gd`。新增湖岸通过 `tools/trace_lake_shore_annotation_1030.py` 提取用户红线内侧，与固定实机参考图进行特征对齐，3,308 个内点的中位配准误差约 0.765 像素；再由 `tools/build_lake_shore_mask_1030.gd` 投影到世界坐标。`shore_annotation.json` 与 `shore_region.json` 保留对齐结果和轮廓，后续重建不必依赖临时截图。

## 当前实机对比

- [本次微调前全景](shore/overview_before.png) / [微调后全景](shore/overview_after.png)
- [本次湖岸近景前](shore/shore_before.png) / [湖岸近景后](shore/shore_after.png)

主路径 `overview_after.png` 已更新为最新结果。`local/` 是上一张局部遮罩的验证记录，`shore/` 是本次微调记录。

## 验证

见 [report.json](report.json)。同一正式场景、同一镜头、D3D12 实机验证通过：

- 3,797 个初始地区树根采样点与原版颜色权重最大差为 0。
- 本次 15,772 个圈外采样点相较微调前最大差为 0；所有 60 米及以上采样点最大差为 0。
- 2,109 个此前偏黄的湖岸内部采样点已以绿色为主。上一张局部遮罩 SHA-256 未变，原有绿色没有减弱。
- 保存的 117 条新增/修改、7 条删除正常加载，现有树木总数 19,470，保存文件 SHA-256 未变。
- 原始随机树位、建筑避让遮罩、草缓存清单 SHA-256 未变，草缓存签名仍为 `ba956502a5277980535f7cf593721cb5134809971f52bead4c27ffa765ecd70a`。

复验命令：

```powershell
& '.current_map_build/runtime/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tools/build_lake_shore_mask_1030.gd --log-file 'D:/Prism Route/prism-route/.current_map_build/lake_shore_build.log'
& '.current_map_build/runtime/Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tools/verify_lake_shore_1030.gd --log-file 'D:/Prism Route/prism-route/.current_map_build/lake_shore_runtime.log'
```
