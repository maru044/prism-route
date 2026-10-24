# 树冠逆光方案（2026-10-24，已确认为正式版本）

用户已确认当前补光与清脆叶绿为正式效果。原版着色器与旧配色保留，供未来树种使用。

## 查看

F5 运行 `map_1021.tscn`，或 F6 运行 `vegetation_grove_test.tscn`。
直接显示正式效果。N、M、[ / ] 对比快捷键、右上角模式文字，以及
`--foliage-lighting=original` / `--green-palette=original` 启动开关已移除。
大场景 H 仍用于隐藏 / 恢复原有界面。修改美术参数通过源码配置进行。

## 当前方案

最初 0.22 补光、0.12 遮蔽弱化的尝试被用户指出对比不足，已收敛为：

- 逆光补光系数 **0.06**；这是着色参数，不是最终像素亮度增加 6%。
- 遮蔽弱化 **0.0**，恢复原来的受遮蔽强度。
- 补光随 `N·L` 平滑变化，最背光处仅接收该系数的四分之一，
  在明暗交界处稍多，向阳面淡出，保留树冠的深色区域和层次。
- 补光跟随方向光的颜色与能量，不使用自发光，也没有整体提高曝光或环境光。

原本的树叶已不投射阴影；本次修改的是树叶自身的着色。
草、建筑、树干、太阳方向、网格、透明裁剪和风动逻辑保持当前设置。
近景与 LOD1 / LOD2 的树叶材质都应用正式效果。

原版仍为 `vegetation_wind.gdshader` / `tree_hlod.gdshader`，本次没有写入这两个文件。
正式树叶着色器为同目录下的 `vegetation_wind_soft_backlight.gdshader` /
`tree_hlod_soft_backlight.gdshader`。
`scripts/foliage_style.gd` 一次性复制并配置树叶材质，保留原 shader 和参数。
草地不纳入这些材质副本。该配置没有输入处理或界面节点。
默认值在该文件与正式 shader 中同步保留。
`tools/build_foliage_backlight_variant.py` 可以从当前原版重新生成正式树叶 shader。

## 检查

以下为正式确认前的历史对比记录；目前仅可由离线工具重拍。
`tools/capture_foliage_backlight.gd` 与独立的 `tools/foliage_review_comparison.gd`
使用真实 1021 大场景，在桥上、
逆光林地和顺光林地分别拍摄 A / B / 恢复 A。固定机位，暂停风动和草地
提交后比较。此次加载 205 个地图网格、19,604 棵树，涉及 33 份树叶材质。
检查原着色器哈希、草材质引用和草烘焙签名未变；无需重烘焙草。
当时 N 切换、方括号调节和 H 隐藏界面的输入检查通过。
正式版本改由 `tools/verify_foliage_style.gd` 验证 N、M、方括号不再改变材质，
H 仍可隐藏界面，并检查各级树叶材质与花树颜色。

同一机位的 Draw Call、图元数在 A/B 间保持相同。这不是 GPU 帧时间测量，
新增光照运算的实际帧时间开销没有在本次定量测量。
截图还检查切回 A 是否恢复原始像素。对比图只做真实截图的裁切、缩放和并排排列。

结果在 `screenshots/foliage_backlight_comparison.png` 和
`screenshots/foliage_backlight_comparison_metrics.json`。
完整临时截图、日志在忽略目录 `.vegetation_art_build/backlight_1024/`。
重拍后运行 `tools/report_foliage_backlight.py` 整理对比图和恢复检查。

实现使用 Godot 的方向光 `light()` 与 `DIFFUSE_LIGHT`，相关内置量定义见
[Godot spatial shader 文档](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html#light-built-ins)。
