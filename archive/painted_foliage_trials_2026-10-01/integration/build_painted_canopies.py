"""Bake coherent eight-direction painted canopies from the accepted trees.

Run with Blender --background --factory-startup --python this_file.
The image generator authors the clump bitmap. Blender reuses the actual close
tree geometry and exports unlit RGBA atlases; no source tree is overwritten.
"""
from pathlib import Path
import math
import json
import sys

import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import build_tree_hlod_assets as bake

OUT = ROOT / "assets" / "vegetation" / "painted_lod"
SOURCE = OUT / "painted_clumps_v1.png"
CELL = 384


def image_statistics(image):
    pixels = np.asarray(image.pixels[:], dtype=np.float32).reshape(-1, 4)
    alpha = pixels[:, 3]
    weight = np.sum(alpha)
    # PNG byte-image pixels are encoded sRGB here. Godot source_color samplers
    # decode them, so normalize detail against the same linear luminance.
    rgb = pixels[:, :3]
    linear_rgb = np.where(rgb <= .04045, rgb / 12.92, ((rgb + .055) / 1.055) ** 2.4)
    luma = linear_rgb @ np.asarray([.299, .587, .114], dtype=np.float32)
    if weight < 1:
        raise RuntimeError("Generated image has no visible pixels")
    return {"size": list(image.size), "alpha_min": float(alpha.min()),
            "alpha_max": float(alpha.max()), "alpha_coverage": float(alpha.mean()),
            "mean_srgb": (np.sum(rgb * alpha[:, None], axis=0) / weight).tolist(),
            "linear_luma_reference": float(np.sum(luma * alpha) / weight)}


def main():
    if not SOURCE.exists():
        raise RuntimeError(f"Missing image-generated clump atlas: {SOURCE}")
    bake.TEMP_DIR = ROOT / ".vegetation_art_build" / "canopy_bake"
    bake.TEMP_DIR.mkdir(parents=True, exist_ok=True)
    source_image = bpy.data.images.load(str(SOURCE), check_existing=False)
    stats = {"clumps": image_statistics(source_image)}
    stats["original_base_colors"] = {}
    for path in sorted((ROOT / "assets/vegetation/textures").glob("tree_*_unlit_*var_v1.png")):
        image = bpy.data.images.load(str(path), check_existing=False)
        stats["original_base_colors"][path.name] = image_statistics(image)["mean_srgb"]
    for path in sorted((ROOT / "assets/vegetation/textures").glob("tree_*_canopy_unlit_8view_v1.png")):
        image = bpy.data.images.load(str(path), check_existing=False)
        stats["original_base_colors"][path.name] = image_statistics(image)["mean_srgb"]
    if stats["clumps"]["alpha_min"] > .01:
        raise RuntimeError("Generated atlas is not transparent")
    for spec in bake.SPECS:
        bpy.ops.wm.open_mainfile(filepath=str(spec["source"]))
        foliage = bake.foliage_objects()
        material = bake.make_unlit_leaf_material(foliage[0].data.materials[0])
        for node in material.node_tree.nodes:
            if node.bl_idname == "ShaderNodeTexImage":
                node.image = bpy.data.images.load(str(SOURCE), check_existing=True)
        bake.assign_bake_material(foliage, material)
        bake.configure_render()
        minimum, maximum = bake.union_bounds(foliage)
        center = (minimum + maximum) * .5
        diameter = max(maximum - minimum)
        paths = []
        for angle in range(8):
            path = bake.TEMP_DIR / f"{spec['key']}_{angle}.png"
            bake.render_view(foliage, center, diameter, angle * math.tau / 8,
                             path, CELL)
            paths.append(path)
        output = OUT / f"painted_{spec['key']}_canopy_8view_v1.png"
        bake.pack_atlas(paths, 4, 2, output)
        atlas = bpy.data.images.load(str(output), check_existing=False)
        stats[spec["key"]] = image_statistics(atlas)
        print("PAINTED_CANOPY", spec["key"], stats[spec["key"]])
    (OUT / "atlas_statistics.json").write_text(json.dumps(stats, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
