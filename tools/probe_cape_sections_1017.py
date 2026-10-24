import sys,json,math
from pathlib import Path
sys.path.insert(0,'D:/Prism Route/tools/terrain-runtime')
import numpy as np
from shapely.geometry import Polygon,LineString,Point,box
from shapely.ops import unary_union
import shapely as S
root=Path(__file__).resolve().parents[1]
out=root/'docs/concepts/cape_spit_1017_v01';out.mkdir(exist_ok=True,parents=True)
data=json.loads((root/'docs/concepts/terrain_rebuild_1017/input.json').read_text('utf8'))
p=Polygon(np.array(next(x for x in data['sources']if x['id']=='1435beff-efcc-4af8-9837-27269aca4586')['loops'][0])[:,:2])
p=S.make_valid(p).intersection(box(-1000,1460,4000,4000))
pts=np.array(next(x for x in data['roads']if x['name']=='east_outer')['points'])
ss=np.r_[0,np.linalg.norm(np.diff(pts,axis=0),axis=1).cumsum()]
# Append the final shore tip, under the existing outlet bridge approach.
end=np.array([684.8062027,1650.6633128,.9414]);last=pts[-1]
extra=np.linspace(last,end,61)[1:];pts=np.vstack([pts,extra]);ss=np.r_[0,np.linalg.norm(np.diff(pts,axis=0),axis=1).cumsum()]
rows=[]
for s in np.arange(1450,ss[-1]-8,10):
 q=np.array([np.interp(s,ss,pts[:,j])for j in range(3)])
 qa=np.array([np.interp(s-1,ss,pts[:,j])for j in range(2)]);qb=np.array([np.interp(s+1,ss,pts[:,j])for j in range(2)])
 tangent=(qb-qa)/np.linalg.norm(qb-qa);n=np.array([-tangent[1],tangent[0]])
 hit=LineString([q[:2]-n*1800,q[:2]+n*1800]).intersection(p)
 geoms=[hit]if hit.geom_type=='LineString'else list(getattr(hit,'geoms',[]))
 geoms=[g for g in geoms if g.geom_type=='LineString'and g.distance(Point(q[:2]))<.5]
 if not geoms:continue
 g=min(geoms,key=lambda g:g.distance(Point(q[:2])));v=np.array(g.coords);offsets=(v-q[:2])@n
 lo,hi=offsets.min(),offsets.max();rows.append({'s':float(s),'p':q.tolist(),'n':n.tolist(),'left':float(lo),'right':float(hi)})
quads=[];invalid=[]
for i,(a,b)in enumerate(zip(rows[:-1],rows[1:])):
 corners=[]
 for row,side in [(a,'left'),(b,'left'),(b,'right'),(a,'right')]:corners.append(np.array(row['p'][:2])+np.array(row['n'])*row[side])
 poly=Polygon(corners)
 if not poly.is_valid:invalid.append(i)
 quads.append(S.make_valid(poly))
covered=unary_union(quads)
report={'sections':len(rows),'invalid_crossings':invalid,'target_area':p.area,'covered_area':covered.area,'missing_area':p.difference(covered).area,'excess_area':covered.difference(p).area,
        'min_width':min(r['right']-r['left']for r in rows),'max_width':max(r['right']-r['left']for r in rows)}
(out/'section_probe.json').write_text(json.dumps({'report':report,'rows':rows,'outline':S.to_geojson(p)}),encoding='utf8')
print(report)
