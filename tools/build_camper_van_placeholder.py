import bpy
import math
import os


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL_DIR = os.path.join(ROOT, "assets", "vehicles", "models")
SOURCE_DIR = os.path.join(ROOT, "assets", "vehicles", "source")
GLB_PATH = os.path.join(MODEL_DIR, "camper_van_placeholder.glb")
BLEND_PATH = os.path.join(SOURCE_DIR, "camper_van_placeholder.blend")


def material(name, color, roughness=0.8, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = next(
        node for node in mat.node_tree.nodes if node.type == "BSDF_PRINCIPLED"
    )
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return mat


def cube(name, location, dimensions, mat, bevel=0.04):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0.0:
        modifier = obj.modifiers.new("Soft placeholder edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.materials.append(mat)
    return obj


def wheel(name, x, y, tire, hub):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=16,
        radius=0.42,
        depth=0.28,
        location=(x, y, 0.47),
        rotation=(0.0, math.radians(90.0), 0.0),
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(tire)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True

    bpy.ops.mesh.primitive_cylinder_add(
        vertices=16,
        radius=0.20,
        depth=0.30,
        location=(x, y, 0.47),
        rotation=(0.0, math.radians(90.0), 0.0),
    )
    hub_obj = bpy.context.object
    hub_obj.name = f"{name}_Hub"
    hub_obj.data.materials.append(hub)


bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

body = material("RV warm ivory", (0.78, 0.76, 0.65))
accent = material("RV muted teal", (0.22, 0.43, 0.43))
glass = material("RV blue glass", (0.13, 0.25, 0.31), roughness=0.3)
rubber = material("RV tires", (0.035, 0.04, 0.045), roughness=0.95)
metal = material("RV wheel hubs", (0.35, 0.37, 0.36), roughness=0.55, metallic=0.35)
light = material("RV lights", (0.94, 0.79, 0.42), roughness=0.45)
rear_light = material("RV rear lights", (0.55, 0.08, 0.055), roughness=0.5)

# Blender uses Z-up. The van is 6.2 m long on Y and 2.3 m wide on X.
cube("RV_Chassis", (0.0, 0.0, 0.66), (2.20, 5.75, 0.34), accent, 0.08)
cube("RV_LivingBox", (0.0, 0.65, 1.70), (2.28, 3.75, 2.20), body, 0.12)
cube("RV_Cab", (0.0, -1.83, 1.43), (2.16, 1.65, 1.62), body, 0.11)
cube("RV_OverCab", (0.0, -1.00, 2.50), (2.28, 1.60, 0.62), body, 0.12)
cube("RV_Roof", (0.0, 0.45, 2.87), (2.18, 4.00, 0.13), accent, 0.05)

# Large, readable windows and door are deliberately simple color blocks.
cube("RV_Windshield", (0.0, -2.67, 1.68), (1.70, 0.055, 0.67), glass, 0.02)
cube("RV_LeftCabWindow", (-1.09, -1.78, 1.70), (0.045, 0.72, 0.62), glass, 0.015)
cube("RV_RightCabWindow", (1.09, -1.78, 1.70), (0.045, 0.72, 0.62), glass, 0.015)
cube("RV_LeftLivingWindow", (-1.16, 0.55, 1.90), (0.045, 1.35, 0.72), glass, 0.02)
cube("RV_RightLivingWindow", (1.16, 1.05, 1.90), (0.045, 0.92, 0.72), glass, 0.02)
cube("RV_SideDoor", (1.165, -0.05, 1.52), (0.045, 0.82, 1.56), accent, 0.02)
cube("RV_RearWindow", (0.0, 2.55, 1.92), (1.35, 0.045, 0.70), glass, 0.02)

cube("RV_FrontBumper", (0.0, -2.80, 0.62), (2.24, 0.16, 0.22), metal, 0.04)
cube("RV_RearBumper", (0.0, 2.80, 0.62), (2.24, 0.16, 0.22), metal, 0.04)
for x in (-0.72, 0.72):
    cube(f"RV_Headlight_{x}", (x, -2.82, 0.94), (0.34, 0.045, 0.22), light, 0.02)
    cube(f"RV_RearLight_{x}", (x, 2.82, 0.96), (0.28, 0.045, 0.25), rear_light, 0.02)

for side, x in (("L", -1.12), ("R", 1.12)):
    wheel(f"RV_Wheel_{side}_Front", x, -1.72, rubber, metal)
    wheel(f"RV_Wheel_{side}_Rear", x, 1.72, rubber, metal)

# A tiny roof unit helps the silhouette read from the third-person camera.
cube("RV_RoofUnit", (0.0, 0.78, 3.02), (1.05, 0.95, 0.20), accent, 0.06)

# Put the authored origin at ground level and keep transforms applied.
bpy.ops.object.select_all(action="SELECT")
for obj in bpy.context.selected_objects:
    if obj.type == "MESH":
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

os.makedirs(MODEL_DIR, exist_ok=True)
os.makedirs(SOURCE_DIR, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
bpy.ops.export_scene.gltf(
    filepath=GLB_PATH,
    export_format="GLB",
    export_apply=True,
    export_yup=True,
    export_materials="EXPORT",
)
print(f"Wrote {GLB_PATH}")
print(f"Wrote {BLEND_PATH}")
