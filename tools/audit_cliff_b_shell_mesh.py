"""Blender BVH audit: non-adjacent triangle crossings on the generated sheet."""
import json
import sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import intersect_ray_tri

root = Path(__file__).resolve().parents[1]
args = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
input_name=args[0] if args else 'cliff_b_shell_v02_mesh.json'
report_name=args[1] if len(args)>1 else 'CLIFF_B_SHELL_V02_MESH_AUDIT.json'
data = json.loads((root / '.map_1012_build' / input_name).read_text())
verts = [Vector(p) for p in data['vertices']]
tris = []
for face in data['faces']:
    tris.append(tuple(face[:3]))
    if len(face) == 4:
        tris.append((face[0],face[2],face[3]))
bvh = BVHTree.FromPolygons(verts,tris,all_triangles=True,epsilon=0)
pairs = bvh.overlap(bvh)
hits = []
tested = 0
degenerate = sum((verts[t[1]]-verts[t[0]]).cross(verts[t[2]]-verts[t[0]]).length < 1e-9 for t in tris)
for a,b in pairs:
    if a >= b or set(tris[a]) & set(tris[b]):
        continue
    tested += 1
    ta,tb = [verts[v] for v in tris[a]],[verts[v] for v in tris[b]]
    crossing = False
    for source,target in [(ta,tb),(tb,ta)]:
        for i in range(3):
            p,q=source[i],source[(i+1)%3]
            direction=q-p
            if direction.length < 1e-9:continue
            normal=(target[1]-target[0]).cross(target[2]-target[0])
            if normal.length<1e-9:continue
            normal.normalize()
            da,db=(p-target[0]).dot(normal),(q-target[0]).dot(normal)
            # Count genuine passage through the triangle plane. Parallel,
            # coplanar and endpoint-only contacts are not penetration.
            if da*db>=0 or min(abs(da),abs(db))<1e-6:continue
            found=intersect_ray_tri(*target,direction,p,True)
            if found is not None:
                t=(found-p).dot(direction)/direction.length_squared
                if 1e-5 < t < 1-1e-5:
                    crossing=True;break
        if crossing:break
    if crossing:
        hits.append({'a':a,'b':b,'vertices_a':tris[a],'vertices_b':tris[b]})
report={'triangles':len(tris),'bvh_pairs':len(pairs),'nonadjacent_candidates':tested,
        'degenerate_triangles':degenerate,'crossing_pairs':len(hits),'examples':hits[:20],
        'scope':'Non-adjacent noncoplanar triangle crossings; adjacency and coplanar overlap excluded.'}
(root / 'docs' / report_name).write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
