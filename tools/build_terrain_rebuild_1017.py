"""Offline constrained triangulation and a shared terrain/road elevation source.

Dependencies are local to D:/Prism Route/tools/terrain-runtime; Rhino remains
the working document. This script never writes to the live CAD document.
"""
import sys,json,math,time
from pathlib import Path
sys.path.insert(0,'D:/Prism Route/tools/terrain-runtime')
import numpy as np
import shapely as S
from shapely.geometry import Polygon,LineString,MultiPolygon,Point
from shapely.ops import unary_union
from shapely.strtree import STRtree
import triangle
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/concepts/terrain_rebuild_1017'

def polygons(g):
    if g.geom_type=='Polygon':return [g]
    return [p for q in getattr(g,'geoms',[])for p in polygons(q)]
def smoothstep(x):x=np.clip(x,0,1);return x*x*(3-2*x)
def save(name,d):
    (OUT/name).write_text(json.dumps(d,separators=(',',':')),encoding='utf8')
def densify_ring(ring,spacing):
    p=np.asarray(ring,float)[:,:2];result=[]
    for a,b in zip(p[:-1],p[1:]):
        n=max(1,int(np.ceil(np.linalg.norm(b-a)/spacing)))
        result.extend(a+(b-a)*t/n for t in range(n))
    return np.asarray(result)
def triangulate(poly,area,extra=None):
    loops=[densify_ring(poly.exterior.coords,2.0)]+[densify_ring(x.coords,2.0)for x in poly.interiors]
    pts=[];segments=[];holes=[];offset=0
    for k,p in enumerate(loops):
        pts.extend(p);segments.extend((offset+i,offset+(i+1)%len(p))for i in range(len(p)));offset+=len(p)
        if k:holes.append(np.asarray(Polygon(p).representative_point().coords)[0])
    if extra is not None and len(extra):
        inside=S.contains_xy(poly,extra[:,0],extra[:,1]);pts.extend(extra[inside])
    pts=np.round(np.asarray(pts,float),5)
    unique,inv=np.unique(pts,axis=0,return_inverse=True)
    seg=inv[np.asarray(segments,int)];seg=seg[seg[:,0]!=seg[:,1]]
    args={'vertices':unique,'segments':seg}
    if holes:args['holes']=np.array(holes)
    tr=triangle.triangulate(args,'pq18a%.3fQ'%area)
    v=tr['vertices'];f=tr['triangles'];cent=v[f].mean(axis=1)
    good=S.covers(poly,S.points(cent)).astype(bool)
    return v,f[good]

class RefSurface:
    def __init__(self,v,f):
        self.v=np.asarray(v,float);f=np.asarray(f,int)
        a,b,c=self.v[f[:,0]],self.v[f[:,1]],self.v[f[:,2]]
        det=(b[:,0]-a[:,0])*(c[:,1]-a[:,1])-(b[:,1]-a[:,1])*(c[:,0]-a[:,0])
        ok=np.abs(det)>1e-7
        self.f=f[ok];self.a=a[ok];self.b=b[ok];self.c=c[ok];self.det=det[ok]
        self.tree=STRtree(S.polygons(self.v[self.f][:,:,:2]))
    def height(self,xy):
        ans=np.full(len(xy),-np.inf)
        for i in range(0,len(xy),1500):
            p=xy[i:i+1500];pairs=self.tree.query(S.points(p));ip,it=pairs
            if not len(ip):continue
            a,b,c=self.a[it],self.b[it],self.c[it];d=self.det[it];x=p[ip]-a[:,:2]
            u=(x[:,0]*(c[:,1]-a[:,1])-x[:,1]*(c[:,0]-a[:,0]))/d
            w=((b[:,0]-a[:,0])*x[:,1]-(b[:,1]-a[:,1])*x[:,0])/d
            ok=(u>=-1e-6)&(w>=-1e-6)&(u+w<=1+1e-6)
            z=a[:,2]+u*(b[:,2]-a[:,2])+w*(c[:,2]-a[:,2])
            np.maximum.at(ans,ip[ok]+i,z[ok])
        return ans
    def nearest_height(self,xy):
        ans=self.height(xy);missing=np.where(~np.isfinite(ans))[0]
        if not len(missing):return ans
        p=xy[missing];it=self.tree.nearest(S.points(p))
        triangles=S.polygons(self.v[self.f[it]][:,:,:2])
        q=np.array([np.asarray(g.coords)[-1]for g in S.shortest_line(S.points(p),triangles)])
        a,b,c=self.a[it],self.b[it],self.c[it];d=self.det[it];x=q-a[:,:2]
        u=(x[:,0]*(c[:,1]-a[:,1])-x[:,1]*(c[:,0]-a[:,0]))/d
        w=((b[:,0]-a[:,0])*x[:,1]-(b[:,1]-a[:,1])*x[:,0])/d
        ans[missing]=a[:,2]+u*(b[:,2]-a[:,2])+w*(c[:,2]-a[:,2])
        return ans

class RoadField:
    def __init__(self,paths):
        aa=[];bb=[]
        for p in paths:
            aa.extend(p[:-1]);bb.extend(p[1:])
        self.a=np.array(aa);self.b=np.array(bb);self.delta=self.b-self.a
        self.l2=(self.delta[:,:2]**2).sum(axis=1)
        self.tree=STRtree(S.linestrings(np.stack([self.a[:,:2],self.b[:,:2]],axis=1)))
    def sample(self,xy):
        idx=self.tree.nearest(S.points(xy));a=self.a[idx];d=self.delta[idx]
        t=np.clip(((xy-a[:,:2])*d[:,:2]).sum(axis=1)/self.l2[idx],0,1)
        near=a+d*t[:,None]
        return np.linalg.norm(xy-near[:,:2],axis=1),near[:,2],idx

def point_on_path(p,xyz):
    d=np.linalg.norm(p[:,:2]-xyz[:2],axis=1);i=d.argmin()
    return int(i),float(d[i])
def run():
    started=time.time();data=json.loads((OUT/'input.json').read_text(encoding='utf8'))
    ps=[]
    for item in data['footprints']:
        p=Polygon(np.asarray(item['points'])[:,:2])
        ps.extend(polygons(S.make_valid(p)))
    land=unary_union([S.set_precision(p,.02)for p in ps])
    # Eliminate tiny numerical cracks from old shared boundaries, retaining
    # the actual lagoon outlet and physically separated islands.
    land=S.make_valid(land.buffer(.12,join_style=1).buffer(-.12,join_style=1))
    ps=[Polygon(p.exterior,[r.coords for r in p.interiors if Polygon(r).area>6000])for p in polygons(land)if p.area>100]
    land=unary_union(ps);save('land_boundaries.json',[{'outer':list(p.exterior.coords),'holes':[list(r.coords)for r in p.interiors],'area':p.area}for p in ps])
    ref=RefSurface(data['reference']['v'],data['reference']['f'])
    # Retained architectural shells remain editable NURBS. The new base
    # meets their projected perimeter instead of laying a second skin on top.
    shells=json.loads((OUT/'preserved_shells.json').read_text(encoding='utf8'))
    shell_polys=[];sv=[];sf=[]
    for row in shells:
        v=np.asarray(row['v']);f=np.asarray(row['f']);tri=v[f][:,:,:2]
        faces=[S.make_valid(Polygon(np.asarray(loop)[:,:2]))for loop in row['outlines']]
        shell_polys.append(unary_union([S.set_precision(p,.02)for p in faces if p.area>.05]))
        sf.extend((f+len(sv)).tolist());sv.extend(v.tolist())
    shell_union=unary_union(shell_polys)
    shell_union=S.make_valid(shell_union.buffer(.05).buffer(-.05).simplify(.08,preserve_topology=True))
    shell_ref=RefSurface(sv,sf)
    render_land=S.make_valid(land.difference(shell_union))
    terrain_polys=[p for p in polygons(render_land)if p.area>50]
    # A uniform elevation lattice avoids inheriting the old patch tessellation
    # as corrugations. Smooth before the exact road grading is imposed.
    minx,miny,maxx,maxy=land.bounds;step=5
    gx=np.arange(minx-10,maxx+15,step);gy=np.arange(miny-10,maxy+15,step)
    xx,yy=np.meshgrid(gx,gy);grid=ref.height(np.column_stack([xx.ravel(),yy.ravel()])).reshape(xx.shape)
    known=np.isfinite(grid);grid[~known]=0
    for _ in range(250):
        if known.all():break
        total=np.zeros_like(grid);counts=np.zeros_like(grid)
        for axis in [0,1]:
            for sign in [-1,1]:
                total+=np.roll(grid*known,sign,axis);counts+=np.roll(known,sign,axis)
        fill=(~known)&(counts>0);grid[fill]=total[fill]/counts[fill];known[fill]=True
    r=12;x=np.arange(-r,r+1);kernel=np.exp(-.5*(x/3.6)**2);kernel/=kernel.sum()
    for axis in [0,1]:
        grid=np.apply_along_axis(lambda q:np.convolve(np.pad(q,(r,r),mode='edge'),kernel,'valid'),axis,grid)
    def macroheight(xy):
        ix=np.clip((xy[:,0]-gx[0])/step,0,len(gx)-1.001);iy=np.clip((xy[:,1]-gy[0])/step,0,len(gy)-1.001)
        a=ix.astype(int);b=iy.astype(int);u=ix-a;v=iy-b
        return (1-u)*(1-v)*grid[b,a]+u*(1-v)*grid[b,a+1]+(1-u)*v*grid[b+1,a]+u*v*grid[b+1,a+1]
    paths={};stations={};anchors={}
    for r in data['roads']:
        p=np.asarray(r['points'],float);s=np.r_[0,np.linalg.norm(np.diff(p[:,:2],axis=0),axis=1).cumsum()]
        z=p[:,2].copy();n=10;x=np.arange(-n,n+1);kernel=np.exp(-(x/5)**2);kernel/=kernel.sum()
        z=np.convolve(np.pad(z,(n,n),mode='edge'),kernel,mode='valid');z=np.clip(z,.85,60.6)
        if r['name']=='upper_link':z=60.356+(60.0001309-60.356)*smoothstep(s/s[-1])
        p[:,2]=z;paths[r['name']]=p;stations[r['name']]=s;anchors[r['name']]=[]
    # The old west coast road leaves the ground footprint by up to 27m.
    # Move this short section into the existing land, instead of expanding
    # the coast into the sea or adding an unnecessary 240m bridge.
    p=paths['west_outer'];s=stations['west_outer'];safe=land.buffer(-20)
    idx=np.where((s>400)&(s<870))[0];pp=S.points(p[idx,:2]);pairs=S.shortest_line(pp,safe)
    target=np.array([np.asarray(g.coords)[-1]for g in pairs]);offset=np.zeros((len(p),2));offset[idx]=target-p[idx,:2]
    radius=60;x=np.arange(-radius,radius+1);kernel=np.exp(-(x/24)**2);kernel/=kernel.sum()
    for j in range(2):offset[:,j]=np.convolve(np.pad(offset[:,j],(radius,radius),mode='edge'),kernel,mode='valid')
    p[:,:2]+=offset;stations['west_outer']=np.r_[0,np.linalg.norm(np.diff(p[:,:2],axis=0),axis=1).cumsum()]
    west_shift=float(np.linalg.norm(offset,axis=1).max())
    # Deck geometry is fixed. Its real endpoints, not nominal water level,
    # anchor the rebuilt shore roads.
    fixed=[];fixed_paths=[]
    for item in data['fixed']:
        if 'mesh'in item:
            q=np.asarray(item['mesh']['v']).reshape(-1,7,3)
            outline=np.vstack([q[:,0],q[::-1,-1],q[:1,0]])
            fixed.append(Polygon(outline[:,:2]));fixed_paths.append(outline)
            if item['name'].startswith('63c'):
                anchors['east_outer'].append(q[0,3]);anchors['west_inner'].append(q[-1,3])
            else:
                anchors['east_outer'].append(q[0,3]);anchors['west_outer'].append(q[-1,3])
        else:
            q=np.asarray(item['points']);a=np.gradient(q[:,:2],axis=0);a/=np.linalg.norm(a,axis=1)[:,None]
            n=np.stack([-a[:,1],a[:,0]],axis=1)
            outline=np.vstack([np.column_stack([q[:,:2]+n*10,q[:,2]]),np.column_stack([q[::-1,:2]-n[::-1]*10,q[::-1,2]]),np.r_[q[0,:2]+n[0]*10,q[0,2]][None,:]])
            outline=np.asarray(json.loads((OUT/'artistic_road_boundary.json').read_text(encoding='utf8')))
            fixed.append(Polygon(outline[:,:2]));fixed_paths.append(outline)
            anchors['upper_link'].append(q[0]);anchors['east_outer'].append(q[-1])
    anchors['west_outer'].append(np.r_[paths['upper_link'][0,:2],60.356])
    # The only low-level T junction uses one common elevation.
    anchors['east_inner'].append(np.r_[paths['east_inner'][-1,:2],.85])
    cross=data['crossings'][-1]['point'];anchors['west_inner'].append(np.array([cross[0],cross[1],.85]))
    anchor_report=[]
    for name,p in paths.items():
        s=stations[name];targets=[];basis=[]
        for xyz in anchors[name]:
            i,dist=point_on_path(p,xyz)
            if dist>4:continue
            w=(1-smoothstep(np.abs(s-s[i])/65))
            basis.append(w);targets.append((i,float(xyz[2])))
        if targets:
            B=np.array(basis).T;A=B[[i for i,z in targets]]
            delta=np.linalg.lstsq(A,np.array([z-p[i,2]for i,z in targets]),rcond=None)[0]
            p[:,2]+=B@delta
            for i,z in targets:anchor_report.append({'road':name,'xyz':p[i].tolist(),'target_z':z,'error':abs(p[i,2]-z)})
    # Grade-separated crossings and the last part of the upper bridge approach
    # stay elevated; they must never become ground-height constraints.
    spans={'east_outer':[(20.0,175.0),(525.0,690.0)],'upper_link':[(205.0,float(stations['upper_link'][-1]))]}
    groups=[['east_outer','west_outer','upper_link'],['east_inner','west_inner']]
    fields=[RoadField([paths[n]for n in names])for names in groups]
    fixedfield=RoadField(fixed_paths)
    def roadheight(xy,group):
        _,z,_=fields[group].sample(xy);dist,zz,_=fixedfield.sample(xy)
        w=(1-smoothstep(dist/10))*(np.abs(zz-z)<4)
        return z*(1-w)+zz*w
    # Determine ground-only paths, splitting high crossing windows.
    ground=[];elevated=[]
    for name,p in paths.items():
        s=stations[name];mask=np.zeros(len(p),bool)
        for a,b in spans.get(name,[]):mask|=(s>=a)&(s<=b);elevated.append({'road':name,'start':a,'end':b})
        # Existing island gaps are supported as small open spans, rather than
        # pulling the terrain footprint over the sea.
        inside=S.covers(land,S.points(p[:,:2]));outside=~inside
        inds=np.where(outside)[0]
        if len(inds):
            for block in np.split(inds,np.where(np.diff(inds)>1)[0]+1):
                if not len(block):continue
                a=max(0,s[block[0]]-8);b=min(s[-1],s[block[-1]]+8)
                if b-a>12 and not any(a>=x and b<=y for x,y in spans.get(name,[])):
                    mask|=(s>=a)&(s<=b);elevated.append({'road':name,'start':float(a),'end':float(b),'reason':'existing_land_gap'})
        inds=np.where(~mask)[0]
        for block in np.split(inds,np.where(np.diff(inds)>1)[0]+1):
            if len(block)>1:ground.append(p[block])
    # Small bridge approaches are already graded in the native asset.
    q=np.asarray(data['fixed'][2]['mesh']['v']).reshape(-1,7,3)[:,3,:].copy()
    ground.append(q)
    gf=RoadField(ground)
    allroads=RoadField(list(paths.values()))
    def terrain_grade(xy,z):
        dist,zz,_=gf.sample(xy);weight=1-smoothstep((dist-18)/65)
        target=zz-.28
        # Fixed bridge approach structure has its own crown: bury the base
        # beneath it, avoiding overlapping white surface skins.
        fd,fz,_=fixedfield.sample(xy);near=(fd<16)&(np.abs(fz-zz)<4)
        target=np.where(near,np.minimum(target,fz-.5),target)
        return z*(1-weight)+target*weight
    # A few precise road-shoulder points improve terrain contact without
    # imposing old patch boundaries on the new topology.
    dense=[]
    for p in paths.values():
        a=np.gradient(p[:,:2],axis=0);a/=np.maximum(np.linalg.norm(a,axis=1)[:,None],1e-8)
        n=np.stack([-a[:,1],a[:,0]],axis=1)
        dense.extend(p[::2,:2]+n[::2]*y for y in [-15,-11,0,11,15])
    extra=np.vstack(dense)
    terrain=[]
    for number,poly in enumerate(terrain_polys):
        v,f=triangulate(poly,38,extra)
        z=macroheight(v)
        boundary=S.distance(S.points(v),land.boundary)
        z-=.65*(1-smoothstep(boundary/3))
        z=terrain_grade(v,np.minimum(z,60.6))
        # Match the actual preserved roof perimeter, with a broad fairing zone.
        sd=S.distance(S.points(v),shell_union);near=np.where(sd<25)[0]
        if len(near):
            nearest=np.array([np.asarray(g.coords)[-1]for g in S.shortest_line(S.points(v[near]),shell_union)])
            zz=shell_ref.nearest_height(nearest);valid=np.isfinite(zz)
            w=1-smoothstep(sd[near]/25);idx=near[valid]
            # Roads keep priority where a roof adjoins their shoulder.
            rd,_,_=gf.sample(v[idx]);w=w[valid]*smoothstep((rd-14)/12)
            z[idx]=z[idx]*(1-w)+(zz[valid]-.08)*w
        rd,rz,_=allroads.sample(v);cap=rd<12
        z[cap]=np.minimum(z[cap],rz[cap]-.34)
        terrain.append({'name':'continuous_land_%02d'%number,'v':np.column_stack([v,z]).tolist(),'f':f.tolist(),'area':poly.area})
        print('Terrain',number,len(v),len(f),flush=True)
    # One mesh per connected road-network polygon. Same-level intersections
    # are unioned before triangulation, eliminating overlapping road ribbons.
    roads=[];fixedunion=unary_union([S.make_valid(x)for x in fixed])
    for group,names in enumerate(groups):
        footprints=[]
        for name in names:
            q=paths[name][:,:2];ta=q[1]-q[0];tb=q[-1]-q[-2]
            # Overrun before trimming to the real bridge cross-section. A
            # square centerline cap leaves a wedge when the bridge cut is skew.
            q=np.vstack([q[0]-ta/np.linalg.norm(ta)*3,q,q[-1]+tb/np.linalg.norm(tb)*3])
            footprints.append(LineString(q).buffer(10,cap_style=2,join_style=1,quad_segs=8))
        joined=unary_union(footprints)
        joined=joined.buffer(8,quad_segs=10).buffer(-8,quad_segs=10)
        poly=joined.difference(fixedunion)
        for i,p in enumerate(polygons(S.make_valid(poly))):
            if p.area<2:continue
            v,f=triangulate(p,4)
            z=roadheight(v,group)
            roads.append({'name':('upper'if group==0 else 'lower')+'_network_%02d'%i,'group':group,'v':np.column_stack([v,z]).tolist(),'f':f.tolist()})
    # Merge overlapping requests before building anything; there must never
    # be two coincident structural decks at the upper link.
    merged=[]
    for name in paths:
        intervals=sorted((r['start'],r['end'])for r in elevated if r['road']==name)
        acc=[]
        for a,b in intervals:
            if acc and a<=acc[-1][1]+3:acc[-1][1]=max(acc[-1][1],b)
            else:acc.append([a,b])
        merged.extend({'road':name,'start':a,'end':b}for a,b in acc)
    elevated=merged
    # Export elevated structural work-lines, with their asphalt grade fixed.
    bridge_specs=[]
    for spec in elevated:
        name=spec['road'];p=paths[name];s=stations[name];aa,bb=spec['start'],spec['end']
        ss=np.linspace(aa,bb,max(25,int((bb-aa)/3)+1))
        q=np.column_stack([np.interp(ss,s,p[:,j])for j in range(3)])
        group=0 if name in groups[0]else 1;q[:,2]=roadheight(q[:,:2],group)
        bridge_specs.append({**spec,'points':q.tolist()})
    save('rebuilt_geometry.json',{'terrain':terrain,'roads':roads,'bridges':bridge_specs,'paths':{k:v.tolist()for k,v in paths.items()}})
    save('design_report.json',{'land_components':len(ps),'land_areas':[p.area for p in ps],'west_coast_road_max_plan_shift_m':west_shift,'road_meshes':len(roads),'spans':elevated,'anchors':anchor_report,'road_max_grades':{n:float((np.abs(np.diff(p[:,2]))/np.diff(stations[n])).max())for n,p in paths.items()},'seconds':time.time()-started,'libraries':{'shapely':S.__version__,'triangle':triangle.__version__}})
    print('Prepared in',round(time.time()-started,2),'seconds',flush=True)

if __name__=='__main__':run()
