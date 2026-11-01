# -*- coding: utf-8 -*-
"""Simple native circular landmark east of the existing curved steel remnant.

Three exact concentric NURBS annular sectors, capped into the existing roof
and ground, plus two surviving roof ribs (one broken) and one skin remnant.
Existing geometry and material definitions are read-only.
"""
from __future__ import unicode_literals,division
import Rhino,scriptcontext as sc,System,math,os,time,json,io
G=Rhino.Geometry
ROOT='D:/Prism Route/prism-route'
OUT=ROOT+'/docs/landmark_ring_1101'
TAG='landmark_ring_1101'
LAYER='\u5efa\u7b51::\u5de8\u73af\u9057\u6784'
CX,CY,CZ=1418.,595.,104.
START,END=-35.,198.
BANDS=[('Outer_ivory',150.,142.,5.,0.,'PR_Saddle_panel'),
       ('Middle_weathered_metal',142.,138.8,4.7,.15,'PR_Saddle_weathered'),
       ('Inner_graphite',138.8,137.2,4.4,.30,'PR_Saddle_dark')]

def state():return sc.sticky[TAG]
def xyz(p):return [float(p.X),float(p.Y),float(p.Z)]
def write(name,value):
    with io.open(OUT+'/'+name,'w',encoding='utf-8') as f:f.write(json.dumps(value,ensure_ascii=False,indent=2))
def objects():
    e=Rhino.DocObjects.ObjectEnumeratorSettings();e.NormalObjects=True;e.HiddenObjects=True;e.LockedObjects=True
    return [o for o in sc.doc.Objects.GetObjectList(e) if not o.IsDeleted]
def fingerprint():
    opts=Rhino.FileIO.SerializationOptions()
    return {str(o.Id):(int(o.Geometry.DataCRC(0)),o.Attributes.ToJSON(opts)) for o in objects()}
def layer(path):
    idx=sc.doc.Layers.FindByFullPath(path,-1)
    if idx>=0:return idx
    l=Rhino.DocObjects.Layer();l.Name=path.rsplit('::',1)[-1]
    if '::' in path:l.ParentLayerId=sc.doc.Layers[layer(path.rsplit('::',1)[0])].Id
    return sc.doc.Layers.Add(l)
def material(name):
    for i,m in enumerate(sc.doc.Materials):
        if not m.IsDeleted and m.Name==name:return i
    raise Exception('Missing reviewed source material: '+name)
def point(r,a,x=None):
    a=math.radians(a)
    return G.Point3d(CX-2.5 if x is None else x,CY+r*math.cos(a),CZ+r*math.sin(a))
def sector(ro,ri,depth,front_offset=0.,start=START,end=END):
    a=math.radians(start)
    plane=G.Plane(G.Point3d(CX-2.5+front_offset,CY,CZ),G.Vector3d(0,math.cos(a),math.sin(a)),G.Vector3d(0,-math.sin(a),math.cos(a)))
    interval=G.Interval(0,math.radians(end-start))
    outer=G.Arc(G.Circle(plane,ro),interval).ToNurbsCurve()
    inner=G.Arc(G.Circle(plane,ri),interval).ToNurbsCurve();inner.Reverse()
    outline=G.PolyCurve();outline.Append(outer);outline.Append(G.LineCurve(outer.PointAtEnd,inner.PointAtStart))
    outline.Append(inner);outline.Append(G.LineCurve(inner.PointAtEnd,outer.PointAtStart));assert outline.IsClosed
    ex=G.Extrusion.Create(outline,depth,True);assert ex
    result=ex.ToBrep();assert result.IsValid and result.IsSolid
    if result.SolidOrientation==G.BrepSolidOrientation.Inward:result.Flip()
    b=result.GetBoundingBox(True)
    assert abs(b.Min.X-(CX-2.5+front_offset))<.001 and abs(b.Max.X-b.Min.X-depth)<.001
    return result
def mesh_of(geometry):
    if isinstance(geometry,G.Mesh):return geometry.DuplicateMesh()
    m=G.Mesh();p=G.MeshingParameters();p.Tolerance=.015;p.MaximumEdgeLength=4.;p.RefineAngle=.06;p.RefineGrid=True
    for piece in G.Mesh.CreateFromBrep(geometry,p):m.Append(piece)
    m.Faces.ConvertQuadsToTriangles();m.Normals.ComputeNormals();m.Compact();return m
def finish(m):
    m.UnifyNormals();m.Normals.ComputeNormals()
    if G.VolumeMassProperties.Compute(m).Volume<0:m.Flip(True,True,True)
    m.Unweld(math.radians(38),True);m.Normals.ComputeNormals();m.Compact()
    assert m.IsValid and m.IsClosed
    return m
def tube(fn,start,end,radius=.22,count=90):
    m=G.Mesh();last=None;sides=10
    for i in range(count+1):
        t=start+(end-start)*i/count;p=fn(t);axis=fn(t+.00001)-fn(t-.00001);assert axis.Unitize()
        x=G.Vector3d.CrossProduct(axis,G.Vector3d.ZAxis) if last is None else last-axis*G.Vector3d.Multiply(last,axis)
        assert x.Unitize();y=G.Vector3d.CrossProduct(axis,x);y.Unitize();last=x
        for j in range(sides):m.Vertices.Add(p+(x*math.cos(2*math.pi*j/sides)+y*math.sin(2*math.pi*j/sides))*radius)
    for i in range(count):
        for j in range(sides):
            a=i*sides+j;b=i*sides+(j+1)%sides;m.Faces.AddFace(a,b,b+sides,a+sides)
    for j in range(1,sides-1):
        m.Faces.AddFace(0,j+1,j);a=count*sides;m.Faces.AddFace(a,a+j,a+j+1)
    return finish(m)
def bezier(pts,t):
    q=[G.Point3d(p) for p in pts]
    for i in range(3):q=[a+(b-a)*t for a,b in zip(q[:-1],q[1:])]
    return q[0]
def skin(fn):
    m=G.Mesh();nu,nv=40,10;stride=nv+1;count=(nu+1)*stride
    for side in [-1,1]:
        for i in range(nu+1):
            for j in range(nv+1):m.Vertices.Add(fn(i/nu,j/nv)+G.Vector3d(0,0,side*.06))
    for i in range(nu):
        for j in range(nv):
            a=i*stride+j;m.Faces.AddFace(a,a+stride,a+stride+1,a+1);a+=count;m.Faces.AddFace(a,a+1,a+stride+1,a+stride)
    for i in range(nu):
        for j in [0,nv]:
            a=i*stride+j;m.Faces.AddFace(a,a+count,a+stride+count,a+stride)
    for i in [0,nu]:
        for j in range(nv):
            a=i*stride+j;m.Faces.AddFace(a,a+1,a+1+count,a+count)
    return finish(m)
def stage(geo,name,category,mat):
    assert geo.IsValid
    state()['parts'].append((geo,name,category,mat))
def prepare():
    assert sc.doc.Path.replace('\\','/').lower()=='d:/prism route/map/map_current.3dm'
    assert str(sc.doc.ModelUnitSystem)=='Meters'
    assert not any(o.Attributes.GetUserString('feature')==TAG for o in objects()),'Existing ring: revise instead of duplicating'
    assert TAG not in sc.sticky,'Staged ring already exists'
    assert 'landmark_ring_site_meshes_1101' in sc.sticky and 'landmark_ring_steel_mesh_1101' in sc.sticky
    folder='D:/Prism Route/archive/landmark_ring_1101'
    if not os.path.exists(folder):os.makedirs(folder)
    backup=folder+'/map_before_'+time.strftime('%Y%m%d_%H%M%S')+'.3dm'
    options=Rhino.FileIO.FileWriteOptions();options.SuppressDialogBoxes=True
    assert sc.doc.Write3dmFile(backup,options)
    sc.sticky[TAG]=dict(before=fingerprint(),parts=[],objects=[],backup=backup,connections=[])
    return dict(backup=backup,original_objects=len(state()['before']))
def build():
    d=state();assert not d['parts'] and not d['objects']
    for name,ro,ri,depth,offset,mat in BANDS:stage(sector(ro,ri,depth,offset),name,'01_concentric_bands',mat)
    steel=sc.sticky['landmark_ring_steel_mesh_1101'];functions=[]
    for i,(query,a) in enumerate([(G.Point3d(1380,463,78),185.),(G.Point3d(1360,480,79),192.)]):
        anchor=steel.ClosestPoint(query);end=point(146.5,a,CX-2.42)
        p1=anchor+(end-anchor)*.30+G.Vector3d(0,0,1.5)
        p2=anchor+(end-anchor)*.72+G.Vector3d(0,0,1.0)
        pts=[anchor,p1,p2,end]
        fn=lambda t,pts=pts:bezier(pts,t);functions.append(fn)
        if i==0:stage(tube(fn,0,1), 'Surviving_roof_rib','02_connection_remnants','PR_Saddle_weathered')
        else:
            stage(tube(fn,0,.47),'Broken_roof_rib_saddle_end','02_connection_remnants','PR_Saddle_weathered')
            stage(tube(fn,.54,1),'Broken_roof_rib_ring_end','02_connection_remnants','PR_Saddle_weathered')
        d['connections'].append(dict(saddle_anchor=xyz(anchor),ring_anchor=xyz(end),chord_length_m=anchor.DistanceTo(end),broken=i==1))
    def panel(u,v):
        # Only one coherent surviving tongue, not a new intact roof or bridge.
        t=.03+u*(.30+.035*math.sin(math.pi*v))
        a=functions[0](t);b=functions[1](t);p=a+(b-a)*v
        p.Z+=.12+.35*math.sin(math.pi*v)*math.sin(math.pi*u)
        return p
    stage(skin(panel),'Remaining_roof_skin_tongue','03_remaining_skin','PR_Saddle_panel')
    write('parameters.json',dict(feature=TAG,center_native=[CX,CY,CZ],outer_diameter_m=300.,inner_diameter_m=274.4,depth_m=5.,
        circle_plane_normal_native=[1,0,0],display_arc_degrees=[START,END],concentric_bands=[dict(name=n,outer_radius=ro,inner_radius=ri,depth=depth,front_recess=offset,material=mat) for n,ro,ri,depth,offset,mat in BANDS],
        buried_arc='The non-visible lower arc is omitted below the roof/earth, to avoid introducing structure into the existing interior.',
        relation='East (+X) of island_saddle_1030; source steel anchors sampled from its real visible mesh; shared materials unchanged',
        connections=d['connections'],backup=d['backup']))
    return dict(staged_objects=len(d['parts']),diameter=300.,top_z=254.,connections=d['connections'])
def check_site():
    d=state();site=sc.sticky['landmark_ring_site_meshes_1101'];ring=G.Mesh()
    for geo,name,cat,mat in d['parts']:
        if cat=='01_concentric_bands':ring.Append(mesh_of(geo))
    ring.Normals.ComputeNormals();ring.Compact();d['ring_mesh']=ring
    # Use exact ring-plane distance for actual bridge vertices in the crossing slab.
    road=site['art_bridge'];near=[]
    for p in road.Vertices:
        if CX-2.5-.05<=p.X<=CX+2.5+.05:
            near.append([float(p.X),float(p.Y),float(p.Z)])
    # Mesh intersection checks the full deck rather than its control hull.
    crossings=G.Intersect.Intersection.MeshMeshFast(ring,road)
    assert not crossings or len(crossings)==0,'Ring crosses the existing pedestrian deck'
    # Foot caps must be buried across every radial layer and extrusion depth.
    feet=[]
    for a in [START,END]:
        for r in [137.2,138.8,142.,150.]:
            for x in [CX-2.5,CX+2.5]:
                p=point(r,a,x);heights=[]
                for key in ['roof','hill','bay_ground','low_ground']:
                    t=G.Intersect.Intersection.MeshRay(site[key],G.Ray3d(G.Point3d(p.X,p.Y,300),-G.Vector3d.ZAxis))
                    if t>=0:heights.append(300.-t)
                assert heights,'Missing actual support at foot'
                h=max(heights);assert p.Z<h+.03,'Exposed floating cap at '+str(xyz(p))
                feet.append(dict(point=xyz(p),surface_z=h,embed_depth_m=h-p.Z))
    clear=[]
    for y in range(650,731):
        t=G.Intersect.Intersection.MeshRay(road,G.Ray3d(G.Point3d(CX,y,300),-G.Vector3d.ZAxis))
        if t<0:continue
        z=300.-t;distance=math.hypot(y-CY,z-CZ);clear.append(137.2-distance)
    assert clear and min(clear)>5.,'Insufficient ring opening clearance'
    # The few connection remnants are on the roof side, away from the road.
    for geo,name,cat,mat in d['parts']:
        if cat=='01_concentric_bands':continue
        hits=G.Intersect.Intersection.MeshMeshFast(mesh_of(geo),road)
        assert not hits or len(hits)==0,'Connection crosses the pedestrian deck'
    report=dict(existing_pedestrian_deck_intersections=0,opening_radial_margin_m=min(clear),bridge_deck_samples=len(clear),
        buried_cap_samples=feet,source_steel_anchors=d['connections'])
    d['site_report']=report;write('site_check.json',report)
    return dict(deck_intersections=0,minimum_radial_margin_m=min(clear),buried_cap_samples=len(feet))
def commit():
    d=state();assert d.get('site_report') and not d['objects']
    rec=sc.doc.BeginUndoRecord('Add simple landmark ring beside curved truss');sc.doc.Views.RedrawEnabled=False
    try:
        for geo,name,cat,mat in d['parts']:
            at=Rhino.DocObjects.ObjectAttributes();at.Name='PR_LandmarkRing_'+name;at.LayerIndex=layer(LAYER+'::'+cat)
            at.MaterialIndex=material(mat);at.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
            at.ObjectColor=sc.doc.Materials[at.MaterialIndex].DiffuseColor
            at.SetUserString('feature',TAG);at.SetUserString('category',cat);at.SetUserString('generator','tools/rhino_landmark_ring_1101.py')
            at.SetUserString('related_feature','island_saddle_1030')
            sid=sc.doc.Objects.Add(geo,at);assert sid!=System.Guid.Empty;d['objects'].append(str(sid))
    except:
        for sid in d['objects']:sc.doc.Objects.Delete(System.Guid(sid),True)
        d['objects']=[];raise
    finally:sc.doc.EndUndoRecord(rec);sc.doc.Views.RedrawEnabled=True;sc.doc.Views.Redraw()
    return dict(added_objects=len(d['objects']))
def audit():
    d=state();current=fingerprint();changed=[sid for sid,record in d['before'].items() if current.get(sid)!=record]
    assert not changed,'Unrelated source model changed'
    owned=[o for o in objects() if o.Attributes.GetUserString('feature')==TAG]
    assert set(str(o.Id) for o in owned)==set(d['objects'])
    b=G.BoundingBox.Empty
    for o in owned:
        assert o.Geometry.IsValid
        assert o.Geometry.IsClosed if isinstance(o.Geometry,G.Mesh) else o.Geometry.IsSolid
        b.Union(o.Geometry.GetBoundingBox(True))
    report=dict(feature=TAG,objects=len(owned),object_ids=d['objects'],unchanged_original_objects=len(d['before']),unrelated_changes=changed,
        bounds_native=[xyz(b.Min),xyz(b.Max)],outer_diameter_m=300.,top_native_z_m=254.,ring_plane_x=CX,
        footprint='Eastern side of the existing saddle: source truss is unchanged',site_checks=d['site_report'],backup=d['backup'])
    write('model_report.json',report)
    return dict(objects=len(owned),original_objects_unchanged=len(d['before']),bounds=report['bounds_native'])
def camera(which):
    views={'site':((900,1100,600),(1370,540,110),38.),
        'detail':((1070,280,205),(1404,555,124),37.),
        'spawn':((639.526,-377.87,34.8),(1417.27,250.71,34.8),38.)}
    eye,target,lens=views[which];vp=sc.doc.Views.ActiveView.ActiveViewport
    vp.SetCameraLocations(G.Point3d(*target),G.Point3d(*eye));vp.Camera35mmLensLength=lens
    sc.doc.Objects.UnselectAll();sc.doc.Views.Redraw()
def capture(which):
    camera(which);vc=Rhino.Display.ViewCapture();vc.Width=1700;vc.Height=1050
    vc.DrawAxes=False;vc.DrawGrid=False;vc.DrawGridAxes=False;vc.ScaleScreenItems=False
    bitmap=vc.CaptureToBitmap(sc.doc.Views.ActiveView);assert bitmap
    bitmap.Save(OUT+'/model_'+which+'.png',System.Drawing.Imaging.ImageFormat.Png);bitmap.Dispose()
    return OUT+'/model_'+which+'.png'
def save():
    audit();d=state();path=OUT+'/landmark_ring.3dm';assert not os.path.exists(path)
    options=Rhino.FileIO.FileWriteOptions();options.SuppressDialogBoxes=True;options.WriteSelectedObjectsOnly=True
    sc.doc.Objects.UnselectAll()
    try:
        for sid in d['objects']:sc.doc.Objects.Select(System.Guid(sid))
        assert sc.doc.Write3dmFile(path,options)
    finally:sc.doc.Objects.UnselectAll()
    for which in ['site','detail','spawn']:
        camera(which);sc.doc.NamedViews.Add('LandmarkRing_'+which+'_1101',sc.doc.Views.ActiveView.ActiveViewport.Id)
    camera('detail')
    assert Rhino.RhinoApp.RunScript('_-Save _Enter',False) and not sc.doc.Modified
    saved=Rhino.FileIO.File3dm.Read(sc.doc.Path);assert saved
    assert set(str(o.Id) for o in saved.Objects if o.Attributes.GetUserString('feature')==TAG)==set(d['objects'])
    component=Rhino.FileIO.File3dm.Read(path);assert component and len(list(component.Objects))==len(d['objects'])
    return dict(main=sc.doc.Path,component=path,objects=len(d['objects']),saved_readback_verified=True)
