"""Three editable shape studies; run with Blender --background --python.

Z is height in Blender; glTF maps it to Godot Y. Geometry only: the inspector
assigns the clear gel, silicone and steel materials at runtime.
"""
from pathlib import Path
import math
import bpy

ROOT = Path(__file__).resolve().parents[1] / "assets" / "products"


def reset():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    mat = bpy.data.materials.new("Preview_Neutral")
    mat.diffuse_color = (0.65, 0.81, 0.88, 1)
    return mat


def finish(obj, name, mat):
    obj.name = name
    obj.data.materials.append(mat)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def lathe(name, points, mat, depth=1.0):
    profile = []
    for i in range(len(points) - 1):
        p0, p1 = points[max(0, i-1)], points[i]
        p2, p3 = points[i+1], points[min(len(points)-1, i+2)]
        for j in range(8):
            t = j / 8
            profile.append(tuple(0.5 * (2*p1[k] + (-p0[k]+p2[k])*t
                + (2*p0[k]-5*p1[k]+4*p2[k]-p3[k])*t*t
                + (-p0[k]+3*p1[k]-3*p2[k]+p3[k])*t*t*t) for k in (0, 1)))
    profile.append(points[-1])
    sides = 72
    vertices = [(max(r, .003)*math.cos(2*math.pi*s/sides),
                 max(r, .003)*math.sin(2*math.pi*s/sides)*depth, h)
                for h, r in profile for s in range(sides)]
    faces = []
    for row in range(len(profile)-1):
        for s in range(sides):
            a, b = row*sides+s, row*sides+(s+1)%sides
            faces.append((a, b, b+sides, a+sides))
    faces.append(tuple(reversed(range(sides))))
    top = (len(profile)-1)*sides
    faces.append(tuple(range(top, top+sides)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, mat)


def sphere(name, center, radius, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=32,
                                        radius=radius, location=center)
    return finish(bpy.context.object, name, mat)


def bubbles(mat, locations):
    for i, (x, h, depth, radius) in enumerate(locations):
        sphere(f"Bubble_{i:02d}", (x, -depth, h), radius, mat)


def base(mat, width=.80, depth=1.0):
    lathe("ClearBase", [(.035, .40), (.05, width*.88), (.11, width),
          (.20, width*.96), (.27, width*.65), (.34, .24), (.47, .18),
          (.53, .19)], mat, depth)


def save(slug):
    directory = ROOT / slug
    source = directory / "source"
    source.mkdir(parents=True, exist_ok=True)
    (source / ".gdignore").write_text("", encoding="utf-8")
    bpy.ops.wm.save_as_mainfile(filepath=str(source / f"{slug}.blend"))
    bpy.ops.export_scene.gltf(filepath=str(directory / f"{slug}.glb"),
                             export_format="GLB", export_cameras=False,
                             export_lights=False)
    print(f"Generated {slug}")


mat = reset()
base(mat, .77, .78)
lathe("OuterShell", [(.46,.17),(.57,.23),(.82,.32),(1.16,.40),
      (1.55,.42),(1.93,.37),(2.33,.27),(2.71,.16),(3.02,.06),(3.12,.003)], mat, .82)
lathe("BlueGelCore", [(.75,.08),(.92,.20),(1.24,.29),(1.59,.31),
      (1.97,.25),(2.34,.15),(2.68,.04),(2.75,.003)], mat, .82)
bubbles(mat, [(-.08,1.1,.13,.026),(.10,1.48,.18,.035),(-.08,1.9,.14,.024),
              (.03,2.33,.07,.018)])
save("elongated_plug")

mat = reset()
base(mat, .86)
lathe("OuterShell", [(.46,.18),(.60,.28),(.80,.47),(1.01,.54),
      (1.22,.48),(1.42,.28),(1.61,.37),(1.81,.43),(2.01,.37),
      (2.18,.23),(2.35,.29),(2.51,.32),(2.69,.25),(2.85,.12),(2.90,.003)], mat)
lathe("BlueGelCore", [(.72,.09),(.85,.31),(1.02,.40),(1.20,.33),
      (1.43,.15),(1.64,.25),(1.82,.30),(2.0,.24),(2.18,.12),
      (2.38,.18),(2.52,.21),(2.69,.12),(2.75,.003)], mat)
bubbles(mat, [(-.13,1.02,.22,.037),(.12,1.16,.20,.026),
              (.09,1.80,.17,.031),(-.05,2.50,.11,.020)])
save("triple_lobe")

mat = reset()
# Upright handle in the front plane, with a thick round edge and a clear hole.
bpy.ops.mesh.primitive_torus_add(major_radius=.34, minor_radius=.085,
    major_segments=72, minor_segments=20, location=(0,0,.425),
    rotation=(math.pi/2,0,0))
finish(bpy.context.object, "OuterShell_Handle", mat)
centers = []
previous_top = .82
for i, radius in enumerate([.34,.30,.26,.22,.18]):
    bottom = previous_top + (.17 if i else .11)
    height = bottom + radius
    lathe(f"OuterShell_Connector_{i:02d}",
          [(previous_top-.025,.052),(previous_top+.03,.060),
           (bottom-.03,.060),(bottom+.025,.052)], mat)
    sphere(f"OuterShell_Bead_{i:02d}", (0,0,height), radius, mat)
    sphere(f"BlueGelCore_{i:02d}", (0,0,height), radius*.73, mat)
    centers.append(height)
    previous_top = height+radius
bubbles(mat, [(r*.13,h-r*.12,r*.41,r*.075)
             for h,r in zip(centers,[.34,.30,.26,.22,.18])])
save("progressive_beads")
