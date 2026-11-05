import bpy
import bmesh
from mathutils import Vector, Euler
import math
from pathlib import Path

# Clear all scene data
bpy.ops.wm.read_factory_settings(use_empty=True)

out_dir = Path("D:/Prism Route/prism-route/assets/furniture/prism")
out_dir.mkdir(parents=True, exist_ok=True)
glb_path = out_dir / "prism_geo_chair.glb"

print(f"Building prism_geo_chair at: {glb_path}")

# ==========================================
# 1. MATERIALS (BLUE & WHITE TECH AESTHETIC)
# ==========================================
def create_mat(name, albedo_rgb, roughness, metallic, emissive_rgb=None, emissive_strength=0.0):
    mat = bpy.data.materials.new(name=name)
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (albedo_rgb[0], albedo_rgb[1], albedo_rgb[2], 1.0)
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
        if emissive_rgb and "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = (emissive_rgb[0], emissive_rgb[1], emissive_rgb[2], 1.0)
            if "Emission Strength" in bsdf.inputs:
                bsdf.inputs["Emission Strength"].default_value = emissive_strength
    return mat

# Pure architectural matte white solid surface (Corian/ceramic)
mat_white = create_mat("Prism_White_Hard", (0.95, 0.96, 0.98), roughness=0.25, metallic=0.0)
# Deep space titanium / dark brushed metal chassis
mat_titanium = create_mat("Prism_Titanium_Metal", (0.18, 0.20, 0.22), roughness=0.22, metallic=0.92)
# Clean cobalt blue minimal flat cushion
mat_blue = create_mat("Prism_Cobalt_Leather", (0.08, 0.25, 0.55), roughness=0.60, metallic=0.0)
# Recessed cyan blue linear accent glow
mat_glow = create_mat("Prism_Cyan_Glow", (0.0, 0.75, 1.0), roughness=0.1, metallic=0.0, emissive_rgb=(0.0, 0.85, 1.0), emissive_strength=4.0)

created_objects = []

def add_beveled_box(name, size, loc, rot=Euler((0, 0, 0)), bevel_width=0.012, segments=3, mat=None):
    # size = (X_width, Y_depth, Z_height)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0))
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    obj.location = loc
    obj.rotation_euler = rot
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    
    if bevel_width > 0:
        bev = obj.modifiers.new(name="Bevel", type='BEVEL')
        bev.width = bevel_width
        bev.segments = segments
        bpy.ops.object.modifier_apply(modifier="Bevel")
        
    bpy.ops.object.shade_smooth()
    if mat:
        obj.data.materials.append(mat)
    created_objects.append(obj)
    return obj

# ==========================================
# 2. BLENDER COORDINATES SPECIFICATION
# ==========================================
# In Blender:
# X: Width [-0.43, +0.43] (0.86m wide)
# Y: Depth [-0.30 (Front), +0.30 (Back)] (0.60m deep)
#    Blender +Y exports to Godot -Z (Backrest at +Y)
#    Blender -Y exports to Godot +Z (Seat opening at -Y)
# Z: Height [0.00 (Ground), 0.85m (Top of Backrest)]

# Target Dimensions:
# - Seat Platform Top: Z = 0.40m
# - Seat Cushion Top: Z = 0.435m (Ideal 0.42m~0.44m seating height)
# - Seat Cushion Center: X = 0.0, Y = 0.0 (Character sits at origin!)
# - Backrest: at Y = +0.28m, top at Z = 0.85m, tilted back (+Y) by 12 degrees
# - Sled/Cantilever Chassis: Ground contact Z = 0.00m

# --- A. White Architectural Seat Shell ---
# (Width 0.86m, Depth 0.58m, Thickness 0.08m)
# Top surface at Z = 0.40m => center Z = 0.36m
add_beveled_box(
    "Seat_Shell_White",
    size=(0.86, 0.58, 0.08),
    loc=(0.0, 0.02, 0.36),
    bevel_width=0.012,
    segments=3,
    mat=mat_white
)

# --- B. White Architectural Backrest ---
# (Width 0.86m, Thickness 0.08m, Height 0.44m)
# Tilted back: rot around X = +12 deg (top leans towards +Y, which is -Z in Godot)
tilt_angle = math.radians(12)
add_beveled_box(
    "Back_Shell_White",
    size=(0.86, 0.08, 0.44),
    loc=(0.0, 0.31, 0.60),
    rot=Euler((tilt_angle, 0, 0)),
    bevel_width=0.012,
    segments=3,
    mat=mat_white
)

# --- C. Cobalt Blue Flat Seat Cushion ---
# (Width 0.80m, Depth 0.52m, Thickness 0.035m)
# Placed on top of seat shell: Z = 0.40 + 0.0175 = 0.4175m, top at 0.435m
add_beveled_box(
    "Cushion_Seat_Blue",
    size=(0.80, 0.52, 0.035),
    loc=(0.0, 0.00, 0.4175),
    bevel_width=0.008,
    segments=3,
    mat=mat_blue
)

# --- D. Cobalt Blue Flat Back Cushion ---
# (Width 0.80m, Thickness 0.025m, Height 0.38m)
add_beveled_box(
    "Cushion_Back_Blue",
    size=(0.80, 0.025, 0.38),
    loc=(0.0, 0.27, 0.60),
    rot=Euler((tilt_angle, 0, 0)),
    bevel_width=0.008,
    segments=3,
    mat=mat_blue
)

# --- E. Titanium Metal Cantilever Frame ---
# Left runner at X = -0.36m, Right runner at X = +0.36m
for side_x in [-0.36, 0.36]:
    # Floor rail: from Y = -0.28 to +0.32, resting on floor Z = 0.00 to 0.04
    add_beveled_box(
        f"Floor_Rail_{'L' if side_x < 0 else 'R'}",
        size=(0.06, 0.62, 0.04),
        loc=(side_x, 0.02, 0.02),
        bevel_width=0.006,
        segments=2,
        mat=mat_titanium
    )
    # Cantilever diagonal riser: rises from floor rear (+Y) towards seat front (-Y)
    # Angle around X: -25 deg
    riser_angle = math.radians(-25)
    add_beveled_box(
        f"Cantilever_Riser_{'L' if side_x < 0 else 'R'}",
        size=(0.055, 0.06, 0.34),
        loc=(side_x, 0.16, 0.18),
        rot=Euler((riser_angle, 0, 0)),
        bevel_width=0.006,
        segments=2,
        mat=mat_titanium
    )
    # Sub-seat mounting rail: under seat at Z = 0.30m
    add_beveled_box(
        f"Subseat_Rail_{'L' if side_x < 0 else 'R'}",
        size=(0.06, 0.52, 0.04),
        loc=(side_x, 0.02, 0.30),
        bevel_width=0.005,
        segments=2,
        mat=mat_titanium
    )

# Transverse crossbeams connecting the two floor rails
add_beveled_box(
    "Base_Crossbeam_Front",
    size=(0.72, 0.06, 0.04),
    loc=(0.0, -0.26, 0.02),
    bevel_width=0.006,
    segments=2,
    mat=mat_titanium
)
add_beveled_box(
    "Base_Crossbeam_Rear",
    size=(0.72, 0.06, 0.04),
    loc=(0.0, 0.30, 0.02),
    bevel_width=0.006,
    segments=2,
    mat=mat_titanium
)

# --- F. Recessed Cyan Glow Accent Seams ---
# Front seam under seat lip (at Y = -0.27m, Z = 0.32m)
add_beveled_box(
    "Glow_Seam_Front",
    size=(0.84, 0.012, 0.008),
    loc=(0.0, -0.27, 0.32),
    bevel_width=0.002,
    segments=1,
    mat=mat_glow
)
# Left and Right side seams
add_beveled_box(
    "Glow_Seam_Left",
    size=(0.012, 0.56, 0.008),
    loc=(-0.428, 0.02, 0.32),
    bevel_width=0.002,
    segments=1,
    mat=mat_glow
)
add_beveled_box(
    "Glow_Seam_Right",
    size=(0.012, 0.56, 0.008),
    loc=(0.428, 0.02, 0.32),
    bevel_width=0.002,
    segments=1,
    mat=mat_glow
)

# ==========================================
# 3. UNIFY & NORMALIZE TRANSFORMS
# ==========================================
bpy.ops.object.select_all(action='DESELECT')
for obj in created_objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = created_objects[0]
bpy.ops.object.join()

final_obj = bpy.context.active_object
final_obj.name = "prism_geo_chair"

# Calculate precise vertices in world space
mw = final_obj.matrix_world
vertices = [mw @ v.co for v in final_obj.data.vertices]
min_x = min(v.x for v in vertices)
max_x = max(v.x for v in vertices)
min_y = min(v.y for v in vertices)
max_y = max(v.y for v in vertices)
min_z = min(v.z for v in vertices)
max_z = max(v.z for v in vertices)

print(f"Pre-normalized Blender: X[{min_x:.3f}, {max_x:.3f}], Y[{min_y:.3f}, {max_y:.3f}], Z[{min_z:.3f}, {max_z:.3f}]")

# We want:
# 1. Center X at 0.0
# 2. Bottom Z at 0.0000m (ground contact)
# 3. Seating cushion center (Y = 0.0) at origin Y = 0.0
# Notice min_z should be 0.0
offset_z = -min_z
center_x = (min_x + max_x) * 0.5
# For Y: the seat cushion was placed with its center at Y = 0.0! Let's keep cushion center at Y = 0.0!
bm = bmesh.new()
bm.from_mesh(final_obj.data)
for v in bm.verts:
    v.co.x -= center_x
    v.co.z += offset_z
bm.to_mesh(final_obj.data)
bm.free()

final_obj.location = (0, 0, 0)
final_obj.rotation_euler = (0, 0, 0)
final_obj.scale = (1, 1, 1)

# Check final
vertices_post = [final_obj.matrix_world @ v.co for v in final_obj.data.vertices]
p_min_x = min(v.x for v in vertices_post)
p_max_x = max(v.x for v in vertices_post)
p_min_y = min(v.y for v in vertices_post)
p_max_y = max(v.y for v in vertices_post)
p_min_z = min(v.z for v in vertices_post)
p_max_z = max(v.z for v in vertices_post)

print(f"Final Blender: Width(X): {p_max_x-p_min_x:.3f}m, Depth(Y): {p_max_y-p_min_y:.3f}m, Height(Z): {p_max_z-p_min_z:.3f}m, Ground Z: {p_min_z:.4f}")

# Export GLB
bpy.ops.export_scene.gltf(
    filepath=str(glb_path),
    export_format='GLB',
    use_selection=True,
    export_apply=True
)

print(f"SUCCESS: Exported {glb_path}")
