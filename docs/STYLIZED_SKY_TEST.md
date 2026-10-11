# 清新天空测试（2026-10-12）

植物小场景 `scenes/vegetation_grove_test.tscn` 已使用用户选定的中间稿。打开该场景，按 F6 查看。

## 美术资产

- 当前贴图：`assets/environment/sky/fresh_cumulus_panorama_v2.png`，1774 × 887，2:1 全景 PNG。
- 中间稿保留清新青蓝渐变、暖白积云和较宽的天空留白；云尺度以用户最终选择为准。
- 初版保存在 `fresh_cumulus_panorama_v1.png`。最终更小的试稿没有接入。
- 使用内置 imagegen 生成；完整生成和编辑提示词保存在同目录的 `fresh_cumulus_generation.json`。
- 这是用于视觉背景的静态风格化贴图。原 HDRI 继续负责照明。

## Godot 接入

`fresh_cumulus_sky.tres` 使用 `stylized_panorama.gdshader`：可见天空采样新 PNG，环境辐射采样原 `rosendal_park_sunset_puresky_4k.exr`，保持原能量 0.48。曝光、太阳和环境光参数沿用小场景原设置。

Shader 对全景两侧各 1.5% 的窄边缘进行颜色衔接，并在上下极点渐变为不随经度变化的颜色，处理球面接缝与极点放射纹。PNG 原稿保持不变。其他植物诊断场景沿用原天空。

## 验证

Godot 4.7.2 实际 GPU 渲染通过，保存四组相同构图的前后对照、八个水平方向和上下极点截图。各方向已检查，未见明显接缝。

使用 `RenderingServer.environment_bake_panorama` 对比原天空与新天空的线性辐射和漫反射照明数据：两者最大 RGB 差值均为 **0.0**，失败项为空。证据保存在 `STYLIZED_SKY_TEST_REPORT.json`。

项目内总览截图：`screenshots/vegetation_grove_fresh_sky.png`。完整本地对照：`D:/Prism Route/review/sky_art_review_20261012/selected_v2/`。

可在项目根目录执行以下命令复现（需要图形渲染，不能加 `--headless`）：

```powershell
& 'D:\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tools/capture_fresh_sky.gd
```

默认输出到 `.model_import_build/sky_art_review/`；可在末尾添加 `-- --output=目标目录`。

实现参考：[Godot Sky shader](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/sky_shader.html)、[环境全景烘焙](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-environment-bake-panorama)。
