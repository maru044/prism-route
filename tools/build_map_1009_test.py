"""Blender batch build: retain CAD geometry and bake gentle top-surface relief.

Run: blender --background --python tools/build_map_1009_test.py
The original export is read only. Outputs are two small GLBs and build metadata.
"""
from pathlib import Path
import json
import math
import heapq
import bpy
import bmesh
from mathutils import Vector, noise
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT.parent / 'map/model_1009.gltf'
OUT = ROOT / 'assets/world/map_1009_test'
MAX_EDGE = 10.0
SEED_OFFSET = Vector((31.47, -82.19, 12.63))


def smoothstep(a, b, value):
    t = min(1.0, max(0.0, (value - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def descendants(root):
    return [root] + list(root.children_recursive)


def join_layer(name, result_name):
    root = bpy.data.objects.get(name)
    if root is None:
        raise RuntimeError('Missing CAD layer: ' + name)
    meshes = [o for o in descendants(root) if o.type == 'MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    world = obj.matrix_world.copy()
    obj.parent = None
    obj.matrix_world = world
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.name = result_name
    return obj


def export(path, objects):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB',
                              use_selection=True, export_yup=True,
                              export_materials='NONE', export_normals=True)


def tree(mesh, flatten=False):
    mesh.calc_loop_triangles()
    vertices = [v.co.copy() for v in mesh.vertices]
    if flatten:
        vertices = [Vector((p.x, p.y, 0)) for p in vertices]
    return BVHTree.FromPolygons(vertices, [tuple(t.vertices) for t in mesh.loop_triangles],
                               all_triangles=True)


def orient_exterior_tops(obj):
    """CAD open surfaces can face down. Use the highest ray hit to orient tops."""
    reference = tree(obj.data)
    ceiling = max(v.co.z for v in obj.data.vertices) + 100
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.normal_update()
    flip = []
    for face in bm.faces:
        if face.normal.z >= -0.55:
            continue
        p = face.calc_center_median()
        hit = reference.ray_cast(Vector((p.x, p.y, ceiling)), Vector((0,0,-1)), ceiling+300)[0]
        if hit is not None and abs(hit.z-p.z) < 0.03:
            flip.append(face)
    bmesh.ops.reverse_faces(bm, faces=flip)
    bm.normal_update()
    bm.to_mesh(obj.data)
    bm.free()
    # Remove imported custom normals that would retain the old down-facing
    # directions after the face winding was corrected.
    custom = obj.data.attributes.get('custom_normal')
    if custom:
        obj.data.attributes.remove(custom)
    obj.data.update()
    return len(flip)


def make_relief(obj, road):
    top_tree = tree(obj.data)
    road_tree = tree(road.data, flatten=True)
    top_z = max(v.co.z for v in obj.data.vertices) + 200.0

    def is_top(p):
        hit, normal, index, distance = top_tree.ray_cast(
            Vector((p.x, p.y, top_z)), Vector((0, 0, -1)), top_z + 300)
        return hit is not None and abs(hit.z - p.z) < 0.03

    bm = bmesh.new()
    bm.from_mesh(obj.data)
    # CAD seams may carry duplicate UV vertices. Weld only the noise copy.
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.0008)
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    for iteration in range(7):
        bm.normal_update()
        top_faces = set(f for f in bm.faces if abs(f.normal.z) > 0.55
                        and is_top(f.calc_center_median()))
        edges = [e for e in bm.edges if e.calc_length() > MAX_EDGE
                 and any(f in top_faces for f in e.link_faces)]
        if not edges:
            break
        bmesh.ops.subdivide_edges(bm, edges=edges, cuts=1, use_grid_fill=True)
        bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) != 3])
        if len(bm.verts) > 350000:
            raise RuntimeError('Unexpected tessellation growth')
        print('RELIEF_SUBDIVIDE', iteration, len(bm.verts), len(bm.faces), flush=True)
    bm.normal_update()
    bm.verts.ensure_lookup_table()
    bm.verts.index_update()

    # Surface-geodesic distance from open borders and hard corners; pin the
    # boundary and taper its vicinity rather than opening new cracks.
    distances = [float('inf')] * len(bm.verts)
    queue = []
    for edge in bm.edges:
        if edge.is_boundary or (len(edge.link_faces) == 2 and
                                edge.calc_face_angle(0) > math.radians(30)):
            for v in edge.verts:
                if distances[v.index] != 0:
                    distances[v.index] = 0.0
                    heapq.heappush(queue, (0.0, v.index))
    while queue:
        distance, index = heapq.heappop(queue)
        if distance != distances[index] or distance > 24:
            continue
        v = bm.verts[index]
        for edge in v.link_edges:
            other = edge.other_vert(v)
            candidate = distance + edge.calc_length()
            if candidate < distances[other.index]:
                distances[other.index] = candidate
                heapq.heappush(queue, (candidate, other.index))

    deltas = []
    changed = 0
    preview = None
    protected_road_max = 0.0
    for v in bm.verts:
        p = v.co.copy()
        if not is_top(p):
            deltas.append(0.0)
            continue
        nearby, normal, index, road_distance = road_tree.find_nearest(Vector((p.x, p.y, 0)))
        road_weight = smoothstep(5.0, 28.0, road_distance)
        border_weight = smoothstep(0.0, 20.0, distances[v.index])
        normal_weight = smoothstep(0.55, 0.90, abs(v.normal.z))
        shore_weight = smoothstep(-0.65, -0.10, p.z)
        weight = road_weight * border_weight * normal_weight * shore_weight
        broad = noise.noise(Vector((p.x / 160, p.y / 160, 0.73)) + SEED_OFFSET,
                            noise_basis='PERLIN_NEW')
        medium = noise.noise(Vector((p.x / 48, p.y / 48, 1.31)) + SEED_OFFSET,
                             noise_basis='PERLIN_NEW')
        fine = noise.noise(Vector((p.x / 14, p.y / 14, 2.19)) + SEED_OFFSET,
                           noise_basis='PERLIN_NEW')
        delta = (broad * 3.0 + medium * 0.9 + fine * 0.12) * weight
        # Keep existing low grassland above the review ocean; positive relief
        # still works at sea-level, while original negative terrain is preserved.
        if delta < 0 and p.z >= -0.65:
            delta = max(delta, min(p.z, -0.25) - p.z)
        v.co.z += delta
        deltas.append(delta)
        changed += abs(delta) > 0.001
        if 5.0 < p.z < 100.0 and (preview is None or abs(delta) > preview[0]):
            preview = (abs(delta), p.copy())
        if road_distance < 5:
            protected_road_max = max(protected_road_max, abs(delta))
    bm.normal_update()
    bmesh.ops.dissolve_degenerate(bm, dist=0.00001, edges=list(bm.edges))
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    obj.data.validate(verbose=False, clean_customdata=False)
    if obj.data.validate(verbose=False, clean_customdata=False):
        raise RuntimeError('Mesh did not validate after cleanup')
    for face in obj.data.polygons:
        face.use_smooth = abs(face.normal.z) > 0.5
    # Record the position before topology cleanup can renumber the vertices.
    original_point = preview[1]
    return {'vertices': len(obj.data.vertices), 'triangles': len(obj.data.polygons),
            'changed_vertices': changed, 'displacement_min_m': min(deltas),
            'displacement_max_m': max(deltas), 'road_protected_max_displacement_m': protected_road_max,
            'target_top_edge_m': MAX_EDGE,
            'noise_layers': [[160.0, 3.0], [48.0, 0.9], [14.0, 0.12]],
            'road_fade_distance_m': [5.0, 28.0], 'boundary_fade_distance_m': 20.0,
            'shore_fade_height_m': [-0.65, -0.10],
            'relief_view': [original_point.x, original_point.z, -original_point.y]}


def road_spawn(road):
    bvh = tree(road.data)
    highest = max(v.co.z for v in road.data.vertices) + 100
    best = None
    for f in road.data.polygons:
        if abs(f.normal.z) < 0.95:
            continue
        p = f.center.copy()
        verts = [road.data.vertices[i].co for i in f.vertices]
        edge = max([b-a for a,b in zip(verts, verts[1:] + verts[:1])], key=lambda e:e.length)
        direction = Vector((edge.x, edge.y, 0)).normalized()
        side = Vector((-direction.y, direction.x, 0))
        checks = [p + side * d for d in [-1.7, 1.7]]
        checks += [p + direction * d for d in [-7, 7]]
        hits = [bvh.ray_cast(Vector((q.x, q.y, highest)), Vector((0,0,-1)), highest+100)[0]
                for q in checks]
        if any(q is None or abs(q.z-p.z) > 1.0 for q in hits):
            continue
        score = p.x*p.x + p.y*p.y
        if best is None or score < best[0]:
            best = (score, p, direction)
    if best is None:
        raise RuntimeError('No road spawn with enough clearance for the RV')
    p, direction = best[1:]
    return [p.x, p.z, -p.y], [direction.x, 0, -direction.y]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    terrain = join_layer('地形', 'Terrain')
    roads = join_layer('路面', 'Roads')
    orientation_fixes = orient_exterior_tops(terrain)
    orient_exterior_tops(roads)
    minimum = Vector(tuple(min(v.co[i] for v in terrain.data.vertices) for i in range(3)))
    maximum = Vector(tuple(max(v.co[i] for v in terrain.data.vertices) for i in range(3)))
    center = (minimum + maximum) * 0.5
    center.z = 0
    for obj in [terrain, roads]:
        for v in obj.data.vertices:
            v.co -= center
        obj.data.update()
    baseline_triangles = sum(len(p.vertices) - 2 for p in terrain.data.polygons)
    spawn, direction = road_spawn(roads)
    flat_faces = [p for p in terrain.data.polygons if abs(p.normal.z) > 0.99 and p.area > 25]
    upper = max(flat_faces, key=lambda p:p.center.z).center.copy()
    export(OUT / 'map_1009_original.glb', [terrain, roads])
    report = make_relief(terrain, roads)
    export(OUT / 'map_1009_natural.glb', [terrain, roads])
    bounds_min = [minimum.x - center.x, minimum.z, -(maximum.y - center.y)]
    bounds_max = [maximum.x - center.x, maximum.z, -(minimum.y - center.y)]
    metadata = {'bounds_min': bounds_min, 'bounds_max': bounds_max,
                'model_translation': [-center.x, 0, center.y],
                'original_terrain_triangles': baseline_triangles, 'natural': report,
                'top_orientation_fixes': orientation_fixes,
                'road_spawn': spawn, 'road_direction': direction,
                'upper_view': [upper.x, upper.z, -upper.y]}
    (OUT / 'build_metadata.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
    print('MAP_1009_BUILD', json.dumps(metadata), flush=True)


if __name__ == '__main__':
    main()
