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
SOURCE = ROOT.parent / 'map/model_1012.gltf'
OUT = ROOT / 'assets/world/map_1012_test'
COUNT, LARGE_COUNT = 20000, 2000
SPACING, LARGE_SPACING, ROAD_CLEARANCE = 9.0, 22.0, 6.0


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


def road_spawn(roads, terrain):
    tree = bvh(roads)
    terrain_tree = bvh(terrain)
    best = None
    for face in roads.data.polygons:
        if face.normal.z < 0.98:
            continue
        p = face.center.copy()
        points = [roads.data.vertices[i].co for i in face.vertices]
        edge = max([b-a for a, b in zip(points, points[1:] + points[:1])], key=lambda e: e.length)
        direction = Vector((edge.x, edge.y, 0)).normalized()
        side = Vector((-direction.y, direction.x, 0))
        probes = [p] + [p + side * d for d in [-1.7, 1.7]]
        probes += [p + direction * d for d in [-9, 9]]
        hits = [ground(tree, q.x, q.y)[0] for q in probes]
        if any(q is None or abs(q.z-p.z) > 0.5 for q in hits):
            continue
        terrain_hits = [ground(terrain_tree, q.x, q.y)[0] for q in probes]
        if any(land is not None and land.z > road.z + 0.005
               for road, land in zip(hits, terrain_hits)):
            continue
        score = p.x*p.x + p.y*p.y + abs(p.z-35)*300
        if best is None or score < best[0]:
            best = (score, p, direction)
    if best is None:
        raise RuntimeError('No road spawn with enough clearance')
    return best[1], best[2]


def layout(terrain, roads, beaches, water, spawn):
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
    spawn, direction = road_spawn(roads, terrain)
    records, vegetation, points = layout(terrain, roads, beaches, water, spawn)
    # Use actual exported surface positions for the four inspection bookmarks.
    meadow = min(points, key=lambda p: (p.x+650)**2 + p.y*p.y + (p.z-35)**2*10)
    beach = max(beaches.data.polygons, key=lambda f: f.area).center.copy()
    terrain_tree = bvh(terrain)
    upper = None
    # The highest tiny face may belong to a sculptural feature rather than a
    # parking platform. Require an open, nearly flat patch around the bookmark.
    for p in sorted(points, key=lambda p: p.z, reverse=True):
        if p.z < 40:
            break
        probes = [ground(terrain_tree, p.x+dx, p.y+dy) for dx, dy in
                  [(8, 0), (-8, 0), (0, 8), (0, -8), (6, 6), (-6, 6), (6, -6), (-6, -6)]]
        if all(hit is not None and normal.z > 0.99 and abs(hit.z-p.z) < 0.15
               for hit, normal, _, _ in probes):
            upper = p
            break
    if upper is None:
        raise RuntimeError('No sufficiently open upper platform bookmark')
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
