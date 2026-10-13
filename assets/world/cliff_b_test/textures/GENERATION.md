# 暖白人工建筑表面纹理

2026-10-14。基础色使用内置 imagegen 生成，原始文件直接复制保留；最终 shader 将其细节强度压低到 0.20，建筑主色由独立暖白参数控制。

基础色：`warm_white_architecture_albedo.png`，1254 × 1254。
微法线及粗糙度：1024 × 1024，使用 `tools/build_architecture_maps.py` 从周期函数生成新的纹理，不从基础色的明暗猜测凹凸。粗糙度范围 0.67–0.79，微法线强度 0.14。

Godot 使用世界坐标三平面投射，尺度 1.6 米；基础色采用镜像重复来连续连接生成图的边缘。粗糙度和法线使用线性数据采样，基础色使用 sRGB。Blender 源文件也包含三张纹理的材质引用。

设计方向：偏暖的白色、细微颗粒、柔和漫反射，保持人工曲面建筑的完整与光洁。没有自然崖壁纹理、岩层、裂缝、苔藓或烘焙阴影。

## 内置 imagegen 完整提示词

```text
Create one seamless tileable 2048 square PBR BASE COLOR material texture, a flat orthographic 2D texture scan filling every pixel edge to edge. Subject: high-end engineered warm-white architectural microcement / smooth factory-cast white architectural concrete cladding for flowing near-future sculptural architecture. Very pale warm off-white ivory, near-neutral white with only a delicate cream undertone. Extremely subtle uniformly distributed microscopic fine aggregate and micro-pore speckling, low amplitude fine grain. Restrained surface color variations, no large blobs. Clean continuous fabricated surface. NOT chalk cliffs, NOT limestone rock, NOT marble veins, NOT beige sandstone, NOT stucco lumps. NO cracks, dirt, moss, weathering, panels, grooves, seams, grout, tiles, borders, text, objects, lighting, highlights, reflections, directional gradients or baked shadows. Uniform flat diffuse illumination. Entire image should look almost white at a distance, with fine tactile detail only close up. Seamlessly repeating all four edges. This is a usable unlit game albedo texture, not an architectural render.
```
