# 小树碎感与黑色孔洞：调研和测试建议

日期：2026-10-01。基线：`0732858`，旧版小树与旧版 LOD。
本次只做资料调研和静态检查，未修改运行时 shader、贴图或模型。
下面的原因排序是依据当前实现提出的待验证判断，不是已完成的因果诊断。

## 1. 结论

用 shader 让局部颜色平稳过渡是可行的。对当前项目，更有价值的是
让树冠的光照、阴影和透明覆盖率稳定，而不是再次增加纹理细节。

当前旧版近景叶簇的不透明区域几乎是同一种颜色。只对 RGB 取平均，
不会消除叶片重叠造成的阴影、透明孔洞、屏幕空间遮蔽或 LOD 抖动。
应按问题来源分别处理，再判断是否需要少量几何修补。

## 2. 当前实现的证据

- 世界小树叶簇贴图为 `leaf_clusters_witness_sparse_flat_v11.png`。
  对 alpha > 220/255 的原始像素统计，RGB 平均值为 [91, 120, 75]，
  三个通道的标准差均为 0。原始颜色没有细碎笔触。
- 旧版中景 clump 图和小树八方向远景图的不透明 RGB 标准差约
  0.5/255，也接近纯色。透明边缘并未包括在上述颜色统计中。
- 上述近景、中景和远景图的 `.import` 均为
  `mipmaps/generate=false`；材质虽声明 mipmap 采样器，实际没有
  mip 链就不能获得其预过滤效果。
- 小树源生成器已有整树椭球法线：
  `tools/build_vegetation_assets.py` 的树冠法线按椭球中心与半径计算，
  并写入自定义顶点法线。不能把“添加球形法线”当成尚未实现的功能。
- 小树 LOD1 已在 shader 中混合整体树冠法线和模型法线，局部法线权重
  0.34。平滑仍需考虑参数、坐标和 LOD 连续性。
- 项目配置 `msaa_3d=2`（4× MSAA），树叶 shader 已使用
  `alpha_to_coverage`；因此也不是缺少这两个开关。
- 世界环境开启 SSAO：半径 1.25、强度 1.20、power 1.30；
  专用植被场景为强度/power 1.35。太阳阴影也开启。
- 近景叶簇启用视角淡出，LOD 转换包含屏幕空间噪声裁剪。
  这些覆盖率变化可能形成碎感，需要单独隔离。
- 源叶簇贴图已经开启 `process/fix_alpha_border=true`。
  黑色区域不能直接归因于未开启边缘修复。

## 3. 资料中有依据的方法

### 整体树冠法线：统一受光形状

让多张叶片卡片共享一个球体或椭球体的法线场，使亮面和暗面按树冠
连续分布。Habrador 的本人制作示例说明了用 Normal Edit 将参考
体的法线用于叶片的方法；它是模仿 Witness 风格的教程，不是
Witness 原团队的制作过程证明。

[Habrador：风格化树与球形法线](https://blog.habrador.com/2018/05/how-to-make-stylized-witness-trees-in.html)

本项目已使用这一思路。进一步测试应检查整体/局部法线比例和
不同 LOD 的一致性，而非简单重复加一次球形法线。
统一法线能平滑受光，不能消除卡片真实投影或没有几何覆盖的孔洞。

### mipmap 与 Alpha 覆盖率：稳定小尺度细节

mipmap 是预先缩小并过滤的纹理，适合避免远处图像颗粒化。
但透明裁剪纹理不能只按普通平均缩小：小叶片的 Alpha 可能低于
裁剪阈值，造成越远越稀疏。Castaño 在为 Witness 植被处理纹理时，
通过每级 mip 的 Alpha 缩放尽量保持通过裁剪的像素比例。

[Godot：纹理导入与 mipmap](https://docs.godotengine.org/en/stable/classes/class_resourceimportertexture.html#mipmaps-generate)
[Castaño：Computing Alpha Mipmaps](https://www.ludicon.com/castano/blog/articles/computing-alpha-mipmaps/)

建议测试旧图的 mip 链及覆盖率补偿，保留图集单元间的足够 padding，
避免低级 mip 串图。若导入器没有对应覆盖率选项，需要离线处理或
自定义加载预制 mip 链。不要把“打开 mipmap”视为已解决孔洞。

### 随距离控制透明裁剪：逐步归并远景形状

Firewatch 原团队的 GDC 演讲明确描述：远处树降低 Alpha cutoff，
使树冠看起来更饱满。它还介绍不同 LOD 对投影几何的简化。

[Jane Ng：Making the World of Firewatch，PDF 第 44–45 页](https://media.gdcvault.com/gdc2016/Presentations/Ng_Jane_MakingTheWorld.pdf)

这是当前项目值得测试的实际案例。它是艺术控制，并不与保持
Alpha 覆盖率完全等价。降低阈值只影响已有的半透明边缘，无法凭空
填补完全透明、没有卡片覆盖的空间，也应避免过度增厚外轮廓。

### Alpha-to-coverage 与时域抗锯齿

Godot 官方说明，MSAA 主要处理几何边缘；Alpha-to-coverage 进一步
处理透明裁剪边缘。TAA 也能减轻透明和 shader 的闪烁，但会带来
模糊和运动拖影。

[Godot：3D 抗锯齿](https://docs.godotengine.org/en/stable/tutorials/3d/3d_antialiasing.html)

我们已使用 4× MSAA 和 Alpha-to-coverage。下一步应评估现有边缘
参数和运动稳定性。TAA 可作为对比项，不能代替更干净的树冠结构。

### 透明边缘颜色与暗部

Godot 的 Fix Alpha Border 用周围颜色填充透明过渡区域，降低双线性
过滤产生的暗边。预乘 Alpha 是另一种表示方式，必须匹配材质的
混合方式，不能仅勾选导入选项。

[Godot：Alpha 边缘修复](https://docs.godotengine.org/en/stable/classes/class_resourceimportertexture.html#process-fix-alpha-border)

对局部纹理 RGB 做平均时，应在线性空间中按 Alpha 加权：
`C = sum(weight * alpha * RGB) / max(sum(weight * alpha), epsilon)`。
普通平均把透明黑色像素一起算进去，可能使叶簇更暗。
RGB 与轮廓 Alpha 的过滤策略应分别设计。

SSAO 会加深屏幕空间遮蔽，其 intensity/power 会影响暗部强度。
我们的环境参数说明它是值得隔离的候选因素，不能证明它就是原因。

[Godot：Environment / SSAO](https://docs.godotengine.org/en/stable/classes/class_environment.html#class-environment-property-ssao-intensity)

## 4. 我们应测试的 shader 方案

采用“树冠连续颜色场 + 整体受光 + 少量局部变化”。

颜色场可由树冠局部高度、椭球位置或低分辨率颜色图控制；
同一树冠邻近位置得到相近的值，细碎变化的权重随距离下降。
颜色变化固定在树的局部空间，避免随相机移动而游走。

示意：`颜色 = mix(树冠连续颜色, 原有叶簇颜色, 局部细节权重)`。
这只控制材质基色，不会自动平均 Godot 后续计算的 SSAO 和阴影。
若碎感主要来自那些项，就需要对它们进行有针对性的调整。

不建议先做全屏模糊：它会混合天空、树干、人物与地面，也难以保留
树冠边界。直接多次采样屏幕颜色还会增加渲染和边界处理成本。
本项目的第一优先级是减少产生碎感的信号，再评估局部过滤。

真正的几何空洞若仍太多，可测试少量较大内层叶簇或一个内收的
低面数树冠内核。这是本项目的候选建模方案，尚未验证；需要保留
主要透空和树干可见性，避免变成实心球。shader 不能替代缺失几何。

## 5. 最小对照实验

保持旧小树、旧贴图、固定相机与太阳，每次只改一组因素。

| 对照 | 操作 | 用途 |
| --- | --- | --- |
| A | 旧版基线 | 保留可回退结果 |
| B | 单独关闭 SSAO，再单独关闭太阳阴影 | 区分遮蔽黑斑与真实阴影 |
| C | 固定风和 LOD，单独关闭视角淡出 | 区分运动、淡出与树本身孔洞 |
| D | 原图生成 mip 并校验 Alpha 覆盖率 | 检查远处细碎/闪烁及变稀疏 |
| E | 连续树冠颜色、受光与暗部范围调整 | 验证 shader 归并颜色的效果 |
| F | 少量内层几何修补 | 仅针对剩余真实空洞 |

关闭阴影只是诊断操作。若确认投影细节过碎，再比较接收阴影策略、
软化阴影或简化投影代理，并检查人物与地面是否仍正确受影。
不能把所有阴影长期关闭作为默认解决方案。

在单树近景、实际玩家高度、中景树林和原四个观景地点观察；
同时看静帧及移动镜头/风动画。判断标准为轮廓、树冠体积、暗部颜色、
空洞数量与运动稳定性，而不是新增多少细节。

本次调研未执行上述对照实验，旧版运行时保持原样。
