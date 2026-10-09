# model_1009 驾驶与地形测试：已归档

2026-10-09 按用户要求归档。这是临时尺度、驾驶和地形起伏验证，已移出当前 `scenes/`、`scripts/`、`tools/` 与专用资产目录。

- [归档说明与恢复方式](../archive/map_1009_world_test_2026-10-09/README.md)。
- [完整历史测试记录](../archive/map_1009_world_test_2026-10-09/docs/MAP_1009_DRIVE_RELIEF_TEST.md)。
- [原始与起伏地形对比](../archive/map_1009_world_test_2026-10-09/screenshots/map_1009_relief_comparison.png)。

归档包含场景、两版地形、专用脚本、工具、截图和验证结果，通过 `.gdignore` 排除 Godot 资源导入。

## 继续采用的设计结论

- 房车计划长 11 m、宽 3 m；后续道路至少 20 m 宽。
- 房车计划只在道路上行驶。
- 不采用此次实验噪声起伏；微地形由用户在 Rhino 中手工塑形。
- 噪声后续可用于部分纹理细节。

这些结论继续保存在 [道路实施计划](ROAD_IMPLEMENTATION_PLAN.md)。
