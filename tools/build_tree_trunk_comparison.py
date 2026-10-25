"""Isolated thin-trunk comparison. Never rebuild or export the accepted foliage.

D:/blender/blender.exe --background --factory-startup --python-exit-code 1
    --python tools/build_tree_trunk_comparison.py
"""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
PARAMS = ROOT / "assets/vegetation/source/tree_trunk_thin_comparison_v1.json"
OUT = ROOT / "assets/vegetation/models/tree_broad_trunk_thin_comparison_v1.glb"
SOURCE = ROOT / "assets/vegetation/source/tree_broad_trunk_thin_comparison_v1.blend"
REPORT = ROOT / ".vegetation_art_build/trunk_comparison/build.json"
p = json.loads(PARAMS.read_text(encoding="utf-8"))
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.open_mainfile(filepath=str(ROOT / "assets/vegetation/source/tree_medium_broad_clustered_canopy.blend"))
trunk = next(o for o in bpy.context.scene.objects if o.type == "MESH" and "Trunk" in o.name)
# Keep the actual source rings and their radii. Only translate their centres.
original = [v.co.copy() for v in trunk.data.vertices]
height = max(v.z for v in original)

def center(z):
    u = max(0.0, min(1.0, z / height))
    return Vector((p["bend_m"] * (math.sin(math.pi*u) + 0.2*u),
                   p["side_bend_m"] * math.sin(math.pi*u), z))

def original_center(z):
    ring = [v for v in original if abs(v.z-z)<1e-4]
    return sum(ring, Vector())/len(ring)

def radius_at(z):
    levels = sorted(set(round(v.z, 5) for v in original))
    radii = []
    for level in levels:
        c = original_center(level)
        radii.append(max((v-c).xy.length for v in original if abs(v.z-level)<1e-4))
    for i in range(len(levels)-1):
        if z <= levels[i+1]:
            t = (z-levels[i])/(levels[i+1]-levels[i])
            return radii[i]*(1-t)+radii[i+1]*t
    return radii[-1]

for vertex, old in zip(trunk.data.vertices, original):
    vertex.co = old + center(old.z)-Vector((0,0,old.z))
trunk.data.update()
parts = [trunk]
branch_stats = []
for i, branch in enumerate(p["branches"]):
    z = height*branch["start_height"]
    # Start at the trunk centre: the thin join is embedded, never a thick collar.
    start = original_center(z) if any(abs(v.z-z)<1e-4 for v in original) else Vector((0,0,z))
    start += center(z)-Vector((0,0,z))
    angle = math.radians(branch["azimuth_degrees"])
    reach = height*branch["reach"]
    end = Vector((math.cos(angle)*reach,math.sin(angle)*reach,height*branch["end_height"]))
    control = start.lerp(end,0.42)+Vector((0,0,-height*branch.get("control_drop",.035)))
    r0 = radius_at(z)*branch["radius_ratio"]
    vertices, faces = [], []
    sides = p["branch_sides"]
    steps = p["branch_segments"]
    for row in range(steps+1):
        t = row/steps
        c = (1-t)**2*start+2*(1-t)*t*control+t*t*end
        tangent = (2*(1-t)*(control-start)+2*t*(end-control)).normalized()
        right = tangent.cross(Vector((0,0,1)))
        if right.length<1e-5:right=Vector((1,0,0))
        right.normalize();up=tangent.cross(right).normalized()
        radius = r0*(1-t)**.85+p["tip_radius_m"]*t
        for side in range(sides):
            theta=math.tau*side/sides
            vertices.append(c+radius*(right*math.cos(theta)+up*math.sin(theta)))
    for row in range(steps):
        for side in range(sides):
            a=row*sides+side;b=row*sides+(side+1)%sides
            faces.append((a,b,b+sides,a+sides))
    faces.extend([tuple(reversed(range(sides))),tuple(steps*sides+s for s in range(sides))])
    mesh=bpy.data.meshes.new(f"ThinBranch{i+1}Mesh");mesh.from_pydata(vertices,[],faces);mesh.update()
    for poly in mesh.polygons[:-2]:poly.use_smooth=True
    obj=bpy.data.objects.new(f"ThinBranch{i+1}",mesh);bpy.context.collection.objects.link(obj)
    obj.data.materials.append(trunk.data.materials[0]);parts.append(obj)
    branch_stats.append({"root_radius_m":r0,"max_radius_ratio":branch["radius_ratio"]})

bpy.ops.object.select_all(action="DESELECT")
for obj in parts:obj.select_set(True)
bpy.context.view_layer.objects.active=trunk;bpy.ops.object.join()
trunk.name="Camphor_Trunk_ThinComparison";trunk.data.name="ThinCurvedBranchTrunkMesh"
# The comparison .blend contains only the wood. Original full-tree .blend is untouched.
for obj in list(bpy.context.scene.objects):
    if obj!=trunk:bpy.data.objects.remove(obj,do_unlink=True)
trunk["comparison_only"]=True
trunk["main_trunk_radii_preserved"]=True
trunk["parameters"]=str(PARAMS.relative_to(ROOT))
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
bpy.ops.export_scene.gltf(filepath=str(OUT),export_format="GLB",use_selection=True,
    export_apply=True,export_yup=True,export_materials="NONE")
trunk.data.calc_loop_triangles()
# Translation preserves every original ring's radial distances exactly.
max_error=0.0
for i,old in enumerate(original):
    expected=old+center(old.z)-Vector((0,0,old.z))
    max_error=max(max_error,(trunk.data.vertices[i].co-expected).length)
report={"height_m":height,"bend_m":p["bend_m"],"main_ring_translation_error":max_error,
        "main_radii_unchanged":max_error<1e-5,"branches":branch_stats,
        "triangles":len(trunk.data.loop_triangles),"source":str(SOURCE),"model":str(OUT)}
REPORT.parent.mkdir(parents=True,exist_ok=True);REPORT.write_text(json.dumps(report,indent=2),encoding="utf-8")
print("THIN_TRUNK_COMPARISON",json.dumps(report))
