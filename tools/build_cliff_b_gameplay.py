"""Build a native snapshot into an editable Blender / Godot material study.

Planting is sampled on actual exposed upper surfaces, with edge and route
clearance. It never changes the architectural source solids.
"""
from pathlib import Path
from collections import defaultdict, Counter
import json
import math
import random
import hashlib
import shutil
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/world/cliff_b_test'
CACHE = ROOT / '.cliff_b_build'
CENTER = Vector((1240, 280, 0))
STEP = 2.0
RIM = 6.0
OFFSET = 0.06


def godot(p):
    return [round(p.x, 5), round(p.z, 5), round(-p.y, 5)]


def make_object(name, vertices, triangles, collection):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], triangles)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    for face in mesh.polygons:
        face.use_smooth = True
    # Preserve cap/wall breaks while smoothing tessellated curved walls.
    adjacency = defaultdict(list)
    for face in mesh.polygons:
        for edge in face.edge_keys:
            adjacency[tuple(sorted(edge))].append(face.normal.copy())
    for edge in mesh.edges:
        normals = adjacency[tuple(sorted(edge.vertices))]
        edge.use_edge_sharp = len(normals) == 2 and normals[0].dot(normals[1]) < .68
    return obj


def tree_for(obj, top_only=False, flat=False):
    obj.data.calc_loop_triangles()
    tris = [tuple(t.vertices) for t in obj.data.loop_triangles if not top_only or t.normal.z > .93]
    vertices = [Vector((v.co.x, v.co.y, 0)) if flat else v.co.copy() for v in obj.data.vertices]
    return BVHTree.FromPolygons(vertices, tris, all_triangles=True)


def combined(objects, flat=False):
    vertices, triangles = [], []
    for obj in objects:
        start = len(vertices)
        vertices.extend(Vector((v.co.x,v.co.y,0)) if flat else v.co.copy() for v in obj.data.vertices)
        obj.data.calc_loop_triangles()
        triangles.extend(tuple(i+start for i in t.vertices) for t in obj.data.loop_triangles)
    return BVHTree.FromPolygons(vertices, triangles, all_triangles=True)


def edge_tree(obj, top_only=True):
    # Weld by position for boundary detection, including unwelded hard edges.
    obj.data.calc_loop_triangles()
    counts, points = Counter(), {}
    for tri in obj.data.loop_triangles:
        if top_only and tri.normal.z <= .93:
            continue
        coords = [obj.data.vertices[i].co for i in tri.vertices]
        keys = [tuple(round(float(v), 3) for v in co) for co in coords]
        for key, co in zip(keys, coords):
            points[key] = co.copy()
        for i in range(3):
            counts[tuple(sorted((keys[i], keys[(i+1)%3])))] += 1
    samples = []
    for (ka, kb), count in counts.items():
        if count != 1:
            continue
        a,b = points[ka],points[kb]
        for i in range(max(2, math.ceil((b-a).length/1.5)+1)):
            n = max(2, math.ceil((b-a).length/1.5)+1)
            samples.append(a.lerp(b, i/(n-1)))
    kd = KDTree(len(samples))
    for i, point in enumerate(samples):
        kd.insert(point, i)
    kd.balance()
    return kd


def field(x, y):
    # Same broad meadow variation used by the game ground shader (Godot Z=-Y).
    z = -y
    return math.sin(x*.018 + math.sin(z*.021)*1.4)*.55 + math.sin(z*.027-x*.006)*.45


def planting(obj, architecture, roads, collection):
    top = tree_for(obj, top_only=True)
    boundary = edge_tree(obj)
    bounds = [v.co for v in obj.data.vertices]
    lo = Vector(tuple(min(p[i] for p in bounds) for i in range(3)))
    hi = Vector(tuple(max(p[i] for p in bounds) for i in range(3)))
    cache = {}
    rejects = Counter()

    def sample(ix, iy):
        key = (ix,iy)
        if key in cache:
            return cache[key]
        x,y = ix*STEP,iy*STEP
        hit,normal,_,_ = top.ray_cast(Vector((x,y,300)),Vector((0,0,-1)),350)
        value = None
        if hit is None:
            rejects['outside_top'] += 1
        elif boundary.find(hit)[2] < RIM:
            rejects['architectural_rim'] += 1
        elif field(x,y) < -.60:
            rejects['open_meadow_gap'] += 1
        elif architecture.ray_cast(hit+Vector((0,0,.3)),Vector((0,0,1)),300)[0] is not None:
            rejects['covered_surface'] += 1
        else:
            # Exclude roads at the same storey, retaining planting above a gallery.
            road_hit = roads.ray_cast(hit+Vector((0,0,2)),Vector((0,0,-1)),4)[0]
            if road_hit is None:
                value = hit+Vector((0,0,OFFSET))
            else:
                rejects['road'] += 1
        cache[key] = value
        return value

    vertices, triangles, indices = [], [], {}
    for ix in range(math.floor(lo.x/STEP),math.ceil(hi.x/STEP)):
        for iy in range(math.floor(lo.y/STEP),math.ceil(hi.y/STEP)):
            keys = [(ix,iy),(ix+1,iy),(ix+1,iy+1),(ix,iy+1)]
            corners = [sample(*key) for key in keys]
            if any(p is None for p in corners):
                continue
            if max(p.z for p in corners)-min(p.z for p in corners) > 1:
                continue
            ids = []
            for key,p in zip(keys,corners):
                if key not in indices:
                    indices[key] = len(vertices)
                    vertices.append(p)
                ids.append(indices[key])
            triangles.extend([(ids[0],ids[1],ids[2]),(ids[0],ids[2],ids[3])])
    if not triangles:
        return None, {'source_id':obj['source_id'],'cells':0,'rejections':dict(rejects)}
    result = make_object('Planting_'+obj.name.split('_',1)[1],vertices,triangles,collection)
    result['source_id'] = obj['source_id']
    result['edge_setback_m'] = RIM
    result['soil_skin_offset_m'] = OFFSET
    area = sum(p.area for p in result.data.polygons)
    return result, {'source_id':obj['source_id'],'object':result.name,'area_m2':round(area,2),
                    'cells':len(triangles)//2,'rejections':dict(rejects)}


def highest(tree,x,y):
    return tree.ray_cast(Vector((x,y,300)),Vector((0,0,-1)),350)[0]


def scatter(zones, terrain, road, water):
    rng = random.Random(14102026)
    records, shrub_rows, bins = [], [], defaultdict(list)
    zone_bvhs = [(obj,tree_for(obj),edge_tree(obj,False)) for obj in zones]

    def free(p, distance):
        cell = (math.floor(p.x/12),math.floor(p.y/12))
        for dx in range(-2,3):
            for dy in range(-2,3):
                for q in bins[(cell[0]+dx,cell[1]+dy)]:
                    if (p-q).length < distance:
                        return False
        return True

    owned = 0
    for obj,bvh,edges in zone_bvhs:
        coords = [v.co for v in obj.data.vertices]
        lowx,highx = min(p.x for p in coords),max(p.x for p in coords)
        lowy,highy = min(p.y for p in coords),max(p.y for p in coords)
        for ix in range(math.floor(lowx/12),math.ceil(highx/12)):
            for iy in range(math.floor(lowy/12),math.ceil(highy/12)):
                p = highest(bvh,(ix+rng.uniform(.1,.9))*12,(iy+rng.uniform(.1,.9))*12)
                if p is None or edges.find(p)[2] < 3.8 or field(p.x,p.y) < .02 or not free(p,14):
                    continue
                large = int(rng.random() < .08 and p.z > 60)
                records.append(godot(p)+[rng.uniform(0,math.tau),rng.uniform(.78,1.04),large])
                bins[(math.floor(p.x/12),math.floor(p.y/12))].append(p)
                owned += 1
        for _ in range(120):
            p = highest(bvh,rng.uniform(lowx,highx),rng.uniform(lowy,highy))
            if p is not None and edges.find(p)[2] > 2 and free(p,4):
                shrub_rows.append(godot(p)+[rng.uniform(0,math.tau),rng.uniform(.7,1.0)])
    # Sparse contextual trees, distinct from the authored B planting beds.
    land = combined(terrain)
    flat_roads = combined(road,True)
    water_bvh = combined(water)
    coords = [v.co for obj in terrain for v in obj.data.vertices]
    lo = Vector(tuple(min(p[i] for p in coords) for i in range(3)))
    hi = Vector(tuple(max(p[i] for p in coords) for i in range(3)))
    context_count = 0
    for _ in range(18000):
        x,y = rng.uniform(lo.x,hi.x),rng.uniform(lo.y,hi.y)
        hit,normal,_,_ = land.ray_cast(Vector((x,y,300)),Vector((0,0,-1)),350)
        if hit is None or abs(normal.z) < .9 or field(x,y) < .32:
            continue
        wet = highest(water_bvh,x,y)
        if wet is not None and wet.z >= hit.z-.2:
            continue
        if flat_roads.find_nearest(Vector((x,y,0)))[3] < 10 or not free(hit,22):
            continue
        if any((highest(land,x+dx,y+dy) is None or abs(highest(land,x+dx,y+dy).z-hit.z)>2)
               for dx,dy in [(5,0),(-5,0),(0,5),(0,-5)]):
            continue
        records.append(godot(hit)+[rng.uniform(0,math.tau),rng.uniform(.82,1.12),int(rng.random()<.10)])
        bins[(math.floor(hit.x/12),math.floor(hit.y/12))].append(hit)
        context_count += 1
        if context_count == 1800:
            break
    return records,shrub_rows,{'cliff_b_trees':owned,'context_trees':context_count,'shrubs':len(shrub_rows)}


def top_bookmark(obj):
    faces = [p for p in obj.data.polygons if p.normal.z > .8]
    face = max(faces,key=lambda p:p.area)
    return face.center.copy()


def main():
    source = CACHE/'rhino_scene.json'
    data = json.loads(source.read_text(encoding='utf-8'))
    if data['units'] != 'Meters':
        raise RuntimeError('Expected metre-scale native geometry')
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    collections = {}
    for name in ['Architecture','Context','PlantingZones']:
        collection = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(collection)
        collections[name] = collection
    groups = defaultdict(list)
    candidates,walkways,own_roads = [],[],[]
    material = bpy.data.materials.new('Warm white fabricated architecture')
    material.use_nodes = True
    shader = material.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (.91,.895,.865,1)
    shader.inputs['Roughness'].default_value = .73
    tex = material.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image = bpy.data.images.load(str(OUT/'textures/warm_white_architecture_albedo.png'))
    tex.projection = 'BOX'
    tex.projection_blend = .25
    uv = material.node_tree.nodes.new('ShaderNodeTexCoord')
    mapping = material.node_tree.nodes.new('ShaderNodeMapping')
    mapping.inputs['Scale'].default_value = (1/1.6,)*3
    links = material.node_tree.links
    links.new(uv.outputs['Object'],mapping.inputs['Vector'])
    links.new(mapping.outputs['Vector'],tex.inputs['Vector'])
    mix = material.node_tree.nodes.new('ShaderNodeMixRGB')
    mix.blend_type = 'MULTIPLY'
    mix.inputs[0].default_value = .2
    mix.inputs[1].default_value = (.91,.895,.865,1)
    links.new(tex.outputs['Color'],mix.inputs[2])
    links.new(mix.outputs[0],shader.inputs['Base Color'])
    for suffix, socket in [('roughness','Roughness'),('normal','Normal')]:
        node = material.node_tree.nodes.new('ShaderNodeTexImage')
        node.image = bpy.data.images.load(str(OUT/('textures/warm_white_architecture_'+suffix+'.png')))
        node.image.colorspace_settings.name = 'Non-Color'
        node.projection = 'BOX'
        node.projection_blend = .25
        links.new(mapping.outputs['Vector'],node.inputs['Vector'])
        if suffix == 'normal':
            normal_node = material.node_tree.nodes.new('ShaderNodeNormalMap')
            normal_node.inputs['Strength'].default_value = .14
            links.new(node.outputs['Color'],normal_node.inputs['Color'])
            links.new(normal_node.outputs['Normal'],shader.inputs[socket])
        else:
            links.new(node.outputs['Color'],shader.inputs[socket])
    meadow = bpy.data.materials.new('Planting zones - sage meadow')
    meadow.diffuse_color = (.42,.51,.29,1)
    for i,record in enumerate(data['objects']):
        kind = record['kind']
        vertices = [Vector(v)-CENTER for v in record['vertices']]
        obj = make_object(kind+'_%02d'%i,vertices,record['triangles'],collections['Architecture' if record['owned'] else 'Context'])
        obj['source_id'] = record['id']
        obj['source_name'] = record['name']
        obj['source_layer'] = record['layer']
        if kind == 'Architecture':
            obj.data.materials.append(material)
        groups[kind].append(obj)
        if record['plant_candidate']:
            candidates.append(obj)
        if record['owned'] and kind == 'Roads':
            own_roads.append(obj)
        if '全长峡谷步行平台' in record['name']:
            walkways.append(obj)
    architecture = combined(groups['Architecture'])
    roads = combined(groups['Roads'])
    zones,zone_reports = [],[]
    for obj in candidates:
        result,report = planting(obj,architecture,roads,collections['PlantingZones'])
        zone_reports.append(report)
        if result:
            result.data.materials.append(meadow)
            zones.append(result)
        print('PLANTING_ZONE',json.dumps(report,ensure_ascii=False),flush=True)
    if not zones:
        raise RuntimeError('No planting zones fit the actual exposed surfaces')
    records,shrubs,population = scatter(zones,groups['Terrain'],groups['Roads'],groups['Water'])
    roof = [Vector((r[0],-r[2],r[1])) for r in records[:population['cliff_b_trees']] if r[1] > 60]
    terraces = [v.co.copy() for obj in zones for v in obj.data.vertices if 9 < v.co.z < 56]
    if not roof or not terraces:
        raise RuntimeError('Roof and terrace planting must both be represented')
    roof_point = min(roof,key=lambda p:(p-Vector((-100,80,63))).length)
    terrace_point = min(terraces,key=lambda p:(p-Vector((80,-80,30))).length)
    # Use bare points at the planting edge, not the center of a tree trunk.
    roof_point.x += 6
    roof_point.y += 4
    roof_hit = highest(architecture,roof_point.x,roof_point.y)
    if roof_hit is not None:
        roof_point = roof_hit+Vector((0,0,OFFSET))
    anchors = [top_bookmark(own_roads[0]),top_bookmark(walkways[0]),terrace_point,roof_point]
    metadata = {'source':'native current Rhino snapshot','source_document':data['source_document'],
        'source_native_sha256':hashlib.sha256((OUT/'source/cliff_b_native_snapshot.3dm').read_bytes()).hexdigest(),
        'geometry_scale':1.0,'native_center':list(CENTER),'anchors':[godot(p) for p in anchors],
        'road_spawn':godot(anchors[0]),'road_direction':[-1,0,0],
        'zone_edge_setback_m':RIM,'planting_grid_m':STEP,'soil_skin_offset_m':OFFSET,
        'zones':zone_reports,'population':population,
        'mesh_triangles':{key:sum(len(o.data.loop_triangles) for o in obs) for key,obs in groups.items()},
        'planting_triangles':sum(len(o.data.polygons) for o in zones)}
    (OUT/'build_metadata.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2),encoding='utf-8')
    (OUT/'tree_layout.json').write_text(json.dumps(records,separators=(',',':')),encoding='utf-8')
    (OUT/'shrub_layout.json').write_text(json.dumps(shrubs,separators=(',',':')),encoding='utf-8')
    native_zones = [{'name':o.name,'vertices':[list(v.co+CENTER) for v in o.data.vertices],
                     'triangles':[list(p.vertices) for p in o.data.polygons]} for o in zones]
    (CACHE/'planting_zones_native.json').write_text(json.dumps(native_zones,separators=(',',':')),encoding='utf-8')
    shutil.copy2(source,OUT/'source/rhino_scene.json')
    bpy.ops.export_scene.gltf(filepath=str(OUT/'cliff_b_world.glb'),export_format='GLB',
        export_yup=True,export_materials='NONE',export_normals=True,export_extras=True)
    # Editable tree placements in the Blender source, separate from the GLB.
    # The game loads the JSON population through its existing three-level LOD.
    instances = bpy.data.collections.new('VegetationPlacements')
    bpy.context.scene.collection.children.link(instances)
    templates = {}
    for name,filename in [('small','tree_small_broad_canopy.glb'),('large','tree_medium_broad_clustered_canopy.glb'),
                          ('shrub','shrub_medium_rounded_canopy.glb')]:
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/vegetation/models'/filename))
        template = bpy.data.collections.new('Template_'+name)
        for obj in set(bpy.data.objects)-before:
            for collection in list(obj.users_collection):
                collection.objects.unlink(obj)
            template.objects.link(obj)
        templates[name] = template
    for index,row in enumerate(records+shrubs):
        kind = ('large' if row[5] else 'small') if index < len(records) else 'shrub'
        obj = bpy.data.objects.new('Plant_'+kind+'_%04d'%index,None)
        obj.instance_type = 'COLLECTION'
        obj.instance_collection = templates[kind]
        obj.location = (row[0],-row[2],row[1])
        obj.rotation_euler.z = row[3]
        obj.scale = (row[4],)*3
        instances.objects.link(obj)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source/cliff_b_material_planting.blend'))
    print('CLIFF_B_BUILD',json.dumps(metadata,ensure_ascii=False),flush=True)


if __name__ == '__main__':
    main()
