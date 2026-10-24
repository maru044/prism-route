"""Build a separate four-segment grass card; never overwrite the v6 production mesh.

D:/blender/blender.exe --background --factory-startup --python-exit-code 1
    --python tools/build_grass_gust_model.py
"""
from pathlib import Path
import math
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
bpy.context.preferences.filepaths.save_version = 0
SEGMENTS = 4
WIDTH, HEIGHT = 0.92, 1.15
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
vertices, faces, uvs, weights = [], [], [], []
for axis in range(3):
    angle = axis * math.pi / 3
    right = Vector((math.cos(angle), math.sin(angle), 0)) * WIDTH / 2
    for back in (False, True):
        base = len(vertices)
        for row in range(SEGMENTS + 1):
            t = row / SEGMENTS
            for side in (-1, 1):
                vertices.append(tuple(right * side + Vector((0, 0, HEIGHT * t))))
                uvs.append(((side + 1) / 2, t))
                weights.append(t)
        for row in range(SEGMENTS):
            a = base + row * 2
            face = (a, a + 1, a + 3, a + 2)
            faces.append(tuple(reversed(face)) if back else face)
mesh = bpy.data.meshes.new("GrassCrossGust4Segments")
mesh.from_pydata(vertices, [], faces)
mesh.update()
uv = mesh.uv_layers.new(name="UVMap")
for polygon in mesh.polygons:
    polygon.use_smooth = True
    for loop in polygon.loop_indices:
        uv.data[loop].uv = uvs[mesh.loops[loop].vertex_index]
mesh.normals_split_custom_set_from_vertices([(0, 0, 1)] * len(vertices))
color = mesh.color_attributes.new(name="wind_weight", type="FLOAT_COLOR", domain="POINT")
for index, weight in enumerate(weights):
    color.data[index].color = (weight, weight, weight, 1)
mesh.color_attributes.active_color = color
obj = bpy.data.objects.new("Grass_Star_3Card_Gust_v7", mesh)
bpy.context.collection.objects.link(obj)
obj["height_segments"] = SEGMENTS
obj["base_asset"] = "grass_star_3card_v6.glb"
obj["wind_vertex_color"] = "COLOR_0.r: continuous root-to-tip arc parameter"
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
material = bpy.data.materials.new("Grass_Gust_Preview")
material.use_nodes = True
texture = material.node_tree.nodes.new("ShaderNodeTexImage")
texture.image = bpy.data.images.load(str(ROOT / "assets/vegetation/textures/grass_tuft_straw_minimal_v5.png"))
bsdf = material.node_tree.nodes.get("Principled BSDF")
material.node_tree.links.new(texture.outputs["Color"], bsdf.inputs["Base Color"])
material.node_tree.links.new(texture.outputs["Alpha"], bsdf.inputs["Alpha"])
mesh.materials.append(material)
out = ROOT / "assets/vegetation/models/grass_star_3card_gust_v7.glb"
bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLB", use_selection=True,
                          export_apply=True, export_yup=True, export_vertex_color="ACTIVE",
                          export_materials="NONE")
source = ROOT / "assets/vegetation/source/grass_star_3card_gust_v7.blend"
texture.image.filepath = "//../textures/grass_tuft_straw_minimal_v5.png"
bpy.ops.wm.save_as_mainfile(filepath=str(source))
print(f"GRASS_GUST_MODEL vertices={len(vertices)} triangles={len(faces) * 2} segments={SEGMENTS}")
