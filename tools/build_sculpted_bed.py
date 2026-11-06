import bpy
import bmesh
from mathutils import Vector, Euler, Matrix
import math
from pathlib import Path

# Reset blender
bpy.ops.wm.read_factory_settings(use_empty=True)

out_dir = Path("D:/Prism Route/prism-route/assets/furniture/prism")
out_dir.mkdir(parents=True, exist_ok=True)
glb_path = out_dir / "prism_geo_bed.glb"

# ==========================================
# 1. PBR MATERIALS & VIEWPORT COLORS
# ==========================================
def create_mat(name, base_rgb, roughness, metallic=0.0, v_color=None):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (base_rgb[0], base_rgb[1], base_rgb[2], 1.0)
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
    if v_color:
        mat.diffuse_color = v_color
    else:
        mat.diffuse_color = (base_rgb[0], base_rgb[1], base_rgb[2], 1.0)
    return mat

mat_white = create_mat("Prism_White_Hard", (0.95, 0.96, 0.98), roughness=0.28, metallic=0.0, v_color=(0.95, 0.96, 0.98, 1.0))
mat_cushion = create_mat("Prism_Slate_Blue_Cushion", (0.205, 0.288, 0.385), roughness=0.70, metallic=0.0, v_color=(0.38, 0.48, 0.58, 1.0))
mat_white_fabric = create_mat("Prism_White_Fabric", (0.92, 0.93, 0.95), roughness=0.75, metallic=0.0, v_color=(0.96, 0.96, 0.97, 1.0))
mat_plinth = create_mat("Prism_Brushed_Metal", (0.68, 0.70, 0.73), roughness=0.24, metallic=0.95, v_color=(0.65, 0.67, 0.70, 1.0))

# ==========================================
# 2. METAL PLINTH (RECESSED FLOATING BASE)
# ==========================================
plinth_mesh = bpy.data.meshes.new("Plinth_Mesh")
plinth_obj = bpy.data.objects.new("Plinth", plinth_mesh)
bpy.context.collection.objects.link(plinth_obj)

bm_p = bmesh.new()
# Width 1.42m (X = -0.71 to +0.71), Length 2.24m (Y = -1.26 to +0.98), Height 0.055m
bmesh.ops.create_cube(bm_p, size=1.0)
bm_p.transform(Matrix.Diagonal((1.42, 2.24, 0.055, 1.0)))
bm_p.transform(Matrix.Translation(Vector((0.0, -0.14, 0.0275))))
bm_p.to_mesh(plinth_mesh)
bm_p.free()

plinth_mesh.materials.append(mat_plinth)
bev_p = plinth_obj.modifiers.new("Bevel", "BEVEL")
bev_p.width = 0.035
bev_p.segments = 4

# ==========================================
# 3. FACETED WHITE SHELL (ORIGAMI PLATFORM BED)
# ==========================================
shell_mesh = bpy.data.meshes.new("White_Shell_Mesh")
shell_obj = bpy.data.objects.new("White_Shell", shell_mesh)
bpy.context.collection.objects.link(shell_obj)

bm = bmesh.new()

# Proportions matched to reference image:
# Low foot rim (Z = 0.32m) so mattress pillows over cleanly
Z_base = 0.055
Z_seat_base = 0.200 # Cavity floor under mattress
Z_foot_rim = 0.320  # Low front rim flush with mattress bevel
Z_kink = 0.500      # Inflection kink on side rail
Z_head_in = 0.950   # Headboard inner top
Z_head_out = 1.000  # Headboard outer top
Z_ridge_rear = 0.620 # Origami fold crease at back

X_in = 0.760        # Inner cavity boundary (+X, total 1.52m mattress width)
X_foot_out = 0.860  # Footboard outer corner
X_kink_out = 0.930  # Side rail outer ridge
X_head_out = 0.920  # Headboard outer top corner
X_head_in = 0.760   # Headboard inner top corner
X_base_f = 0.730    # Bottom footprint front
X_base_r = 0.730    # Bottom footprint rear

Y_base_f = -1.260
Y_base_r = 0.980
Y_foot_f = -1.380   # Frontmost apron
Y_foot_in = -1.300  # Front inner lip
Y_kink = 0.320      # Inflection kink moved towards headboard for sleek low sides
Y_head_base = 0.950 # Headboard bottom crease
Y_head_in = 1.220   # Headboard inner top (26.5° lounge recline)
Y_head_out = 1.280  # Headboard outer top
Y_ridge_rear = 1.300 # Rearmost origami crease

v_coords = {
    # Centerline vertices (X = 0)
    "c_base_f": (0.0, Y_base_f, Z_base),
    "c_foot_f": (0.0, Y_foot_f, Z_foot_rim),
    "c_foot_in": (0.0, Y_foot_in, Z_foot_rim),
    "c_bed_f": (0.0, Y_foot_in, Z_seat_base),
    "c_bed_r": (0.0, Y_head_base, Z_seat_base),
    "c_head_in": (0.0, Y_head_in, Z_head_in),
    "c_head_out": (0.0, Y_head_out, Z_head_out),
    "c_ridge_r": (0.0, Y_ridge_rear, Z_ridge_rear),
    "c_base_r": (0.0, Y_base_r, Z_base),
    
    # Outer bottom footprint (+X)
    "o_base_f": (X_base_f, Y_base_f, Z_base),
    "o_base_m": ((X_base_f + X_base_r) * 0.52, (Y_base_f + Y_base_r) * 0.45, Z_base),
    "o_base_r": (X_base_r, Y_base_r, Z_base),
    
    # Front Footboard / Rim (+X)
    "f_rim_in": (X_in, Y_foot_in, Z_foot_rim),
    "f_rim_out": (X_foot_out, Y_foot_f, Z_foot_rim),
    "f_bed_in": (X_in, Y_foot_in, Z_seat_base),
    
    # Side Rail Inflection Kink (+X)
    "k_rail_in": (X_in, Y_kink, Z_kink),
    "k_rail_out": (X_kink_out, Y_kink, Z_kink),
    
    # Headboard Top Corners (+X)
    "h_top_in": (X_head_in, Y_head_in, Z_head_in),
    "h_top_out": (X_head_out, Y_head_out, Z_head_out),
    
    # Rear Ridge Corner (+X)
    "r_ridge": (X_kink_out * 0.95, Y_ridge_rear, Z_ridge_rear),
    
    # Cavity Floor Rear Corner (+X)
    "i_bed_r": (X_in, Y_head_base, Z_seat_base)
}

verts = {}
for k, pt in v_coords.items():
    verts[k] = bm.verts.new(pt)

# 1. Front Foot Apron (canted outward)
bm.faces.new([verts["c_base_f"], verts["o_base_f"], verts["f_rim_out"], verts["c_foot_f"]])
# 2. Foot Rim Top Lip
bm.faces.new([verts["c_foot_f"], verts["f_rim_out"], verts["f_rim_in"], verts["c_foot_in"]])
# 3. Foot Inner Drop to cavity floor
bm.faces.new([verts["c_foot_in"], verts["f_rim_in"], verts["f_bed_in"], verts["c_bed_f"]])
# 4. Side Rail Top - Front segment (Foot to Kink)
bm.faces.new([verts["f_rim_in"], verts["f_rim_out"], verts["k_rail_out"], verts["k_rail_in"]])
# 5. Side Rail Top - Sloping segment (Kink to Headboard)
bm.faces.new([verts["k_rail_in"], verts["k_rail_out"], verts["h_top_out"], verts["h_top_in"]])
# 6. Headboard Top Rim
bm.faces.new([verts["c_head_in"], verts["h_top_in"], verts["h_top_out"], verts["c_head_out"]])
# 7. Headboard Inner Front Face (where cushion rests)
bm.faces.new([verts["c_bed_r"], verts["i_bed_r"], verts["h_top_in"], verts["c_head_in"]])
# 8. Inner Cavity Floor (under mattress)
bm.faces.new([verts["c_bed_f"], verts["f_bed_in"], verts["i_bed_r"], verts["c_bed_r"]])
# 9. Inner Cavity Side Wall
bm.faces.new([verts["f_bed_in"], verts["f_rim_in"], verts["k_rail_in"], verts["i_bed_r"]])
bm.faces.new([verts["k_rail_in"], verts["h_top_in"], verts["i_bed_r"]])
# 10. Outer Flank - Upper Facet (Rail to Ridge)
bm.faces.new([verts["k_rail_out"], verts["h_top_out"], verts["r_ridge"]])
# 11. Outer Flank - Lower Front Facet
bm.faces.new([verts["f_rim_out"], verts["o_base_f"], verts["o_base_m"], verts["k_rail_out"]])
# 12. Outer Flank - Lower Rear Facet
bm.faces.new([verts["k_rail_out"], verts["o_base_m"], verts["o_base_r"], verts["r_ridge"]])
# 13. Rear Back Upper Facet (Folded origami back)
bm.faces.new([verts["c_head_out"], verts["h_top_out"], verts["r_ridge"], verts["c_ridge_r"]])
# 14. Rear Back Lower Facet (Ridge to Base)
bm.faces.new([verts["c_ridge_r"], verts["r_ridge"], verts["o_base_r"], verts["c_base_r"]])
# 15. Bottom Plate (contacting plinth)
bm.faces.new([verts["c_base_f"], verts["c_base_r"], verts["o_base_r"], verts["o_base_m"]])
bm.faces.new([verts["c_base_f"], verts["o_base_m"], verts["o_base_f"]])

bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.to_mesh(shell_mesh)
bm.free()

shell_mesh.materials.append(mat_white)

mod_mirror = shell_obj.modifiers.new("Mirror", "MIRROR")
mod_mirror.use_axis[0] = True
mod_mirror.use_clip = True

bev_s = shell_obj.modifiers.new("Bevel", "BEVEL")
bev_s.width = 0.022
bev_s.segments = 3
bev_s.limit_method = "ANGLE"
bev_s.angle_limit = math.radians(35)

# ==========================================
# 4. MATTRESS (SLATE BLUE-GRAY FABRIC)
# ==========================================
# Width: 1.50m (X = -0.75 to +0.75)
# Length: 2.25m (from Y = -1.33m at front foot to Y = +0.92m at headboard)
# Height: 0.22m to 0.460m (Top surface exactly at 0.460m!)
mat_mesh = bpy.data.meshes.new("Mattress_Mesh")
mat_obj = bpy.data.objects.new("Mattress", mat_mesh)
bpy.context.collection.objects.link(mat_obj)

bm_m = bmesh.new()
bmesh.ops.create_cube(bm_m, size=1.0)
bm_m.transform(Matrix.Diagonal((1.49, 2.25, 0.24, 1.0)))
bm_m.transform(Matrix.Translation(Vector((0.0, -0.205, 0.340))))
bm_m.to_mesh(mat_mesh)
bm_m.free()

mat_mesh.materials.append(mat_cushion)

bev_m = mat_obj.modifiers.new("Bevel", "BEVEL")
bev_m.width = 0.065
bev_m.segments = 5

sub_m = mat_obj.modifiers.new("Subsurf", "SUBSURF")
sub_m.levels = 1

# ==========================================
# 5. DUVET / TOP SHEET (SUBTLE ACCENT ON MATTRESS)
# ==========================================
# Covers the lower 65% of the bed from foot Y = -1.33m up to Y = 0.15m
sheet_mesh = bpy.data.meshes.new("Duvet_Mesh")
sheet_obj = bpy.data.objects.new("Duvet", sheet_mesh)
bpy.context.collection.objects.link(sheet_obj)

bm_d = bmesh.new()
bmesh.ops.create_cube(bm_d, size=1.0)
bm_d.transform(Matrix.Diagonal((1.50, 1.48, 0.022, 1.0)))
bm_d.transform(Matrix.Translation(Vector((0.0, -0.59, 0.466))))
bm_d.to_mesh(sheet_mesh)
bm_d.free()

sheet_mesh.materials.append(mat_cushion)
bev_d = sheet_obj.modifiers.new("Bevel", "BEVEL")
bev_d.width = 0.022
bev_d.segments = 4

# ==========================================
# 6. HEADBOARD CUSHION (PADDED BACKREST)
# ==========================================
head_cush_mesh = bpy.data.meshes.new("Headboard_Cushion_Mesh")
head_cush_obj = bpy.data.objects.new("Headboard_Cushion", head_cush_mesh)
bpy.context.collection.objects.link(head_cush_obj)

bm_h = bmesh.new()
bmesh.ops.create_cube(bm_h, size=1.0)
bm_h.transform(Matrix.Diagonal((1.44, 0.08, 0.48, 1.0)))
rot_h = Matrix.Rotation(-math.radians(26.5), 4, "X")
bm_h.transform(rot_h)
bm_h.transform(Matrix.Translation(Vector((0.0, 1.08, 0.62))))
bm_h.to_mesh(head_cush_mesh)
bm_h.free()

head_cush_mesh.materials.append(mat_cushion)
bev_h = head_cush_obj.modifiers.new("Bevel", "BEVEL")
bev_h.width = 0.035
bev_h.segments = 4

# ==========================================
# 7. DECORATIVE PILLOWS
# ==========================================
# Pillow 1: Long lumbar bolster pillow (Slate blue-gray)
pil1_mesh = bpy.data.meshes.new("Pillow_Lumbar_Mesh")
pil1_obj = bpy.data.objects.new("Pillow_Lumbar", pil1_mesh)
bpy.context.collection.objects.link(pil1_obj)

bm_p1 = bmesh.new()
bmesh.ops.create_cube(bm_p1, size=1.0)
bm_p1.transform(Matrix.Diagonal((0.92, 0.18, 0.22, 1.0)))
rot_p1 = Matrix.Rotation(-math.radians(28.0), 4, "X")
bm_p1.transform(rot_p1)
bm_p1.transform(Matrix.Translation(Vector((0.0, 0.68, 0.53))))
bm_p1.to_mesh(pil1_mesh)
bm_p1.free()

pil1_mesh.materials.append(mat_cushion)
bev_p1 = pil1_obj.modifiers.new("Bevel", "BEVEL")
bev_p1.width = 0.055
bev_p1.segments = 5
sub_p1 = pil1_obj.modifiers.new("Subsurf", "SUBSURF")
sub_p1.levels = 1

# Pillow 2: Small accent pillow (Pure white fabric)
pil2_mesh = bpy.data.meshes.new("Pillow_White_Mesh")
pil2_obj = bpy.data.objects.new("Pillow_White", pil2_mesh)
bpy.context.collection.objects.link(pil2_obj)

bm_p2 = bmesh.new()
bmesh.ops.create_cube(bm_p2, size=1.0)
bm_p2.transform(Matrix.Diagonal((0.46, 0.14, 0.18, 1.0)))
rot_p2 = Matrix.Rotation(-math.radians(22.0), 4, "X")
bm_p2.transform(rot_p2)
bm_p2.transform(Matrix.Translation(Vector((-0.16, 0.52, 0.49))))
bm_p2.to_mesh(pil2_mesh)
bm_p2.free()

pil2_mesh.materials.append(mat_white_fabric)
bev_p2 = pil2_obj.modifiers.new("Bevel", "BEVEL")
bev_p2.width = 0.045
bev_p2.segments = 5
sub_p2 = pil2_obj.modifiers.new("Subsurf", "SUBSURF")
sub_p2.levels = 1

# ==========================================
# 8. MOTION ANCHOR SOCKETS (EMPTIES)
# ==========================================
# 1. Bed Edge Front (Bed foot edge where character sits or kneels in front)
empty_edge = bpy.data.objects.new("Anchor_BedEdge_Front", None)
empty_edge.empty_display_type = "ARROWS"
empty_edge.empty_display_size = 0.35
empty_edge.location = Vector((0.0, -1.33, 0.460))
empty_edge.rotation_euler = Euler((0.0, 0.0, math.radians(180.0)), "XYZ")
bpy.context.collection.objects.link(empty_edge)

# 2. Bed Center Surface (Lying on bed)
empty_center = bpy.data.objects.new("Anchor_Bed_Center", None)
empty_center.empty_display_type = "ARROWS"
empty_center.empty_display_size = 0.35
empty_center.location = Vector((0.0, -0.25, 0.460))
empty_center.rotation_euler = Euler((0.0, 0.0, 0.0), "XYZ")
bpy.context.collection.objects.link(empty_center)

# 3. Bed Headboard Recline (Lounging against headboard)
empty_head = bpy.data.objects.new("Anchor_Bed_Headboard", None)
empty_head.empty_display_type = "ARROWS"
empty_head.empty_display_size = 0.35
empty_head.location = Vector((0.0, 0.60, 0.460))
empty_head.rotation_euler = Euler((0.0, 0.0, 0.0), "XYZ")
bpy.context.collection.objects.link(empty_head)

# ==========================================
# 9. APPLY MODIFIERS & EXPORT GLB
# ==========================================
bpy.context.view_layer.update()

for obj in [plinth_obj, shell_obj, mat_obj, sheet_obj, head_cush_obj, pil1_obj, pil2_obj]:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    for mod in obj.modifiers:
        try:
            bpy.ops.object.modifier_apply(modifier=mod.name)
        except Exception as e:
            print(f"Mod apply error on {obj.name}: {e}")
    obj.select_set(False)

for obj in bpy.data.objects:
    obj.select_set(True)

bpy.ops.export_scene.gltf(
    filepath=str(glb_path),
    export_format='GLB',
    use_selection=True,
    export_apply=True,
    export_yup=True
)

print(f"Successfully baked and exported: {glb_path}")

# ==========================================
# 10. SETUP CAMERA & RENDER SHOWCASE IMAGE
# ==========================================
cam_data = bpy.data.cameras.new("Showcase_Cam")
cam_obj = bpy.data.objects.new("Showcase_Cam", cam_data)
bpy.context.collection.objects.link(cam_obj)
bpy.context.scene.camera = cam_obj

cam_obj.location = Vector((-2.90, -3.80, 1.65))
cam_dir = Vector((0.0, -0.10, 0.45)) - cam_obj.location
rot_quat = cam_dir.to_track_quat('-Z', 'Y')
cam_obj.rotation_euler = rot_quat.to_euler()

light_data = bpy.data.lights.new(name="Sun_Light", type='SUN')
light_data.energy = 4.0
light_obj = bpy.data.objects.new(name="Sun_Light", object_data=light_data)
light_obj.location = Vector((-4.0, -3.0, 5.0))
light_obj.rotation_euler = Euler((math.radians(45), math.radians(20), math.radians(-35)), 'XYZ')
bpy.context.collection.objects.link(light_obj)

fill_data = bpy.data.lights.new(name="Fill_Light", type='SUN')
fill_data.energy = 2.2
fill_obj = bpy.data.objects.new(name="Fill_Light", object_data=fill_data)
fill_obj.rotation_euler = Euler((math.radians(25), math.radians(-35), math.radians(130)), 'XYZ')
bpy.context.collection.objects.link(fill_obj)

scene = bpy.context.scene
scene.render.resolution_x = 1280
scene.render.resolution_y = 720
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.light = 'STUDIO'
scene.display.shading.color_type = 'MATERIAL'

preview_img_path = Path("C:/Users/PC/.gemini/antigravity/brain/51c58479-72e8-436c-a199-d13ab3cac199/sculpted_bed_preview.png")
scene.render.filepath = str(preview_img_path)
bpy.ops.render.render(write_still=True)
print(f"Saved refined preview render to: {preview_img_path}")
