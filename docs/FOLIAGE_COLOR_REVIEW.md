# 草地分区与绿树配色检查（2026-10-24）

## 草与地面：不是过时图片

`tools/audit_meadow_color.gd` 将运行时 `landscape_mask.res` 的 RG16F 基础层
与最新 `.current_map_build/landscape_mask.rg16f` 逐像素比较。
4096×4096，共 16,777,216 像素，差异 **0**。资源保存时间较早不代表内容过时。
该遮罩保存 CAD 建筑边界的有符号距离及层高，不是草色分区图。

真正的问题是：草使用世界坐标下的低频噪声分区，地面使用另一套正弦分区。
`landscape.gdshader` 已增加共享分区模式，1021 在草材质完成初始化后，将其实际
noise 资源、scale、warp、transition width 和 center 传给地面。参数如下：

- noise scale：0.00135；warp：210 m；过渡半宽：135 m；center X：20 m。
- 地面干草根色沿用 `#968A55`。
- 绿区底色由草的 `palette_green / palette_dry` 线性颜色倍率自动配对，
  当前约 `#727940`，并非另挑一块偏灰绿的颜色。
- 草保留 ±35 m 的逐叶边界混合与微小明度变化，地面对应其平均分区。

原正弦模式保留为 `use_shared_meadow_biome=false` 的诊断对照；正常 1021
使用共享模式。没有更改草的位置、密度或缓存格式。烘焙签名仍是
`b3f8cc2f8957e6b70ae3f4e2691ecc1debfcfcd1d9a1da524811694b43da4d31`，
无需为本次颜色修正重烘焙。

## 绿树：已确认的清脆叶绿

用户明确否定偏青白的薄荷/青绿方向，目前这些方案已不在可切换选项中。
用户已确认清脆叶绿与当前补光为正式版本。1021 大场景和植物测试场景默认使用
此配色，固定补光 0.06、遮蔽弱化 0.0。已移除 N、M、方括号对比快捷键、
右上角对比提示和对应启动参数。移动、出生点、C 切换角色/房车、H 隐藏界面等原有操作保持。

这次采用同一叶绿色相中的明暗色阶，保持亮部的绿相，而不是通过加入大量蓝色
或抬曝光获得浅色。参照为 [MUI 官方颜色文档的 Material Design Green 色阶](https://mui.com/material-ui/customization/color/)：

| 用途 | 色号 | 来源色阶 |
| --- | --- | --- |
| 深部 | `#2E7D32` | Green 800 |
| 暗部 | `#388E3C` | Green 700 |
| 主色 | `#66BB6A` | Green 400 |
| 亮部 | `#81C784` | Green 300 |

这些是有明确出处的通用配色参照，不是游戏树木材质的行业统一标准。
将其用于本项目树冠、选择该明暗跨度，是本项目的美术试验。
色号是材质输入，不是渲染后屏幕像素；实际观感以同机位截图为准。
此前查阅的 [Epic 风格化材质示例](https://dev.epicgames.com/documentation/en-us/unreal-engine/stylized-rendering-materials?application_version=4.27)
提供材质实例可迭代的工作流参照，没有规定“标准树绿”。离线对比工具仍保留。

正式配色继续使用现有花树的受控色板路径，适用于 1021 的绿树近/中/远 LOD，
保留修补后的树冠、法线、风动和透明裁剪。花树的现有色板保持。
小测试场景的 instance 参数与大场景的 material 参数分别处理，避免共享材质时
把粉色/橙色花树一起染绿。

## 查看与验证

F5 运行 1021，F6 进入植物测试场景，直接显示正式效果。
参数位于 `scripts/foliage_style.gd`，这是一次性材质配置，没有输入处理或额外界面。

旧配色保留供后续部分树种使用，目前不增加树种分配逻辑：

- 原始叶片贴图及 `vegetation_wind.gdshader` / `tree_hlod.gdshader` 的纹理取色路径保留。
- 原材质的 `use_species_palette=0`、原 biome 色调和树种参数保留；正式效果使用材质副本。
- 原 biome 干区色调 `(1.03, 0.98, 0.82)`、绿区色调 `(0.83, 0.97, 0.89)`
  仍在 `vegetation_lod_streamer.gd` 与测试场景中，旧绿色由贴图与这些参数共同构成。
- `tools/foliage_review_comparison.gd` 仅供离线截图调用，能够重现原配色；游戏入口不引用它。

`tools/verify_foliage_style.gd` 在真实大场景及 `-- --grove` 测试场景中检查
正式默认值、花树色板保持、退役快捷键无效果，以及草缓存签名与共享分区。
正式配置实测通过：大场景 9 份绿树材质、24 份花树材质；测试场景 12 份绿树材质、
7 份花树材质。H 隐藏界面仍正常，草缓存签名保持。结果位于忽略目录
`.vegetation_art_build/approved_style_1024/`。

下面为确定正式版本之前的历史对比过程。截图工具已改用独立离线控制器，
不再依赖游戏内快捷键，也不会给正常场景添加对比面板。

`tools/capture_foliage_color.gd` 在真实 1021 的顺光、逆光机位拍摄原色、候选、
恢复原色；固定逆光补光 0.06、遮蔽弱化 0.0，并暂停风动和草提交。
9 份绿树材质参与对比，24 份花树材质的色板参数保持原值；同一机位图元数、
Draw Call 相同。另用 `-- --grove` 检查小测试场景的粉色大树不受绿树配色影响。
当时的 M 循环切换及草缓存签名检查通过；M 现已退役。
没有声称增加的材质运算无性能成本。

`tools/report_foliage_color.py` 还检查恢复原色的图片误差及花树图片不变。
整理的真实截图、色卡与审计结果：

- `screenshots/foliage_green_color_comparison.png`：顺光和逆光各一组。
- `screenshots/foliage_green_palette.png`：输入色号，不带光照。
- `screenshots/meadow_color_mask_comparison.png`：地面旧分区 / 共享分区。
- `screenshots/foliage_green_color_metrics.json`：运行数据与像素恢复检查。

临时截图和遮罩检查数据在忽略目录 `.vegetation_art_build/color_1024/`。
截图整理只进行裁切/缩放/拼接，没有重绘树木或修饰颜色。
