# -*- coding: utf-8 -*-
"""Native NURBS massing: separately designed lobes, curved walls and terraces."""
from __future__ import division,unicode_literals
import Rhino,scriptcontext as sc,System,io,os,json,math
G=Rhino.Geometry
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK=os.path.join(ROOT,'.map_1012_build')
STATE=os.path.join(WORK,'cliff_b_solid_nurbs_state.json')
TAG='prism_cliff_b_solid_nurbs_v01'


def read(path):
    with io.open(path,encoding='utf-8') as f:return json.load(f)


def write(path,data):
    with io.open(path,'w',encoding='utf-8') as f:f.write(json.dumps(data,ensure_ascii=False,indent=2,separators=(',',': ')))


def cfg():return read(os.path.join(ROOT,'tools','cliff_b_solid_nurbs_v01.json'))


def helpers():
    path=os.path.join(ROOT,'tools','rhino_cliff_b_shell_v02.py')
    n={'__file__':path,'__name__':'nurbs_helpers'}
    exec(compile('\n'.join(io.open(path,encoding='utf-8').read().splitlines()[1:]),path,'exec'),n)
    n['TAG']=TAG;n['cfg']=cfg
    return n


def add(geometry,name,group,state,attrs=None):
    if isinstance(geometry,G.Brep) and group!='11_浅水示意' and not geometry.IsSolid:raise RuntimeError('Open mass '+name)
    oid=helpers()['add'](geometry,name,group,state,attrs)
    o=sc.doc.Objects.FindId(oid);a=o.Attributes.Duplicate()
    a.SetUserString('description','Native NURBS architectural mass / independent lobe design')
    sc.doc.Objects.ModifyAttributes(o,a,True)
    return oid


def save(path=None):
    path=path or os.path.join(os.path.dirname(ROOT),'map','map_cliffB_solid_nurbs_v01.3dm')
    opts=Rhino.FileIO.FileWriteOptions();opts.UpdateDocumentPath=False;opts.IncludeRenderMeshes=False
    opts.SuppressAllInput=True;opts.SuppressDialogBoxes=True
    if not sc.doc.Write3dmFile(path,opts):raise RuntimeError('Cannot save')
    return path


def source_input():
    p=os.path.join(WORK,'cliff_b_solid_side_input.json')
    if not os.path.exists(p):p=os.path.join(ROOT,'assets','world','cliff_b_solid_nurbs_v01_source','source_input.json')
    return read(p)


def source_rows():return source_input()['rows']


def source_state():
    p=os.path.join(WORK,'cliff_b_shell_v03_state.json')
    if not os.path.exists(p):p=os.path.join(ROOT,'assets','world','cliff_b_shell_v03_source','generation_state.json')
    return read(p)


def smooth(t):
    t=max(0,min(1,t));return t*t*(3-2*t)


def sample(index):
    rows=source_rows();n=len(rows);index=max(0,min(n-1.00001,index))
    i=int(index);u=index-i
    r=[rows[i][j]*(1-u)+rows[(i+1)%n][j]*u for j in range(5)]
    size=math.hypot(r[2],r[3]);r[2]/=size;r[3]/=size
    return r


def loop(points,count=None):
    c=G.Curve.CreateInterpolatedCurve(list(points)+[points[0]],3,G.CurveKnotStyle.ChordPeriodic)
    if c is None:raise RuntimeError('Cannot interpolate loop')
    if count:c=c.Rebuild(count,3,True)
    hits=G.Intersect.Intersection.CurveSelf(c,.01)
    if hits and hits.Count:raise RuntimeError('Profile self-intersects')
    return c


def begin(state):
    if any(o.Attributes.GetUserString('recipe')==TAG for o in sc.doc.Objects):raise RuntimeError('Already generated')
    backup=os.path.join(os.path.dirname(ROOT),'map','map_before_cliffB_solid_nurbs_v01.3dm')
    if not os.path.exists(backup):save(backup)
    state['backup']=backup;state['config']=cfg()
    old=source_state()
    for r in old['objects']:
        if r['group'] in ['01_实体核心','02_顶部厚壳','12_顶部建筑']:continue
        o=sc.doc.Objects.FindId(System.Guid(r['id']))
        add(o.Geometry.Duplicate(),o.Name,r['group'],state,o.Attributes)
    rows=source_rows();points=[]
    for i in range(0,len(rows),4):
        r=rows[i];a=rows[(i-2)%len(rows)];b=rows[(i+2)%len(rows)]
        distance=math.hypot(b[0]-a[0],b[1]-a[1]);turn=math.hypot(b[2]-a[2],b[3]-a[3])
        radius=distance/max(turn,1e-8)
        setback=min(cfg()['backing_setback_m'],radius*.55)*smooth((r[4]-65)/65)
        points.append(G.Point3d(r[0]-r[2]*setback,r[1]-r[3]*setback,0))
    boundary=loop(points,192)
    core=G.Extrusion.Create(boundary,57,True).ToBrep()
    add(core,'B_NURBS_退后实体内核','01_退后内核',state)
    state['backing_id']=state['objects'][-1]['id']
    state['backing_length']=boundary.GetLength()
    state['pod_metrics']=[]
    print(json.dumps({'backing_solid':core.IsSolid,'objects':len(state['objects'])}))


def pod_profile(spec,depth,zlevel,shape):
    start=134+(spec['center']-spec['span']/2)*452
    finish=134+(spec['center']+spec['span']/2)*452
    outer=[];inner=[]
    for i in range(25):
        u=i/24;r=sample(start+(finish-start)*u)
        envelope=math.sin(math.pi*u)**.70
        outward=-depth*.38*(1-envelope)+(spec['outer']+shape*spec['bulge'])*envelope
        # Pointed tapered ends broaden into a usable architectural platform.
        rear=-depth*(.70+.30*envelope)
        outer.append(G.Point3d(r[0]+r[2]*outward,r[1]+r[3]*outward,0))
        inner.append(G.Point3d(r[0]+r[2]*rear,r[1]+r[3]*rear,0))
    points=outer+list(reversed(inner))
    cx=sum(p.X for p in points)/len(points);cy=sum(p.Y for p in points)/len(points)
    if shape==2:
        for p in points:p.X=cx+(p.X-cx)*.978;p.Y=cy+(p.Y-cy)*.978
    for p in points:
        slope=spec['slope_x']*(p.X-cx)+spec['slope_y']*(p.Y-cy)
        p.Z=zlevel+slope*(0 if zlevel==0 else min(1,zlevel/spec['height']))
    return loop(points,cfg()['profile_points'])


def pod(state,index):
    spec=cfg()['pods'][index];depth=spec['depth'];profiles=None
    for trial in range(8):
        try:
            profiles=[pod_profile(spec,depth,0,0),pod_profile(spec,depth,spec['height']*.52,1),
                      pod_profile(spec,depth,spec['height']-cfg()['bevel_height_m'],0),
                      pod_profile(spec,depth,spec['height'],2)]
            break
        except RuntimeError:
            depth*=.80
    if profiles is None:raise RuntimeError('No simple pod footprint')
    wall=G.Brep.CreateFromLoft(profiles[:3],G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Normal,False)
    bevel=G.Brep.CreateFromLoft(profiles[2:],G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Straight,False)
    caps=list(G.Brep.CreatePlanarBreps(profiles[0],.01) or [])+list(G.Brep.CreatePlanarBreps(profiles[-1],.01) or [])
    joined=G.Brep.JoinBreps(list(wall or [])+list(bevel or [])+caps,.01)
    if not joined or len(joined)!=1 or not joined[0].IsSolid:raise RuntimeError('Pod does not close')
    g=joined[0]
    if g.SolidOrientation==G.BrepSolidOrientation.Inward:g.Flip()
    for edge in g.Edges:
        hits=G.Intersect.Intersection.CurveSelf(edge,.01)
        if hits and hits.Count:raise RuntimeError('Pod edge twists')
    add(g,'B_NURBS_%02d_%s'%(index,spec['name']),'02_独立曲面台地',state)
    state['pod_metrics'].append({'index':index,'name':spec['name'],'depth_used':depth,'height':spec['height'],
                                 'faces':g.Faces.Count,'solid':g.IsSolid,'valid':g.IsValid,'edge_self_events':0})
    print(json.dumps(state['pod_metrics'][-1],ensure_ascii=False))


def roof(state):
    helpers_v1=helpers()['recipe']();original,_=helpers_v1['curves']()
    backing=sc.doc.Objects.FindId(System.Guid(state['backing_id'])).Geometry
    boundary=min([e for e in backing.Edges if e.IsClosed],key=lambda e:e.GetBoundingBox(True).Min.Z)
    road=helpers_v1['source_object']('road_id').Geometry.Edges[1].DuplicateCurve()
    road.Transform(G.Transform.PlanarProjection(G.Plane.WorldXY))
    points=[]
    for i in range(320):
        p=original.PointAtNormalizedLength(i/320);ok,t=road.ClosestPoint(p)
        weight=smooth((p.DistanceTo(road.PointAt(t))-70)/75)
        ok,u=boundary.ClosestPoint(p);q=boundary.PointAt(u)
        tangent=original.TangentAt(original.NormalizedLengthParameter(i/320)[1]);tangent.Z=0;tangent.Unitize()
        p=G.Point3d(p.X*(1-weight)+q.X*weight+tangent.Y*.6*weight,
                    p.Y*(1-weight)+q.Y*weight-tangent.X*.6*weight,0)
        points.append(p)
    outline=loop(points,192)
    profiles=[]
    for inset,z in [(0,57),(0,59),(-3.8,63)]:
        c=outline.DuplicateCurve() if inset==0 else list(outline.Offset(G.Plane.WorldXY,inset,.01,G.CurveOffsetCornerStyle.Sharp))[0]
        c=c.Rebuild(192,3,True);c.Transform(G.Transform.Translation(0,0,z));profiles.append(c)
    parts=[]
    for a,b in zip(profiles,profiles[1:]):parts.extend(G.Brep.CreateFromLoft([a,b],G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Straight,False))
    parts.extend(G.Brep.CreatePlanarBreps(profiles[0],.01));parts.extend(G.Brep.CreatePlanarBreps(profiles[-1],.01))
    joined=G.Brep.JoinBreps(parts,.01)
    if not joined or len(joined)!=1 or not joined[0].IsSolid:raise RuntimeError('Roof not closed')
    add(joined[0],'B_NURBS_随内核退台的斜切屋盖','03_斜切屋盖',state)
    params=helpers_v1['read_config']();cx,cy=params['pavilion_center_xy']
    a,b=[60*r for r in params['pavilion_radii_ratio']]
    curves=[G.Ellipse(G.Plane(G.Point3d(cx,cy,z),G.Vector3d.ZAxis),a*scale,b*scale).ToNurbsCurve()
            for scale,z in [(1.0,63.0),(.96,67.0),(.66,72.6)]]
    parts=[]
    for a,b in zip(curves,curves[1:]):parts.extend(G.Brep.CreateFromLoft([a,b],G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Straight,False))
    parts.extend(G.Brep.CreatePlanarBreps(curves[0],.01));parts.extend(G.Brep.CreatePlanarBreps(curves[-1],.01))
    pavilion=G.Brep.JoinBreps(parts,.01)[0]
    if pavilion.SolidOrientation==G.BrepSolidOrientation.Inward:pavilion.Flip()
    add(pavilion,'B_NURBS_顶部低矮建筑_斜肩平顶','12_斜切顶部建筑',state)


def show(state):
    for name in ['崖壁B_实体侧层叠与斜切_v01','崖壁B_自由开口与架空底层_v03']:
        index=sc.doc.Layers.FindByFullPath(name,-1)
        if index>=0:
            l=sc.doc.Layers[index];l.IsVisible=False;l.CommitChanges()
    sc.doc.Objects.UnselectAll();sc.doc.Views.Redraw()


def refine_backing(state):
    rows=source_rows();points=[]
    for i in range(0,len(rows),4):
        r=rows[i];a=rows[(i-2)%len(rows)];b=rows[(i+2)%len(rows)]
        radius=math.hypot(b[0]-a[0],b[1]-a[1])/max(math.hypot(b[2]-a[2],b[3]-a[3]),1e-8)
        setback=min(45,radius*.55)*smooth((r[4]-65)/65)
        points.append(G.Point3d(r[0]-r[2]*setback,r[1]-r[3]*setback,0))
    core=G.Extrusion.Create(loop(points,192),57,True).ToBrep()
    if not core.IsValid or not core.IsSolid:raise RuntimeError('Backing invalid')
    oid=System.Guid(state['backing_id'])
    if not sc.doc.Objects.Replace(oid,core):raise RuntimeError('Cannot replace backing')
    old=[r for r in state['objects'] if r['group'] in ['03_斜切屋盖','12_斜切顶部建筑']]
    roof(state)
    for r in old:
        sc.doc.Objects.Delete(System.Guid(r['id']),True);state['objects'].remove(r)
    state['backing_setback_used_m']=45


def recess(state):
    # A broad asymmetric vaulted opening, oriented to the solid-side shoreline.
    r=sample(134+.69*452);out=G.Vector3d(r[2],r[3],0);t=G.Vector3d(-r[3],r[2],0)
    origin=G.Point3d(r[0]+out.X*25,r[1]+out.Y*25,-1)
    plane=G.Plane(origin,t,G.Vector3d.ZAxis)
    upper=[plane.PointAt(x,z) for x,z in [(-52,0),(-49,7),(-34,16),(-10,20),(15,19),(38,13),(55,0)]]
    arch=G.Curve.CreateInterpolatedCurve(upper,3,G.CurveKnotStyle.Chord)
    close=G.LineCurve(upper[-1],upper[0])
    profile=G.Curve.JoinCurves([arch,close],.01)[0]
    cutter=G.Surface.CreateExtrusion(profile,-out*48).ToBrep().CapPlanarHoles(.01)
    if cutter.SolidOrientation==G.BrepSolidOrientation.Inward:cutter.Flip()
    record=next(r for r in state['objects'] if r['name'].startswith('B_NURBS_04_'))
    obj=sc.doc.Objects.FindId(System.Guid(state['backing_id'] if len(state.get('joined_pods',[]))==9 else record['id']))
    result=G.Brep.CreateBooleanDifference(obj.Geometry,cutter,.01)
    if not result or len(result)!=1 or not result[0].IsSolid or not result[0].IsValid:
        raise RuntimeError('Recess boolean failed')
    if not sc.doc.Objects.Replace(obj.Id,result[0]):raise RuntimeError('Cannot replace recess mass')
    state['recess']={'width_m':107,'max_height_m':19,'cut_depth_m':48,'closed_nurbs':True}


def restore_for_recess(state):
    # Keep the cutter outward: Rhino's solid booleans are orientation sensitive.
    temp={'objects':[],'pod_metrics':[]};pod(temp,4)
    old=next(r for r in state['objects'] if r['name'].startswith('B_NURBS_04_'))
    fresh=sc.doc.Objects.FindId(System.Guid(temp['objects'][0]['id']))
    sc.doc.Objects.Show(System.Guid(old['id']),True)
    if not sc.doc.Objects.Replace(System.Guid(old['id']),fresh.Geometry.DuplicateBrep()):raise RuntimeError('Cannot restore editable lobe')
    sc.doc.Objects.Hide(System.Guid(old['id']),True)
    sc.doc.Objects.Delete(fresh.Id,True)
    refine_backing(state);state['joined_pods']=[];state['editable_hidden_ids']=[]


def union_one(state,index):
    records=[r for r in state['objects'] if r['group']=='02_独立曲面台地']
    record=next(r for r in records if r['name'].startswith('B_NURBS_%02d_'%index))
    obj=sc.doc.Objects.FindId(System.Guid(record['id']))
    core=sc.doc.Objects.FindId(System.Guid(state['backing_id']))
    result=G.Brep.CreateBooleanUnion([core.Geometry,obj.Geometry],.01)
    if not result or len(result)!=1 or not result[0].IsSolid or not result[0].IsValid:
        raise RuntimeError('Union failed, retained separate editable masses')
    if not sc.doc.Objects.Replace(core.Id,result[0]):raise RuntimeError('Cannot replace joined core')
    sc.doc.Objects.Hide(obj,True)
    state.setdefault('joined_pods',[]).append(index)
    state.setdefault('editable_hidden_ids',[]).append(record['id'])
    print(json.dumps({'joined_pod':index,'faces':result[0].Faces.Count,'valid':result[0].IsValid}))


def porch(state):
    r=sample(134+.69*452);out=G.Vector3d(r[2],r[3],0);t=G.Vector3d(-r[3],r[2],0)
    plane=G.Plane(G.Point3d(r[0],r[1],.8),t,out)
    points=[plane.PointAt(x,y) for x,y in [(-56,-18),(-60,-6),(-57,14),(-30,22),(20,21),(60,13),(62,-6),(55,-18)]]
    c=loop(points)
    g=G.Extrusion.Create(c,.8,True).ToBrep()
    if g.SolidOrientation==G.BrepSolidOrientation.Inward:g.Flip()
    add(g,'B_NURBS_凹厅前亲水平台','07_实体侧亲水平台',state)


def join_roof(state):
    record=next(r for r in state['objects'] if r['group']=='03_斜切屋盖')
    roof_obj=sc.doc.Objects.FindId(System.Guid(record['id']))
    core=sc.doc.Objects.FindId(System.Guid(state['backing_id']))
    result=G.Brep.CreateBooleanUnion([core.Geometry,roof_obj.Geometry],.01)
    if not result or len(result)!=1 or not result[0].IsValid or not result[0].IsSolid:raise RuntimeError('Roof union failed')
    if not sc.doc.Objects.Replace(core.Id,result[0]):raise RuntimeError('Cannot join roof')
    sc.doc.Objects.Hide(roof_obj,True);state['editable_hidden_ids'].append(record['id'])
    state['roof_union']={'valid':True,'solid':True,'faces':result[0].Faces.Count}


def audit(state):
    helper=helpers()['recipe']();core_obj=sc.doc.Objects.FindId(System.Guid(state['backing_id']))
    core=core_obj.Geometry;mesh=helper['mesh_for'](core,4)
    porch_geo=sc.doc.Objects.FindId(System.Guid(next(r['id'] for r in state['objects'] if r['group']=='07_实体侧亲水平台'))).Geometry
    porch_mesh=helper['mesh_for'](porch_geo,3)
    checks=[]
    for obstacle in source_input()['obstacles']:
        obj=sc.doc.Objects.FindId(System.Guid(obstacle['id']));other=helper['mesh_for'](obj.Geometry,5)
        h=G.Intersect.Intersection.MeshMeshFast(mesh,other);h2=G.Intersect.Intersection.MeshMeshFast(porch_mesh,other)
        closest=float('inf')
        for i in range(0,mesh.Vertices.Count,29):
            p=G.Point3d(mesh.Vertices[i]);q=other.ClosestPoint(p)
            if q.IsValid:closest=min(closest,p.DistanceTo(q))
        checks.append({'id':str(obj.Id),'intersections':len(h) if h else 0,'porch_intersections':len(h2) if h2 else 0,'sampled_clearance_m':closest})
    if any(c['intersections'] or c['porch_intersections'] for c in checks):raise RuntimeError('New geometry hits another island')
    road=helper['source_object']('road_id').Geometry.DuplicateBrep();road.Transform(G.Transform.Translation(0,0,.1))
    volume=road.Faces[0].CreateExtrusion(G.LineCurve(G.Point3d.Origin,G.Point3d(0,0,5.1)),True)
    h=G.Intersect.Intersection.MeshMeshFast(mesh,helper['mesh_for'](volume))
    if h and len(h):raise RuntimeError('New core blocks road')
    paths=[];perimeter,path=helper['curves']()
    for entry in source_state()['walking_clearance']['paths']:
        p,tangent,outward=helper['frame'](entry['path_s'],perimeter,path);p.Z=.66
        plane=G.Plane(p,tangent,-outward)
        if plane.ZAxis.Z<0:plane=G.Plane(p,-tangent,-outward)
        volume=G.Box(plane,G.Interval(-.75,.75),G.Interval(-20,26),G.Interval(.1,2.2)).ToBrep()
        h=G.Intersect.Intersection.MeshMeshFast(mesh,helper['mesh_for'](volume,2))
        paths.append({'s':entry['path_s'],'intersections':len(h) if h else 0})
    if any(p['intersections'] for p in paths):raise RuntimeError('Roadside walking route blocked')
    edge_events=[]
    for e in core.Edges:
        h=G.Intersect.Intersection.CurveSelf(e,.01)
        if h and h.Count:edge_events.append(int(e.EdgeIndex))
    if edge_events:raise RuntimeError('Core edges self-intersect')
    state['audit']={'neighbors':checks,'road_intersections':0,'ground_paths':paths,'core_edge_self_events':edge_events,
                    'core_valid':core.IsValid,'core_closed':core.IsSolid,'core_faces':core.Faces.Count,'core_volume_m3':G.VolumeMassProperties.Compute(core).Volume}
    # Triangulation is solely an audit output; the authored object remains NURBS.
    mesh.Faces.ConvertQuadsToTriangles();mesh.Vertices.CombineIdentical(True,True);mesh.Compact()
    write(os.path.join(WORK,'cliff_b_solid_nurbs_audit_mesh.json'),{
        'vertices':[[float(p.X),float(p.Y),float(p.Z)] for p in mesh.Vertices],
        'faces':[[int(f.A),int(f.B),int(f.C)] for f in mesh.Faces]})
    print(json.dumps(state['audit']))


def preview(state):
    folder=os.path.join(ROOT,'docs','cliff_b_solid_nurbs_v01')
    if not os.path.isdir(folder):os.makedirs(folder)
    with io.open(os.path.join(folder,'.gdignore'),'w',encoding='utf-8') as f:f.write('\n')
    view=sc.doc.Views.ActiveView;vp=view.ActiveViewport
    mode=Rhino.Display.DisplayModeDescription.FindByName('Arctic')
    hidden=[];overrides=[]
    try:
        for o in sc.doc.Objects:
            if o.IsHidden or o.IsDeleted:continue
            if o.Geometry.ObjectType in [Rhino.DocObjects.ObjectType.Curve,Rhino.DocObjects.ObjectType.Annotation,Rhino.DocObjects.ObjectType.Point]:
                if sc.doc.Objects.Hide(o,True):hidden.append(o.Id)
            elif isinstance(o.Geometry,(G.Brep,G.Extrusion,G.Mesh)) and o.Attributes.GetUserString('component')!='11_浅水示意':
                overrides.append((o.Id,o.Attributes.Duplicate()))
                a=o.Attributes.Duplicate();a.SetDisplayModeOverride(mode);sc.doc.Objects.ModifyAttributes(o,a,True)
        sc.doc.Views.RedrawEnabled=True;vp.CameraUp=G.Vector3d.ZAxis
        cap=Rhino.Display.ViewCapture();cap.Width=1600;cap.Height=1000
        cap.DrawGrid=False;cap.DrawAxes=False;cap.DrawGridAxes=False
        cameras=[('context',G.Point3d(1250,-700,350),G.Point3d(1230,230,30),32),
                 ('terraces',G.Point3d(1230,-160,155),G.Point3d(1270,225,28),32),
                 ('recess',G.Point3d(1300,35,27),G.Point3d(1300,230,15),28),
                 ('roadside',G.Point3d(1260,1120,430),G.Point3d(1220,340,28),32)]
        for name,eye,target,lens in cameras:
            vp.SetCameraLocations(target,eye);vp.Camera35mmLensLength=lens
            sc.doc.NamedViews.Add('B_NURBS_v01_'+name,vp.Id);view.Redraw()
            bitmap=cap.CaptureToBitmap(view);bitmap.Save(os.path.join(folder,name+'.png'),System.Drawing.Imaging.ImageFormat.Png);bitmap.Dispose()
    finally:
        for oid,attrs in overrides:sc.doc.Objects.ModifyAttributes(oid,attrs,True)
        for oid in hidden:sc.doc.Objects.Show(oid,True)
    vp.SetCameraLocations(cameras[0][2],cameras[0][1]);vp.Camera35mmLensLength=32
    sc.doc.Views.Redraw();state['saved_model']=save()
    write(os.path.join(folder,'report.json'),state)
    print('Saved '+state['saved_model'])


def run(stage):
    state=read(STATE) if os.path.exists(STATE) else {'objects':[],'stages':[],'document_serial':int(sc.doc.RuntimeSerialNumber)}
    if state['document_serial']!=sc.doc.RuntimeSerialNumber:raise RuntimeError('Document changed')
    if stage in state['stages']:raise RuntimeError('Stage already completed')
    old=sc.doc.Views.RedrawEnabled;undo=sc.doc.BeginUndoRecord('Cliff B NURBS '+stage);before=len(state['objects'])
    try:
        sc.doc.Views.RedrawEnabled=False
        if stage=='begin':begin(state)
        elif stage.startswith('pod_'):pod(state,int(stage.split('_')[1]))
        elif stage=='roof':roof(state)
        elif stage=='show':show(state)
        elif stage=='refine_backing':refine_backing(state)
        elif stage=='recess':recess(state)
        elif stage=='final_recess':recess(state)
        elif stage=='restore_for_recess':restore_for_recess(state)
        elif stage.startswith('rejoin_'):union_one(state,int(stage.split('_')[1]))
        elif stage=='correct_recess':recess(state)
        elif stage=='porch':porch(state)
        elif stage=='join_roof':join_roof(state)
        elif stage=='audit':audit(state)
        elif stage=='preview':preview(state)
        elif stage.startswith('union_'):union_one(state,int(stage.split('_')[1]))
        else:raise RuntimeError('Unknown stage')
        state['stages'].append(stage);write(STATE,state)
    except Exception:
        for r in state['objects'][before:]:sc.doc.Objects.Delete(System.Guid(r['id']),True)
        raise
    finally:
        sc.doc.EndUndoRecord(undo);sc.doc.Views.RedrawEnabled=old;sc.doc.Views.Redraw()
