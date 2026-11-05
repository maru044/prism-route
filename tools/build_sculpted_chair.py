import bpy
import bmesh
from mathutils import Vector, Euler, Matrix
import math
from pathlib import Path

bpy.ops.wm.read_factory_settings(use_empty=True)

out_dir = Path("D:/Prism Route/prism-route/assets/furniture/prism")
out_dir.mkdir(parents=True, exist_ok=True)
glb_path = out_dir / "prism_geo_chair.glb"

# ==========================================
# 1. PBR MATERIALS
# ==========================================
def create_mat(name, base_rgb, roughness, metallic=0.0):
    mat = bpy.data.materials.new(name=name)
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (base_rgb[0], base_rgb[1], base_rgb[2], 1.0)
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
    return mat

# Pure architectural matte white
mat_white = create_mat("Prism_White_Hard", (0.95, 0.96, 0.98), roughness=0.28, metallic=0.0)

# Muted architectural slate blue-gray for cushions (NO bright blue)
# In sRGB ~ #7D92A6 -> Linear RGB (0.205, 0.288, 0.385)
mat_cushion = create_mat("Prism_Slate_Blue_Cushion", (0.205, 0.288, 0.385), roughness=0.70, metallic=0.0)

# Brushed titanium / satin metallic plinth
mat_plinth = create_mat("Prism_Brushed_Metal", (0.68, 0.70, 0.73), roughness=0.24, metallic=0.95)

# ==========================================
# 2. SCULPTED WHITE SHELL WITH 28° LOUNGE RECLINE
# ==========================================
mesh = bpy.data.meshes.new("White_Shell_Mesh")
obj_shell = bpy.data.objects.new("White_Shell", mesh)
bpy.context.collection.objects.link(obj_shell)

bm = bmesh.new()

# Proportions adjusted for deep recline (27°~28°) to eliminate head/neck clipping:
# - Backrest leans back deeper (Y_top_in = 0.370, Y_top_out = 0.460)
# - Backrest top calibrated to Z = 0.815m (outer 0.835m) so head/hair rest naturally over cushion
# - Low sleek front armrests (Z = 0.42m at front, Z = 0.45m at kink)
# - Ergonomic cavity cradling the reclined back cushion
# - Recessed metallic plinth at bottom (Z = 0.00 to 0.045m)

X_in = 0.345          # Inner cavity side wall
X_arm_f = 0.445       # Front armrest outer rim
X_kink = 0.475        # Inflection point outer rim
X_top_out = 0.450     # Top outer corner of backrest
X_top_in = 0.345      # Top inner corner of backrest
X_ridge_rear = 0.490  # Rear side ridge corner
X_base_f = 0.355      # Base front outer corner
X_base_r = 0.365      # Base rear outer corner

Z_base = 0.045        # Plinth top / shell bottom
Z_seat_base = 0.320   # Cavity floor
Z_arm_f = 0.420       # Low front armrest height
Z_kink = 0.450        # Inflection point height
Z_ridge_rear = 0.390  # Rear corner ridge height
Z_top_in = 0.815      # Top inner rim of backrest frame (calibrated for head/neck clearance)
Z_top_out = 0.835     # Top outer rim of backrest

Y_base_f = -0.270
Y_base_r = 0.360
Y_apron_f = -0.460
Y_arm_f = -0.450
Y_kink = -0.140
Y_seat_r = 0.120      # Inner bottom rear corner where backrest begins
Y_top_in = 0.370      # Reclined backrest inner top (27.5° recline angle!)
Y_top_out = 0.470     # Reclined backrest outer top
Y_ridge_rear = 0.510  # Rearmost origami crease corner

v_coords = {
    # Centerline (X = 0)
    "c_base_f": (0.0, Y_base_f, Z_base),
    "c_apron_f": (0.0, Y_apron_f, Z_seat_base),
    "c_seat_r": (0.0, Y_seat_r, Z_seat_base),
    "c_top_in": (0.0, Y_top_in, Z_top_in),
    "c_top_out": (0.0, Y_top_out, Z_top_out),
    "c_ridge_r": (0.0, Y_ridge_rear, Z_ridge_rear),
    "c_base_r": (0.0, Y_base_r, Z_base),
    
    # Base outer (+X)
    "o_base_f": (X_base_f, Y_base_f, Z_base),
    "o_base_m": ((X_base_f + X_base_r) * 0.52, 0.04, Z_base),
    "o_base_r": (X_base_r, Y_base_r, Z_base),
    
    # Front Apron / Armrest Front
    "f_apron_in": (X_in, Y_apron_f, Z_seat_base),
    "f_arm_in": (X_in, Y_arm_f, Z_arm_f),
    "f_arm_out": (X_arm_f, Y_arm_f, Z_arm_f),
    
    # Kink (Inflection point on armrest top)
    "k_arm_in": (X_in, Y_kink, Z_kink),
    "k_arm_out": (X_kink, Y_kink, Z_kink),
    
    # Backrest Top Corners
    "b_top_in": (X_top_in, Y_top_in, Z_top_in),
    "b_top_out": (X_top_out, Y_top_out, Z_top_out),
    
    # Ridge rear corner
    "r_ridge": (X_ridge_rear, Y_ridge_rear, Z_ridge_rear),
    
    # Cavity seat rear corner
    "i_seat_r": (X_in, Y_seat_r, Z_seat_base)
}

verts = {}
for k, pt in v_coords.items():
    verts[k] = bm.verts.new(pt)

# Create Faces:
# Front Apron
bm.faces.new([verts["c_base_f"], verts["o_base_f"], verts["f_apron_in"], verts["c_apron_f"]])
# Front armrest face
bm.faces.new([verts["f_apron_in"], verts["o_base_f"], verts["f_arm_out"], verts["f_arm_in"]])

# Armrest Top Front Flat
bm.faces.new([verts["f_arm_in"], verts["f_arm_out"], verts["k_arm_out"], verts["k_arm_in"]])
# Armrest Top Sloping to Backrest
bm.faces.new([verts["k_arm_in"], verts["k_arm_out"], verts["b_top_out"], verts["b_top_in"]])

# Top rim of backrest
bm.faces.new([verts["c_top_in"], verts["b_top_in"], verts["b_top_out"], verts["c_top_out"]])

# Outer Flank - Upper Facet
bm.faces.new([verts["k_arm_out"], verts["b_top_out"], verts["r_ridge"]])

# Outer Flank - Lower Front Facet
bm.faces.new([verts["f_arm_out"], verts["o_base_f"], verts["o_base_m"], verts["k_arm_out"]])

# Outer Flank - Lower Rear Facet
bm.faces.new([verts["k_arm_out"], verts["o_base_m"], verts["o_base_r"], verts["r_ridge"]])

# Rear Upper Facet
bm.faces.new([verts["c_top_out"], verts["b_top_out"], verts["r_ridge"], verts["c_ridge_r"]])

# Rear Lower Facet
bm.faces.new([verts["c_ridge_r"], verts["r_ridge"], verts["o_base_r"], verts["c_base_r"]])

# Inner Cavity - Seat Base
bm.faces.new([verts["c_apron_f"], verts["f_apron_in"], verts["i_seat_r"], verts["c_seat_r"]])

# Inner Cavity - Backrest Wall
bm.faces.new([verts["c_seat_r"], verts["i_seat_r"], verts["b_top_in"], verts["c_top_in"]])

# Inner Cavity - Armrest Front Wall
bm.faces.new([verts["f_apron_in"], verts["f_arm_in"], verts["k_arm_in"], verts["i_seat_r"]])

# Inner Cavity - Armrest Sloping Wall
bm.faces.new([verts["k_arm_in"], verts["b_top_in"], verts["i_seat_r"]])

# Bottom Cap
bm.faces.new([verts["c_base_f"], verts["c_base_r"], verts["o_base_r"], verts["o_base_m"], verts["o_base_f"]])

bm.to_mesh(mesh)
bm.free()

# Mirror modifier across X
mod_mirror = obj_shell.modifiers.new(name="Mirror", type='MIRROR')
mod_mirror.use_axis[0] = True
mod_mirror.use_bisect_axis[0] = True
mod_mirror.use_clip = True

# Bevel modifier for rounded edges
mod_bevel = obj_shell.modifiers.new(name="Bevel", type='BEVEL')
mod_bevel.width = 0.016
mod_bevel.segments = 4
mod_bevel.limit_method = 'ANGLE'
mod_bevel.angle_limit = math.radians(20)

bpy.context.view_layer.objects.active = obj_shell
bpy.ops.object.modifier_apply(modifier="Mirror")
bpy.ops.object.modifier_apply(modifier="Bevel")
bpy.ops.object.shade_smooth()
obj_shell.data.materials.append(mat_white)

# ==========================================
# 3. BUILD BLUE-GRAY PLUSH CUSHIONS (27.5° RECLINE)
# ==========================================
def build_cushion(name, size, loc, rot=Euler((0, 0, 0)), bevel_w=0.024):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0))
    cush = bpy.context.active_object
    cush.name = name
    cush.scale = size
    cush.location = loc
    cush.rotation_euler = rot
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    
    bev = cush.modifiers.new(name="Bevel", type='BEVEL')
    bev.width = bevel_w
    bev.segments = 5
    bev.limit_method = 'ANGLE'
    bpy.ops.object.modifier_apply(modifier="Bevel")
    bpy.ops.object.shade_smooth()
    cush.data.materials.append(mat_cushion)
    return cush

# Seat Cushion:
# Sits from Z = 0.320 to 0.420m (thickness = 0.100m, top at ideal seat height 0.420m)
# Extends from Y = -0.460 to Y = +0.100 (depth 0.560m, center Y = -0.180m)
cushion_seat = build_cushion(
    "Cushion_Seat",
    size=(0.676, 0.560, 0.100),
    loc=(0.0, -0.180, 0.370),
    bevel_w=0.025
)

# Back Cushion:
# Reclines BACKWARD at 27.5 degrees:
tilt_rad = -math.radians(27.5)
cushion_back = build_cushion(
    "Cushion_Back",
    size=(0.655, 0.090, 0.520),
    loc=(0.0, 0.205, 0.560),
    rot=Euler((tilt_rad, 0, 0)),
    bevel_w=0.028
)

# ==========================================
# 4. RECESSED METAL PLINTH
# ==========================================
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0))
plinth = bpy.context.active_object
plinth.name = "Base_Plinth"
plinth.scale = (0.700, 0.630, 0.045)
plinth.location = (0.0, 0.045, 0.0225)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

bev_p = plinth.modifiers.new(name="Bevel", type='BEVEL')
bev_p.width = 0.015
bev_p.segments = 3
bpy.ops.object.modifier_apply(modifier="Bevel")
bpy.ops.object.shade_smooth()
plinth.data.materials.append(mat_plinth)

# ==========================================
# 5. JOIN & NORMALIZE TRANSFORMS
# ==========================================
all_objs = [obj_shell, cushion_seat, cushion_back, plinth]
bpy.ops.object.select_all(action='DESELECT')
for o in all_objs:
    o.select_set(True)
bpy.context.view_layer.objects.active = obj_shell
bpy.ops.object.join()

final_obj = bpy.context.active_object
final_obj.name = "prism_geo_chair"

# Check bounding box
verts_world = [final_obj.matrix_world @ v.co for v in final_obj.data.vertices]
min_x = min(v.x for v in verts_world)
max_x = max(v.x for v in verts_world)
min_y = min(v.y for v in verts_world)
max_y = max(v.y for v in verts_world)
min_z = min(v.z for v in verts_world)
max_z = max(v.z for v in verts_world)

print(f"Blender Dimensions: Width(X): {max_x-min_x:.3f}m, Depth(Y): {max_y-min_y:.3f}m, Height(Z): {max_z-min_z:.3f}m, Ground Z: {min_z:.4f}m")

# Exact ground snap: min_z -> 0.0000m
# Center X: -> 0.0000m
offset_z = -min_z
center_x = (min_x + max_x) * 0.5
bm_norm = bmesh.new()
bm_norm.from_mesh(final_obj.data)
for v in bm_norm.verts:
    v.co.x -= center_x
    v.co.z += offset_z
bm_norm.to_mesh(final_obj.data)
bm_norm.free()

final_obj.location = (0, 0, 0)
final_obj.rotation_euler = (0, 0, 0)
final_obj.scale = (1, 1, 1)

# Export GLB
bpy.ops.export_scene.gltf(
    filepath=str(glb_path),
    export_format='GLB',
    use_selection=True,
    export_apply=True
)
print(f"Exported clean GLB to: {glb_path}")
