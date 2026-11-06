import bpy
import bmesh
from mathutils import Vector, Euler, Matrix
import math
from pathlib import Path

# Clear all existing scene data
bpy.ops.wm.read_factory_settings(use_empty=True)

out_dir = Path("D:/Prism Route/prism-route/assets/furniture/prism")
out_dir.mkdir(parents=True, exist_ok=True)
glb_path = out_dir / "prism_geo_desk.glb"

# ==========================================
# 1. PBR MATERIALS
# ==========================================
def create_mat(name, base_rgb, roughness, metallic=0.0, emission_rgb=None, emission_strength=0.0):
    mat = bpy.data.materials.new(name=name)
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (base_rgb[0], base_rgb[1], base_rgb[2], 1.0)
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
        if emission_rgb and "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = (emission_rgb[0], emission_rgb[1], emission_rgb[2], 1.0)
            bsdf.inputs["Emission Strength"].default_value = emission_strength
        elif emission_rgb and "Emission" in bsdf.inputs:
            bsdf.inputs["Emission"].default_value = (emission_rgb[0], emission_rgb[1], emission_rgb[2], 1.0)
    return mat

# Pure architectural matte white shell (#F4F6F9)
mat_white = create_mat("Prism_White_Hard", (0.95, 0.96, 0.98), roughness=0.25, metallic=0.02)

# Brushed titanium metal for collar brackets, foot caps, and subrail (#B8BAC0)
mat_titanium = create_mat("Prism_Brushed_Titanium", (0.76, 0.78, 0.81), roughness=0.35, metallic=0.75)

# Sci-fi LED glow strip (soft architectural luminescence)
mat_led = create_mat("Prism_LED_Strip", (1.0, 1.0, 0.98), roughness=0.10, metallic=0.0,
                     emission_rgb=(1.0, 0.98, 0.92), emission_strength=5.0)

# ==========================================
# 2. KEY PARAMETERS (ERGONOMIC & ARCHITECTURAL)
# ==========================================
# Contact measurement: Keqing hands at Godot (0.0, 0.838, -0.030) -> Blender (0.0, +0.030, 0.838)
Z_top = 0.838       # Tabletop upper surface height
Z_bot = 0.773       # Tabletop lower surface height (thickness = 65mm)
Z_mid = 0.805       # Mid-height ridge for side origami diamond facets

Y_front = -0.090    # Front edge (character side) -> 12cm margin to hands contact point
Y_back  =  0.430    # Rear edge -> total depth = 520mm (adjusted aspect ratio)
Y_center = (Y_front + Y_back) * 0.5 # 0.170m

X_span = 0.725      # Half width -> total width = 1.450m

# ==========================================
# 3. ORIGAMI FACETED TABLETOP
# ==========================================
mesh_top = bpy.data.meshes.new("Tabletop_Mesh")
obj_top = bpy.data.objects.new("Tabletop", mesh_top)
bpy.context.collection.objects.link(obj_top)

bm_top = bmesh.new()

# Create clean origami tabletop box:
bmesh.ops.create_cube(bm_top, size=1.0)
bmesh.ops.scale(bm_top, vec=Vector((X_span * 2.0, Y_back - Y_front, Z_top - Z_bot)), verts=bm_top.verts)
bmesh.ops.translate(bm_top, vec=Vector((0.0, Y_center, (Z_top + Z_bot) * 0.5)), verts=bm_top.verts)

# Chamfer bottom perimeter inward to form 45-degree undercut chamfer
for v in bm_top.verts:
    if v.co.z < Z_mid:
        if v.co.y < Y_center:
            v.co.y += 0.032
        else:
            v.co.y -= 0.032
        if v.co.x > 0:
            v.co.x -= 0.035
        else:
            v.co.x += 0.035

# Add subtle bevel on upper and side edges
bmesh.ops.bevel(bm_top, geom=bm_top.edges[:], offset=0.016, segments=2, profile=0.7, affect='EDGES')

# Add iconic origami end facet (diamond crease at lateral ends)
for v in bm_top.verts:
    dist_x = abs(v.co.x)
    if dist_x > X_span - 0.08:
        dy = abs(v.co.y - Y_center)
        dz = abs(v.co.z - Z_mid)
        if dz < 0.020 and dy < 0.12:
            v.co.x += (1.0 if v.co.x > 0 else -1.0) * 0.018 * (1.0 - dy / 0.12)
        elif dy > 0.16:
            v.co.x -= (1.0 if v.co.x > 0 else -1.0) * 0.022 * ((dy - 0.16) / 0.10)

bmesh.ops.recalc_face_normals(bm_top, faces=bm_top.faces[:])
bm_top.to_mesh(mesh_top)
bm_top.free()
obj_top.data.materials.append(mat_white)
mesh_top.shade_smooth()


# ==========================================
# 4. UNDERSIDE TITANIUM SUB-FRAME & LED STRIP
# ==========================================
Z_frame_top = Z_bot
Z_frame_bot = 0.735
W_frame_x = 1.30
D_frame_y = 0.40

mesh_frame = bpy.data.meshes.new("Underframe_Mesh")
obj_frame = bpy.data.objects.new("Underframe", mesh_frame)
bpy.context.collection.objects.link(obj_frame)

bm_frame = bmesh.new()
bmesh.ops.create_cube(bm_frame, size=1.0)
bmesh.ops.scale(bm_frame, vec=Vector((W_frame_x, D_frame_y, Z_frame_top - Z_frame_bot)), verts=bm_frame.verts)
bmesh.ops.translate(bm_frame, vec=Vector((0.0, Y_center, (Z_frame_top + Z_frame_bot) * 0.5)), verts=bm_frame.verts)
bmesh.ops.bevel(bm_frame, geom=bm_frame.edges[:], offset=0.008, segments=2, affect='EDGES')
bmesh.ops.recalc_face_normals(bm_frame, faces=bm_frame.faces[:])
bm_frame.to_mesh(mesh_frame)
bm_frame.free()
obj_frame.data.materials.append(mat_titanium)
mesh_frame.shade_smooth()

# Embedded LED Light Strips
mesh_led = bpy.data.meshes.new("LED_Strip_Mesh")
obj_led = bpy.data.objects.new("LED_Strip", mesh_led)
bpy.context.collection.objects.link(obj_led)

bm_led = bmesh.new()
bmesh.ops.create_cube(bm_led, size=1.0)
bmesh.ops.scale(bm_led, vec=Vector((0.92, 0.014, 0.010)), verts=bm_led.verts)
bmesh.ops.translate(bm_led, vec=Vector((0.0, Y_front + 0.020, Z_bot - 0.005)), verts=bm_led.verts)

v_idx = len(bm_led.verts)
bmesh.ops.create_cube(bm_led, size=1.0)
v_rear = bm_led.verts[v_idx:]
bmesh.ops.scale(bm_led, vec=Vector((0.92, 0.014, 0.010)), verts=v_rear)
bmesh.ops.translate(bm_led, vec=Vector((0.0, Y_back - 0.020, Z_bot - 0.005)), verts=v_rear)

bmesh.ops.recalc_face_normals(bm_led, faces=bm_led.faces[:])
bm_led.to_mesh(mesh_led)
bm_led.free()
obj_led.data.materials.append(mat_led)
mesh_led.shade_smooth()


# ==========================================
# 5. ORIGAMI SPLAYED COLUMN LEGS (CRISP FACETS)
# ==========================================
def get_leg_cross_section_verts(cx, cy, z, wx, wy, crease_f, crease_o, sign):
    pts = [
        Vector((cx, cy - wy - crease_f, z)),                               # 0: Front crease apex
        Vector((cx + sign * (wx * 0.72), cy - wy * 0.70, z)),              # 1: Front outer corner
        Vector((cx + sign * (wx + crease_o), cy, z)),                      # 2: Outer ridge apex
        Vector((cx + sign * (wx * 0.72), cy + wy * 0.70, z)),              # 3: Rear outer corner
        Vector((cx, cy + wy + crease_f, z)),                               # 4: Rear crease apex
        Vector((cx - sign * (wx * 0.85), cy, z)),                          # 5: Inner face (open leg clearance)
    ]
    return pts

def build_faceted_leg(is_left=True):
    sign = -1.0 if is_left else 1.0
    
    x_top = sign * 0.465
    y_top = Y_center
    z_top = 0.700
    
    x_bot = sign * 0.535
    y_bot = Y_center
    z_bot = 0.038
    
    wx_t = 0.062
    wy_t = 0.092
    crease_f_t = 0.022
    crease_o_t = 0.024
    
    wx_b = 0.072
    wy_b = 0.102
    crease_f_b = 0.026
    crease_o_b = 0.028
    
    bm_l = bmesh.new()
    
    pts_top = get_leg_cross_section_verts(x_top, y_top, z_top, wx_t, wy_t, crease_f_t, crease_o_t, sign)
    pts_bot = get_leg_cross_section_verts(x_bot, y_bot, z_bot, wx_b, wy_b, crease_f_b, crease_o_b, sign)
    
    v_top = [bm_l.verts.new(p) for p in pts_top]
    v_bot = [bm_l.verts.new(p) for p in pts_bot]
    
    n = len(v_top)
    side_faces = []
    vertical_edges = []
    
    for i in range(n):
        i_next = (i + 1) % n
        # Counter-clockwise winding for outward normal
        f = bm_l.faces.new([v_bot[i], v_bot[i_next], v_top[i_next], v_top[i]])
        side_faces.append(f)
            
    # Caps
    bm_l.faces.new(v_top)
    bm_l.faces.new(reversed(v_bot))
    
    bmesh.ops.recalc_face_normals(bm_l, faces=bm_l.faces[:])
    
    # Set smooth shading on faces, but keep vertical crease edges sharp!
    for f in bm_l.faces:
        f.smooth = True
        
    for e in bm_l.edges:
        # Find vertical edges (edges connecting a bot vert to top vert)
        v0, v1 = e.verts
        if (v0 in v_bot and v1 in v_top) or (v0 in v_top and v1 in v_bot):
            # Sharp crease along front apex, outer apex, and rear apex
            e.smooth = False
        else:
            e.smooth = True
            
    return bm_l

# Left Leg
mesh_l_leg = bpy.data.meshes.new("Left_Leg_Mesh")
obj_l_leg = bpy.data.objects.new("Left_Leg", mesh_l_leg)
bpy.context.collection.objects.link(obj_l_leg)
bm_l = build_faceted_leg(is_left=True)
bm_l.to_mesh(mesh_l_leg)
bm_l.free()
obj_l_leg.data.materials.append(mat_white)

# Right Leg
mesh_r_leg = bpy.data.meshes.new("Right_Leg_Mesh")
obj_r_leg = bpy.data.objects.new("Right_Leg", mesh_r_leg)
bpy.context.collection.objects.link(obj_r_leg)
bm_r = build_faceted_leg(is_left=False)
bm_r.to_mesh(mesh_r_leg)
bm_r.free()
obj_r_leg.data.materials.append(mat_white)


# ==========================================
# 6. TITANIUM COLLARS & FOOT CAPS (FLUSH ACCENTS)
# ==========================================
mesh_metal = bpy.data.meshes.new("Metal_Accents_Mesh")
obj_metal = bpy.data.objects.new("Metal_Accents", mesh_metal)
bpy.context.collection.objects.link(obj_metal)

bm_metal = bmesh.new()

def add_cap_to_bmesh(bm_target, x_b, x_t, y, z_l, z_h, wx, wy, cf, co, sign):
    pts_b = get_leg_cross_section_verts(x_b, y, z_l, wx, wy, cf, co, sign)
    pts_t = get_leg_cross_section_verts(x_t, y, z_h, wx, wy, cf, co, sign)
    vb = [bm_target.verts.new(p) for p in pts_b]
    vt = [bm_target.verts.new(p) for p in pts_t]
    n = len(vb)
    for i in range(n):
        inxt = (i + 1) % n
        bm_target.faces.new([vb[i], vb[inxt], vt[inxt], vt[i]])
    bm_target.faces.new(vt)
    bm_target.faces.new(reversed(vb))
    
    # Sharp crease on vertical edges
    for e in bm_target.edges:
        v0, v1 = e.verts
        if (v0 in vb and v1 in vt) or (v0 in vt and v1 in vb):
            e.smooth = False
        else:
            e.smooth = True

# Left Foot Cap (0.000 to 0.038)
add_cap_to_bmesh(bm_metal, -0.538, -0.535, Y_center, 0.000, 0.038, 0.074, 0.104, 0.026, 0.028, -1.0)

# Right Foot Cap (0.000 to 0.038)
add_cap_to_bmesh(bm_metal,  0.538,  0.535, Y_center, 0.000, 0.038, 0.074, 0.104, 0.026, 0.028,  1.0)

# Left Top Collar (0.700 to 0.735)
add_cap_to_bmesh(bm_metal, -0.465, -0.462, Y_center, 0.700, 0.735, 0.063, 0.094, 0.022, 0.024, -1.0)

# Right Top Collar (0.700 to 0.735)
add_cap_to_bmesh(bm_metal,  0.465,  0.462, Y_center, 0.700, 0.735, 0.063, 0.094, 0.022, 0.024,  1.0)

bmesh.ops.recalc_face_normals(bm_metal, faces=bm_metal.faces[:])
bm_metal.to_mesh(mesh_metal)
bm_metal.free()

obj_metal.data.materials.append(mat_titanium)


# ==========================================
# 7. STANDARDIZED INTERACTION SOCKETS (ANCHORS)
# ==========================================
# Floor interaction anchor: (0.0, 0.0, 0.0)
empty_front = bpy.data.objects.new("Anchor_Desk_Front", None)
empty_front.empty_display_type = "ARROWS"
empty_front.empty_display_size = 0.25
empty_front.location = Vector((0.0, 0.0, 0.0))
empty_front.rotation_euler = Euler((0.0, 0.0, 0.0), "XYZ")
bpy.context.collection.objects.link(empty_front)

# Tabletop surface contact anchor: (0.0, 0.838, -0.030) in Godot -> Blender: Vector((0.0, +0.030, 0.838))
empty_surface = bpy.data.objects.new("Anchor_Desk_Surface", None)
empty_surface.empty_display_type = "ARROWS"
empty_surface.empty_display_size = 0.25
empty_surface.location = Vector((0.0, 0.030, Z_top))
empty_surface.rotation_euler = Euler((0.0, 0.0, 0.0), "XYZ")
bpy.context.collection.objects.link(empty_surface)

# Tabletop geometric center anchor: (0.0, 0.838, -0.170) in Godot -> Blender: Vector((0.0, Y_center, Z_top))
empty_center = bpy.data.objects.new("Anchor_Desk_Center", None)
empty_center.empty_display_type = "ARROWS"
empty_center.empty_display_size = 0.25
empty_center.location = Vector((0.0, Y_center, Z_top))
empty_center.rotation_euler = Euler((0.0, 0.0, 0.0), "XYZ")
bpy.context.collection.objects.link(empty_center)


# ==========================================
# 8. EXPORT GLB WITH Y-UP STANDARD
# ==========================================
bpy.context.view_layer.update()
for obj in bpy.data.objects:
    obj.select_set(True)

bpy.ops.export_scene.gltf(
    filepath=str(glb_path),
    export_format='GLB',
    use_selection=True,
    export_apply=True,
    export_yup=True
)
print(f"Exported refined origami desk GLB with anchors to: {glb_path}")
