# 1026 正式水面与独立对照场景

2026-10-27 调整：关闭水面随大风增强的波纹、倒影模糊和高光扩展。所有水域保持平静时的细微波动，角色涉水涟漪、透底和局部镜像继续启用；草木风力菜单不受影响。以下风力联动和大风截图记录为 10 月 26 日的历史实现。

同日修复人物透明路径与水面合成的兼容性，水下小腿现在参与现有水体吸收和散射；没有额外叠加一层角色水色。见 [角色入水修复记录](CHARACTER_WATER_1027.md)。

人物局部湿润及离水渐干也已接入正式 F5，见 [第二阶段记录](CHARACTER_WETNESS_1027.md)。

本版落实 issue #16 的首轮画面验证：建筑/树群平面倒影、真实浅水透底、风力联动和角色位置涟漪。局部镜像方案已确认采用，正式 F5 地图直接启用，出生点仍为初始洞穴。

## 入口

- F5 直接启动 `scenes/map_1021.tscn`，默认局部镜像与浅水，无需经过测试场景。原有 F/V/C/R/H 与风力菜单继续工作，没有新增快捷键。
- 正式 HUD 移除水面测试跳转，不显示材质对照或测试机位菜单。
- `scenes/water_1026_test.tscn` 仍可单独 F6 或通过 `tools/run_water_1026.ps1` 启动；其中的地图按钮直接进入正式地图。
- `tools/run_water_1026.ps1 -World` 直接进入正式地图。
- `scenes/water_1026_world_test.tscn` 保留为独立 F6 诊断场景。对照菜单由专用脚本 `water_world_test.gd` 提供，正式地图不依赖这个脚本。
- 导出依赖清单包含水面管理器、交互、配置和着色器；测试场景、对照菜单脚本和诊断截图不进入正式包。

小场景可以切换原版、天空反射浅水、局部平面镜像浅水、原生 SSR 不透明水四种路线；平静/微风/大风/24 秒自动风，以及脚步波纹开关。镜面、浅水、海面与角色涉水四个按钮用于观察同一份材质。没有添加额外快捷键。

## 已实现

- `scripts/water/water_manager.gd`：一张半宽半高的 HDR 镜像视口；共享原来的 World3D，使用独立可见层和反射专用代理，不复制游戏逻辑或草地 streamer。建筑和地形共享原网格及原材质参数的裁剪版本；树群共享现有中级 MultiMesh 与配色，近处补树干。只保留相机附近约 240m 的代理，镜像相机远裁剪 400m；没有再次渲染密集草叶。
- 镜像视口使用线性 HDR、线性映射与曝光 1，主画面最后进行原来的 ACES/曝光。天空备用路径复用现有天空 PNG、方向和接缝/极点处理。
- 以世界高度裁剪建筑/地形的水下部分；镜像相机保持直立，避免球形公告板把树冠转到水下。反射相机不改变主视口 active camera，也不成为植被流送目标。
- 水面不可见或俯瞰高度过高时停更反射；重新进入时渐入。每帧更新镜像相机，避免移动时低帧率倒影滞后。
- `water_profiles.gd`：按对象 UUID 映射南湖、北湖、近海、远海；7 个水面有独立 ShaderMaterial，共用一份核心 shader。
- `water_surface.gdshader`：使用实际屏幕颜色和深度计算透底、视线光程吸收和观察角度反射；保留真正的 Sand 床面。岸边浅层渐变与前景采样校验抑制细蓝线、折射光晕。
- 风使用解析多尺度法线、随风移动的局部包络、远景导数过滤，以及对反射纹理本身的少量过滤；不移动 CAD 顶点，不改变水位和碰撞。地图订阅已有 `grass_wind_world.blend`，不更改草风 B。
- `water_interaction.gd`：最多 16 个世界位置事件，波速约 1.10m/s，最长 5 秒逐渐衰减。角色步行/落地的高度振幅分别为 0.020/0.030m（原版的 2.5 倍），波包宽度随年龄从 0.30m 增长，使涉水扰动更清楚。按真实移动距离交替左右脚偏移生成；要求角色落地、实际水面身份及下方地面，桥上/陆地不触发。复位、控制对象切换和远距离传送清空历史。
- 原生 SSR 使用单独的不透明 shader，避免将读取屏幕深度的透明水面误当成原生 SSR 已生效。该模式是实验对照，不提供浅水透底。
- 性能面板增加独立反射视口 GPU 计时；不能把主视口和反射视口计时直接相加当作整帧耗时。

没有新水面图片、草地烘焙或 CAD/GLB 变更。现有天空、树木素材均被复用。
诊断截图反复覆盖 `.current_map_build/water_1026/review/`；仓库仅保留精选截图和报告，`assets/water/review/.gdignore` 阻止这些证据被当成游戏纹理导入。

## 验证与证据

`tools/verify_water_1026.gd` 用真实角色检查涉水、陆地、桥面、传送、波纹寿命和水体隔离，并对四种材质进行不封顶 GPU A/B。额外关闭/改变反射代理、透底和波纹，验证最终像素确实受这些功能影响。

`tools/verify_water_1026_world.gd` 使用正式 202 件、10,350,912 三角形地图和现有草缓存；检查全部 7 件水面仍在零米、水查询层 4 和角色实体掩码 32 保持原样。南北湖底共 103 个样点检查水面覆盖及重叠，并检查反射中的树群、自由/全景/角色/房车镜头切换。性能对照固定风力，等待反射渐入和草块加载完成，避免 AUTO 风相位影响 A/B。

本次目标平台为 Godot 4.7.2、Forward+、Windows D3D12、RTX 5070 Ti；4× MSAA，1600×900 主画面，800×450 反射。精确统计与失败列表见：

- `assets/water/review/render.json`：小场景像素与 GPU 验证。
- `assets/water/review/world_render.json`：正式地图两个固定机位、镜头切换及树群反射验证。
- `assets/water/review/world_geometry.json`：湖床深度和无顶盖水域采样。
- `assets/water/review/small_planar.png`、`small_shallow.png`、`small_ripples.png`：小场景静水、透底和波纹。
- `assets/water/review/world_south_planar.png`、`world_north_planar.png`：地图画面。

地图 mesh SHA256 仍为 `fdae80e03e06ed572843a59acaceb65cf7d05df172ab3bb4e7566f528395ad3a`。
草缓存签名仍为 `332104410f188f3a2eebca87c177bfc25c12f8de89c4941bb5fa414be7588b8d`，完整、损坏数 0。

复现命令（项目根目录，Godot 路径可替换）：

```powershell
& '.\.current_map_build\runtime\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --fixed-fps 60 --script res://tools/verify_water_1026.gd -- --water-verify
& '.\.current_map_build\runtime\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tools/verify_water_1026.gd -- --capture --water-verify
& '.\.current_map_build\runtime\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tools/verify_water_1026_world.gd -- --capture
```

## 当前范围与后续

局部镜像已成为正式默认方案，其他材质路线仅用于独立对照。浅水当前采用屏幕深度/屏幕色，仍受透明排序和屏外采样限制；没有把建筑种植遮罩充当水深。局部水深 atlas、完整海岸反射边界、焦散、泡沫、真实几何海浪、浮力和水下镜头都没有启用。此阶段不需要为调色、风和波纹重新烘焙草地。

角色采用移动距离/落地节奏的脚步 fallback，尚未绑定足骨动画事件；波纹互相叠加，但没有模拟岸边反弹。反射采用限定距离的中级树冠，远景和草叶不会与主镜头逐叶一致。新树种/新材质接入后需要单独核对反射代理及颜色同步。

第三方资料只用于研究，水面/代理/事件代码是项目内实现，未安装水插件或导入第三方演示贴图：

- [研究与验收依据：issue #16](https://github.com/maru044/prism-route/issues/16)
- [The Witness 帧分析](https://blog.thomaspoulet.fr/posts/the-witness-frame-analysis-part-1/)
- [Godot 原生 SSR 文档](https://docs.godotengine.org/en/4.7/tutorials/3d/environment_and_post_processing.html)
- [Godot HDR 视口纹理](https://docs.godotengine.org/en/4.7/classes/class_viewport.html#class-viewport-property-use-hdr-2d)
- [Godot 天空全景坐标实现](https://github.com/godotengine/godot/blob/4.7/servers/rendering/renderer_rd/shaders/environment/sky.glsl)
