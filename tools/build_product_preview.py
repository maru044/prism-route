"""Build the first collectible product mesh and a synthetic studio EXR.

Run with: blender --background --factory-startup --python tools/build_product_preview.py
The EXR is a lighting diagram: clean softboxes, no photographed studio props.
"""

from pathlib import Path
import math

import bpy
import numpy as np


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "products" / "classic_drop"
OUT.mkdir(parents=True, exist_ok=True)
(OUT / "source").mkdir(parents=True, exist_ok=True)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


def material(name, color, metallic=0.0, roughness=0.1):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


glass = material("Outer_Clear_Shell", (0.86, 0.95, 1.0), roughness=0.035)
gel = material("Inner_Blue_Gel", (0.01, 0.26, 0.83), roughness=0.09)
base = material("Clear_Base", (0.82, 0.9, 0.96), roughness=0.07)
bubble_mat = material("Gel_Bubbles", (0.75, 0.94, 1.0), roughness=0.02)


def interpolate(points, subdivisions=7):
    """Catmull-Rom profile through (height, radius) control points."""
    result = []
    for i in range(len(points) - 1):
        p0 = points[max(0, i - 1)]
        p1 = points[i]
        p2 = points[i + 1]
        p3 = points[min(len(points) - 1, i + 2)]
        for j in range(subdivisions):
            t = j / subdivisions
            row = []
            for k in (0, 1):
                value = 0.5 * (
                    2 * p1[k]
                    + (-p0[k] + p2[k]) * t
                    + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t * t
                    + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t * t * t
                )
                row.append(value)
            result.append((row[0], max(0.005, row[1])))
    result.append((points[-1][0], max(0.005, points[-1][1])))
    return result


def lathe(name, controls, mat, sides=64):
    profile = interpolate(controls)
    vertices = []
    faces = []
    for height, radius in profile:
        for side in range(sides):
            theta = 2 * math.pi * side / sides
            # Blender is Z-up; glTF import maps this axis to Godot's Y-up.
            vertices.append((radius * math.cos(theta), radius * math.sin(theta), height))
    for row in range(len(profile) - 1):
        for side in range(sides):
            nxt = (side + 1) % sides
            a = row * sides + side
            b = row * sides + nxt
            faces.append((a, b, b + sides, a + sides))
    faces.append(tuple(reversed(tuple(range(sides)))))
    top = (len(profile) - 1) * sides
    faces.append(tuple(range(top, top + sides)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    for poly in mesh.polygons:
        poly.use_smooth = True
    return obj


lathe(
    "OuterShell",
    [
        (0.47, 0.19), (0.52, 0.28), (0.68, 0.41), (0.91, 0.56),
        (1.25, 0.66), (1.58, 0.64), (1.93, 0.53), (2.29, 0.34),
        (2.62, 0.14), (2.76, 0.025),
    ],
    glass,
)
lathe(
    "BlueGelCore",
    [
        (0.72, 0.13), (0.79, 0.25), (1.02, 0.39), (1.30, 0.47),
        (1.59, 0.45), (1.89, 0.35), (2.23, 0.19), (2.39, 0.015),
    ],
    gel,
)
lathe(
    "ClearBase",
    [
        (0.04, 0.45), (0.045, 0.75), (0.07, 0.91), (0.12, 0.96),
        (0.20, 0.93), (0.26, 0.78), (0.31, 0.49), (0.39, 0.31),
        (0.48, 0.28), (0.51, 0.23),
    ],
    base,
)

for i, (x, y, z, radius) in enumerate(
    [
        (-0.15, 1.12, 0.30, 0.042), (0.18, 1.41, 0.34, 0.052),
        (-0.26, 1.55, 0.20, 0.026), (0.03, 1.80, 0.28, 0.038),
        (0.12, 2.08, 0.15, 0.020), (-0.04, 1.34, 0.41, 0.018),
    ]
):
    # Blender's negative Y faces Godot's positive Z and the preview camera.
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=radius, location=(x, -z, y))
    bubble = bpy.context.object
    bubble.name = f"Bubble_{i:02d}"
    bubble.data.materials.append(bubble_mat)
    for poly in bubble.data.polygons:
        poly.use_smooth = True

bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "source" / "classic_drop.blend"))
bpy.ops.export_scene.gltf(filepath=str(OUT / "classic_drop.glb"), export_format="GLB")


def softbox(azimuth, elevation, width, height, feather=0.035):
    """Equirectangular rectangular light with a soft edge."""
    distance_x = np.abs((az - azimuth + np.pi) % (2 * np.pi) - np.pi)
    distance_y = np.abs(el - elevation)
    x = np.clip((width / 2 - distance_x) / feather + 0.5, 0.0, 1.0)
    y = np.clip((height / 2 - distance_y) / feather + 0.5, 0.0, 1.0)
    return (x * x * (3 - 2 * x)) * (y * y * (3 - 2 * y))


width, height = 2048, 1024
longitude = np.linspace(-np.pi, np.pi, width, endpoint=False, dtype=np.float32)
latitude = np.linspace(np.pi / 2, -np.pi / 2, height, dtype=np.float32)
az, el = np.meshgrid(longitude, latitude)
rgb = np.empty((height, width, 3), dtype=np.float32)
rgb[:] = (0.12, 0.135, 0.16)
panels = [
    (-36, 12, 20, 86, (12.0, 13.0, 15.0)),
    (48, 5, 9, 77, (7.0, 9.0, 12.0)),
    (4, 77, 105, 23, (5.0, 5.5, 6.0)),
    (152, 11, 15, 86, (8.0, 9.0, 11.0)),
    (-135, 13, 38, 67, (1.6, 1.8, 2.1)),
]
for longitude_deg, latitude_deg, width_deg, height_deg, color in panels:
    weight = softbox(*map(math.radians, (longitude_deg, latitude_deg, width_deg, height_deg)))
    rgb += weight[:, :, None] * np.asarray(color, dtype=np.float32)

pixels = np.empty((height, width, 4), dtype=np.float32)
pixels[:, :, :3] = rgb
pixels[:, :, 3] = 1.0
image = bpy.data.images.new("Synthetic_Studio_Softboxes", width, height, alpha=True, float_buffer=True)
image.pixels.foreach_set(pixels.ravel())
bpy.context.scene.render.image_settings.file_format = "OPEN_EXR"
bpy.context.scene.render.image_settings.color_depth = "32"
image.save_render(str(OUT / "synthetic_studio.exr"), scene=bpy.context.scene)
print(f"Product mesh and synthetic studio written to {OUT}")
