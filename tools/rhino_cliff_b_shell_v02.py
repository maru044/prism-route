# -*- coding: utf-8 -*-
"""Rhino-side v02: perforated sheet mesh and repaired NURBS roof.

Execute one stage at a time with the UTF-8 loader documented for v01.
"""
from __future__ import division, unicode_literals
import io, os, json, math
import Rhino, System, scriptcontext as sc
from System.Drawing import Color

G = Rhino.Geometry
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK = os.path.join(ROOT,'.map_1012_build')
STATE = os.path.join(WORK,'cliff_b_shell_v02_state.json')
TAG = 'prism_cliff_b_sheet_v02'


def read(path):
    with io.open(path,encoding='utf-8') as f:
        return json.load(f)


def write(path,data):
    with io.open(path,'w',encoding='utf-8') as f:
        f.write(json.dumps(data,ensure_ascii=False,indent=2,separators=(',',': ')))


def cfg():
    return read(os.path.join(ROOT,'tools','cliff_b_shell_v02.json'))


def recipe():
    path=os.path.join(ROOT,'tools','rhino_cliff_b_parametric.py')
    ns={'__file__':path,'__name__':'cliff_b_v01_helpers'}
    exec(compile('\n'.join(io.open(path,encoding='utf-8').read().splitlines()[1:]),path,'exec'),ns)
    return ns


def layer(name,parent=None):
    full=parent.FullPath+'::'+name if parent else name
    index=sc.doc.Layers.FindByFullPath(full,-1)
    if index<0:
        l=Rhino.DocObjects.Layer();l.Name=name;l.Color=Color.FromArgb(240,238,230)
        if parent:l.ParentLayerId=parent.Id
        index=sc.doc.Layers.Add(l)
    return sc.doc.Layers[index]


def add(geometry,name,group,state,original_attrs=None):
    if not geometry.IsValid:raise RuntimeError('Invalid '+name)
    root=layer(cfg()['layer']);sub=layer(group,root)
    attrs=original_attrs.Duplicate() if original_attrs else Rhino.DocObjects.ObjectAttributes()
    attrs.Name=name;attrs.LayerIndex=sub.Index;attrs.WireDensity=-1
    attrs.SetUserString('recipe',TAG);attrs.SetUserString('component',group)
    attrs.SetUserString('name',name);attrs.SetUserString('description','Opening-first curved sheet prototype v02')
    if original_attrs is None:
        attrs.ObjectColor=Color.FromArgb(243,240,232)
        attrs.ColorSource=Rhino.DocObjects.ObjectColorSource.ColorFromObject
        attrs.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
        attrs.MaterialIndex=recipe()['material'](TAG+'_chalk',(243,240,232))
    oid=sc.doc.Objects.Add(geometry,attrs)
    if oid==System.Guid.Empty:raise RuntimeError('Cannot add '+name)
    if isinstance(geometry,G.Brep):
        mp=G.MeshingParameters();mp.Tolerance=.04;mp.RelativeTolerance=0
        mp.MaximumEdgeLength=4;mp.RefineGrid=True;mp.JaggedSeams=False
        sc.doc.Objects.FindId(oid).SetRenderMeshParameters(mp)
    state['objects'].append({'id':str(oid),'name':name,'group':group})
    return oid


def foundation(state):
    v1path=os.path.join(WORK,'cliff_b_parametric_state.json')
    if not os.path.exists(v1path):
        v1path=os.path.join(ROOT,'assets','world','cliff_b_parametric_source','generation_state.json')
    v1=read(v1path)
    if any(o.Attributes.GetUserString('recipe')==TAG for o in sc.doc.Objects):
        raise RuntimeError('v02 already exists; do not duplicate')
    backup=os.path.join(os.path.dirname(ROOT),'map','map_before_cliffB_shell_v02.3dm')
    if not os.path.exists(backup):save(backup)
    state['backup']=backup
    for record in v1['objects']:
        if record['group'] in ['02_顶部厚壳','06_参数化主肋','07_底层支承','00_参数引导线']:continue
        obj=sc.doc.Objects.FindId(System.Guid(record['id']))
        if obj is None:raise RuntimeError('Missing v01 context')
        add(obj.Geometry.Duplicate(),obj.Name,record['group'],state,obj.Attributes)
    perimeter,_=recipe()['curves']()
    profiles=[];max_deviation=0
    for i in range(9):
        theta=-math.pi/2+math.pi*i/8
        inset=cfg()['roof_rollover_width_m']*(1-math.cos(theta))
        c=perimeter.DuplicateCurve() if inset<1e-6 else list(perimeter.Offset(G.Plane.WorldXY,-inset,.01,G.CurveOffsetCornerStyle.Round))[0]
        c.Transform(G.Transform.Translation(0,0,60+cfg()['roof_thickness_m']/2*math.sin(theta)))
        rebuilt=c.Rebuild(cfg()['roof_rebuild_points'],3,True)
        for j in range(240):
            q=rebuilt.PointAtNormalizedLength(j/240)
            ok,t=c.ClosestPoint(q)
            max_deviation=max(max_deviation,q.DistanceTo(c.PointAt(t)))
        profiles.append(rebuilt)
    loft=G.Brep.CreateFromLoft(profiles,G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Normal,False)
    caps=list(G.Brep.CreatePlanarBreps(profiles[0],.01) or [])+list(G.Brep.CreatePlanarBreps(profiles[-1],.01) or [])
    joined=G.Brep.JoinBreps(list(loft)+caps,.01)
    if not joined or len(joined)!=1 or not joined[0].IsSolid:raise RuntimeError('Roof not solid')
    roof=joined[0]
    if roof.SolidOrientation==G.BrepSolidOrientation.Inward:roof.Flip()
    events=[]
    for e in roof.Edges:
        si=G.Intersect.Intersection.CurveSelf(e,.01)
        if si and si.Count:events.append(e.EdgeIndex)
    if events:raise RuntimeError('Roof edge self-intersection')
    state['roof']={'edge_self_events':events,'sampled_rebuild_deviation_m':max_deviation,
                  'valid':roof.IsValid,'solid':roof.IsSolid,
                  'z_range':[roof.GetBoundingBox(True).Min.Z,roof.GetBoundingBox(True).Max.Z]}
    add(roof,'B_v02_修复圆滑厚屋盖','02_顶部厚壳',state)
    print(json.dumps(state['roof']))


def shell(state):
    data=read(os.path.join(WORK,'cliff_b_shell_v02_mesh.json'))
    mesh=G.Mesh()
    for p in data['vertices']:mesh.Vertices.Add(*p)
    for f in data['faces']:
        if len(f)==3:mesh.Faces.AddFace(f[0],f[1],f[2])
        else:mesh.Faces.AddFace(f[0],f[1],f[2],f[3])
    mesh.UnifyNormals();mesh.Normals.ComputeNormals();mesh.Compact()
    if not mesh.IsValid or not mesh.IsClosed:raise RuntimeError('Shell mesh invalid or open')
    if mesh.SolidOrientation()<0:mesh.Flip(True,True,True)
    state['shell']={'vertices':mesh.Vertices.Count,'faces':mesh.Faces.Count,
                    'closed':mesh.IsClosed,'valid':mesh.IsValid,'orientation':mesh.SolidOrientation(),
                    'openings':data['openings'],'length_m':data['length_m'],'basis':data['basis']}
    add(mesh,'B_v02_不规则开口连续厚曲面','06_连续曲面表皮',state)
    print(json.dumps({k:state['shell'][k] for k in ['vertices','faces','closed','valid','orientation','length_m']}))


def audit(state):
    v1=recipe();source=v1['source_object']('road_id').Geometry.DuplicateBrep()
    source.Transform(G.Transform.Translation(0,0,.10))
    volume=source.Faces[0].CreateExtrusion(G.LineCurve(G.Point3d.Origin,G.Point3d(0,0,5.1)),True)
    road_mesh=v1['mesh_for'](volume)
    tests=[]
    for record in state['objects']:
        if record['group'] not in ['01_实体核心','06_连续曲面表皮']:continue
        g=sc.doc.Objects.FindId(System.Guid(record['id'])).Geometry
        mesh=g if isinstance(g,G.Mesh) else v1['mesh_for'](g)
        lines=G.Intersect.Intersection.MeshMeshFast(mesh,road_mesh)
        tests.append({'name':record['name'],'intersections':len(lines) if lines else 0})
    state['clearance']=tests
    if any(t['intersections'] for t in tests):raise RuntimeError('Road clearance blocked')
    roof_id=next(r['id'] for r in state['objects'] if r['group']=='02_顶部厚壳')
    roof=sc.doc.Objects.FindId(System.Guid(roof_id)).Geometry
    side=roof.Faces[0]
    self_count=0
    for direction in [0,1]:
        domain=side.Domain(1-direction)
        for i in range(1,121):
            curve=side.IsoCurve(direction,domain.ParameterAt(i/121))
            hits=G.Intersect.Intersection.CurveSelf(curve,.01)
            if hits:self_count+=hits.Count
    state['roof']['isocurve_self_events']=self_count
    if self_count:raise RuntimeError('Roof isocurve loops')
    v1layer=sc.doc.Layers.FindByFullPath(v1['read_config']()['layer'],-1)
    old=sc.doc.Layers[v1layer];old.IsVisible=False;old.CommitChanges()
    # Retain the user's source geometry, hide only the replaced sketch parts.
    source_cfg=v1['read_config']()
    source_ids=[source_cfg[k] for k in ['cliff_id','roof_id','base_id','road_id']]+source_cfg['rooftop_massing_ids']
    for oid in source_ids:
        obj=sc.doc.Objects.FindId(System.Guid(oid))
        if obj is not None:
            state.setdefault('source_visibility',{}).setdefault(oid,{'hidden':obj.IsHidden})
            if not obj.IsHidden:sc.doc.Objects.Hide(obj,True)
    sc.doc.Objects.UnselectAll()
    print(json.dumps({'clearance':tests,'roof_isocurve_self_events':self_count}))


def refine_shell(state):
    record=next(r for r in state['objects'] if r['group']=='06_连续曲面表皮')
    old=sc.doc.Objects.FindId(System.Guid(record['id']))
    if old.Attributes.GetUserString('recipe')!=TAG:raise RuntimeError('Not a v02 object')
    temporary={'objects':[]}
    shell(temporary)
    new=sc.doc.Objects.FindId(System.Guid(temporary['objects'][0]['id']))
    try:
        if not sc.doc.Objects.Replace(old.Id,new.Geometry.Duplicate()):raise RuntimeError('Cannot replace shell')
    finally:
        sc.doc.Objects.Delete(new.Id,True)
    state['shell']=temporary['shell']
    state['mesh_self_audit']=read(os.path.join(ROOT,'docs','CLIFF_B_SHELL_V02_MESH_AUDIT.json'))
    audit(state)
    preview(state)


def save(path=None):
    if path is None:path=os.path.join(os.path.dirname(ROOT),'map','map_cliffB_shell_v02.3dm')
    opts=Rhino.FileIO.FileWriteOptions();opts.SuppressAllInput=True;opts.SuppressDialogBoxes=True
    opts.IncludeRenderMeshes=False;opts.UpdateDocumentPath=False
    if not sc.doc.Write3dmFile(path,opts):raise RuntimeError('Model save failed')
    print('SAVED '+path)


def preview(state):
    folder=os.path.join(ROOT,'docs','cliff_b_shell_v02')
    if not os.path.isdir(folder):os.makedirs(folder)
    with io.open(os.path.join(folder,'.gdignore'),'w',encoding='utf-8') as f:f.write('\n')
    v1=recipe();perimeter,road=v1['curves']();point=v1['point']
    view=next(v for v in sc.doc.Views if v.ActiveViewport.IsPerspectiveProjection)
    sc.doc.Views.ActiveView=view;vp=view.ActiveViewport;vp.CameraUp=G.Vector3d.ZAxis
    vp.DisplayMode=Rhino.Display.DisplayModeDescription.FindByName('Shaded')
    cameras=[('整体',G.Point3d(1260,1120,430),G.Point3d(1220,340,28),32),
             ('峡谷',point(.50,61,9,perimeter,road),point(.61,8,26,perimeter,road),25),
             ('中层',point(.36,34,41,perimeter,road),point(.46,5,38,perimeter,road),32),
             ('屋盖',G.Point3d(950,580,110),G.Point3d(1003,380,60),45)]
    keep=set(r['id'] for r in state['objects']);keep.add(v1['read_config']()['shallow_bed_id'])
    hidden=[];capture=Rhino.Display.ViewCapture();capture.Width=1600;capture.Height=1000
    capture.DrawGrid=False;capture.DrawAxes=False;capture.DrawGridAxes=False
    try:
        for o in sc.doc.Objects:
            if not o.IsDeleted and not o.IsHidden and str(o.Id) not in keep:
                if sc.doc.Objects.Hide(o,True):hidden.append(o.Id)
        for i,(name,location,target,lens) in enumerate(cameras):
            vp.Camera35mmLensLength=lens;vp.SetCameraLocations(target,location)
            sc.doc.NamedViews.Add('B曲面v02_'+name,vp.Id);view.Redraw()
            bitmap=capture.CaptureToBitmap(view)
            path=os.path.join(folder,['overview.png','canyon.png','road.png','roof.png'][i])
            bitmap.Save(path,System.Drawing.Imaging.ImageFormat.Png);bitmap.Dispose()
    finally:
        for oid in hidden:sc.doc.Objects.Show(oid,True)
        vp.Camera35mmLensLength=32;vp.SetCameraLocations(cameras[0][2],cameras[0][1]);sc.doc.Views.Redraw()
    write(os.path.join(ROOT,'docs','CLIFF_B_SHELL_V02_REPORT.json'),state)
    save()
    print('PREVIEWS '+folder)


def run(stage):
    state=read(STATE) if os.path.exists(STATE) else {'objects':[],'stages':[],'document_serial':int(sc.doc.RuntimeSerialNumber)}
    if state['document_serial']!=sc.doc.RuntimeSerialNumber:raise RuntimeError('Document changed')
    if stage in state['stages']:raise RuntimeError('Already completed '+stage)
    undo=sc.doc.BeginUndoRecord('Cliff B sheet v02 '+stage);old=sc.doc.Views.RedrawEnabled
    count=len(state['objects'])
    try:
        sc.doc.Views.RedrawEnabled=False
        {'foundation':foundation,'shell':shell,'audit':audit,'preview':preview,'refine_shell':refine_shell,'refine_organic':refine_shell}[stage](state)
        state['stages'].append(stage);write(STATE,state)
    except Exception:
        for r in state['objects'][count:]:sc.doc.Objects.Delete(System.Guid(r['id']),True)
        raise
    finally:
        sc.doc.EndUndoRecord(undo);sc.doc.Views.RedrawEnabled=old;sc.doc.Views.Redraw()
    print(json.dumps({'stage':stage,'objects':len(state['objects'])}))
