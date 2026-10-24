# -*- coding: utf-8 -*-
"""Independent rear terraces with a shared watertight core and bevelled roof."""
from __future__ import division,unicode_literals
import io,os,json,math
import Rhino,System,scriptcontext as sc

ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK=os.path.join(ROOT,'.map_1012_build')
STATE=os.path.join(WORK,'cliff_b_solid_side_state.json')
REPORT=os.path.join(ROOT,'docs','CLIFF_B_SOLID_SIDE_V01_REPORT.json')
TAG='prism_cliff_b_solid_side_v01'
G=Rhino.Geometry


def read(path):
    with io.open(path,encoding='utf-8') as f:return json.load(f)


def write(path,value):
    with io.open(path,'w',encoding='utf-8') as f:f.write(json.dumps(value,ensure_ascii=False,indent=2,separators=(',',': ')))


def config():return read(os.path.join(ROOT,'tools','cliff_b_solid_side_v01.json'))


def helpers():
    path=os.path.join(ROOT,'tools','rhino_cliff_b_shell_v02.py')
    ns={'__file__':path,'__name__':'solid_side_helpers'}
    code='\n'.join(io.open(path,encoding='utf-8').read().splitlines()[1:])
    exec(compile(code,path,'exec'),ns)
    ns['TAG']=TAG;ns['cfg']=config
    return ns


def add(geometry,name,group,state,attrs=None):
    if isinstance(geometry,G.Mesh) and not geometry.IsClosed:raise RuntimeError('Open mesh '+name)
    if isinstance(geometry,G.Brep) and not geometry.IsSolid and group!='11_浅水示意':raise RuntimeError('Open Brep '+name)
    oid=helpers()['add'](geometry,name,group,state,attrs)
    obj=sc.doc.Objects.FindId(oid);values=obj.Attributes.Duplicate()
    values.SetUserString('description','Layered solid-side prototype; shared boundaries and planar bevel sections')
    sc.doc.Objects.ModifyAttributes(obj,values,True)
    return oid


def save(path=None):
    path=path or os.path.join(os.path.dirname(ROOT),'map','map_cliffB_solid_side_v01.3dm')
    opts=Rhino.FileIO.FileWriteOptions();opts.SuppressAllInput=True;opts.SuppressDialogBoxes=True
    opts.UpdateDocumentPath=False;opts.IncludeRenderMeshes=False
    if not sc.doc.Write3dmFile(path,opts):raise RuntimeError('Save failed')
    print('SAVED '+path)
    return path


def begin(state):
    known=set(r['id'] for r in state['objects'])
    if any(o.Attributes.GetUserString('recipe')==TAG and str(o.Id) not in known for o in sc.doc.Objects):raise RuntimeError('Untracked prototype objects already exist')
    before=os.path.join(os.path.dirname(ROOT),'map','map_before_cliffB_solid_side_v01.3dm')
    if not os.path.exists(before):save(before)
    state['backup']=before;state['config']=config()
    old=read(os.path.join(WORK,'cliff_b_shell_v03_state.json'))
    state['source_objects']=old['objects']
    for record in old['objects']:
        if record['group'] in ['01_实体核心','02_顶部厚壳','12_顶部建筑']:continue
        obj=sc.doc.Objects.FindId(System.Guid(record['id']))
        if obj is None:raise RuntimeError('Source object missing')
        add(obj.Geometry.Duplicate(),obj.Name,record['group'],state,obj.Attributes)


def body(state):
    data=read(os.path.join(WORK,'cliff_b_solid_side_mesh.json'))
    audit=read(os.path.join(ROOT,'docs','CLIFF_B_SOLID_SIDE_V01_MESH_AUDIT.json'))
    if audit['crossing_pairs'] or audit['degenerate_triangles']:raise RuntimeError('Core mesh audit failed')
    mesh=G.Mesh()
    for p in data['vertices']:mesh.Vertices.Add(*p)
    for f in data['faces']:
        if len(f)==3:mesh.Faces.AddFace(*f)
        else:mesh.Faces.AddFace(f[0],f[1],f[2],f[3])
    mesh.UnifyNormals();mesh.Normals.ComputeNormals();mesh.Compact()
    if mesh.SolidOrientation()<0:mesh.Flip(True,True,True)
    if not mesh.IsClosed or not mesh.IsValid:raise RuntimeError('Core is not closed/valid')
    mesh.Unweld(math.radians(25),True);mesh.Normals.ComputeNormals()
    state['body']=data['metrics'];state['body']['closed']=mesh.IsClosed;state['body']['valid']=mesh.IsValid
    state['body']['orientation']=mesh.SolidOrientation();state['mesh_audit']=audit
    add(mesh,'B_实体侧_六层连续核心_斜切层边','01_层叠实体核心',state)
    print(json.dumps(state['body']))


def capped_profile_loft(profiles):
    parts=[]
    for a,b in zip(profiles,profiles[1:]):
        loft=G.Brep.CreateFromLoft([a,b],G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Straight,False)
        if not loft:raise RuntimeError('Bevel surface failed')
        parts.extend(loft)
    parts.extend(G.Brep.CreatePlanarBreps(profiles[0],.01) or [])
    parts.extend(G.Brep.CreatePlanarBreps(profiles[-1],.01) or [])
    joined=G.Brep.JoinBreps(parts,.01)
    if not joined or len(joined)!=1 or not joined[0].IsSolid:raise RuntimeError('Bevel surfaces do not close')
    geometry=joined[0]
    if geometry.SolidOrientation==G.BrepSolidOrientation.Inward:geometry.Flip()
    for edge in geometry.Edges:
        hits=G.Intersect.Intersection.CurveSelf(edge,.01)
        if hits and hits.Count:raise RuntimeError('Bevel edge self-intersects')
    return geometry


def roof(state):
    perimeter,_=helpers()['recipe']()['curves']()
    profiles=[]
    for offset,z in config()['roof_profiles']:
        candidates=[perimeter.DuplicateCurve()] if abs(offset)<1e-9 else list(perimeter.Offset(G.Plane.WorldXY,offset,.01,G.CurveOffsetCornerStyle.Sharp) or [])
        candidates=[c for c in candidates if c.IsClosed]
        if len(candidates)!=1:raise RuntimeError('Roof offset contour split')
        c=candidates[0].Rebuild(config()['roof_rebuild_points'],3,True)
        c.Transform(G.Transform.Translation(0,0,z));profiles.append(c)
    geometry=capped_profile_loft(profiles)
    state['roof']={'closed':geometry.IsSolid,'valid':geometry.IsValid,'faces':geometry.Faces.Count,
                   'profiles':config()['roof_profiles'],'edge_self_events':0,'nominal_join_plane_z':57.0}
    add(geometry,'B_顶部厚屋盖_直线斜切收边','02_斜切屋盖',state)
    cfg=helpers()['recipe']()['read_config']();cx,cy=cfg['pavilion_center_xy']
    a,b=[60*r for r in cfg['pavilion_radii_ratio']]
    curves=[]
    for scale,z in [(1.0,63.0),(.96,67.0),(.66,72.6)]:
        curves.append(G.Ellipse(G.Plane(G.Point3d(cx,cy,z),G.Vector3d.ZAxis),a*scale,b*scale).ToNurbsCurve())
    pavilion=capped_profile_loft(curves)
    add(pavilion,'B_顶部低矮建筑_斜肩平顶','12_斜切顶部建筑',state)
    print(json.dumps({'roof':state['roof'],'pavilion_solid':pavilion.IsSolid}))


def audit(state):
    helper=helpers()['recipe']();data=read(os.path.join(WORK,'cliff_b_solid_side_mesh.json'))
    body_record=next(r for r in state['objects'] if r['group']=='01_层叠实体核心')
    core=sc.doc.Objects.FindId(System.Guid(body_record['id'])).Geometry
    roof_record=next(r for r in state['objects'] if r['group']=='02_斜切屋盖')
    roof_geo=sc.doc.Objects.FindId(System.Guid(roof_record['id'])).Geometry
    roof_mesh=helper['mesh_for'](roof_geo,5)
    roof_bottom=min([e for e in roof_geo.Edges if e.IsClosed],key=lambda e:e.GetBoundingBox(True).Min.Z).DuplicateCurve()
    roof_bottom.Transform(G.Transform.PlanarProjection(G.Plane.WorldXY))
    top_vertices=[p for p in core.Vertices if abs(float(p.Z)-57.0)<.001]
    outside=[]
    for p in top_vertices:
        test=G.Point3d(float(p.X),float(p.Y),0)
        if roof_bottom.Contains(test,G.Plane.WorldXY,.02)==G.PointContainment.Outside:outside.append([float(p.X),float(p.Y)])
    state['roof_core_join']={'plane_z_m':57.0,'core_top_vertices_checked':len(top_vertices),'outside_roof_cap':len(outside)}
    if outside:raise RuntimeError('Core top is not covered by roof cap')
    checks=[]
    for oid in data['obstacle_ids']:
        obj=sc.doc.Objects.FindId(System.Guid(oid));other=helper['mesh_for'](obj.Geometry,6)
        hits=G.Intersect.Intersection.MeshMeshFast(core,other)
        roof_hits=G.Intersect.Intersection.MeshMeshFast(roof_mesh,other)
        closest=float('inf')
        for i in range(0,core.Vertices.Count,17):
            p=G.Point3d(core.Vertices[i]);q=other.ClosestPoint(p)
            if q.IsValid:closest=min(closest,p.DistanceTo(q))
        checks.append({'id':oid,'body_intersections':len(hits) if hits else 0,
                       'roof_intersections':len(roof_hits) if roof_hits else 0,'sampled_clearance_m':closest})
    state['neighbor_checks']=checks
    if any(c['body_intersections'] or c['roof_intersections'] for c in checks):raise RuntimeError('Prototype intersects surrounding island/terrain')
    road=helper['source_object']('road_id').Geometry.DuplicateBrep();road.Transform(G.Transform.Translation(0,0,.1))
    volume=road.Faces[0].CreateExtrusion(G.LineCurve(G.Point3d.Origin,G.Point3d(0,0,5.1)),True)
    hits=G.Intersect.Intersection.MeshMeshFast(core,helper['mesh_for'](volume))
    state['road_clearance_intersections']=len(hits) if hits else 0
    if hits and len(hits):raise RuntimeError('Core blocks roadway')
    old=read(os.path.join(WORK,'cliff_b_shell_v03_state.json'))
    probes=[];perimeter,path=helper['curves']()
    for entry in old['walking_clearance']['paths']:
        p,tangent,outward=helper['frame'](entry['path_s'],perimeter,path);p.Z=.66
        plane=G.Plane(p,tangent,-outward)
        if plane.ZAxis.Z<0:plane=G.Plane(p,-tangent,-outward)
        volume=G.Box(plane,G.Interval(-.75,.75),G.Interval(-20,26),G.Interval(.1,2.2)).ToBrep()
        hits=G.Intersect.Intersection.MeshMeshFast(core,helper['mesh_for'](volume,2))
        probes.append({'s':entry['path_s'],'intersections':len(hits) if hits else 0})
    state['retained_roadside_walking_checks']=probes
    if any(p['intersections'] for p in probes):raise RuntimeError('Core blocks retained ground route')
    previous=sc.doc.Layers.FindByFullPath(config()['source_layer'],-1)
    layer=sc.doc.Layers[previous];layer.IsVisible=False;layer.CommitChanges()
    sc.doc.Objects.UnselectAll()
    print(json.dumps({'neighbors':checks,'road_clearance':state['road_clearance_intersections'],'ground_routes_clear':True}))


def refine_roof(state):
    record=next(r for r in state['objects'] if r['group']=='02_斜切屋盖')
    old=sc.doc.Objects.FindId(System.Guid(record['id']))
    if old.Attributes.GetUserString('recipe')!=TAG:raise RuntimeError('Not an owned roof')
    temporary={'objects':[]}
    roof(temporary)
    fresh=next(r for r in temporary['objects'] if r['group']=='02_斜切屋盖')
    geometry=sc.doc.Objects.FindId(System.Guid(fresh['id'])).Geometry.DuplicateBrep()
    try:
        if not sc.doc.Objects.Replace(old.Id,geometry):raise RuntimeError('Roof replacement failed')
    finally:
        for r in temporary['objects']:sc.doc.Objects.Delete(System.Guid(r['id']),True)
    state['roof']=temporary['roof'];state['config']=config()
    audit(state)
    preview(state)


def finalize_body(state):
    record=next(r for r in state['objects'] if r['group']=='01_层叠实体核心')
    old=sc.doc.Objects.FindId(System.Guid(record['id']))
    if old.Attributes.GetUserString('recipe')!=TAG:raise RuntimeError('Not an owned core')
    temporary={'objects':[]}
    body(temporary)
    fresh=sc.doc.Objects.FindId(System.Guid(temporary['objects'][0]['id']))
    geometry=fresh.Geometry.DuplicateMesh()
    try:
        if not sc.doc.Objects.Replace(old.Id,geometry):raise RuntimeError('Core replacement failed')
    finally:sc.doc.Objects.Delete(fresh.Id,True)
    state['body']=temporary['body'];state['mesh_audit']=temporary['mesh_audit'];state['config']=config()
    audit(state);preview(state)


def preview(state):
    folder=os.path.join(ROOT,'docs','cliff_b_solid_side_v01')
    if not os.path.isdir(folder):os.makedirs(folder)
    with io.open(os.path.join(folder,'.gdignore'),'w',encoding='utf-8') as f:f.write('\n')
    view=next(v for v in sc.doc.Views if v.ActiveViewport.IsPerspectiveProjection)
    sc.doc.Views.ActiveView=view;vp=view.ActiveViewport;vp.CameraUp=G.Vector3d.ZAxis
    previous_mode=vp.DisplayMode
    vp.DisplayMode=Rhino.Display.DisplayModeDescription.FindByName('Arctic')
    capture=Rhino.Display.ViewCapture();capture.Width=1600;capture.Height=1000
    capture.DrawGrid=False;capture.DrawAxes=False;capture.DrawGridAxes=False
    cameras=[('实体侧与邻岛',G.Point3d(1250,-700,350),G.Point3d(1230,230,30),32),
             ('层叠近景',G.Point3d(1320,40,80),G.Point3d(1360,230,27),28),
             ('斜切屋盖',G.Point3d(1250,50,95),G.Point3d(1320,220,60),35),
             ('道路侧对照',G.Point3d(1260,1120,430),G.Point3d(1220,340,28),32)]
    hidden=[]
    try:
        for obj in sc.doc.Objects:
            if not obj.IsDeleted and not obj.IsHidden and obj.Geometry.ObjectType in [Rhino.DocObjects.ObjectType.Curve,Rhino.DocObjects.ObjectType.Annotation,Rhino.DocObjects.ObjectType.Point]:
                if sc.doc.Objects.Hide(obj,True):hidden.append(obj.Id)
        for i,(name,location,target,lens) in enumerate(cameras):
            vp.Camera35mmLensLength=lens;vp.SetCameraLocations(target,location)
            sc.doc.NamedViews.Add('B实体侧v01_'+name,vp.Id);view.Redraw()
            bitmap=capture.CaptureToBitmap(view)
            bitmap.Save(os.path.join(folder,['context.png','terraces.png','roof.png','roadside.png'][i]),System.Drawing.Imaging.ImageFormat.Png)
            bitmap.Dispose()
    finally:
        for oid in hidden:sc.doc.Objects.Show(oid,True)
        vp.DisplayMode=previous_mode
    vp.Camera35mmLensLength=32;vp.SetCameraLocations(cameras[0][2],cameras[0][1]);sc.doc.Views.Redraw()
    state['saved_model']=save();write(REPORT,state)
    print('CAPTURES '+folder)


def run(stage):
    state=read(STATE) if os.path.exists(STATE) else {'objects':[],'stages':[],'document_serial':int(sc.doc.RuntimeSerialNumber)}
    if state['document_serial']!=sc.doc.RuntimeSerialNumber:raise RuntimeError('Active document changed')
    if stage in state['stages']:raise RuntimeError('Stage already done')
    old=sc.doc.Views.RedrawEnabled;undo=sc.doc.BeginUndoRecord('Cliff B solid side '+stage);before=len(state['objects'])
    try:
        sc.doc.Views.RedrawEnabled=False
        {'begin':begin,'body':body,'roof':roof,'audit':audit,'preview':preview,'refine_roof':refine_roof,'finalize_body':finalize_body}[stage](state)
        state['stages'].append(stage);write(STATE,state)
    except Exception:
        for r in state['objects'][before:]:sc.doc.Objects.Delete(System.Guid(r['id']),True)
        raise
    finally:
        sc.doc.EndUndoRecord(undo);sc.doc.Views.RedrawEnabled=old;sc.doc.Views.Redraw()
    print(json.dumps({'stage':stage,'objects':len(state['objects'])}))
