"""Build the editable title-screen coast and export its runtime glTF scene."""

from math import cos, pi, radians, sin
from pathlib import Path
from random import Random

import bpy
from mathutils import Vector


OUTPUT = Path(__file__).resolve().parents[2] / "assets" / "title"
RNG = Random(1385)


def material(name, hex_color):
    def linear(channel):
        return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4

    color = tuple(linear(int(hex_color[i:i + 2], 16) / 255) for i in (0, 2, 4)) + (1,)
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = 0.92
    return mat


def collection(name):
    group = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(group)
    return group


def move_to(obj, group):
    for owner in list(obj.users_collection):
        owner.objects.unlink(obj)
    group.objects.link(obj)


def mesh(name, points, faces, materials, indices, group):
    data = bpy.data.meshes.new(name)
    data.from_pydata(points, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    group.objects.link(obj)
    for mat in materials:
        data.materials.append(mat)
    for poly, index in zip(data.polygons, indices):
        poly.material_index = index
    return obj


def cylinder(name, xyz, scale, mat, group, sides=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, location=xyz)
    obj = bpy.context.object
    obj.name, obj.scale = name, scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    move_to(obj, group)
    return obj


def box(name, xyz, scale, mat, group, bevel=0.04):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz)
    obj = bpy.context.object
    obj.name, obj.scale = name, scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        rounding = obj.modifiers.new("Chipped edge", "BEVEL")
        rounding.width, rounding.segments = bevel, 1
    obj.data.materials.append(mat)
    move_to(obj, group)
    return obj


def marker(name, xyz, group):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_size = 0.6
    obj.location = xyz
    group.objects.link(obj)
    return obj


def island(name, cx, cy, rx, ry, height, ground, rocks, group):
    count = 84
    points = [(cx, cy, height + 0.33)]
    faces, ids = [], []
    contour = [
        1 + 0.11 * sin(3 * i * 2 * pi / count) + 0.06 * cos(7 * i * 2 * pi / count)
        + RNG.uniform(-0.035, 0.035) for i in range(count)
    ]
    for ring, elevation in [(0.46, height + .24), (0.78, height), (1.0, height - .38), (1.04, .64), (1.17, -.85)]:
        for i in range(count):
            t = 2 * pi * i / count
            points.append((cx + rx * ring * contour[i] * cos(t), cy + ry * ring * contour[i] * sin(t),
                           elevation + 0.24 * sin(t * 8) + RNG.uniform(-.25, .24)))
    for i in range(count):
        faces.append((0, 1 + i, 1 + (i + 1) % count))
        ids.append(RNG.randrange(2))
    for level in range(4):
        for i in range(count):
            a, b = 1 + level * count + i, 1 + level * count + (i + 1) % count
            faces.extend([(a, a + count, b), (b, a + count, b + count)])
            color = RNG.randrange(2) if level < 2 else 2 + RNG.randrange(len(rocks))
            ids.extend([color, color if RNG.random() > .22 else min(color + 1, 4)])
    return mesh(name, points, faces, ground + rocks, ids, group)


def arc(group, concrete, seams):
    cx, cy, cz = 3.5, 61, 11.45
    points, faces, indices = [], [], []
    segments = 132
    for i in range(segments + 1):
        t = radians(59 + 262 * i / segments)
        x, z = cos(t), sin(t)
        cut = 1.0 if min(i, segments - i) < 4 else 0.0
        for corner, (radius, depth) in enumerate([(8.4, -1.3), (6.48, -1.27), (6.48, 1.47), (8.4, 1.5)]):
            stagger = cut * (sin(corner * 4 + i * 1.7) * .29)
            points.append((cx + (radius + stagger) * x - stagger * z,
                           cy + depth + .24 * z + stagger * .3,
                           cz + (radius + stagger) * z + stagger * x))
        if i:
            for corner in range(4):
                a, b = (i - 1) * 4 + corner, (i - 1) * 4 + (corner + 1) % 4
                faces.append((a, b, b + 4, a + 4))
                indices.append(1 if cut and i % 2 else 0)
    faces.extend([(3, 2, 1, 0), tuple(range(segments * 4, segments * 4 + 4))])
    indices.extend([1, 1])
    ring = mesh("Broken observation ring", points, faces, [concrete, seams], indices, group)
    # Point normals consistently outward before the through-hole booleans.
    bpy.context.view_layer.objects.active = ring
    ring.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    ring.select_set(False)
    for theta, radius in [(143, .58), (161, .69)]:
        t = radians(theta)
        bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=radius, depth=5,
                                           location=(cx + 7.44 * cos(t), cy, cz + 7.44 * sin(t)),
                                           rotation=(pi / 2, 0, 0))
        cutter = bpy.context.object
        modifier = ring.modifiers.new("Through-aperture", "BOOLEAN")
        modifier.object = cutter
        modifier.operation = "DIFFERENCE"
        bpy.context.view_layer.objects.active = ring
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        bpy.data.objects.remove(cutter, do_unlink=True)
    rounding = ring.modifiers.new("Weathered arris", "BEVEL")
    rounding.width, rounding.segments = .055, 1
    for theta in range(76, 310, 24):
        t = radians(theta)
        row = box("Ring panel joint", (cx + 7.44 * cos(t), cy - 1.306 + .24 * sin(t), cz + 7.44 * sin(t)),
                  (1.76, .023, .026), seams, group, 0)
        row.rotation_euler.y = -t


def ground_height(x, y):
    near_slope = 1.22 * max(0, 1 - y / 5.55) ** 1.25
    seaward_slope = min(1.98, max(0, y - 6.4) * .21)
    return (6.17 - .088 * (x - 1.89) - near_slope - seaward_slope
            + .085 * sin(x * .66 + y * .34) + .068 * cos(y * .53))


def trail_center(y):
    distance = y - 4.45
    return 2.42 + .54 * distance - .14 * max(distance, 0) ** 1.55


def headland_edge(x):
    return 18.8 - .24 * x + 1.4 * sin(x * .22)


def foreground(fields, rocks, ground=()):
    points, faces, ids = [], [], []
    nx, ny = 76, 58
    for i in range(nx + 1):
        x = -27 + 50 * i / nx
        for j in range(ny + 1):
            y = -.7 + (headland_edge(x) + .7) * j / ny
            points.append((x, y, ground_height(x, y)))
    for i in range(nx):
        for j in range(ny):
            a = i * (ny + 1) + j
            faces.append((a, a + ny + 1, a + ny + 2, a + 1))
            x = (points[a][0] + points[a + ny + 2][0]) * .5
            y = (points[a][1] + points[a + ny + 2][1]) * .5
            ids.append(2 if abs(x - trail_center(y)) < .89 else RNG.randrange(2))
    meadow = mesh("TitleMeadow", points, faces, ground, ids, fields)
    for polygon in meadow.data.polygons:
        polygon.use_smooth = True
    lip, lip_faces = [], []
    for i in range(nx + 1):
        x = -27 + 50 * i / nx
        y = headland_edge(x)
        lip.extend([(x, y, ground_height(x, y)), (x, y + RNG.uniform(.6, 1.45), 2.2 + RNG.uniform(-.4, .85)),
                    (x, y + RNG.uniform(1.7, 2.3), -.6)])
    for i in range(nx):
        a = i * 3
        lip_faces.extend([(a, a + 1, a + 4, a + 3), (a + 1, a + 2, a + 5, a + 4)])
    mesh("Foreland strata", lip, lip_faces, rocks, [RNG.randrange(3) for _ in lip_faces], fields)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    shot, field, cliffs, ruin, green = map(collection, [
        "Title composition", "Golden foreland", "Headland and sea stacks", "Observation ruin",
        "World tree placement",
    ])
    rocks = [material("Limestone warm", "b9a591"), material("Cliff shadow", "a59c94"), material("Exposed chalk", "d1bca0")]
    soil = [material("Golden soil", "b1a064"), material("Sunlit meadow", "b1a064"), material("Footpath", "d1ab6a")]
    moss = [material("Headland olive", "8e884e"), material("Headland ochre", "b6a062")]
    concrete, seams, inset = material("Ivory cast stone", "e1d4bb"), material("Worn concrete joint", "b3aa9a"), material("Recess shadow", "767c7e")

    foreground(field, rocks, soil)
    headland = island("Layered rocky headland", -1.2, 63.2, 21.8, 15.2, 3.05, moss, rocks, cliffs)
    approach = island("Low approach spur", -14.7, 47.5, 10, 7.7, 1.85, moss, rocks, cliffs)
    for i in range(11):
        x, y = RNG.uniform(16, 28), RNG.uniform(50, 72)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1, location=(x, y, RNG.uniform(-.18, .45)))
        stone = bpy.context.object
        stone.name = "Collapsed coastal block"
        stone.scale = (RNG.uniform(.6, 1.8), RNG.uniform(.7, 1.7), RNG.uniform(.45, 1.35))
        stone.data.materials.append(RNG.choice(rocks))
        move_to(stone, cliffs)
    for y, sx, sy, height, z in [(62, 14.7, 9.7, 1.44, 3.28), (64.0, 11.7, 7.0, 1.21, 4.49), (66.0, 8.1, 5.1, .86, 5.54)]:
        cylinder("Terraced concrete podium", (0, y, z), (sx, sy, height * .5), concrete, ruin, 64)
        cylinder("Roof seam", (0, y, z + height * .5 - .07), (sx + .045, sy + .045, .072), seams, ruin, 64)
    arc(ruin, concrete, seams)
    for i, (x, y, height, z) in enumerate([(-10.0, 60, 8.5, 3.7), (-14.5, 59.8, 5.3, 2.9), (-8.15, 62.4, 4.9, 4.65)]):
        box("Pier base", (x, y, z + .43), (2.75, 2.25, .92), concrete, ruin)
        pier = box("Split buttress", (x, y, z + height * .5), (1.03, 1.38, height), concrete, ruin)
        pier.rotation_euler.y = radians(-5 + i * 3.5)
        box("Slit reveal", (x + .09, y - .7, z + height * .51), (.13, .041, height * .56), inset, ruin, 0)
    for i in range(14):
        t = radians(221 + i * 7.9)
        slot = box("Podium recess", (14.73 * cos(t), 62 + 9.76 * sin(t), 3.24), (.16, .04, .70), inset, ruin, 0)
        slot.rotation_euler.z = t - pi / 2
    tree_sites = [
        ("Orange", approach, -17.4, 48.6, .42, 26),
        ("Red", headland, -12.7, 54.1, .38, 109),
        ("Orange", headland, -5.8, 52.7, .31, 181),
        ("Red", headland, 3.6, 52.2, .38, 224),
        ("Orange", headland, 12.8, 56.8, .44, 296),
        ("Green", approach, -20.6, 48.5, .24, 76),
        ("Green", approach, -12.6, 47.2, .23, 152),
        ("Green", headland, -16.8, 55.0, .29, 34),
        ("Green", headland, -1.3, 51.7, .21, 248),
        ("Green", headland, 8.2, 53.9, .26, 42),
        ("Green", headland, 15.7, 55.7, .23, 317),
        ("Green", headland, 17.4, 59.6, .28, 122),
    ]
    for index, (color, support, x, y, scale, yaw) in enumerate(tree_sites, 1):
        hit, ground, _, _ = support.ray_cast(Vector((x, y, 20)), Vector((0, 0, -1)))
        if not hit:
            raise ValueError(f"No title tree support at ({x}, {y})")
        ground.z -= .04
        tree_marker = marker(f"TitleTree{color}{index:02}", ground, green)
        tree_marker.scale = (scale,) * 3
        tree_marker.rotation_euler.z = radians(yaw)

    for i, (x, y, size) in enumerate([(-1.65, 4.2, .45), (-3.3, 8.0, .55), (.35, 10.6, .29), (4.5, 12.6, .50)]):
        stone = box(f"Path stone {i + 1}", (x, y, ground_height(x, y) + .035), (size * 1.6, size, size * .38), rocks[2], field, .076)
        stone.rotation_euler.z = RNG.uniform(-.57, .71)
    for group in (cliffs, ruin, green):
        for obj in group.objects:
            obj.location.y -= 9.0
    actor_x, actor_y = 2.42, 4.45
    actor_floor = ground_height(actor_x, actor_y) + .028
    marker("LumineAnchor", (actor_x, actor_y, actor_floor), shot)
    marker("LumineLookTarget", (-14, 51, 7), shot)
    camera_data = bpy.data.cameras.new("Title lens")
    camera_data.lens, camera_data.clip_end = 19.45, 2500
    camera = bpy.data.objects.new("TitleCamera", camera_data)
    shot.objects.link(camera)
    camera.location = (0, 0, actor_floor + 1.597)
    camera.rotation_euler = Vector((0, 1, .033)).to_track_quat("-Z", "Y").to_euler()
    scene = bpy.context.scene
    scene.camera = camera
    scene.render.resolution_x, scene.render.resolution_y = 1920, 1080
    scene.render.resolution_percentage = 100
    bpy.ops.object.select_all(action="DESELECT")
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == "VIEW_3D":
                area.spaces.active.region_3d.view_perspective = "CAMERA"
                area.spaces.active.shading.color_type = "MATERIAL"

    (OUTPUT / "source").mkdir(parents=True, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT / "source" / "title_coast.blend"), compress=True)
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT / "title_coast.glb"), export_format="GLB",
                              export_cameras=True, export_apply=True)


if __name__ == "__main__":
    main()
