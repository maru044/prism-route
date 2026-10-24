# -*- coding: utf-8 -*-
"""A lagoon bridge: shared-topology deck/haunch/piers, original route preserved.

Run inside Rhino 8. Functions are deliberately separate: prepare, preview,
publish, verify, save. No terrain rebuilding, Boolean unions or small bridge.
"""
from __future__ import division, unicode_literals
import Rhino, scriptcontext as sc, System, math, os, io, json, datetime
from System.Drawing import Color
G = Rhino.Geometry
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'docs', 'concepts', 'lagoon_bridges_2026-10-17', 'model_A')
TAG = 'lagoon_long_bridge_A_1017_v01'
LAYER = '1017_泻湖长桥_A_v01'
GUID = '863e8b4d-3ba9-4b63-b708-81f9e4298736'
END = 559.0645859972
PIERS = [42.0 + 39.0*i for i in range(13)]
WIDTH = 26.0
J = [-13,-12.7,-11.7,-10.8,-9.8,-5,0,5,9.8,10.8,11.7,12.7,13]
NY = len(J)-1

def xyz(p): return [float(p.X),float(p.Y),float(p.Z)]
def smooth(t):
    t=max(0,min(1,t));return t*t*(3-2*t)
def obj(guid): return sc.doc.Objects.FindId(System.Guid(guid))
def write(name,data):
    if not os.path.isdir(OUT):os.makedirs(OUT)
    with io.open(os.path.join(OUT,name),'w',encoding='utf-8') as f:
        f.write(unicode(json.dumps(data,ensure_ascii=False,indent=2,default=str)))
def source(): return obj(GUID).Geometry
def frame(s):
    c=source();ok,t=c.LengthParameter(max(0,min(c.GetLength(),s)))
    p=c.PointAt(t);a=c.TangentAt(t);a.Z=0;a.Unitize()
    n=G.Vector3d(-a.Y,a.X,0)
    return p,a,n
def height(s):
    q=max(0,min(1,s/END))
    # Shore grades tend to zero, with one continuous gentle crown.
    return .977*(1-smooth(q))+.09221*smooth(q)+12.0*math.sin(math.pi*q)**1.5
def point(s,y,z=None):
    p,a,n=frame(s);p=p+n*y;p.Z=height(s) if z is None else z
    return p
def perimeter(i0,i1,j0,j1):
    return ([(i,j0)for i in range(i0,i1)]+[(i1,j)for j in range(j0,j1)]
           +[(i,j1)for i in range(i1,i0,-1)]+[(i0,j)for j in range(j1,j0,-1)])
def build(lo,hi,piers):
    # Exact, close end rows resist longitudinal shrinkage at the shore joint.
    stations=sorted(set([lo,lo+.3,lo+.8,hi-.8,hi-.3,hi]+
                       [lo+(hi-lo)*i/int(math.ceil((hi-lo)/2.6))
                        for i in range(1,int(math.ceil((hi-lo)/2.6)))]))
    nx=len(stations)-1;roots=[]
    for s in piers:
        i0=min(range(nx+1),key=lambda i:abs(stations[i]-(s-17)))
        i1=min(range(nx+1),key=lambda i:abs(stations[i]-(s+17)))
        roots.append((i0,i1,3,NY-3,s))
    mesh=G.Mesh();top={};bottom={};bp={};tp={}
    def vert(p):return mesh.Vertices.Add(p)
    for i,s in enumerate(stations):
        weight=max([math.exp(-((s-r)/17)**2)for r in piers]or[0])
        for j,y in enumerate(J):
            # Flat usable crown; edge rounds down beyond the pedestrian strip.
            edge=smooth((abs(y)-11.7)/1.3)
            p=point(s,y,height(s)-.24*edge);tp[i,j]=p;top[i,j]=vert(p)
            cross=max(0,1-(y/13)**2)
            depth=.85+.85*cross+1.15*weight*cross
            b=point(s,y,p.Z-depth);bp[i,j]=b;bottom[i,j]=vert(b)
    for i in range(nx):
        for j in range(NY):
            mesh.Faces.AddFace(top[i,j],top[i+1,j],top[i+1,j+1],top[i,j+1])
            if not any(i0<=i<i1 and j0<=j<j1 for i0,i1,j0,j1,s in roots):
                mesh.Faces.AddFace(bottom[i,j+1],bottom[i+1,j+1],bottom[i+1,j],bottom[i,j])
    boundary=perimeter(0,nx,0,NY);last=[top[k]for k in boundary]
    for f in [.22,.55,.83,1]:
        ring=[]
        for i,j in boundary:
            a=tp[i,j];b=bp[i,j];p=G.Point3d(a.X,a.Y,a.Z+(b.Z-a.Z)*f)
            # Only lateral roll; no artificial radial bulge along curved route.
            if j in [0,NY] and i not in [0,nx]:
                v=frame(stations[i])[2]*(.18*math.sin(math.pi*f)*(1 if j==NY else -1));p+=v
            ring.append(bottom[i,j]if f==1 else vert(p))
        for k in range(len(last)):
            m=(k+1)%len(last);mesh.Faces.AddFace(last[k],ring[k],ring[m],last[m])
        last=ring
    feet=[]
    for num,(i0,i1,j0,j1,s)in enumerate(roots):
        boundary=perimeter(i0,i1,j0,j1);ring0=[bp[k]for k in boundary]
        center=point(s,0,sum(p.Z for p in ring0)/len(ring0));p,a,n=frame(s)
        rx=max(abs(G.Vector3d.Multiply(v-center,a))for v in ring0)
        ry=max(abs(G.Vector3d.Multiply(v-center,n))for v in ring0)
        last=[bottom[k]for k in boundary]
        # Broad springing is part of the belly itself. Narrow oval stem and
        # slight longitudinal sweep, with a flared foot concealed below water.
        steps=[(.035,.78),(.09,.64),(.19,.49),(.33,.36),(.52,.235),(.73,.16),(.90,.14),(1,.18)]
        for t,scale in steps:
            ring=[];circ=smooth((t-.1)/.55)
            for v in ring0:
                d=v-center;x=G.Vector3d.Multiply(d,a);y=G.Vector3d.Multiply(d,n)
                angle=math.atan2(y/ry,x/rx)
                x=x*(1-circ)+rx*math.cos(angle)*circ
                y=y*(1-circ)+ry*math.sin(angle)*circ
                # Keep shoulder above the water; buried end is -3m.
                z=v.Z+( -3.0-v.Z)*t
                v2=center+a*(x*scale+1.3*smooth(t))+n*(y*scale*(1-.26*circ))
                v2.Z=z;ring.append(vert(v2))
            for k in range(len(last)):
                m=(k+1)%len(last);mesh.Faces.AddFace(last[m],ring[m],ring[k],last[k])
            last=ring
        cap=vert(point(s+1.3,0,-3))
        for k in range(len(last)):mesh.Faces.AddFace(last[(k+1)%len(last)],cap,last[k])
        feet.append({'station_m':s,'root_m':[rx*2,ry*2],'stem_m':[rx*.28,ry*.28*.74]})
    mesh.Vertices.CullUnused();mesh.UnifyNormals();mesh.Normals.ComputeNormals();mesh.Compact()
    if mesh.SolidOrientation()<0:mesh.Flip(True,True,True)
    assert mesh.IsValid and mesh.IsClosed and mesh.IsManifold(),'Invalid control topology'
    subd=G.SubD.CreateFromMesh(mesh,G.SubDCreationOptions.Smooth)
    assert subd and subd.IsValid and subd.IsSolid,'Invalid SubD'
    limit=G.Mesh.CreateFromSubD(subd,2)
    assert limit.IsValid and limit.IsClosed and len(limit.SplitDisjointPieces())==1
    return {'subd':subd,'control':mesh,'limit':limit,'feet':feet,'stations':stations}
def layer(name,visible=True):
    root=sc.doc.Layers.FindByFullPath(LAYER,-1)
    if root<0:
        l=Rhino.DocObjects.Layer();l.Name=LAYER;root=sc.doc.Layers.Add(l)
    path=LAYER+'::'+name;i=sc.doc.Layers.FindByFullPath(path,-1)
    if i<0:
        l=Rhino.DocObjects.Layer();l.Name=name;l.ParentLayerId=sc.doc.Layers[root].Id;l.IsVisible=visible;i=sc.doc.Layers.Add(l)
    return i
def material(name,color,shine=40,reflect=.08):
    m=Rhino.DocObjects.Material();m.Name=name;m.DiffuseColor=color;m.Shine=shine;m.Reflectivity=reflect
    return sc.doc.Materials.Add(m)
def attrs(name,child,mi):
    a=Rhino.DocObjects.ObjectAttributes();a.Name=name;a.LayerIndex=layer(child)
    a.MaterialIndex=mi;a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
    a.SetUserString('recipe',TAG);return a
def prepare():
    d=build(217.5,334.5,[237,276]);sc.sticky[TAG+'_sample']=d
    write('sample_topology.json',{'valid':bool(d['subd'].IsValid),'solid':bool(d['subd'].IsSolid),'vertices':int(d['control'].Vertices.Count),'faces':int(d['control'].Faces.Count),'piers':d['feet']})
    print('Two-pier sample prepared: valid closed connected SubD')
def preview():
    d=sc.sticky[TAG+'_sample'];mi=material('泻湖桥_暖白高光',Color.FromArgb(239,235,225),85,.2)
    a=attrs('验证_双墩连续桥腹','99_样段验证_隐藏',mi)
    oid=sc.doc.Objects.AddSubD(d['subd'],a);sc.sticky[TAG+'_sample_id']=str(oid)
    vp=sc.doc.Views.ActiveView.ActiveViewport;center=point(276,0,6);p,axis,n=frame(276)
    vp.ChangeToPerspectiveProjection(True,50);vp.SetCameraLocations(center,center+n*145+axis*65+G.Vector3d(0,0,22))
    vp.ZoomBoundingBox(d['subd'].GetBoundingBox(True));sc.doc.Views.Redraw()
    print(str(oid))
def save_copy(path):
    opt=Rhino.FileIO.FileWriteOptions();opt.UpdateDocumentPath=False;opt.IncludeRenderMeshes=False
    opt.SuppressAllInput=True;opt.SuppressDialogBoxes=True
    assert sc.doc.Write3dmFile(path,opt),'Save failed '+path
def backup():
    if sc.sticky.get(TAG+'_backup'):return
    path=os.path.join(os.path.dirname(ROOT),'map','map_1016_before_lagoon_A_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'.3dm')
    save_copy(path);sc.sticky[TAG+'_backup']=path;print(path)
def prepare_full():
    d=build(0,END,PIERS);sc.sticky[TAG+'_full']=d
    write('full_topology.json',{'valid':True,'solid':True,'vertices':int(d['control'].Vertices.Count),'faces':int(d['control'].Faces.Count),'piers':d['feet']})
    print('Full bridge prepared: %d control faces'%d['control'].Faces.Count)

def finish_surfaces():
    d=sc.sticky[TAG+'_full'];limit=d['limit']
    # Query the actual SubD limit crown, rather than laying a coincident plane
    # over the analytic control net. One cached mesh is reused for every ray.
    def crown(s,y):
        p=point(s,y,100)
        dist=G.Intersect.Intersection.MeshRay(limit,G.Ray3d(p,-G.Vector3d.ZAxis))
        # End-cap rounding must not pull the driving surface below the crown.
        return max(height(s),100-dist) if dist>=0 else height(s)
    count=int(math.ceil(END/1.4));samples=[END*i/count for i in range(count+1)]
    d['crown']=crown;d['samples']=samples
    def strip(ys,dz):
        m=G.Mesh()
        ys=sorted(ys)
        for s in samples:
            for y in ys:m.Vertices.Add(point(s,y,crown(s,y)+dz))
        ny=len(ys)
        for i in range(count):
            for j in range(ny-1):
                k=i*ny+j;m.Faces.AddFace(k,k+ny,k+ny+1,k+1)
        m.Normals.ComputeNormals();m.Compact();assert m.IsValid
        return m
    road=strip([-10,-7,-3.5,0,3.5,7,10],.075)
    edges=[strip([sign*10.1,sign*10.25],.095)for sign in [-1,1]]
    center=strip([-.065,.065],.095)
    d['road']=road;d['lines']=edges+[center]
    # Closed rolled kerbs and round handrails, without tall decorative fins.
    def tube(y,zoff,radius):
        m=G.Mesh();sides=12
        for s in samples:
            p,a,n=frame(s);p=point(s,y,crown(s,y)+zoff)
            for j in range(sides):
                angle=2*math.pi*j/sides
                m.Vertices.Add(p+n*(radius*math.cos(angle))+G.Vector3d.ZAxis*(radius*math.sin(angle)))
        for i in range(count):
            for j in range(sides):
                a=i*sides+j;b=i*sides+(j+1)%sides;m.Faces.AddFace(a,b,b+sides,a+sides)
        for i,rev in [(0,True),(count,False)]:
            c=m.Vertices.Add(point(samples[i],y,crown(samples[i],y)+zoff))
            for j in range(sides):
                a=i*sides+j;b=i*sides+(j+1)%sides
                m.Faces.AddFace(c,b,a)if rev else m.Faces.AddFace(c,a,b)
        m.UnifyNormals();m.Normals.ComputeNormals();m.Compact()
        if m.SolidOrientation()<0:m.Flip(True,True,True)
        assert m.IsValid and m.IsClosed
        return m
    rails=[];kerbs=[];posts=[]
    for sign in [-1,1]:
        y=sign*12
        kerbs.append(tube(y,.18,.24))
        rails.append(tube(y,1.22,.085));rails.append(tube(y,.69,.048))
        pm=G.Mesh()
        postcount=int(math.ceil(END/5))
        for i in range(postcount+1):
            s=END*i/postcount;p=point(s,y,crown(s,y)+.25)
            cylinder=G.Cylinder(G.Circle(G.Plane(p,G.Vector3d.ZAxis),.067),.97)
            pm.Append(G.Mesh.CreateFromCylinder(cylinder,1,10,True,True))
        pm.Normals.ComputeNormals();pm.Compact();posts.append(pm)
    d['rails']=rails;d['kerbs']=kerbs;d['posts']=posts
    print('Road, markings, rolled kerbs and low rails prepared')

def publish():
    d=sc.sticky[TAG+'_full'];assert 'road'in d
    if sc.sticky.get(TAG+'_objects'):raise RuntimeError('Already published; use owned-object replacement')
    backup();rec=sc.doc.BeginUndoRecord('泻湖长桥 A 连续展肩结构')
    rows=[]
    try:
        mi=material('泻湖长桥_暖白半光建筑涂层',Color.FromArgb(239,235,226),90,.22)
        asphalt=material('泻湖长桥_石墨沥青',Color.FromArgb(55,59,62),12,.025)
        metal=material('泻湖长桥_浅灰金属扶手',Color.FromArgb(177,184,182),100,.5)
        paint=material('泻湖长桥_车道标线',Color.FromArgb(237,234,220),30,.05)
        def add(geo,name,child,mat):
            a=attrs(name,child,mat)
            oid=sc.doc.Objects.AddSubD(geo,a)if isinstance(geo,G.SubD)else sc.doc.Objects.AddMesh(geo,a)
            assert oid!=System.Guid.Empty
            rows.append({'id':str(oid),'name':name,'layer':child})
        add(d['subd'],'A_整桥_桥身柱肩与13墩连续_SubD','01_桥身与桥墩_连续SubD',mi)
        add(d['road'],'A_连续缓拱沥青路面','02_路面',asphalt)
        for i,m in enumerate(d['lines']):add(m,'A_车道线_%02d'%i,'03_标线',paint)
        for i,m in enumerate(d['kerbs']):add(m,'A_圆转边带_%02d'%i,'04_低护栏与边带',mi)
        for i,m in enumerate(d['rails']):add(m,'A_连续扶手_%02d'%i,'04_低护栏与边带',metal)
        for i,m in enumerate(d['posts']):add(m,'A_扶手立柱_%02d'%i,'04_低护栏与边带',metal)
        # Keep the exact flat plan rail and new graded working rail for editing.
        li=layer('90_源曲线_隐藏',False)
        for name,curve in [('原路线_跨湖段',source().Trim(source().Domain.T0,source().LengthParameter(END)[1])),
                           ('缓拱三维中心线',G.Curve.CreateInterpolatedCurve([point(s,0)for s in d['samples']],3))]:
            a=Rhino.DocObjects.ObjectAttributes();a.Name=name;a.LayerIndex=li;a.SetUserString('recipe',TAG)
            oid=sc.doc.Objects.AddCurve(curve,a);rows.append({'id':str(oid),'name':name,'layer':'90_源曲线_隐藏'})
        li=layer('99_样段验证_隐藏');l=sc.doc.Layers[li];l.IsVisible=False;sc.doc.Layers.Modify(l,li,True)
        sc.sticky[TAG+'_objects']=rows
        sc.doc.Objects.UnselectAll()
    finally:sc.doc.EndUndoRecord(rec);sc.doc.Views.Redraw()
    write('objects.json',rows)
    print(json.dumps({'published':len(rows),'pier_count':13,'length_m':END},ensure_ascii=False))

def verify():
    d=sc.sticky[TAG+'_full'];fail=[];changed=[]
    for oid,crc in sc.sticky['lagoon_A_source_crc'].items():
        o=obj(oid)
        if o is None or int(o.Geometry.DataCRC(0))!=crc:changed.append(oid)
    if changed:fail.append('Original source geometry changed')
    if not d['subd'].IsValid or not d['subd'].IsSolid:fail.append('Invalid/open bridge SubD')
    if not d['limit'].IsClosed or len(d['limit'].SplitDisjointPieces())!=1:fail.append('Bridge not single closed component')
    grades=[abs((height(s+.1)-height(s-.1))/.2)for s in d['samples'][1:-1]]
    water=obj('3861e9e6-1993-4c9a-9445-ddd4e3b687a2').Geometry.Faces[0]
    footchecks=[]
    for s in PIERS:
        p=point(s+1.3,0,0);ok,u,v=water.ClosestPoint(p)
        footchecks.append({'station_m':s,'water_trim':str(water.IsPointOnFace(u,v))})
    if any(r['water_trim']=='Exterior'for r in footchecks):fail.append('Pier center outside lagoon water')
    separations=[];misses=0
    for i in range(len(d['samples'])-1):
        s=(d['samples'][i]+d['samples'][i+1])/2
        for y in [-9,0,9]:
            p=point(s,y,100);ray=G.Ray3d(p,-G.Vector3d.ZAxis)
            a=G.Intersect.Intersection.MeshRay(d['limit'],ray)
            b=G.Intersect.Intersection.MeshRay(d['road'],ray)
            if a>=0 and b>=0:separations.append(a-b)
            else:misses+=1
    if not separations or min(separations)<=0:fail.append('Asphalt intersects structure')
    if misses:fail.append('Road sampling misses')
    d['road'].FaceNormals.ComputeFaceNormals()
    report={'failures':fail,'source_geometry_count':len(sc.sticky['lagoon_A_source_crc']),
            'sources_unchanged':not changed,'changed_ids':changed,'native_closed_subd':True,
            'single_connected_bridge':len(d['limit'].SplitDisjointPieces())==1,
            'control_vertices':int(d['control'].Vertices.Count),'control_faces':int(d['control'].Faces.Count),
            'limit_faces':int(d['limit'].Faces.Count),'bridge_length_m':END,
            'water_crossing_m':END-21.4393273718,'total_width_m':WIDTH,'road_width_m':20,
            'deck_top_range_m':[height(END),height(END/2)],'max_grade_percent':max(grades)*100,
            'pier_count':len(PIERS),'pier_centers':footchecks,'asphalt_offset_above_limit_m':.075,
            'road_midcell_samples':len(separations),'road_midcell_misses':misses,
            'min_asphalt_separation_m':min(separations),'max_asphalt_separation_m':max(separations),
            'min_road_face_normal_z':min(float(n.Z)for n in d['road'].FaceNormals),
            'limitations':'Concept asset, not structural engineering. No game collision or drive test yet. Small outlet bridge untouched.'}
    write('verification.json',report);print(json.dumps(report,ensure_ascii=False));return report

def view(kind):
    vp=sc.doc.Views.ActiveView.ActiveViewport;d=sc.sticky[TAG+'_full']
    vp.ChangeToPerspectiveProjection(True,50)
    if kind=='overview':
        center=point(280,0,0);p,a,n=frame(280)
        vp.SetCameraLocations(center,center+n*650+a*170+G.Vector3d(0,0,330))
        vp.ZoomBoundingBox(d['subd'].GetBoundingBox(True))
    elif kind=='shoulder':
        center=point(280,0,7);p,a,n=frame(280)
        vp.SetCameraLocations(center,center+n*90+a*55+G.Vector3d(0,0,9))
        vp.ZoomBoundingBox(G.BoundingBox([point(s,y,z)for s in [218,334]for y in [-13,13]for z in [-1,15]]))
    elif kind=='drive':
        # Elevated deck inspection: large ocean extent otherwise clips the
        # foreground in Rhino's automatic perspective depth range.
        cam=point(160,-4,d['crown'](160,-4)+12);target=point(245,-4,d['crown'](245,-4)+4.5)
        vp.SetCameraLocations(target,cam)
        info=Rhino.DocObjects.ViewportInfo(vp);info.SetFrustumNearFar(.1,10000);vp.SetViewProjection(info,True)
    sc.doc.Views.Redraw()
def capture(name):
    cap=Rhino.Display.ViewCapture();cap.Width=1800;cap.Height=1100
    cap.DrawGrid=False;cap.DrawAxes=False;cap.DrawGridAxes=False
    bmp=cap.CaptureToBitmap(sc.doc.Views.ActiveView)
    path=os.path.join(OUT,name+'.png');bmp.Save(path,System.Drawing.Imaging.ImageFormat.Png);bmp.Dispose();print(path)
def save():
    report=verify();assert not report['failures'],'Verification failed before save'
    rows=sc.sticky[TAG+'_objects'];file=Rhino.FileIO.File3dm();file.Settings.ModelUnitSystem=sc.doc.ModelUnitSystem
    # Preserve only the bridge layers/materials, with indices remapped.
    lm={};mm={}
    for row in rows:
        o=obj(row['id']);old=o.Attributes.LayerIndex
        if old not in lm:
            l=Rhino.DocObjects.Layer();l.Id=System.Guid.NewGuid();l.Name=sc.doc.Layers[old].Name;l.IsVisible=sc.doc.Layers[old].IsVisible
            file.AllLayers.Add(l);lm[old]=next(x.Index for x in file.AllLayers if x.Id==l.Id)
        a=o.Attributes.Duplicate();a.LayerIndex=lm[old]
        oldmat=a.MaterialIndex
        if oldmat>=0:
            if oldmat not in mm:
                m=Rhino.DocObjects.Material(sc.doc.Materials[oldmat]);m.Id=System.Guid.NewGuid()
                file.AllMaterials.Add(m);mm[oldmat]=next(x.Index for x in file.AllMaterials if x.Id==m.Id)
            a.MaterialIndex=mm[oldmat]
        file.Objects.Add(o.Geometry,a)
    asset=os.path.join(os.path.dirname(ROOT),'map','lagoon_bridges_A_1017.3dm')
    file.Views.Add(Rhino.DocObjects.ViewInfo(sc.doc.Views.ActiveView.ActiveViewport))
    assert file.Write(asset,8),'Asset save failed'
    # Save the updated working document, retaining its established filename.
    assert Rhino.RhinoApp.RunScript('_Save',False),'Scene save failed'
    write('saved_files.json',{'asset':asset,'scene':sc.doc.Path,'backup':sc.sticky[TAG+'_backup'],'small_bridge':'Not modified'})
    print(json.dumps({'asset':asset,'scene':sc.doc.Path},ensure_ascii=False))

if __name__=='__main__': prepare()
