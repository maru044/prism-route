"""Build an unchanged, metre-scale Rhino map and a spaced vegetation layout.

Run with Blender --background --python tools/build_map_1012_test.py.
Only derived GLB/JSON assets are written; the input glTF stays read-only.
"""
from pathlib import Path
from collections import Counter
import hashlib
import json
import math
import random
import bpy
import bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT.parent / 'map/mesh.gltf'
OUT = ROOT / 'assets/world/map_1012_test'
COUNT, LARGE_COUNT = 20000, 2000
SPACING, LARGE_SPACING, ROAD_CLEARANCE = 9.0, 22.0, 6.0
# Source-space XZ coordinates keep review locations stable when tessellation
# changes face areas, triangle directions or the terrain's sampled bounds.
VIEWPOINT_SOURCE_XZ = [(1249.19108, -1045.56347), (364.25708, -915.34980),
                       (1372.90845, -179.36627), (1854.12592, -430.02997)]
ROAD_DIRECTION = Vector((-0.93346, -0.35869, 0)).normalized()


def join_layer(layer, name):
    parent = bpy.data.objects.get(layer)
    if not parent:
        raise RuntimeError('Missing Rhino layer: ' + layer)
    objects = [o for o in [parent] + list(parent.children_recursive)
               if o.type == 'MESH' and len(o.data.polygons)]
    if not objects:
        raise RuntimeError('Layer has no triangles: ' + layer)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    result = bpy.context.object
    world = result.matrix_world.copy()
    result.parent = None
    result.matrix_world = world
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    result.name = name
    return result


def bvh(obj, flatten=False):
    obj.data.calc_loop_triangles()
    vertices = [Vector((v.co.x, v.co.y, 0)) if flatten else v.co.copy()
                for v in obj.data.vertices]
    return BVHTree.FromPolygons(vertices, [tuple(t.vertices) for t in obj.data.loop_triangles],
                               all_triangles=True)


def fix_tops(obj):
    reference = bvh(obj)
    ceiling = max(v.co.z for v in obj.data.vertices) + 100
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.normal_update()
    flips = []
    for face in bm.faces:
        if face.normal.z >= -0.55:
            continue
        p = face.calc_center_median()
        hit = reference.ray_cast(Vector((p.x, p.y, ceiling)), Vector((0, 0, -1)), ceiling + 300)[0]
        if hit is not None and abs(hit.z - p.z) < 0.03:
            flips.append(face)
    bmesh.ops.reverse_faces(bm, faces=flips)
    bm.to_mesh(obj.data)
    bm.free()
    if flips:
        custom = obj.data.attributes.get('custom_normal')
        if custom:
            obj.data.attributes.remove(custom)
    obj.data.update()
    return len(flips)


def godot(p):
    return [round(p.x, 5), round(p.z, 5), round(-p.y, 5)]


def ground(tree, x, y):
    return tree.ray_cast(Vector((x, y, 400)), Vector((0, 0, -1)), 450)


def review_point(obj, source_xz, center):
    point = ground(bvh(obj), source_xz[0] - center.x, -source_xz[1] - center.y)[0]
    if point is None:
        raise RuntimeError('Review point no longer lies on ' + obj.name)
    return point


def layout(terrain, roads, beaches, water, spawn, review_points):
    terrain_tree = bvh(terrain)
    road_flat = bvh(roads, True)
    beach_flat = bvh(beaches, True)
    water_tree = bvh(water)
    points = [v.co for v in terrain.data.vertices]
    minimum = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    maximum = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    rng = random.Random(10122026)
    # Visit every spacing-sized cell before repeating. This avoids the previous broad
    # noise mask concentrating the entire population into dense forests.
    cells = [(x, y) for x in range(math.floor(minimum.x / SPACING), math.ceil(maximum.x / SPACING))
             for y in range(math.floor(minimum.y / SPACING), math.ceil(maximum.y / SPACING))]
    points, bins = [], {}
    reject = Counter()

    def clear(p, storage, entries, distance):
        cell = (math.floor(p.x / distance), math.floor(p.y / distance))
        for dx in [-1, 0, 1]:
            for dy in [-1, 0, 1]:
                for index in storage.get((cell[0]+dx, cell[1]+dy), []):
                    other = entries[index]
                    if (p.x-other.x)**2 + (p.y-other.y)**2 < distance**2:
                        return False
        return True

    for iteration in range(24):
        rng.shuffle(cells)
        for cx, cy in cells:
            x = (cx + rng.uniform(0.12, 0.88)) * SPACING
            y = (cy + rng.uniform(0.12, 0.88)) * SPACING
            hit, normal, _, _ = ground(terrain_tree, x, y)
            if hit is None or normal.z < 0.85:
                reject['empty_or_steep'] += 1
                continue
            if Vector((hit.x-spawn.x, hit.y-spawn.y)).length < 24:
                reject['spawn'] += 1
                continue
            if any((hit.x-p.x)**2 + (hit.y-p.y)**2 < 10**2 for p in review_points):
                reject['review_point'] += 1
                continue
            if road_flat.find_nearest(Vector((x, y, 0)))[3] < ROAD_CLEARANCE:
                reject['road'] += 1
                continue
            if hit.z < 6 and beach_flat.find_nearest(Vector((x, y, 0)))[3] < 8:
                reject['beach'] += 1
                continue
            water_hit = ground(water_tree, x, y)[0]
            if water_hit is not None and hit.z <= water_hit.z + 0.15:
                reject['water'] += 1
                continue
            if not clear(hit, bins, points, SPACING):
                reject['spacing'] += 1
                continue
            # Keep trunks away from unsupported edges and major height steps.
            safe = True
            for dx, dy in [(4, 0), (-4, 0), (0, 4), (0, -4)]:
                edge_hit = ground(terrain_tree, x+dx, y+dy)[0]
                if edge_hit is None or abs(edge_hit.z-hit.z) > 3:
                    safe = False
                    break
            if not safe:
                reject['edge'] += 1
                continue
            cell = (math.floor(x / SPACING), math.floor(y / SPACING))
            bins.setdefault(cell, []).append(len(points))
            points.append(hit)
            if len(points) == COUNT:
                break
        print('TREE_LAYOUT_PASS', iteration, len(points), flush=True)
        if len(points) == COUNT:
            break
    if len(points) != COUNT:
        raise RuntimeError(f'Only {len(points)} spaced trees fit; requested {COUNT}')
    order = list(range(len(points)))
    rng.shuffle(order)
    large, large_bins, large_points = set(), {}, []
    for index in order:
        p = points[index]
        if clear(p, large_bins, large_points, LARGE_SPACING):
            cell = (math.floor(p.x / LARGE_SPACING), math.floor(p.y / LARGE_SPACING))
            large_bins.setdefault(cell, []).append(len(large_points))
            large_points.append(p)
            large.add(index)
        if len(large) == LARGE_COUNT:
            break
    if len(large) != LARGE_COUNT:
        raise RuntimeError('Unable to distribute exactly 2000 large trees')
    records = []
    for index, p in enumerate(points):
        records.append(godot(p) + [rng.uniform(0, math.tau), rng.uniform(0.82, 1.20), int(index in large)])
    return records, {'tree_count': len(records), 'large_tree_count': len(large),
                     'minimum_horizontal_spacing_m': SPACING,
                     'large_to_large_minimum_spacing_m': LARGE_SPACING,
                     'road_projection_clearance_m': ROAD_CLEARANCE,
                     'seed': 10122026, 'candidate_rejections': dict(reject)}, points


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    objects = [join_layer(layer, name) for layer, name in
               [('地形', 'Terrain'), ('路面', 'Roads'), ('沙滩', 'Beaches'), ('水面', 'Water')]]
    terrain, roads, beaches, water = objects
    source_counts = {obj.name: len(obj.data.polygons) for obj in objects}
    fixes = {obj.name: fix_tops(obj) for obj in objects}
    vertices = [v.co for v in terrain.data.vertices]
    minimum = Vector(tuple(min(v[i] for v in vertices) for i in range(3)))
    maximum = Vector(tuple(max(v[i] for v in vertices) for i in range(3)))
    center = (minimum + maximum) * 0.5
    center.z = 0
    for obj in objects:
        for v in obj.data.vertices:
            v.co -= center
        obj.data.update()
    spawn, meadow, beach, upper = [review_point(obj, xz, center) for obj, xz in
                                 zip([roads, terrain, beaches, terrain], VIEWPOINT_SOURCE_XZ)]
    direction = ROAD_DIRECTION
    records, vegetation, _ = layout(terrain, roads, beaches, water, spawn, [meadow, upper])
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = terrain
    bpy.ops.export_scene.gltf(filepath=str(OUT / 'map_1012.glb'), export_format='GLB',
                              use_selection=True, export_yup=True,
                              export_materials='NONE', export_normals=True)
    if source_hash != hashlib.sha256(SOURCE.read_bytes()).hexdigest():
        raise RuntimeError('Source glTF changed during build; rebuild the new export')
    metadata = {'source': str(SOURCE), 'source_sha256': source_hash,
                'geometry_scale': 1.0, 'model_translation': [-center.x, 0, center.y],
                'bounds_min': godot(Vector((minimum.x-center.x, maximum.y-center.y, minimum.z))),
                'bounds_max': godot(Vector((maximum.x-center.x, minimum.y-center.y, maximum.z))),
                'source_polygon_counts': source_counts, 'top_orientation_fixes': fixes,
                'road_spawn': godot(spawn), 'road_direction': godot(direction),
                'anchors': [godot(p) for p in [spawn, meadow, beach, upper]],
                'water_level_m': 0.0, 'water_display_offset_m': 0.0,
                'water_source': 'authored_mesh_only',
                'vegetation': vegetation, 'layout_columns': ['x', 'y', 'z', 'yaw', 'scale', 'large']}
    (OUT / 'build_metadata.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding='utf-8')
    (OUT / 'tree_layout.json').write_text(json.dumps(records, separators=(',', ':')), encoding='utf-8')
    print('MAP_1012_BUILD', json.dumps(metadata, ensure_ascii=False), flush=True)


if __name__ == '__main__':
    main()
