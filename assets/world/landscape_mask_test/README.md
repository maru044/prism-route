# CAD 世界遮罩局部验证

已保存的游戏预览资源仍来自前一轮 6 条开放中心线，其余向上的地表以草地为主。当前 CAD 已增加中央大岛、椭圆顶盖两条闭合建筑带中线，共 8 条；读取、导出及闭环遮罩计算验证通过，但本次没有覆盖这里的游戏预览资产，需按下方流程重建后查看新版。CAD 编辑入口仅使用工作区 `D:/Prism Route/map/map_current.3dm`，不另存独立 CAD 副本。`cad_layout.json` 是上一次游戏资源构建的曲线采样及米制宽度记录。

运行 `res://scenes/landscape_mask_test.tscn`。直接使用提交的 GLB 和 RG16F 资源，无需 Rhino、Python 或生成缓存。按 `1` 看抗锯齿遮罩，`2` 看合成的低分辨率硬边诊断，`3` 看相同网格的白模，`V` 切换视角；右键加 WASD/QE 漫游。

曲线放入 Rhino 的 `参考::种植边界` 或其子图层，名称如 `临水线 [w=8]` 指定总宽 8 m，向中线两侧各展开一半；其次读取用户文本 `world_mask_width_m`，都未指定则默认 6 m。开放线保持端点渐尖，闭合线沿环恒宽、无接缝缺口，内外轮廓之间为建筑带，环内仍是草地。隐藏曲线不导出。工具只读取曲线，不重建或覆盖它们。当前「路边3 [w-6]」没有合法宽度标记，按默认 6 m 处理。

中央大岛 `[w=6]` 中线距原顶面边缘 3 m；椭圆顶盖 `[w=3]` 中线距边缘 1.5 m。原 `参考::建筑种植遮罩` 中的两条种植边界保留，位置不同，不是本层建筑带中线。新中线记录源对象和岛体家族图层，导出会加入对应顶盖与阶梯平台，并从各自宿主采样高程，避免两层顶盖互相串高。

更新流程：

1. 在连接的 Rhino 执行 `tools/rhino_landscape_pools.py` 的 `export_test()`。在原局部验证范围上，按曲线关联的顶盖及家族图层补齐宿主和相邻道路；不是通用全岛导出器。最新 CAD 导出为 8 条中线、47 件对象、819,086 三角形，缓存位于 `.landscape_mask_build`。
2. 用具备 numpy、Pillow、scipy、opencv 的 Python 执行 `tools/build_landscape_world_mask.py`。
3. 在 Godot 执行 `--path <项目目录> --script res://tools/verify_landscape_world_mask.gd -- --rebuild-mask`，更新距离场资源并覆盖四张验证截图。

缓存只写入忽略目录 `.landscape_mask_build`。日常查看不要使用 `--rebuild-mask`，它需要前两步产生的临时原始数据。

世界 XZ 遮罩在原网格的不透明着色器中混合材质，不叠加覆盖网格。边界使用 CAD 线段距离及 `fwidth` 抗锯齿，高度与坡向限制减少跨层误投；曲面轮廓精度由 Rhino 导出网格单独控制。这里尚未重建的旧资源为 4096²、560×682 m；15 个源对象，441,485 个三角形。

闭合环带的检查：`python -m unittest discover -s tests -p test_landscape_world_mask.py -v`。实际 CAD 八条曲线的独立验证记录在 `docs/concepts/central_island_mask_2026-10-21/centerline_code_check.json`；测试输出仅写入忽略缓存，不覆盖本目录成品。

`review/` 是实际 Godot D3D12 Forward+ 截图。草地仍是程序色块；原有地形接缝、道路重叠和碰撞不属于本次修复范围。主游戏场景未替换。
