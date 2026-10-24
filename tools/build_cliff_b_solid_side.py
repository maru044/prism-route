"""One watertight terraced core with shared rings and angular bevel edges."""
from pathlib import Path
import json,math,random
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'.map_1012_build'


def build():
    cfg=json.loads((ROOT/'tools/cliff_b_solid_side_v01.json').read_text(encoding='utf-8'))
    source=json.loads((WORK/'cliff_b_solid_side_input.json').read_text(encoding='utf-8'))
    data=np.asarray(source['rows']);count=len(data)
    allowance=np.full(count,30.0)
    distances=np.full(count,float('inf'))
    for obstacle in source['obstacles']:
        for boundary in obstacle['boundaries']:
            a=np.asarray(boundary['points']);v=np.roll(a,-1,axis=0)-a
            for i,row in enumerate(data):
                n=row[2:4];w=a-row[:2]
                denominator=n[0]*v[:,1]-n[1]*v[:,0]
                good=np.abs(denominator)>1e-9
                t=np.divide(w[:,0]*v[:,1]-w[:,1]*v[:,0],denominator,out=np.full(len(a),np.inf),where=good)
                u=np.divide(w[:,0]*n[1]-w[:,1]*n[0],denominator,out=np.full(len(a),np.inf),where=good)
                hits=t[good & (u>=0) & (u<=1) & (t>=0)]
                if len(hits):distances[i]=min(distances[i],float(hits.min()))
    allowance=np.minimum(allowance,np.maximum(0,distances-cfg['neighbor_margin_m']))
    # A conservative cyclic minimum filter keeps the limiting field smooth
    # without averaging outward past the nearest measured obstacle.
    for _ in range(3):allowance=np.minimum(allowance,(np.roll(allowance,1)+np.roll(allowance,-1))/2)
    def smooth(t):
        t=min(1,max(0,t));return t*t*(3-2*t)
    weights=[round(smooth((r[4]-65)/65),3) for r in data]
    ds=np.linalg.norm(np.roll(data[:,:2],-1,axis=0)-data[:,:2],axis=1)
    dn=np.linalg.norm(np.roll(data[:,2:4],-1,axis=0)-data[:,2:4],axis=1)
    radius=np.divide(ds,dn,out=np.full(count,1e6),where=dn>1e-8)
    radius=np.minimum.reduce([np.roll(radius,k) for k in range(-4,5)])
    profile_scale=np.minimum(1,radius*.55/(39+cfg['bevel_width_m']))
    rng=random.Random(cfg['seed'])
    phases=[rng.uniform(-math.pi,math.pi) for _ in range(7)]
    heights=cfg['level_heights_m'];offsets=cfg['level_offsets_m']
    height_values=[]
    for i in range(count):
        values=[0.0]
        s=i/count;w=weights[i]
        for level in range(1,6):
            wave=cfg['height_wave_m']*(math.sin(2*math.pi*s+phases[level])+.32*math.sin(6*math.pi*s+phases[level]*.5))
            values.append(min(57-6*(6-level),max(values[-1]+6,heights[level]+w*wave)))
        values.append(57.0);height_values.append(values)
    vertices=[];rings=[];lookup={}
    def vertex(point):
        key=tuple(round(v,7) for v in point)
        if key not in lookup:lookup[key]=len(vertices);vertices.append(point)
        return lookup[key]
    def height(level,i):
        return height_values[i][level]
    def offset(level,i):
        s=i/count;w=weights[i]
        # Preserve positive terrace width after the slanted edge. Too large
        # independent phase changes would place the cap beyond its own lip.
        wave=.7*math.sin(4*math.pi*s+phases[level])
        value=(offsets[level]+wave)*w*float(profile_scale[i])
        if value>0:value=min(value,float(allowance[i]))
        return value
    def ring(level,mode):
        ids=[]
        for i,row in enumerate(data):
            w=weights[i]
            if mode=='bottom':o=offset(0,i);z=0
            elif mode=='wall':o=offset(level-1,i)-1.0*w*float(profile_scale[i]);z=height(level,i)-cfg['bevel_height_m']
            elif mode=='bevel':o=offset(level-1,i)-cfg['bevel_width_m']*w*float(profile_scale[i]);z=height(level,i)
            else:o=offset(level,i);z=height(level,i)
            if o>0:o=min(o,float(allowance[i]))
            ids.append(vertex([float(row[0]+row[2]*o),float(row[1]+row[3]*o),float(z)]))
        rings.append(ids)
    ring(0,'bottom')
    for level in range(1,7):
        ring(level,'wall');ring(level,'bevel');ring(level,'terrace')
    faces=[]
    def face(ids):
        unique=[]
        for v in ids:
            if not unique or unique[-1]!=v:unique.append(v)
        if len(unique)>1 and unique[0]==unique[-1]:unique.pop()
        if len(set(unique))<3:return
        if len(unique)==3:faces.append(unique)
        elif len(unique)==4:faces.append(unique)
    for a,b in zip(rings,rings[1:]):
        for i in range(count):
            j=(i+1)%count
            face([a[i],a[j],b[j],b[i]])

    def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
    def cap(ids,reverse):
        indices=list(ids)
        if sum(vertices[indices[i]][0]*vertices[indices[(i+1)%count]][1]-vertices[indices[(i+1)%count]][0]*vertices[indices[i]][1] for i in range(count))<0:indices.reverse()
        while len(indices)>3:
            found=False
            for k in range(len(indices)):
                ia,ib,ic=indices[k-1],indices[k],indices[(k+1)%len(indices)]
                a,b,c=vertices[ia],vertices[ib],vertices[ic]
                if cross(a,b,c)<=1e-8:continue
                minx,maxx=min(a[0],b[0],c[0]),max(a[0],b[0],c[0])
                miny,maxy=min(a[1],b[1],c[1]),max(a[1],b[1],c[1])
                blocked=False
                for iv in indices:
                    if iv in [ia,ib,ic]:continue
                    p=vertices[iv]
                    if minx<=p[0]<=maxx and miny<=p[1]<=maxy and cross(a,b,p)>=-1e-9 and cross(b,c,p)>=-1e-9 and cross(c,a,p)>=-1e-9:
                        blocked=True;break
                if blocked:continue
                f=[ia,ib,ic];faces.append(f[::-1] if reverse else f);indices.pop(k);found=True;break
            if not found:raise RuntimeError('Cap triangulation failed; inspect contour self-intersections')
        faces.append(indices[::-1] if reverse else indices)
    cap(rings[0],True);cap(rings[-1],False)
    back_length=sum(source['ring_length_m']/count for w in weights if w>.25)
    metrics={'body_ring_length_m':source['ring_length_m'],'terraced_side_length_m':back_length,
             'levels':6,'profile_rings':len(rings),'shared_vertices':len(vertices),
             'faces':len(faces),'source_core_id':source['core_id'],'neighbor_margin_m':cfg['neighbor_margin_m'],
             'sampled_neighbor_clearance_min_m':min(float(d) for d,w in zip(distances,weights) if math.isfinite(d) and w>.1),
             'bevel_width_m':cfg['bevel_width_m'],'bevel_height_m':cfg['bevel_height_m']}
    payload={'vertices':vertices,'faces':faces,'metrics':metrics,
             'obstacle_ids':[o['id'] for o in source['obstacles']],
             'profile_rings':rings,'back_weights':weights,'outward_allowance_m':allowance.tolist()}
    (WORK/'cliff_b_solid_side_mesh.json').write_text(json.dumps(payload,separators=(',',':')),encoding='utf-8')
    print(json.dumps(metrics))


if __name__=='__main__':build()
