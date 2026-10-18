# CAD 世界遮罩局部验证

当前 Rhino 草稿的 6 条开放中心线控制暖白装饰带，其余向上的地表以草地为主。CAD 编辑入口仅使用工作区 `D:/Prism Route/map/map_current.3dm`，不另存独立 CAD 副本。`cad_layout.json` 是本次导出生成的曲线采样及米制宽度记录。

运行 `res://scenes/landscape_mask_test.tscn`。直接使用提交的 GLB 和 RG16F 资源，无需 Rhino、Python 或生成缓存。按 `1` 看抗锯齿遮罩，`2` 看合成的低分辨率硬边诊断，`3` 看相同网格的白模，`V` 切换视角；右键加 WASD/QE 漫游。

曲线放入 Rhino 的 `参考::种植边界` 或其子图层，名称如 `临水线 [w=8]` 指定最大总宽 8 m，端点渐尖；其次读取用户文本 `world_mask_width_m`，都未指定则默认 6 m。隐藏曲线不导出。工具只读取曲线，不重建或覆盖它们。当前「路边3 [w-6]」没有合法宽度标记，按默认 6 m 处理。

更新流程：

1. 在连接的 Rhino 执行 `tools/rhino_landscape_pools.py` 的 `export_test()`。当前导出范围和地形宿主仍限定为这次局部验证，不是通用全岛导出器。
2. 用具备 numpy、Pillow、scipy、opencv 的 Python 执行 `tools/build_landscape_world_mask.py`。
3. 在 Godot 执行 `--path <项目目录> --script res://tools/verify_landscape_world_mask.gd -- --rebuild-mask`，更新距离场资源并覆盖四张验证截图。

缓存只写入忽略目录 `.landscape_mask_build`。日常查看不要使用 `--rebuild-mask`，它需要前两步产生的临时原始数据。

世界 XZ 遮罩在原网格的不透明着色器中混合材质，不叠加覆盖网格。边界使用 CAD 线段距离及 `fwidth` 抗锯齿，高度与坡向限制减少跨层误投；曲面轮廓精度由 Rhino 导出网格单独控制。当前 4096²、560×682 m；15 个源对象，441,485 个三角形。

`review/` 是实际 Godot D3D12 Forward+ 截图。草地仍是程序色块；原有地形接缝、道路重叠和碰撞不属于本次修复范围。主游戏场景未替换。
