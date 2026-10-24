"""Triangulate only the new road; the spit itself remains a native NURBS solid."""
import sys,json
from pathlib import Path
sys.path.insert(0,'D:/Prism Route/tools/terrain-runtime')
import numpy as np
import shapely as S
from shapely.geometry import Polygon
from shapely.ops import unary_union
from build_terrain_rebuild_1017 import triangulate,polygons,RoadField,smoothstep
out=Path(__file__).resolve().parents[1]/'docs/concepts/spit_road_1017_v01'
data=json.loads((out/'road_input.json').read_text('utf8'))
q=np.array([r['cross']for r in data['rows']],float)
poly=Polygon(np.vstack([q[:,0,:2],q[::-1,-1,:2]]))
assert poly.is_valid
fixed=[];fixedpaths=[]
for item in data['fixed']:
    v=np.array(item['v']).reshape(-1,7,3)
    loop=np.vstack([v[:,0],v[::-1,-1],v[:1,0]])
    fixed.append(Polygon(loop[:,:2]));fixedpaths.append(loop)
field=RoadField([q[:,j]for j in range(5)])
ff=RoadField(fixedpaths)
def zheight(xy):
    _,z,_=field.sample(xy);dist,zz,_=ff.sample(xy)
    w=1-smoothstep(dist/9)
    return z*(1-w)+zz*w
roads=[]
for p in polygons(poly.difference(unary_union(fixed))):
    if p.area<.5:continue
    v,f=triangulate(p,1.5)
    z=zheight(v)
    roads.append({'v':np.column_stack([v,z]).tolist(),'f':f.tolist()})
cut=Polygon(np.vstack([np.array(data['left'])[:,:2],np.array(data['right'])[::-1,:2]]))
assert cut.is_valid,'Spit corridor outline crosses itself'
cutters=[cut.simplify(.08,preserve_topology=True)]
cutters.extend(fixed)
# Remove duplicate nested bridge cut shapes before the native 2D Boolean.
cutters=polygons(S.make_valid(unary_union(cutters)))
lines=[]
for offset in [0,-9.5,9.5]:
    pts=[];faces=[]
    j=2 if offset==0 else (0 if offset<0 else 4)
    for i in range(len(q)-1):
        if offset==0 and int(data['rows'][i]['s']/7)%2:continue
        # No new markings on the existing bridge's owned footprint.
        a=q[i,j,:2].copy();b=q[i+1,j,:2].copy();d=b-a;n=np.array([-d[1],d[0]])/np.linalg.norm(d)
        if offset!=0:
            a-=n*np.sign(offset)*.5;b-=n*np.sign(offset)*.5
        corners=np.array([a-n*.075,b-n*.075,b+n*.075,a+n*.075])
        marking=Polygon(corners)
        if not poly.covers(marking)or any(p.intersects(marking)for p in fixed):continue
        if np.linalg.norm((a+b)/2-q[np.argmin(np.linalg.norm(q[:,2,:2]-np.array(data['fixed'][0]['v'][3][:2]),axis=1)),2,:2])<19:continue
        z=zheight(corners)+.025;k=len(pts);pts.extend(np.column_stack([corners,z]).tolist());faces.append([k,k+1,k+2,k+3])
    lines.append({'v':pts,'f':faces})
result={'roads':roads,'markings':lines,'cutters':[list(p.exterior.coords)[:-1]for p in cutters],
        'report':{'road_meshes':len(roads),'road_triangles':sum(len(r['f'])for r in roads),'road_height_min':min(p[2]for r in roads for p in r['v']),
                  'road_height_max':max(p[2]for r in roads for p in r['v']),'spit_max_half_widths':[36,28],
                  'description':'Native NURBS spit, unchanged sandbar beyond the corridor, actual fixed bridge decks clipped from the new asphalt.'}}
(out/'road_geometry.json').write_text(json.dumps(result,separators=(',',':')),encoding='utf8')
print(result['report'])
