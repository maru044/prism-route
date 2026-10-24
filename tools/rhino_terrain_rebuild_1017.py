# -*- coding: utf-8 -*-
"""Staged terrain/road reconstruction; never edits or deletes original geometry."""
from __future__ import division, unicode_literals
import Rhino,scriptcontext as sc,System,io,json,os,math,datetime
G=Rhino.Geometry
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.join(ROOT,'docs','concepts','terrain_rebuild_1017')
TAG='terrain_road_rebuild_1017_v01'
GREEN=['1435beff-efcc-4af8-9837-27269aca4586','012ab31c-3bd7-4f32-8676-9592c584ca4c','e8d79f0e-6908-48e3-af35-3d131f7da558']
WALLS=['27172e67-243a-4398-9933-89de8ecae12d','fac1e44f-0311-414e-ae69-18e143ff155a','fd3b1833-5662-4283-888f-36ac476092f6']
BASE=['9ed1bc59-e9fa-4024-8095-564d74c4c87c','92714fcc-8762-4105-8ee9-d6796c31dc9f','c1228167-d010-44ad-8775-757dd4984934','e7a0e133-f284-4cd4-8796-349bb8638efc','9c6e4638-fa65-4d06-b84d-21feb0ab3b1b','7f48c0e6-3eff-429b-b3b0-92d2ba679c0f','0bec2de6-c09c-4d63-86b6-3c6a48d6f3bb','1d532d53-1e77-48a8-97d9-8eff168923b9','adac435c-fe23-4fb1-98d3-e151d881ee4c']
FEATURE='9c6e4638-fa65-4d06-b84d-21feb0ab3b1b'
ISLE=['88eb76d2-2c5c-4c70-b64a-dd922afa1433','eda8bdb1-ff67-4448-a07f-e78e6914d209','0c51b890-631a-4633-b1b4-1682b8736500','580b55d4-797c-49fa-ba1d-f2c9d74e4d03']
ISLE_WALL=['73e5d619-0b3e-4b57-ba79-be508a583cba','886652a9-6613-4f5e-b1fc-01aa8b5259d7','2068dd45-fc33-4cb3-b561-4cbfe1b7330a','4df36f45-d898-40ce-8a5d-7802a8711ae2']
LAYER='1017_统一基底与道路_v01'
def obj(x):return sc.doc.Objects.FindId(System.Guid(x))
def xyz(p):return [float(p.X),float(p.Y),float(p.Z)]
def write(name,data):
    if not os.path.isdir(OUT):os.makedirs(OUT)
    with io.open(os.path.join(OUT,name),'w',encoding='utf-8')as f:f.write(unicode(json.dumps(data,ensure_ascii=False,separators=(',',':'),default=str)))
def meshrow(m):
    m.Faces.ConvertQuadsToTriangles()
    return {'v':[xyz(p)for p in m.Vertices],'f':[[int(f.A),int(f.B),int(f.C)]for f in m.Faces]}
def sample(c,spacing=2):
    n=max(4,int(math.ceil(c.GetLength()/spacing)))
    return [xyz(c.PointAtNormalizedLength(i/n))for i in range(n+1)]
def allobjects():
    es=Rhino.DocObjects.ObjectEnumeratorSettings();es.HiddenObjects=True;es.LockedObjects=True;es.NormalObjects=True
    return list(sc.doc.Objects.GetObjectList(es))
def effective(o):
    if o.IsHidden:return False
    l=sc.doc.Layers[o.Attributes.LayerIndex]
    while l:
        if not l.IsVisible:return False
        if l.ParentLayerId==System.Guid.Empty:break
        l=sc.doc.Layers.FindId(l.ParentLayerId)
    return True
def inspect():
    if TAG in sc.sticky:raise RuntimeError('State already exists; do not reset published work')
    sources=[];loops=[];reference=G.Mesh()
    mp=G.MeshingParameters();mp.MaximumEdgeLength=14;mp.MinimumEdgeLength=.3;mp.Tolerance=.15;mp.RefineGrid=True;mp.JaggedSeams=False
    extra='d01b8d98-9f3d-46e7-8737-7b60ad7a5657'
    for sid in GREEN+BASE+ISLE+[extra]:
        o=obj(sid);b=o.Geometry;faces=[]
        if sid in BASE or sid==extra:
            floors=[f for f in b.Faces if f.NormalAt(f.Domain(0).Mid,f.Domain(1).Mid).Z<-.5]
            cs=[l.To3dCurve()for floor in floors for l in floor.Loops if l.LoopType==G.BrepLoopType.Outer]
        else:cs=[l.To3dCurve()for l in b.Faces[0].Loops if l.LoopType==G.BrepLoopType.Outer]
        for c in cs:
            c.Transform(G.Transform.PlanarProjection(G.Plane.WorldXY))
            if c.ClosedCurveOrientation(G.Plane.WorldXY)==G.CurveOrientation.Clockwise:c.Reverse()
            loops.append(c)
        for f in b.Faces:
            if f.NormalAt(f.Domain(0).Mid,f.Domain(1).Mid).Z<.2:continue
            m=G.Mesh()
            for part in G.Mesh.CreateFromBrep(f.DuplicateFace(False),mp)or[]:m.Append(part)
            reference.Append(m)
        sources.append({'id':sid,'name':o.Name,'loops':[sample(c,4)for c in cs]})
    reference.Append(obj('63868f64-fba3-4988-aebd-1bb2ed0ffca3').Geometry.DuplicateMesh())
    # Two original 35m masses consist mainly of side walls; reconstruct their
    # missing cap coverage from their original closed plan outlines.
    for sid in ['9cb3a43e-9748-4c6b-a69d-83a23c90c034','0ad18ac2-7a98-4505-9fa1-dbad0e0d6439']:
        c=obj(sid).Geometry.DuplicateCurve();c.Transform(G.Transform.PlanarProjection(G.Plane.WorldXY))
        if c.ClosedCurveOrientation(G.Plane.WorldXY)==G.CurveOrientation.Clockwise:c.Reverse()
        loops.append(c);sources.append({'id':sid,'name':'35m_island_plan','loops':[sample(c,4)]})
        c35=c.DuplicateCurve();c35.Transform(G.Transform.Translation(0,0,35))
        for b in G.Brep.CreatePlanarBreps(c35,.01):
            for m in G.Mesh.CreateFromBrep(b,mp):reference.Append(m)
    # Robust polygon union runs outside Rhino, avoiding a long native Boolean
    # on nearly coincident old patch boundaries. No document geometry changes.
    union=loops
    polys=[]
    for c in union:
        area=G.AreaMassProperties.Compute(c).Area
        if area<1:continue
        polys.append({'points':sample(c,2),'area':area,'orientation':str(c.ClosedCurveOrientation(G.Plane.WorldXY))})
    roads=[];native={}
    specs=[('east_outer','cdd81362-826e-4133-b37d-94bf806717f9',0,-90),
           ('west_outer','2937ea84-2de9-4456-a5ac-8c233052abf0',90,None),
           ('east_inner','00028edd-af0b-445e-aa13-c900d6695ec0',0,None),
           ('west_inner','1250e9ac-b574-4747-9f94-e0cabd4019bb',0,None),
           ('upper_link','50067c9d-905e-4d45-ad89-67928551d05f',0,None)]
    for name,cid,lo,hi in specs:
        c=obj(cid).Geometry.DuplicateCurve();length=c.GetLength();hi=length if hi is None else length+hi
        if name=='upper_link':
            p=obj('a1b27c6d-d860-43c1-924d-31881bf38425').Geometry.PointAtStart
            ok,t=c.ClosestPoint(G.Point3d(p.X,p.Y,0));hi=c.GetLength(G.Interval(c.Domain.T0,t))
        ok,a=c.LengthParameter(lo);ok,b=c.LengthParameter(hi);c=c.Trim(a,b)
        roads.append({'name':name,'source':cid,'points':sample(c,1.5),'length':c.GetLength()});native[name]=c
    fixed=[]
    for name,cid in [('artistic','a1b27c6d-d860-43c1-924d-31881bf38425')]:
        c=obj(cid).Geometry;fixed.append({'name':name,'points':sample(c,2)})
    # Fixed bridge deck positions and grades come from actual mesh vertices.
    for sid in ['63c66d8c-cc9e-4399-b804-6042fb2e4a40','c34009e4-d6a5-420c-b0f9-f19d0f78cfc5']:
        m=obj(sid).Geometry;fixed.append({'name':sid,'mesh':meshrow(m.DuplicateMesh())})
    crossings=[]
    for ia,a in enumerate(roads):
        ca=native[a['name']].DuplicateCurve();ca.Transform(G.Transform.PlanarProjection(G.Plane.WorldXY))
        for b in roads[ia+1:]:
            cb=native[b['name']].DuplicateCurve();cb.Transform(G.Transform.PlanarProjection(G.Plane.WorldXY))
            for hit in G.Intersect.Intersection.CurveCurve(ca,cb,.02,.02):
                if not hit.IsPoint:continue
                sa=ca.GetLength(G.Interval(ca.Domain.T0,hit.ParameterA));sb=cb.GetLength(G.Interval(cb.Domain.T0,hit.ParameterB))
                za=native[a['name']].PointAt(hit.ParameterA).Z;zb=native[b['name']].PointAt(hit.ParameterB).Z
                crossings.append({'a':a['name'],'b':b['name'],'sa':sa,'sb':sb,'za':float(za),'zb':float(zb),'point':xyz(hit.PointA)})
    d={'curves':union,'reference':reference,'native_roads':native,'source_crc':{str(o.Id):int(o.Geometry.DataCRC(0))for o in allobjects()},'source_visibility':{str(o.Id):not o.IsHidden for o in allobjects()}}
    sc.sticky[TAG]=d
    write('input.json',{'footprints':polys,'sources':sources,'roads':roads,'fixed':fixed,'crossings':crossings,'reference':meshrow(reference.DuplicateMesh())})
    print(json.dumps({'footprints':[(round(x['area'],1),x['orientation'])for x in polys],'reference_vertices':reference.Vertices.Count,'crossings':crossings},default=str))

def closed_mesh(row,depth=None):
    """Shared indices at every rim; reversed top triangulation forms bottom."""
    vertices=row['v'];faces=row['f'];n=len(vertices);m=G.Mesh()
    for x,y,z in vertices:m.Vertices.Add(x,y,z)
    for x,y,z in vertices:m.Vertices.Add(x,y,-9 if depth is None else z-depth)
    edges={}
    for a,b,c in faces:
        # Triangle exports positive XY orientation.
        m.Faces.AddFace(a,b,c);m.Faces.AddFace(c+n,b+n,a+n)
        for x,y in [(a,b),(b,c),(c,a)]:
            key=(min(x,y),max(x,y))
            if key in edges:edges[key]=None
            else:edges[key]=(x,y)
    for edge in edges.values():
        if edge:
            a,b=edge;m.Faces.AddFace(b,a,a+n,b+n)
    m.UnifyNormals();m.Unweld(.65,True);m.Normals.ComputeNormals();m.Compact()
    assert m.IsValid and m.IsClosed,'Invalid terrain/road solid: '+row['name']
    return m

def update():
    d=sc.sticky[TAG];old=list(d['objects']);prepare()
    # Replace only the objects owned by this recipe. Original CAD objects
    # are never replaced or deleted.
    native=d['terrain']+d['roads']+d['bodies']
    assert len(native)==len(old),'Component count changed; use republish_geometry'
    for row,g in zip(old,native):assert sc.doc.Objects.Replace(System.Guid(row['id']),g)
    sc.doc.Views.Redraw()

def republish_geometry():
    d=sc.sticky[TAG];old=list(d['objects']);prepare();rows=[]
    # Own output only: preserve attributes/materials while topology changes.
    groups=[('01_连续基础地形',d['terrain']),('02_同层合并道路',d['roads']),('03_开放短跨与展肩',d['bodies'])]
    rec=sc.doc.BeginUndoRecord('更新重建地形_清除重复表皮')
    try:
        for child,geometries in groups:
            template=next(obj(r['id']).Attributes.Duplicate()for r in old if r['layer']==child)
            for i,g in enumerate(geometries):
                a=template.Duplicate();a.Name=child+'_%02d'%i;a.ObjectId=System.Guid.Empty
                oid=sc.doc.Objects.AddMesh(g,a)if isinstance(g,G.Mesh)else sc.doc.Objects.AddBrep(g,a)
                assert oid!=System.Guid.Empty;rows.append({'id':str(oid),'layer':child,'name':a.Name})
        for r in old:assert sc.doc.Objects.Delete(System.Guid(r['id']),True)
        d['objects']=rows
        d.pop('markings',None)
        sid='81aa365d-5fb7-430a-afc2-819c6030473b'
        if obj(sid)and not obj(sid).IsHidden:
            sc.doc.Objects.Hide(System.Guid(sid),True);d['hidden'].append(sid)
    finally:sc.doc.EndUndoRecord(rec);sc.doc.Views.Redraw()
    write('publication.json',{'backup':d['backup'],'objects':rows,'hidden_original_objects':d['hidden'],'hidden_source_layers':d['hidden_layers']})
    print('Updated %d own generated objects'%len(rows))

def prepare():
    d=sc.sticky[TAG]
    with io.open(os.path.join(OUT,'rebuilt_geometry.json'),'r',encoding='utf8')as f:data=json.load(f)
    terrain=[closed_mesh(x)for x in data['terrain']]
    roads=[closed_mesh(x,.18)for x in data['roads']]
    ground=G.Mesh()
    for row in data['terrain']:
        m=G.Mesh()
        for p in row['v']:m.Vertices.Add(*p)
        for f in row['f']:m.Faces.AddFace(*f)
        ground.Append(m)
    def groundz(p):
        ray=G.Ray3d(G.Point3d(p.X,p.Y,150),-G.Vector3d.ZAxis)
        hit=G.Intersect.Intersection.MeshRay(ground,ray)
        return 150-hit if hit>=0 else -4
    bodies=[]
    roadgroups=[G.Mesh(),G.Mesh()]
    for row,m in zip(data['roads'],roads):roadgroups[row['group']].Append(m)
    for sid in ['63c66d8c-cc9e-4399-b804-6042fb2e4a40','c34009e4-d6a5-420c-b0f9-f19d0f78cfc5']:roadgroups[1].Append(obj(sid).Geometry)
    for m in G.Mesh.CreateFromBrep(obj('0808d32c-6ebc-4105-9258-a0f755ac2752').Geometry,G.MeshingParameters.Default):roadgroups[0].Append(m)
    for spec in data['bridges']:
        points=[G.Point3d(*p)for p in spec['points']];sections=[]
        group=0 if spec['road']in ['east_outer','west_outer','upper_link']else 1
        za=min(points[0].Z-4,groundz(points[0])-4)
        zb=min(points[-1].Z-4,groundz(points[-1])-4)
        for i,p in enumerate(points):
            t=i/(len(points)-1);tangent=points[min(i+1,len(points)-1)]-points[max(0,i-1)];tangent.Z=0;tangent.Unitize();normal=G.Vector3d(-tangent.Y,tangent.X,0)
            top=p.Z-.24
            # Open arch intrados, continuous flared haunches at both banks.
            base=top-2.3+(za-(top-2.3))*(1-t)**4+(zb-(top-2.3))*t**4
            width=13.4+2.0*(2*t-1)**4
            half=[(0,top),(5,top),(9,top),(10.7,top),(11.8,top+.06),
                  (12.8,top+.12),(width,top-1),(width+.25,(top+base)/2),
                  (width-.2,base+.5),(11.5,base),(6,base),(0,base)]
            yz=half+[(-y,z)for y,z in reversed(half[1:-1])]
            cross=[]
            for y in [-9,-4.5,0,4.5,9]:
                ray=G.Ray3d(G.Point3d(p.X+normal.X*y,p.Y+normal.Y*y,150),-G.Vector3d.ZAxis)
                h=G.Intersect.Intersection.MeshRay(roadgroups[group],ray)
                cross.append(150-h if h>=0 else p.Z)
            def correction(y):
                yy=max(-9,min(9,y));k=min(3,int((yy+9)/4.5));w=(yy-(-9+k*4.5))/4.5
                return cross[k]*(1-w)+cross[k+1]*w-p.Z
            profile=[G.Point3d(p.X+normal.X*y,p.Y+normal.Y*y,z+correction(y)*max(0,min(1,(z-base)/(top-base))))for y,z in yz]
            sections.append(G.NurbsCurve.Create(True,3,profile))
        loft=G.Brep.CreateFromLoft(sections,G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Normal,False)
        assert loft and len(loft)==1
        b=loft[0].CapPlanarHoles(.001);assert b and b.IsValid and b.IsSolid
        if b.SolidOrientation==G.BrepSolidOrientation.Inward:b.Flip()
        bodies.append(b)
    d.update({'data':data,'terrain':terrain,'roads':roads,'bodies':bodies,'ground':ground})
    write('prepared.json',{'terrain':[{'valid':bool(m.IsValid),'closed':bool(m.IsClosed),'vertices':int(m.Vertices.Count),'faces':int(m.Faces.Count)}for m in terrain],
                           'roads':[{'valid':bool(m.IsValid),'closed':bool(m.IsClosed),'faces':int(m.Faces.Count)}for m in roads],
                           'spans':[{'solid':bool(b.IsSolid),'faces':int(b.Faces.Count)}for b in bodies]})
    print('Prepared %d closed land components, %d road meshes, %d solid arch bodies'%(len(terrain),len(roads),len(bodies)))

def layer(child):
    i=sc.doc.Layers.FindByFullPath(LAYER,-1)
    if i<0:
        l=Rhino.DocObjects.Layer();l.Name=LAYER;i=sc.doc.Layers.Add(l)
    parent=i;i=sc.doc.Layers.FindByFullPath(LAYER+'::'+child,-1)
    if i<0:
        l=Rhino.DocObjects.Layer();l.Name=child;l.ParentLayerId=sc.doc.Layers[parent].Id;i=sc.doc.Layers.Add(l)
    return i

def publish():
    from System.Drawing import Color
    d=sc.sticky[TAG];assert not d.get('objects'),'Already published'
    backup=os.path.join(os.path.dirname(ROOT),'map','map_1016_before_terrain_rebuild_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'.3dm')
    opt=Rhino.FileIO.FileWriteOptions();opt.UpdateDocumentPath=False;opt.IncludeRenderMeshes=False;opt.SuppressAllInput=True;opt.SuppressDialogBoxes=True
    assert sc.doc.Write3dmFile(backup,opt);d['backup']=backup
    rec=sc.doc.BeginUndoRecord('重建连续地形与道路_保留全部原件');rows=[];hidden=[];layers=[]
    try:
        def material(name,rgb,shine,reflect):
            m=Rhino.DocObjects.Material();m.Name=name;m.DiffuseColor=Color.FromArgb(*rgb);m.Shine=shine;m.Reflectivity=reflect
            return sc.doc.Materials.Add(m)
        white=material('1017_基底暖白建筑涂层',[235,231,220],80,.18)
        asphalt=material('1017_连续路网_石墨沥青',[54,59,62],10,.02)
        def add(g,name,child,mi):
            a=Rhino.DocObjects.ObjectAttributes();a.Name=name;a.LayerIndex=layer(child);a.MaterialIndex=mi
            a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject;a.SetUserString('recipe',TAG)
            a.ObjectColor=sc.doc.Materials[mi].DiffuseColor;a.ColorSource=Rhino.DocObjects.ObjectColorSource.ColorFromObject
            oid=sc.doc.Objects.AddMesh(g,a)if isinstance(g,G.Mesh)else sc.doc.Objects.AddBrep(g,a)
            assert oid!=System.Guid.Empty;rows.append({'id':str(oid),'name':name,'layer':child})
        for i,m in enumerate(d['terrain']):add(m,'连续基础地形_%02d'%i,'01_连续基础地形',white)
        for i,m in enumerate(d['roads']):add(m,'连续道路_%s'%d['data']['roads'][i]['name'],'02_同层合并道路',asphalt)
        for i,b in enumerate(d['bodies']):add(b,'开放式跨越_%s_%02d'%(d['data']['bridges'][i]['road'],i),'03_开放短跨与展肩',white)
        superseded=GREEN+WALLS+BASE+ISLE+ISLE_WALL+[
            'd01b8d98-9f3d-46e7-8737-7b60ad7a5657','63868f64-fba3-4988-aebd-1bb2ed0ffca3',
            '577d868b-7597-4058-83f8-4b630606b305','bbea2185-f5e3-4821-a363-63f19f463bc4',
            'aa0a6f09-e81f-4449-995c-d0dc494f9dd2','40073513-6a9f-4fd8-b5ec-9439b6ec8178',
            '88e167e1-7ea9-4444-87d1-9c1f3a925aa5','edcb244c-3a23-4a97-b31a-639b7d2296aa','bd3ff7b1-e651-4cc0-add3-48e0155cfb81',
            '47800a9c-ca72-4dc5-8203-d6d5d91d29a9','59dd95cc-d6f3-4378-ae67-d76fcbdf6ac8','5182ccac-8e3b-4322-8826-976a9254271b',
            '60f020cf-5e56-4bbd-b67f-9059a1ab401c','b62a4e53-2495-4477-a10c-dff489b98855']
        for sid in superseded:
            o=obj(sid)
            if o and not o.IsHidden:
                assert sc.doc.Objects.Hide(o.Id,True);hidden.append(sid)
        for l in list(sc.doc.Layers):
            if l.IsDeleted or not l.IsVisible:continue
            if '隐藏'in l.Name or ('崖岸_内退曲面_B方案_v02' in l.FullPath and l.Name=='03_种植区域'):
                layers.append(l.FullPath);l.IsVisible=False;sc.doc.Layers.Modify(l,l.Index,True)
        sc.doc.Objects.UnselectAll();d.update({'objects':rows,'hidden':hidden,'hidden_layers':layers})
    finally:sc.doc.EndUndoRecord(rec);sc.doc.Views.Redraw()
    write('publication.json',{'backup':backup,'objects':rows,'hidden_original_objects':hidden,'hidden_source_layers':layers})
    print('Published %d objects; preserved %d hidden originals'%(len(rows),len(hidden)))

def check_roads():
    d=sc.sticky[TAG];results={};G=Rhino.Geometry
    # Sample the actual triangulated road top and terrain, including both
    # lane edges. This catches interpolation overshoot between recipe points.
    for name,points in d['data']['paths'].items():
        group=0 if name in ['east_outer','west_outer','upper_link']else 1
        network=G.Mesh()
        for row in d['data']['roads']:
            if row['group']!=group:continue
            m=G.Mesh()
            for p in row['v']:m.Vertices.Add(*p)
            for f in row['f']:m.Faces.AddFace(*f)
            network.Append(m)
        gaps=[];bad=[];samples=[]
        for i in range(1,len(points)-1,4):
            p=G.Point3d(*points[i]);t=G.Point3d(*points[i+1])-G.Point3d(*points[i-1]);t.Z=0;t.Unitize();n=G.Vector3d(-t.Y,t.X,0)
            for y in [-9,0,9]:
                q=p+n*y;ray=G.Ray3d(G.Point3d(q.X,q.Y,150),-G.Vector3d.ZAxis)
                road=G.Intersect.Intersection.MeshRay(network,ray)
                if road<0:continue # A retained bridge owns this footprint.
                q.Z=150-road;samples.append(q)
                land=G.Intersect.Intersection.MeshRay(d['ground'],ray)
                if land>=0:
                    gap=land-road;gaps.append(gap)
                    if gap<.05:bad.append({'xyz':xyz(q),'gap':gap})
        results[name]={'samples':len(samples),'minimum_ground_gap':min(gaps)if gaps else None,'ground_conflicts':bad}
    d['roadcheck']=results;write('road_ground_check.json',results)
    print(json.dumps({k:{'samples':v['samples'],'min_gap':v['minimum_ground_gap'],'bad':len(v['ground_conflicts'])}for k,v in results.items()}))

def prepare_obstacles():
    d=sc.sticky[TAG];own=set(r['id']for r in d['objects']);ob=[]
    mp=G.MeshingParameters();mp.MaximumEdgeLength=6;mp.MinimumEdgeLength=.1;mp.Tolerance=.06;mp.RefineGrid=True
    for o in allobjects():
        if not effective(o)or str(o.Id)in own:continue
        g=o.Geometry;l=sc.doc.Layers[o.Attributes.LayerIndex].FullPath
        if '崖岸'not in l and l!='1017':continue
        if not isinstance(g,(G.Brep,G.Mesh,G.SubD)):continue
        m=G.Mesh()
        if isinstance(g,G.Brep):
            for part in G.Mesh.CreateFromBrep(g,mp):m.Append(part)
        elif isinstance(g,G.Mesh):m=g.DuplicateMesh()
        elif isinstance(g,G.SubD):
            b=g.ToBrep()
            for part in G.Mesh.CreateFromBrep(b,mp):m.Append(part)
        ob.append({'id':str(o.Id),'name':o.Name,'mesh':m,'bbox':m.GetBoundingBox(True)})
    d['obstacles']=ob;print('Prepared %d preserved architectural obstacles'%len(ob))

def check_obstacles(name):
    d=sc.sticky[TAG];points=d['data']['paths'][name];bad={}
    group=0 if name in ['east_outer','west_outer','upper_link']else 1;network=G.Mesh()
    for row,m in zip(d['data']['roads'],d['roads']):
        if row['group']==group:network.Append(m)
    for i in range(1,len(points)-1,5):
        p=G.Point3d(*points[i]);t=G.Point3d(*points[i+1])-G.Point3d(*points[i-1]);t.Z=0;t.Unitize();n=G.Vector3d(-t.Y,t.X,0)
        for y in [-8,0,8]:
            q=p+n*y
            hit=G.Intersect.Intersection.MeshRay(network,G.Ray3d(G.Point3d(q.X,q.Y,150),-G.Vector3d.ZAxis))
            if hit<0:continue # Existing bridge owns this area after clipping.
            q.Z=150-hit
            for ob in d['obstacles']:
                box=ob['bbox']
                if not(box.Min.X<=q.X<=box.Max.X and box.Min.Y<=q.Y<=box.Max.Y):continue
                if q.Z+4.5<box.Min.Z or q.Z+.1>box.Max.Z:continue
                line=G.Line(G.Point3d(q.X,q.Y,q.Z+.15),G.Point3d(q.X,q.Y,q.Z+4.5))
                hit=G.Intersect.Intersection.MeshLine(ob['mesh'],line)
                inside=ob['mesh'].IsClosed and ob['mesh'].IsPointInside(G.Point3d(q.X,q.Y,q.Z+2.3),.01,False)
                if hit or inside:
                    if ob['id']not in bad:bad[ob['id']]={'name':ob['name'],'samples':[]}
                    bad[ob['id']]['samples'].append(xyz(q))
    d.setdefault('obstaclechecks',{})[name]=bad;write('obstacle_check.json',d['obstaclechecks'])
    print(json.dumps({k:{'name':v['name'],'count':len(v['samples']),'first':v['samples'][0]}for k,v in bad.items()},ensure_ascii=False))

def final_checks():
    d=sc.sticky[TAG];net=G.Mesh()
    for m in d['roads']:net.Append(m)
    endtests=[]
    for sid in ['63c66d8c-cc9e-4399-b804-6042fb2e4a40','c34009e4-d6a5-420c-b0f9-f19d0f78cfc5']:
        mesh=obj(sid).Geometry
        for k in [0,mesh.Vertices.Count-7]:
            errors=[]
            for j in [0,1,3,5,6]:
                p=G.Point3d(mesh.Vertices[k+j]);q=net.ClosestMeshPoint(p,2)
                errors.append(p.DistanceTo(q.Point)if q else 99)
            endtests.append({'bridge':sid,'row':k,'max_position_error_m':max(errors)})
    f=obj('0808d32c-6ebc-4105-9258-a0f755ac2752').Geometry.Faces[0]
    for t in [f.Domain(1).T0,f.Domain(1).T1]:
        errors=[]
        for u in [0,.25,.5,.75,1]:
            p=f.PointAt(f.Domain(0).ParameterAt(u),t);q=net.ClosestMeshPoint(p,2)
            errors.append(p.DistanceTo(q.Point)if q else 99)
        endtests.append({'bridge':'artistic','parameter':t,'max_position_error_m':max(errors)})
    mp=G.MeshingParameters();mp.MaximumEdgeLength=2;mp.Tolerance=.025;mp.RefineGrid=True
    spanchecks=[]
    for spec,body in zip(d['data']['bridges'],d['bodies']):
        limit=G.Mesh()
        for m in G.Mesh.CreateFromBrep(body,mp):limit.Append(m)
        gaps=[]
        for i in range(1,len(spec['points'])-1):
            p=G.Point3d(*spec['points'][i]);a=G.Point3d(*spec['points'][i+1])-G.Point3d(*spec['points'][i-1]);a.Z=0;a.Unitize();n=G.Vector3d(-a.Y,a.X,0)
            for y in [-9,0,9]:
                q=p+n*y;ray=G.Ray3d(G.Point3d(q.X,q.Y,150),-G.Vector3d.ZAxis)
                road=G.Intersect.Intersection.MeshRay(net,ray);support=G.Intersect.Intersection.MeshRay(limit,ray)
                if road>=0 and support>=0:gaps.append(support-road)
        spanchecks.append({'road':spec['road'],'solid':bool(body.IsSolid),'minimum_road_body_gap_m':min(gaps)if gaps else None})
    changed=[sid for sid,crc in d['source_crc'].items()if obj(sid)is None or int(obj(sid).Geometry.DataCRC(0))!=crc]
    result={'original_geometry_unchanged':not changed,'changed_original_ids':changed,
            'terrain_objects':len(d['terrain']),'road_objects':len(d['roads']),'arch_objects':len(d['bodies']),
            'all_new_land_and_road_meshes_closed':all(m.IsValid and m.IsClosed for m in d['terrain']+d['roads']),
            'bridge_head_tests':endtests,'span_road_clearances':spanchecks,
            'road_ground':{k:{'samples':v['samples'],'minimum_gap_m':v['minimum_ground_gap'],'conflicts':len(v['ground_conflicts'])}for k,v in d['roadcheck'].items()},
            'obstacle_conflicts':{k:{sid:len(v['samples'])for sid,v in found.items()}for k,found in d['obstaclechecks'].items()},
            'limitations':'Rhino geometry and sampled clearance checks only; game collider and driving test not performed.'}
    write('verification.json',result);d['verification']=result;print(json.dumps(result));return result

def finishes():
    from System.Drawing import Color
    d=sc.sticky[TAG];assert not d.get('markings'),'Already finished'
    # A quieter finish on the continuous ground; architectural bridge shells
    # keep their own warm white specular coating.
    for r in d['objects']:
        if r['layer']!='01_连续基础地形':continue
        o=obj(r['id']);a=o.Attributes.Duplicate();m=sc.doc.Materials[a.MaterialIndex]
        m.DiffuseColor=Color.FromArgb(224,222,209);m.Shine=25;m.Reflectivity=.04;m.CommitChanges()
        a.ObjectColor=m.DiffuseColor;sc.doc.Objects.ModifyAttributes(o.Id,a,True)
    networks=[G.Mesh(),G.Mesh()]
    for row,m in zip(d['data']['roads'],d['roads']):networks[row['group']].Append(m)
    meshes=[G.Mesh(),G.Mesh()]
    nodes=[G.Point3d(578.1209,212.3699,60.356),G.Point3d(1245.7333,1057.2355,.85)]
    for name,pts in d['data']['paths'].items():
        group=0 if name in ['east_outer','west_outer','upper_link']else 1;distance=0
        frames=[]
        for i,p in enumerate(pts):
            q=G.Point3d(*p);a=G.Point3d(*pts[min(i+1,len(pts)-1)])-G.Point3d(*pts[max(0,i-1)]);a.Z=0;a.Unitize()
            if i:distance+=q.DistanceTo(G.Point3d(*pts[i-1]))
            frames.append((q,G.Vector3d(-a.Y,a.X,0),distance))
        for i in range(len(frames)-1):
            q,n,s=frames[i]
            if any(q.DistanceTo(node)<26 for node in nodes):continue
            for y in [-9.5,0,9.5]:
                if y==0 and int(s/7)%2:continue
                vv=[]
                for k,yy in [(i,y-.075),(i+1,y-.075),(i+1,y+.075),(i,y+.075)]:
                    p,normal,station=frames[k];p=p+normal*yy
                    ray=G.Ray3d(G.Point3d(p.X,p.Y,150),-G.Vector3d.ZAxis)
                    hit=G.Intersect.Intersection.MeshRay(networks[group],ray)
                    if hit<0:break
                    p.Z=150-hit+.025;vv.append(p)
                if len(vv)!=4:continue
                m=meshes[group];a=m.Vertices.Count
                for p in vv:m.Vertices.Add(p)
                m.Faces.AddFace(a,a+1,a+2,a+3)
    m=Rhino.DocObjects.Material();m.Name='1017_路网暖白标线';m.DiffuseColor=Color.FromArgb(235,231,215);m.Shine=10;mi=sc.doc.Materials.Add(m)
    rows=[]
    for i,g in enumerate(meshes):
        g.UnifyNormals();g.Normals.ComputeNormals();g.Compact();assert g.IsValid
        a=Rhino.DocObjects.ObjectAttributes();a.Name='连续路网标线_%d'%i;a.LayerIndex=layer('04_路面标线');a.MaterialIndex=mi
        a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject;a.SetUserString('recipe',TAG)
        oid=sc.doc.Objects.AddMesh(g,a);assert oid!=System.Guid.Empty
        rows.append({'id':str(oid),'name':a.Name,'layer':'04_路面标线'})
    d['markings']=rows;d['objects'].extend(rows)
    write('publication.json',{'backup':d['backup'],'objects':d['objects'],'hidden_original_objects':d['hidden'],'hidden_source_layers':d['hidden_layers']})
    sc.doc.Views.Redraw();print('Finished terrain material and road markings')

def view(kind):
    vp=sc.doc.Views.ActiveView.ActiveViewport
    vp.ChangeToPerspectiveProjection(True,45)
    vp.DisplayMode=next(x for x in Rhino.Display.DisplayModeDescription.GetDisplayModes()if x.EnglishName=='Rendered')
    if kind=='overview':vp.SetCameraLocations(G.Point3d(1180,970,10),G.Point3d(3260,2900,2100))
    elif kind=='east_crossing':vp.SetCameraLocations(G.Point3d(1680,320,35),G.Point3d(2090,600,245))
    elif kind=='junction':vp.SetCameraLocations(G.Point3d(1215,1070,10),G.Point3d(1440,1430,175))
    elif kind=='west':vp.SetCameraLocations(G.Point3d(480,850,25),G.Point3d(90,1160,280))
    sc.doc.Views.Redraw()

def capture(name):
    cap=Rhino.Display.ViewCapture();cap.Width=1800;cap.Height=1200;cap.DrawGrid=False;cap.DrawAxes=False;cap.DrawGridAxes=False
    bmp=cap.CaptureToBitmap(sc.doc.Views.ActiveView);path=os.path.join(OUT,name+'.png')
    bmp.Save(path,System.Drawing.Imaging.ImageFormat.Png);bmp.Dispose();print(path)

if __name__=='__main__':inspect()
