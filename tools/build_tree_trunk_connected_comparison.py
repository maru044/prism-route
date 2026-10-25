"""Build only a connected wood comparison. No accepted crown/world asset writes.

Blender background script. Each branch replaces a small 2x2 patch of the parent
with an eight-vertex opening, then bridges that opening into the curved branch.
This is a single closed surface, not joined intersecting tubes or a voxel union.
"""
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[1]
args = sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
species = args[args.index("--species")+1] if "--species" in args else "broad"
if species == "broad":
    PARAMS = ROOT / "assets/vegetation/source/tree_trunk_connected_comparison_v2.json"
    p = json.loads(PARAMS.read_text(encoding="utf-8"))
    source_tree = "tree_medium_broad_clustered_canopy"
else:
    PARAMS = ROOT / "assets/vegetation/source/tree_trunk_species_comparison_v2.json"
    p = json.loads(PARAMS.read_text(encoding="utf-8"))[species]
    source_tree = p["source_tree"]
stem = f"tree_{species}_trunk_connected_comparison_v2"
SOURCE = ROOT / f"assets/vegetation/source/{stem}.blend"
MODEL = ROOT / f"assets/vegetation/models/{stem}.glb"
REPORT = ROOT / (".vegetation_art_build/trunk_comparison/connected_v2_build.json" if species == "broad"
                 else f".vegetation_art_build/trunk_comparison/{species}_v2_build.json")
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.open_mainfile(filepath=str(ROOT / f"assets/vegetation/source/{source_tree}.blend"))
old = next(o for o in bpy.context.scene.objects if o.type == "MESH" and "Trunk" in o.name)
material = old.data.materials[0]
source_levels = sorted(set(round(v.co.z, 5) for v in old.data.vertices))
source_rings = []
for z in source_levels:
    points = [v.co.copy() for v in old.data.vertices if abs(v.co.z-z) < 1e-4]
    c = sum(points, Vector()) / len(points)
    # Source ring vertices already share a stable angular index. Sorting each
    # ring by atan2 would rotate the seam when its small rotation crosses pi.
    ring = [v-c for v in points]
    source_rings.append(ring)
SIDES = len(source_rings[0])
assert SIDES >= 8 and all(len(r) == SIDES for r in source_rings)


def radial(z):
    for i in range(len(source_levels)-1):
        if z <= source_levels[i+1]+1e-6:
            t = (z-source_levels[i])/(source_levels[i+1]-source_levels[i])
            return [a.lerp(b, t) for a, b in zip(source_rings[i], source_rings[i+1])]
    t = (z-source_levels[-1])/(p["main_path_zxy"][-1][0]-source_levels[-1])
    return [v.normalized()*((1-t)*v.length+t*p["main_tip_radius_m"]) for v in source_rings[-1]]


def center(z):
    """Hermite curve in height; only centre positions change, never ring scale."""
    controls = p["main_path_zxy"]
    for i in range(len(controls)-1):
        a, b = controls[i:i+2]
        if z > b[0]+1e-6:
            continue
        span = b[0]-a[0]
        t = (z-a[0])/span
        va, vb = Vector((a[1], a[2])), Vector((b[1], b[2]))
        prev = controls[max(0, i-1)]
        nxt = controls[min(len(controls)-1, i+2)]
        ma = (vb-Vector((prev[1], prev[2])))/(b[0]-prev[0])
        mb = (Vector((nxt[1], nxt[2]))-va)/(nxt[0]-a[0])
        v = (2*t**3-3*t*t+1)*va + (t**3-2*t*t+t)*span*ma
        v += (-2*t**3+3*t*t)*vb + (t**3-t*t)*span*mb
        return Vector((v.x, v.y, z))
    raise ValueError(z)


# Narrow local rings make the branch mouth proportionate to a slender branch,
# rather than stretching a hole over a metre-long parent segment.
ports = []
for branch in p["branches"]:
    z = branch["height_m"]
    r = max(v.length for v in radial(z))*branch["radius_ratio"]
    # Upward-growing branches need a taller crotch than a horizontal socket;
    # otherwise their inner wall cuts back through the parent's upper wall.
    half_height = r*3.0
    ports.append({"z": z, "half_height": half_height, "radius": r, "branch": branch})
levels = set(source_levels)
levels.update(row[0] for row in p["main_path_zxy"])
for port in ports:
    lo, hi = port["z"]-port["half_height"], port["z"]+port["half_height"]
    levels = {z for z in levels if not lo < z < hi}
    levels.update([lo, port["z"], hi])
levels = sorted(levels)
vertices = [center(z)+v for z in levels for v in radial(z)]
uvs = [(side/SIDES, z/source_levels[-1]*3.2) for z in levels for side in range(SIDES)]
faces = []
skipped = set()
for port in ports:
    row = levels.index(port["z"])-1
    angle = math.radians(port["branch"]["azimuth_degrees"])
    def angle_distance(side):
        v = radial(port["z"])[side]
        delta = math.atan2(v.y, v.x)-angle
        return abs(math.atan2(math.sin(delta), math.cos(delta)))
    middle = min(range(SIDES), key=angle_distance)
    col = (middle-1) % SIDES
    port["row"], port["col"] = row, col
    for y in [row, row+1]:
        for x in [col, (col+1) % SIDES]:
            skipped.add((y, x))

def idx(y, x):
    return y*SIDES + x % SIDES

for y in range(len(levels)-1):
    for x in range(SIDES):
        if (y, x) not in skipped:
            faces.append((idx(y,x), idx(y,x+1), idx(y+1,x+1), idx(y+1,x)))
faces.extend([tuple(reversed(range(SIDES))), tuple(idx(len(levels)-1,x) for x in range(SIDES))])
branch_stats = []
for port in ports:
    y, x = port["row"], port["col"]
    boundary = [idx(y,x), idx(y,x+1), idx(y,x+2), idx(y+1,x+2),
                idx(y+2,x+2), idx(y+2,x+1), idx(y+2,x), idx(y+1,x)]
    b = port["branch"]
    start = sum((vertices[i] for i in boundary), Vector())/8
    end = Vector(b["end_xyz"])
    control1 = start+Vector(b["first_handle_xyz"])
    control2 = end+Vector(b["last_handle_xyz"])

    def bezier(t):
        u = 1-t
        return u**3*start+3*u*u*t*control1+3*u*t*t*control2+t**3*end

    def tangent(t):
        u = 1-t
        return (3*u*u*(control1-start)+6*u*t*(control2-control1)+3*t*t*(end-control2)).normalized()

    axis = tangent(0)
    right = axis.cross(Vector((0,0,1))).normalized()
    up = axis.cross(right).normalized()
    angles = [math.atan2((vertices[i]-start).dot(up), (vertices[i]-start).dot(right)) for i in boundary]
    previous = boundary
    distance = 0.0
    last_center = start
    # Transport the frame along the curve to avoid unintended twisting.
    for step in range(1, p["branch_segments"]+1):
        t = step/p["branch_segments"]
        new_axis = tangent(t)
        right = axis.rotation_difference(new_axis) @ right
        right.normalize()
        up = new_axis.cross(right).normalized()
        axis = new_axis
        r = port["radius"]*(1-t)**1.12+b["tip_radius_m"]*t
        current = []
        current_center = bezier(t)
        distance += (current_center-last_center).length
        last_center = current_center
        for side, angle in enumerate(angles):
            current.append(len(vertices))
            vertices.append(current_center+r*(right*math.cos(angle)+up*math.sin(angle)))
            uvs.append((side/8, (port["z"]+distance)/source_levels[-1]*3.2))
        for s in range(8):
            n = (s+1) % 8
            faces.append((previous[s], previous[n], current[n], current[s]))
        previous = current
    faces.append(tuple(previous))
    branch_stats.append({"name": b["name"], "height_m": port["z"], "root_radius_m": port["radius"],
                         "tip_xyz": list(end), "shared_mouth_vertices": len(boundary)})

mesh = bpy.data.meshes.new(f"{species.title()}ConnectedSlimTrunkV2Mesh")
mesh.from_pydata(vertices, [], faces)
mesh.update()
if p.get("bark_uv", False):
    layer = mesh.uv_layers.new(name="UVMap")
    for face in mesh.polygons:
        face_uvs = [uvs[mesh.loops[loop].vertex_index] for loop in face.loop_indices]
        crosses_seam = max(uv[0] for uv in face_uvs)-min(uv[0] for uv in face_uvs) > .5
        for loop, uv in zip(face.loop_indices, face_uvs):
            layer.data[loop].uv = (uv[0]+(1 if crosses_seam and uv[0]<.5 else 0), uv[1])
bm = bmesh.new();bm.from_mesh(mesh)
# A removed patch's centre vertex is intentionally unused.
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_edges], context="VERTS")
bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
bm.verts.ensure_lookup_table();bm.faces.ensure_lookup_table()
nonmanifold = sum(not edge.is_manifold for edge in bm.edges)
components = 0
unseen = set(bm.verts)
while unseen:
    components += 1
    todo = [unseen.pop()]
    while todo:
        for edge in todo.pop().link_edges:
            for v in edge.verts:
                if v in unseen:
                    unseen.remove(v);todo.append(v)
bm.to_mesh(mesh);bm.free();mesh.update()
for face in mesh.polygons:
    face.use_smooth = len(face.vertices) <= 4
mesh.materials.append(material)
obj = bpy.data.objects.new(f"{species.title()}_Trunk_ConnectedComparisonV2", mesh)
bpy.context.collection.objects.link(obj)
for other in list(bpy.context.scene.objects):
    if other != obj:
        bpy.data.objects.remove(other, do_unlink=True)
bpy.ops.object.select_all(action="DESELECT");obj.select_set(True)
bpy.context.view_layer.objects.active = obj
mesh.calc_loop_triangles()
degenerate = sum(tri.area < 1e-10 for tri in mesh.loop_triangles)
max_radius_error = 0.0
for z, source_ring in zip(source_levels, source_rings):
    for v in source_ring:
        expected = center(z)+v
        max_radius_error = max(max_radius_error, min((point.co-expected).length for point in mesh.vertices))
tree = BVHTree.FromPolygons([v.co for v in mesh.vertices], [list(t.vertices) for t in mesh.loop_triangles], all_triangles=True, epsilon=0)
intersections = set()
for a, b in tree.overlap(tree):
    if a < b and not set(mesh.loop_triangles[a].vertices).intersection(mesh.loop_triangles[b].vertices):
        intersections.add((a,b))
assert nonmanifold == 0 and components == 1 and degenerate == 0
assert max_radius_error < 1e-5, max_radius_error
if intersections:
    for a, b in sorted(intersections):
        print("INTERSECTION", a, b, [[list(mesh.vertices[v].co) for v in mesh.loop_triangles[t].vertices] for t in [a,b]])
assert not intersections, sorted(intersections)
obj["comparison_only"] = True
obj["connected_surface"] = True
obj["main_trunk_radii_preserved"] = True
obj["parameters"] = str(PARAMS.relative_to(ROOT))
report = {"species": species, "triangles": len(mesh.loop_triangles), "vertices": len(mesh.vertices),
          "connected_components": components, "nonmanifold_edges": nonmanifold,
          "degenerate_triangles": degenerate, "self_intersections": len(intersections),
          "main_radii_unchanged": max_radius_error < 1e-5, "max_source_section_error_m": max_radius_error,
          "bark_uv": bool(mesh.uv_layers), "branches": branch_stats, "source": str(SOURCE), "model": str(MODEL)}
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
bpy.ops.export_scene.gltf(filepath=str(MODEL), export_format="GLB", use_selection=True,
                        export_apply=True, export_yup=True, export_materials="NONE")
REPORT.parent.mkdir(parents=True, exist_ok=True)
REPORT.write_text(json.dumps(report, indent=2), encoding="utf-8")
print("CONNECTED_TRUNK_COMPARISON", json.dumps(report))
