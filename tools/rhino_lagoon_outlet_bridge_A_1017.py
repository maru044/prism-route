# -*- coding: utf-8 -*-
"""Single-span outlet bridge, controlled by three longitudinal side rails.

Rhino 8 recipe. Original roads are retained, hidden only after cropped copies
and a continuous replacement approach are ready. No intermediate water pier.
"""
from __future__ import division, unicode_literals
import Rhino, scriptcontext as sc, System, math, os, io, json, datetime
from System.Drawing import Color
G=Rhino.Geometry
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.join(ROOT,'docs','concepts','lagoon_bridges_2026-10-17','small_bridge_A')
TAG='lagoon_outlet_bridge_A_1017_v01'
LAYER='1017_泻湖出口小桥_A_v01'
CIDS=['cdd81362-826e-4133-b37d-94bf806717f9','2937ea84-2de9-4456-a5ac-8c233052abf0']
ROADS=['bdacfd36-f6ba-4012-90e8-e6c58454a409','573e16fb-6179-4e81-803e-67340b8f1f0d']
APPROACH=90.0
def xyz(p):return [float(p.X),float(p.Y),float(p.Z)]
def obj(g):return sc.doc.Objects.FindId(System.Guid(g))
def smooth(t):t=max(0,min(1,t));return t*t*(3-2*t)
def write(name,data):
    if not os.path.isdir(OUT):os.makedirs(OUT)
    with io.open(os.path.join(OUT,name),'w',encoding='utf-8')as f:f.write(unicode(json.dumps(data,ensure_ascii=False,indent=2,default=str)))
def route():
    a=obj(CIDS[0]).Geometry;b=obj(CIDS[1]).Geometry
    p=a.PointAtEnd;q=b.PointAtStart;length=p.DistanceTo(q)
    gap=G.NurbsCurve.Create(False,3,[p,p+a.TangentAtEnd*(length/3),q-b.TangentAtStart*(length/3),q])
    ok,ta=a.LengthParameter(a.GetLength()-APPROACH);ok,tb=b.LengthParameter(APPROACH)
    parta=a.Trim(ta,a.Domain.T1);partb=b.Trim(b.Domain.T0,tb)
    c=G.Curve.JoinCurves([parta,gap,partb],.001)[0]
    cuts=[];retained=[]
    for rid,p in zip(ROADS,[parta.PointAtStart,partb.PointAtEnd]):
        brep=obj(rid).Geometry;face=brep.Faces[1];ok,u,v=face.ClosestPoint(p)
        assert ok and face.IsSurface,'Road face must be an untrimmed surface'
        cross=[face.PointAt(face.Domain(0).T0,v),face.PointAt(face.Domain(0).T1,v)]
        pieces=[f.DuplicateFace(False)for f in brep.Faces if f.FaceIndex!=1]
        pieces.append(face.UnderlyingSurface().Trim(face.Domain(0),G.Interval(v,face.Domain(1).T1)).ToBrep())
        joined=G.Brep.JoinBreps(pieces,.001)
        assert joined and all(x.IsValid for x in joined)
        retained.append(list(joined));cuts.append({'road':rid,'face':1,'v':v,'cross':cross,'point':p})
    es=Rhino.DocObjects.ObjectEnumeratorSettings();es.HiddenObjects=True;es.LockedObjects=True;es.NormalObjects=True
    state={'route':c,'gap':gap,'cuts':cuts,'retained':retained,'length':c.GetLength(),
           'mid':APPROACH+gap.GetLength()/2,'radius':gap.GetLength()/2,
           'source_crc':{str(o.Id):int(o.Geometry.DataCRC(0))for o in sc.doc.Objects.GetObjectList(es)}}
    sc.sticky[TAG]=state
    write('site.json',{'gap_m':gap.GetLength(),'total_length_m':c.GetLength(),'approaches_m':APPROACH,
                       'bank_points':[xyz(a.PointAtEnd),xyz(b.PointAtStart)],'road_cuts':[{'road':x['road'],'v':x['v'],'point':xyz(x['point'])}for x in cuts]})
    print('Outlet span %.3fm; approaches %.1fm each'%(gap.GetLength(),APPROACH))
def frame(s):
    d=sc.sticky[TAG];c=d['route'];ok,t=c.LengthParameter(max(0,min(d['length'],s)))
    p=c.PointAt(t);a=c.TangentAt(t);a.Z=0;a.Unitize();n=G.Vector3d(-a.Y,a.X,0)
    return p,a,n
def top(s):
    d=sc.sticky[TAG];p,a,n=frame(s)
    return p.Z-.075+4.8*math.sin(math.pi*s/d['length'])**2
def bottom(s):
    d=sc.sticky[TAG];x=(s-d['mid'])/(d['radius']+21.7)
    # C2 return into the buried springings, avoiding the ellipse's infinite
    # slope where it used to meet a constant-height approach underside.
    return -2.5+7.0*max(0,1-x*x)**3 if abs(x)<1 else -2.5
def point(s,y,z):
    p,a,n=frame(s);p=p+n*y;p.Z=z;return p
def profile(s):
    d=sc.sticky[TAG];t=top(s);b=bottom(s)
    shoulder=math.exp(-((abs(s-d['mid'])-d['radius'])/18)**2)
    end=smooth(min(s,d['length']-s)/25)
    # Three side rails: upper edge / outer swept fold / intrados. The fold
    # spreads near the springings, and relaxes toward the approach tips.
    upper=12.4+.5*end
    fold=13.5+2.7*shoulder+1.1*end
    foldz=t*.54+b*.46
    half=[(0,t),(5,t),(10,t),(11,t),(11.5,t),
          (upper,t+.14*end),(upper+.65,t+.38*end),
          (fold-.3,t-.25),(fold,foldz+.35),(fold-.25,foldz-.1),
          (12.9,b+.12),(10,b),(5,b),(0,b)]
    # Counterclockwise perimeter, shared continuously across all stations.
    yz=half+[(-y,z)for y,z in reversed(half[1:-1])]
    return [point(s,y,z)for y,z in yz],[(upper,t+.14*end),(fold,foldz+.35),(12.9,b+.12)]
def build():
    d=sc.sticky[TAG];length=d['length'];mid=d['mid'];rad=d['radius']
    # The C2 intrados needs no dense knot cluster at its springings. Keep
    # a modest section count rather than baking many little surface patches.
    stations=set([length*i/48 for i in range(49)])
    stations.update([mid,APPROACH,APPROACH+2*rad,mid-rad-21.7,mid+rad+21.7])
    stations=sorted(s for s in stations if 0<=s<=length)
    sections=[];rails=[[],[],[]]
    for s in stations:
        pts,control=profile(s);curve=G.NurbsCurve.Create(True,3,pts)
        assert curve.IsClosed and curve.IsValid
        sections.append(curve)
        for i,(y,z)in enumerate(control):rails[i].append(point(s,y,z))
    loft=G.Brep.CreateFromLoft(sections,G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Normal,False)
    assert loft and len(loft)==1,'Loft failed'
    body=loft[0].CapPlanarHoles(.001)
    assert body and body.IsValid and body.IsSolid,'Bridge body is not a valid solid'
    if body.SolidOrientation==G.BrepSolidOrientation.Inward:body.Flip()
    mp=G.MeshingParameters();mp.MaximumEdgeLength=1.6;mp.MinimumEdgeLength=.025
    mp.Tolerance=.012;mp.RefineGrid=True;mp.JaggedSeams=False
    limit=G.Mesh()
    for m in G.Mesh.CreateFromBrep(body,mp):limit.Append(m)
    limit.Vertices.CombineIdentical(True,True);limit.Weld(math.pi);limit.UnifyNormals();limit.Normals.ComputeNormals();limit.Compact()
    assert limit.IsValid and limit.IsClosed and len(limit.SplitDisjointPieces())==1
    d.update({'body':body,'limit':limit,'sections':sections,'rails':[G.Curve.CreateInterpolatedCurve(x,3)for x in rails],'stations':stations})
    write('topology.json',{'valid':True,'solid':True,'brep_faces':body.Faces.Count,'loft_sections':len(sections),'render_faces':int(limit.Faces.Count),'three_side_rails':['upper_edge','outer_fold','intrados']})
    print('Closed NURBS body prepared: %d sections, %d faces'%(len(sections),body.Faces.Count))
def finish():
    d=sc.sticky[TAG];length=d['length'];n=int(math.ceil(length/.8));samples=[length*i/n for i in range(n+1)]
    # Road follows the analytic smooth crown, with the same grade and position
    # as the two existing road cuts at its tips. The native loft is checked
    # against this actual road surface afterwards.
    def roadpoint(s,y,dz=0):
        p=point(s,y,top(s)+.075+dz)
        for idx,dist in [(0,s),(1,length-s)]:
            if dist>=8:continue
            cut=d['cuts'][idx];s0=0 if idx==0 else length
            c0,c1=cut['cross'];base,a,normal=frame(s0)
            if G.Vector3d.Multiply(c1-c0,normal)<0:c0,c1=c1,c0
            exact=c0+(c1-c0)*((y+10)/20);old=point(s0,y,frame(s0)[0].Z)
            correction=exact-old;p+=correction*(1-smooth(dist/8))
        return p
    def strip(ys,dz=0):
        ys=sorted(ys);m=G.Mesh();ny=len(ys)
        for s in samples:
            for y in ys:m.Vertices.Add(roadpoint(s,y,dz))
        for i in range(n):
            for j in range(ny-1):
                k=i*ny+j;m.Faces.AddFace(k,k+ny,k+ny+1,k+1)
        m.Normals.ComputeNormals();m.Compact();assert m.IsValid
        return m
    d['road']=strip([-10,-7,-3.5,0,3.5,7,10]);d['lines']=[strip([-.065,.065],.022),strip([-9.6,-9.47],.022),strip([9.47,9.6],.022)]
    rails=[];posts=[]
    # Restrained low guardrails, matching the long bridge material family.
    for sign in [-1,1]:
        for zoff,radius in [(1.2,.085),(.65,.045)]:
            m=G.Mesh();sides=12
            for s in samples:
                p=roadpoint(s,sign*11.7,zoff);normal=frame(s)[2]
                for j in range(sides):
                    a=2*math.pi*j/sides;m.Vertices.Add(p+normal*(radius*math.cos(a))+G.Vector3d.ZAxis*(radius*math.sin(a)))
            for i in range(n):
                for j in range(sides):
                    a=i*sides+j;b=i*sides+(j+1)%sides;m.Faces.AddFace(a,b,b+sides,a+sides)
            for i in [0,n]:
                center=m.Vertices.Add(roadpoint(samples[i],sign*11.7,zoff))
                for j in range(sides):
                    a=i*sides+j;b=i*sides+(j+1)%sides
                    m.Faces.AddFace(center,b,a)if i==0 else m.Faces.AddFace(center,a,b)
            m.UnifyNormals();m.Normals.ComputeNormals();m.Compact();rails.append(m)
        m=G.Mesh();postn=int(math.ceil(length/4.8))
        for i in range(postn+1):
            s=length*i/postn;p=roadpoint(s,sign*11.7,.18)
            cyl=G.Cylinder(G.Circle(G.Plane(p,G.Vector3d.ZAxis),.065),1.02)
            m.Append(G.Mesh.CreateFromCylinder(cyl,1,10,True,True))
        m.Normals.ComputeNormals();m.Compact();posts.append(m)
    d.update({'samples':samples,'roadpoint':roadpoint,'handrails':rails,'posts':posts})
    print('Deck, markings and low rails prepared')
def layer(child,visible=True):
    i=sc.doc.Layers.FindByFullPath(LAYER,-1)
    if i<0:
        l=Rhino.DocObjects.Layer();l.Name=LAYER;i=sc.doc.Layers.Add(l)
    parent=i;i=sc.doc.Layers.FindByFullPath(LAYER+'::'+child,-1)
    if i<0:
        l=Rhino.DocObjects.Layer();l.Name=child;l.ParentLayerId=sc.doc.Layers[parent].Id;l.IsVisible=visible;i=sc.doc.Layers.Add(l)
    return i
def mat(name,rgb,shine,reflect):
    m=Rhino.DocObjects.Material();m.Name=name;m.DiffuseColor=Color.FromArgb(*rgb);m.Shine=shine;m.Reflectivity=reflect
    return sc.doc.Materials.Add(m)
def attributes(name,child,mi):
    a=Rhino.DocObjects.ObjectAttributes();a.Name=name;a.LayerIndex=layer(child)
    a.MaterialIndex=mi;a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
    a.SetUserString('recipe',TAG);return a
def backup():
    d=sc.sticky[TAG]
    if 'backup'in d:return
    path=os.path.join(os.path.dirname(ROOT),'map','map_1016_before_outlet_bridge_A_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'.3dm')
    opt=Rhino.FileIO.FileWriteOptions();opt.UpdateDocumentPath=False;opt.IncludeRenderMeshes=False;opt.SuppressAllInput=True;opt.SuppressDialogBoxes=True
    assert sc.doc.Write3dmFile(path,opt);d['backup']=path;print(path)
def publish():
    d=sc.sticky[TAG];assert not d.get('objects'),'Already published'
    backup();rows=[];rec=sc.doc.BeginUndoRecord('泻湖出口小桥 A 三曲线连续桥腹')
    try:
        white=mat('出口小桥_暖白半光建筑涂层',[239,235,226],90,.22)
        asphalt=mat('出口小桥_石墨沥青',[55,59,62],12,.025)
        metal=mat('出口小桥_浅灰金属扶手',[177,184,182],100,.5)
        paint=mat('出口小桥_车道标线',[237,234,220],30,.05)
        def add(g,name,child,mi):
            a=attributes(name,child,mi)
            if isinstance(g,G.Brep):oid=sc.doc.Objects.AddBrep(g,a)
            elif isinstance(g,G.Mesh):oid=sc.doc.Objects.AddMesh(g,a)
            else:oid=sc.doc.Objects.AddCurve(g,a)
            assert oid!=System.Guid.Empty
            rows.append({'id':str(oid),'name':name,'layer':child})
        add(d['body'],'出口小桥_连续展肩与单跨拱腹_NURBS','01_连续桥体_NURBS',white)
        add(d['road'],'出口小桥_桥面与两岸接坡','02_桥面与接坡',asphalt)
        for i,g in enumerate(d['lines']):add(g,'出口小桥_标线_%d'%i,'03_标线',paint)
        for i,g in enumerate(d['handrails']+d['posts']):add(g,'出口小桥_低护栏_%d'%i,'04_低护栏',metal)
        # The old roads remain in their original layers and retain their GUIDs.
        # Only cropped copies render, so the raised approaches have no old
        # asphalt surface underneath them in the same footprint.
        for i,pieces in enumerate(d['retained']):
            old=obj(ROADS[i]);mi=old.Attributes.MaterialIndex
            for j,g in enumerate(pieces):
                a=old.Attributes.Duplicate();a.Name='保留岸路_%d_%d_仅裁去接坡段'%(i,j)
                a.LayerIndex=layer('05_保留岸路_裁去接坡');a.SetUserString('recipe',TAG)
                oid=sc.doc.Objects.AddBrep(g,a);assert oid!=System.Guid.Empty
                rows.append({'id':str(oid),'name':a.Name,'layer':'05_保留岸路_裁去接坡'})
        for rid in ROADS:assert sc.doc.Objects.Hide(System.Guid(rid),True)
        for i,g in enumerate(d['rails']):add(g,['01_桥面边缘控制线','02_侧腹转折控制线','03_下缘拱线'][i],'90_三条侧面控制线_隐藏',white)
        add(d['route'],'出口小桥_原岸路延续三维路线','90_三条侧面控制线_隐藏',white)
        li=layer('90_三条侧面控制线_隐藏');l=sc.doc.Layers[li];l.IsVisible=False;sc.doc.Layers.Modify(l,li,True)
        d['objects']=rows;sc.doc.Objects.UnselectAll()
    finally:sc.doc.EndUndoRecord(rec);sc.doc.Views.Redraw()
    write('objects.json',rows);print('Published %d objects'%len(rows))
def verify():
    d=sc.sticky[TAG];fail=[]
    changed=[x for x,crc in d['source_crc'].items()if obj(x)is None or int(obj(x).Geometry.DataCRC(0))!=crc]
    if changed:fail.append('Original geometry changed')
    if not d['body'].IsValid or not d['body'].IsSolid:fail.append('Body not a valid solid')
    values=[];misses=0
    for i in range(len(d['samples'])-1):
        s=(d['samples'][i]+d['samples'][i+1])/2
        for y in [-9,0,9]:
            p=point(s,y,100);ray=G.Ray3d(p,-G.Vector3d.ZAxis)
            a=G.Intersect.Intersection.MeshRay(d['limit'],ray);b=G.Intersect.Intersection.MeshRay(d['road'],ray)
            if a>=0 and b>=0:values.append(a-b)
            else:misses+=1
    if not values or min(values)<=0:fail.append('Road intersects bridge body')
    if misses:fail.append('Deck sample misses')
    ends=[]
    for i,s in enumerate([0,d['length']]):
        cut=d['cuts'][i];a,b=cut['cross'];errs=[]
        first=0 if i==0 else d['road'].Vertices.Count-7
        for j in [0,3,6]:
            p=G.Point3d(d['road'].Vertices[first+j])
            errs.append(min(p.DistanceTo(a),p.DistanceTo(b))if j!=3 else p.DistanceTo((a+b)/2))
        ends.append(max(errs))
    if max(ends)>.002:fail.append('Road endpoint mismatch')
    d['road'].FaceNormals.ComputeFaceNormals()
    p=point(d['mid'],0,0);ray=G.Ray3d(p,G.Vector3d.ZAxis);clearance=G.Intersect.Intersection.MeshRay(d['limit'],ray)
    if clearance<3.5:fail.append('Central water opening too low')
    report={'failures':fail,'sources_unchanged':not changed,'source_object_count':len(d['source_crc']),
            'solid_nurbs':bool(d['body'].IsSolid),'connected_components':len(d['limit'].SplitDisjointPieces()),
            'gap_m':2*d['radius'],'approach_length_each_m':APPROACH,'asset_length_m':d['length'],
            'road_endpoint_error_m':ends,'road_samples':len(values),'road_sample_misses':misses,
            'minimum_road_separation_m':min(values),'maximum_road_separation_m':max(values),
            'minimum_road_normal_z':min(float(n.Z)for n in d['road'].FaceNormals),
            'central_water_clearance_m':clearance,'max_grade_percent':max(abs((top(s+.05)-top(s-.05))/.1)*100 for s in d['samples'][1:-1]),
            'preserved_hidden_roads':ROADS,'limitations':'Visual asset, not yet game collision/driving validated. All original geometry retained, two source roads hidden and replaced by cropped copies.'}
    write('verification.json',report);print(json.dumps(report));return report
def view(kind):
    d=sc.sticky[TAG];vp=sc.doc.Views.ActiveView.ActiveViewport;mid=d['mid'];p,a,n=frame(mid)
    vp.ChangeToPerspectiveProjection(True,50)
    if kind=='overview':
        vp.SetCameraLocations(point(mid,0,0),p-n*195+a*80+G.Vector3d(0,0,85));vp.ZoomBoundingBox(d['body'].GetBoundingBox(True))
    elif kind=='arch':
        vp.SetCameraLocations(point(mid,0,3),p-n*80+a*65+G.Vector3d(0,0,23))
        vp.ZoomBoundingBox(G.BoundingBox([point(s,y,z)for s in [mid-45,mid+45]for y in [-17,17]for z in [-2,7]]))
    elif kind=='both':
        target=G.Point3d(900,1400,0);vp.SetCameraLocations(target,G.Point3d(200,2200,650))
        vp.ZoomBoundingBox(G.BoundingBox(G.Point3d(520,1180,-5),G.Point3d(1200,1760,30)))
    sc.doc.Views.Redraw()
def capture(name):
    cap=Rhino.Display.ViewCapture();cap.Width=1800;cap.Height=1100;cap.DrawGrid=False;cap.DrawAxes=False;cap.DrawGridAxes=False
    bmp=cap.CaptureToBitmap(sc.doc.Views.ActiveView);path=os.path.join(OUT,name+'.png')
    bmp.Save(path,System.Drawing.Imaging.ImageFormat.Png);bmp.Dispose();print(path)
def save():
    d=sc.sticky[TAG];r=verify();assert not r['failures'],'Verification failed'
    file=Rhino.FileIO.File3dm();file.Settings.ModelUnitSystem=sc.doc.ModelUnitSystem;lm={};mm={}
    for row in d['objects']:
        if row['layer']=='05_保留岸路_裁去接坡':continue
        o=obj(row['id']);a=o.Attributes.Duplicate();old=a.LayerIndex
        if old not in lm:
            l=Rhino.DocObjects.Layer();l.Id=System.Guid.NewGuid();l.Name=sc.doc.Layers[old].Name;l.IsVisible=sc.doc.Layers[old].IsVisible
            file.AllLayers.Add(l);lm[old]=next(x.Index for x in file.AllLayers if x.Id==l.Id)
        a.LayerIndex=lm[old];mi=a.MaterialIndex
        if mi>=0:
            if mi not in mm:
                m=Rhino.DocObjects.Material(sc.doc.Materials[mi]);m.Id=System.Guid.NewGuid();file.AllMaterials.Add(m)
                mm[mi]=next(x.Index for x in file.AllMaterials if x.Id==m.Id)
            a.MaterialIndex=mm[mi]
        file.Objects.Add(o.Geometry,a)
    file.Views.Add(Rhino.DocObjects.ViewInfo(sc.doc.Views.ActiveView.ActiveViewport))
    path=os.path.join(os.path.dirname(ROOT),'map','lagoon_outlet_bridge_A_1017.3dm')
    assert file.Write(path,8);file.Dispose();assert Rhino.RhinoApp.RunScript('_Save',False)
    write('saved_files.json',{'asset':path,'scene':'D:/Prism Route/map/map_1016.3dm','backup':d['backup']})
    print(path)
