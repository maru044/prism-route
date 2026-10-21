"""Bake a fixed layout using 1012's stratified spacing and exclusion rules.

Run with Blender --background --python tools/build_map_1021_trees.py.
Reads the current CAD export; never changes CAD or the accepted 1012 layout.
"""
from pathlib import Path
from collections import Counter
import json, math, random, hashlib
import numpy as np
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
import map_1021_surface_roles as surface_roles
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / '.current_map_build'
OUT = ROOT / 'assets/world/current_map_validation'
SPACING, LARGE_SPACING, ROAD_CLEARANCE = 9.0, 22.0, 6.0
COUNT, LARGE_COUNT = 20000, 2000

def make_bvh(source, kinds, flat=False):
    vertices, faces = [], []
    for row in source['objects']:
        if row['kind'] not in kinds or (row['kind']=='Structure' and not row['collision']): continue
        v = np.memmap(CACHE/'source.bin', dtype='<f4', mode='r', offset=row['offset'], shape=(row['vertex_count'],3))
        f = np.memmap(CACHE/'source.bin', dtype='<i4', mode='r', offset=row['offset']+row['vertex_count']*12, shape=(row['index_count']//3,3))
        offset = len(vertices)
        vertices.extend((float(p[0]),float(p[1]),0.0 if flat else float(p[2])) for p in v)
        faces.extend(tuple(int(i)+offset for i in tri) for tri in f)
    result = BVHTree.FromPolygons(vertices,faces,all_triangles=True)
    print('BVH_READY',kinds,flat,len(faces),flush=True)
    return result

def ground(tree,x,y):
    return tree.ray_cast(Vector((x,y,400)),Vector((0,0,-1)),450)

def main():
    source = json.loads((CACHE/'source.json').read_text(encoding='utf-8-sig'))
    surface_roles.apply(source['objects'])
    meta = json.loads((OUT/'metadata.json').read_text(encoding='utf-8'))
    terrain = make_bvh(source,{'Terrain'})
    roads = make_bvh(source,{'Road'},True)
    beaches = make_bvh(source,{'Sand'},True)
    water = make_bvh(source,{'Water'})
    occluders = make_bvh(source,{'Structure','Sand'})
    mask = np.memmap(CACHE/'landscape_mask.rg16f',dtype='<f2',mode='r',shape=(4096,4096,2))
    center = source['native_center']
    def godot(p): return [round(p.x-center[0],5),round(p.z,5),round(center[1]-p.y,5)]
    def in_band(p):
        q=godot(p);u=(q[0]-meta['origin_xz'][0])/meta['extent_xz'][0];v=(q[2]-meta['origin_xz'][1])/meta['extent_xz'][1]
        if not(0<=u<1 and 0<=v<1):return False
        d,h=mask[int(v*4096),int(u*4096)]
        return float(d)<3.0 and abs(p.z-float(h))<3.2
    bounds=[r['bounds'] for r in source['objects'] if r['kind']=='Terrain']
    low=np.asarray(bounds)[:,0].min(0);high=np.asarray(bounds)[:,1].max(0)
    cells=[(x,y) for x in range(math.floor(low[0]/SPACING),math.ceil(high[0]/SPACING)) for y in range(math.floor(low[1]/SPACING),math.ceil(high[1]/SPACING))]
    rng=random.Random(10122026);points=[];bins={};reject=Counter()
    def clear(p,storage,entries,distance):
        cell=(math.floor(p.x/distance),math.floor(p.y/distance))
        for dx in [-1,0,1]:
            for dy in [-1,0,1]:
                for i in storage.get((cell[0]+dx,cell[1]+dy),[]):
                    other=entries[i]
                    if (p.x-other.x)**2+(p.y-other.y)**2<distance**2:return False
        return True
    for iteration in range(24):
        rng.shuffle(cells)
        for cx,cy in cells:
            x=(cx+rng.uniform(.12,.88))*SPACING;y=(cy+rng.uniform(.12,.88))*SPACING
            p,n,_,_=ground(terrain,x,y)
            if p is None or abs(n.z)<.85:reject['empty_or_steep']+=1;continue
            occluder=ground(occluders,x,y)[0]
            # Also reject coplanar structure caps: physics may resolve either
            # coincident face, and those caps must remain architectural.
            if occluder is not None and occluder.z>=p.z-.05:reject['covered_by_structure']+=1;continue
            if any((x-r['native'][0])**2+(y-r['native'][1])**2<max(10,24 if r['key']=='south_gallery' else 10)**2 for r in meta['spawns']):reject['spawn']+=1;continue
            if roads.find_nearest(Vector((x,y,0)))[3]<ROAD_CLEARANCE:reject['road']+=1;continue
            if p.z<6 and beaches.find_nearest(Vector((x,y,0)))[3]<8:reject['beach']+=1;continue
            w=ground(water,x,y)[0]
            if w is not None and p.z<=w.z+.15:reject['water']+=1;continue
            if in_band(p):reject['architecture_mask']+=1;continue
            if not clear(p,bins,points,SPACING):reject['spacing']+=1;continue
            safe=True
            for dx,dy in [(4,0),(-4,0),(0,4),(0,-4)]:
                edge=ground(terrain,x+dx,y+dy)[0]
                if edge is None or abs(edge.z-p.z)>3:safe=False;break
            if not safe:reject['edge']+=1;continue
            cell=(math.floor(x/SPACING),math.floor(y/SPACING));bins.setdefault(cell,[]).append(len(points));points.append(p)
            if len(points)==COUNT:break
        print('TREE_LAYOUT_PASS',iteration,len(points),flush=True)
        if len(points)==COUNT:break
    # A smaller current planting footprint must not relax accepted spacing.
    order=list(range(len(points)));rng.shuffle(order);large=set();large_bins={};large_points=[]
    for i in order:
        p=points[i]
        if clear(p,large_bins,large_points,LARGE_SPACING):
            cell=(math.floor(p.x/LARGE_SPACING),math.floor(p.y/LARGE_SPACING));large_bins.setdefault(cell,[]).append(len(large_points));large_points.append(p);large.add(i)
        if len(large)==min(LARGE_COUNT,len(points)//10):break
    records=[godot(p)+[rng.uniform(0,math.tau),rng.uniform(.82,1.20),int(i in large)] for i,p in enumerate(points)]
    layout_path=OUT/'tree_layout.json';layout_path.write_text(json.dumps(records,separators=(',',':')),encoding='utf-8')
    report={'reference':'tools/build_map_1012_test.py','tree_count':len(points),'large_tree_count':len(large),'requested_tree_count':COUNT,'minimum_horizontal_spacing_m':SPACING,'large_to_large_minimum_spacing_m':LARGE_SPACING,'road_projection_clearance_m':ROAD_CLEARANCE,'edge_probe_distance_m':4,'seed':10122026,'candidate_rejections':dict(reject),'source_mesh_sha256':meta['mesh_sha256'],'layout_sha256':hashlib.sha256(layout_path.read_bytes()).hexdigest()}
    (OUT/'tree_layout_metadata.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print('MAP_1021_TREES',json.dumps(report),flush=True)

if __name__=='__main__':main()
