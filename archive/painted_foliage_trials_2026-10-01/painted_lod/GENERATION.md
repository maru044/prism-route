# Painted foliage source, 2026-10-01

Mode: built-in `image_gen`, editing with three local reference images.
`transparent_background: true`. No CLI/API fallback was used.

The original successful PNG is preserved byte-for-byte as `painted_clumps_v1.png`.
The generated file was:
`C:\Users\PC\.codex\generated_images\01a0ec7f-3b99-7e01-a043-cd658c234ca8\exec-a82cd74e-5ecf-40cd-a63e-c0c99321f15a.png`.

## Reference images, in order

1. `D:\Prism Route\prism-route\assets\vegetation\textures\tree_broad_clump_unlit_4var_v1.png`
2. `D:\Prism Route\assets\新建文件夹\a3ac5c41-23bc-49db-92d8-a5e87bf42020.png`
3. `D:\Prism Route\assets\新建文件夹\2d3b9178-fb14-4efd-b9d3-df71e861d320.png`

## Exact successful prompt

```text
Use case: stylized-concept. Asset: transparent game foliage clump texture atlas for plant LOD and distant forest HLOD. Image 1 is the existing 2x2 atlas to repaint; images 2 and 3 are landscape painting style references only. Repaint the FOUR isolated foliage clumps in image 1 with clear small gouache leaf brush marks grouped into coherent larger masses. Keep exactly two columns and two rows, each cell's clump center, bounding footprint and major asymmetric silhouette. Every clump is a foliage volume fragment, WITHOUT tree trunk, ground or scenery. True transparent alpha background and generous transparent gutters. Restrained neutral muted sage/olive green matching image 1, average RGB roughly 110,130,90. Subtle intrinsic tonal and occlusion variation, about 15 percent, with a few natural small air gaps near the outline and a mostly connected interior. Leaves should resemble the painted foliage in images 2 and 3, with irregular clustered shapes and calm masses readable when reduced to 64 pixels. Neutral illumination: no painted directional sunlight, no rim light, no cast shadows, no glowing or pale fringe. Do not add sky, rocks, flowers, characters, typography, watermark or checkerboard. Avoid photorealism, fuzzy noise and four identical spherical blobs. Return one square production texture atlas.
```

## Derived assets

`tools/build_painted_canopies.py` bakes the accepted Blender tree meshes into
eight-view RGBA atlases using this image. It also records transparency,
linear luminance and original opaque base colors in `atlas_statistics.json`.
These are reproducible render derivatives, not additional generated images.
