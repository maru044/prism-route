# 崖壁 B 材质与植被效果图

日期：2026-10-13。使用内置 imagegen，基于现有白模的概念重绘。

原始图保存在同目录 source_overview.png、source_terraces.png；材质植被参考归档为 reference_material_planting.png。

这是材质与种植方向图，不是模型或碰撞验证，也不是已落地的引擎材质。模型保持原状。

## 台地说明

生成配置明确设置九个错层台地；脚本以曲线放样、封口构成闭合体块。宽顶面是设计中的种植与步行平台，并非独立悬浮面。脚本包含端部收尖和顶边斜切：局部尖薄渐隐与突然转折属于当前体量稿需要深化的接头，不能因为整体有效闭合就判定完成。树群放在宽平台内部，留出边缘，最终还需落实覆土、平台厚度和步行连接。

## 完整提示词

```text
Use case: sketch-to-render. Create ONE landscape material-and-vegetation concept render of the user's existing Cliff B building island.
Image 1 is the STRICT GEOMETRY AND CAMERA target, an oblique Rhino screenshot. Image 2 is the same building's terrace detail for geometry only. Image 3 is a warm-white material and planting reference, not replacement architecture.
Remove all Rhino UI, labels and guide lines, fill the frame with the scene. Preserve Image 1's exact oblique viewpoint, long crescent/asymmetric horseshoe roof, rounded end caps, original circular low roof feature, left/near side's irregular arched supports and existing road gallery, concave right/far side's staggered substantial solid terrace masses, neighboring small islands and original roadway layout. No redesign, added storeys, towers, bridges, new perforations or extra terrace bands.
Apply matte warm chalk-white mineral concrete / ivory limestone-plaster: subtle fine mineral grain, restrained warm-grey patina in sheltered joints and at the base, very low contrast surface variation, no shiny marble, no coarse cliff rock and no dense crack texture. Smooth flowing Zaha-inspired architecture.
The projecting terrace tops in Image 2 are intentionally usable planted landscape shelves attached to a SOLID core. Keep these broad shelves. Plant on their wider portions, leave narrow tapering ends bare so geometry remains readable; do not disguise intersections with foliage and do not invent thin floating slabs.
Cover around 55-65% of the broad roof with irregular reclaimed meadow, leave a generous exposed ivory rim, retain the circular roof feature visible. Sage/olive and fresh green grass with subdued golden straw tufts, coherent open grassy areas. Small loose groves of rounded broadleaf trees with stylized full canopies, scattered low shrubs and occasional trailing greenery from terrace edges. Trees correctly small relative to the monumental sixty-metre-high building. Natural irregular planting, no formal ornamental flowerbeds, no tropical palm resort look, no uniform green blanket. Surrounding land has grass and sparse tree groves, existing road ribbons stay clear.
Existing low canyon and perimeter: pale turquoise shallow water, pale sandy bed faintly visible, small gentle ripples; original dry circulation remains under arches. Keep original geography, no new canals.
Bright calm nature-reclaimed post-apocalypse, abandoned near-future monument, clean blue daylight, warm ivory in sunlight and soft grey shade, balanced restrained greens and aqua. Polished stylized 3D GAME architectural concept, simpler foliage and lower-frequency textures than photorealistic resort references. No crowds, vehicles, commercial lights, furniture, text or watermark. Single high resolution widescreen image. Material and planting paint-over, fidelity to existing massing first.
```
