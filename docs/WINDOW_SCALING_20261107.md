# 窗口拉伸与固定 1080p · 2026-11-07

用户要求最大化时画面拉伸铺满窗口，内部渲染分辨率仍为 1920×1080。

`project.godot` 保留原有 1920×1080 基准尺寸与窗口初始尺寸，将 `display/window/stretch/mode` 从 `canvas_items` 改为 `viewport`，并设置 `display/window/stretch/aspect="ignore"`。这样先渲染固定 1080p，再缩放到整个客户区；窗口与 16:9 比例不同时，X／Y 分别拉伸，不加黑边。没有强制修改启动窗口模式，正常最大化操作仍由系统处理。

`scripts/water/water_manager.gd` 的半分辨率镜面视口改为依据主视口 `get_visible_rect().size` 计算。根 Window 的 `size` 是实际窗口尺寸，最大化后可能远大于内部渲染尺寸；不能再用它计算反射分辨率。本次反射保持 960×540。

在正式 `scenes/main.tscn`、D3D12 下启动单个验证实例，保持真实水面镜面路径激活，实测：

| 状态 | 实际窗口客户区 | 主渲染纹理 | 水面反射 |
| --- | --- | --- | --- |
| 普通窗口 | 1280×720 | 1920×1080 | 960×540 |
| 不同宽高比窗口 | 1600×1000 | 1920×1080 | 960×540 |
| 系统最大化 | 2560×1369 | 1920×1080 | 960×540 |

三种状态下最终画布变换的原点均为 `(0,0)`，X／Y 缩放后的边界分别覆盖完整窗口；最大化状态为 `Window.MODE_MAXIMIZED`。验证完成后实例已退出。中间脚本、日志和数值报告位于忽略目录 `.current_map_build/window_stretch_1107/`，没有增加自动启动脚本或更改模型、材质、植被及烘焙。

Godot 的 [多分辨率说明](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html) 区分了 `canvas_items` 与固定渲染后拉伸的 `viewport` 模式。后续如果希望根据窗口增加实际渲染分辨率，应作为独立画质选项处理；不要仅为最大化而改高基准分辨率。
