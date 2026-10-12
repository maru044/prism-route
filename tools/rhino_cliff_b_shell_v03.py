# -*- coding: utf-8 -*-
"""v03 uses the checked roof/context helpers and independent source layers.

Load this file as UTF-8 in Rhino, then run(stage) one stage at a time.
"""
from __future__ import division, unicode_literals
import io,os,json,math
import Rhino,System,scriptcontext as sc

ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
path=os.path.join(ROOT,'tools','rhino_cliff_b_shell_v02.py')
code='\n'.join(io.open(path,encoding='utf-8').read().splitlines()[1:])
for old,new in [('shell_v02','shell_v03'),('SHELL_V02','SHELL_V03'),('sheet_v02','sheet_v03'),('B曲面v02_','B曲面v03_'),('B_v02_','B_v03_')]:
    code=code.replace(old,new)
H={'__file__':path,'__name__':'cliff_b_v03_helpers'}
exec(compile(code,path,'exec'),H)
G=Rhino.Geometry


def pedestrian_audit(state):
    data=H['read'](os.path.join(H['WORK'],'cliff_b_shell_v03_mesh.json'))
    source=H['recipe']();perimeter,road=source['curves']()
    candidates=[]
    for record in state['objects']:
        obj=sc.doc.Objects.FindId(System.Guid(record['id']));geometry=obj.Geometry
        box=geometry.GetBoundingBox(True)
        if box.Max.Z<=.71 or box.Min.Z>=2.9:continue
        mesh=geometry if isinstance(geometry,G.Mesh) else source['mesh_for'](geometry)
        candidates.append((record['name'],mesh))
    results=[]
    for entry in data['walking_entries']:
        choices=[entry['s']]+[entry['s']+delta*entry['floor_width_m']/data['length_m'] for delta in [-.12,.12,-.24,.24]]
        attempts=[]
        for s in choices:
            origin,tangent,outward=source['frame'](s,perimeter,road);origin.Z=.66
            inward=-outward
            plane=G.Plane(origin,tangent,inward)
            if plane.ZAxis.Z<0:
                tangent=-tangent;plane=G.Plane(origin,tangent,inward)
            volume=G.Box(plane,G.Interval(-.75,.75),G.Interval(-20,26),G.Interval(.10,2.20)).ToBrep()
            volume_mesh=source['mesh_for'](volume,2)
            blocked=[]
            for name,mesh in candidates:
                hits=G.Intersect.Intersection.MeshMeshFast(mesh,volume_mesh)
                if hits and len(hits):blocked.append(name)
            attempts.append({'s':s,'blocked_by':blocked})
            if not blocked:break
        results.append({'floor_width_m':entry['floor_width_m'],'arch_top_m':entry['top_m'],
                        'path_s':s,'clear':not blocked,'attempts':attempts})
    state['walking_clearance']={'path_width_m':1.5,'floor_offset_m':.10,'height_m':2.10,
                                'outer_to_inner_distance_m':46,'paths':results,
                                'all_clear':all(r['clear'] for r in results)}
    state['ground_support_intervals_m']=data['ground_support_intervals_m']
    state['mesh_self_audit']=H['read'](os.path.join(ROOT,'docs','CLIFF_B_SHELL_V03_MESH_AUDIT.json'))
    if not state['walking_clearance']['all_clear']:raise RuntimeError('Some ground entrance paths are blocked')
    previous=sc.doc.Layers.FindByFullPath('崖壁B_曲面表皮验证_v02',-1)
    if previous>=0:
        l=sc.doc.Layers[previous];l.IsVisible=False;l.CommitChanges()
    print(json.dumps({'entrances':len(results),'all_clear':True,'ground_feet':len(data['ground_support_intervals_m'])}))


def walk_preview(state):
    source=H['recipe']();perimeter,road=source['curves']();point=source['point']
    entrance=state['walking_clearance']['paths'][3]
    s=entrance['path_s']
    near_foot=s-entrance['floor_width_m']*.37/state['shell']['length_m']
    view=next(v for v in sc.doc.Views if v.ActiveViewport.IsPerspectiveProjection)
    vp=view.ActiveViewport
    outside=point(s,70,2.5,perimeter,road)
    outside_target=point(s,9,20,perimeter,road)
    inside=point(near_foot,-20,2.5,perimeter,road)
    inside_target=point(s,24,12,perimeter,road)
    keep=set(r['id'] for r in state['objects']);keep.add(source['read_config']()['shallow_bed_id'])
    hidden=[]
    capture=Rhino.Display.ViewCapture();capture.Width=1600;capture.Height=1000
    capture.DrawGrid=False;capture.DrawAxes=False;capture.DrawGridAxes=False
    try:
        for obj in sc.doc.Objects:
            if not obj.IsDeleted and not obj.IsHidden and str(obj.Id) not in keep:
                if sc.doc.Objects.Hide(obj,True):hidden.append(obj.Id)
        vp.Camera35mmLensLength=20;vp.CameraUp=G.Vector3d.ZAxis
        for name,location,target in [('底层入口',outside,outside_target),('底层内部',inside,inside_target)]:
            vp.SetCameraLocations(target,location);sc.doc.NamedViews.Add('B曲面v03_'+name,vp.Id)
            view.Redraw();bitmap=capture.CaptureToBitmap(view)
            filename='entrance.png' if name=='底层入口' else 'inside.png'
            bitmap.Save(os.path.join(ROOT,'docs','cliff_b_shell_v03',filename),System.Drawing.Imaging.ImageFormat.Png)
            bitmap.Dispose()
    finally:
        for oid in hidden:sc.doc.Objects.Show(oid,True)
        vp.Camera35mmLensLength=32
        vp.SetCameraLocations(G.Point3d(1220,340,28),G.Point3d(1260,1120,430));sc.doc.Views.Redraw()
    H['save']()


def run(stage):
    if stage not in ['pedestrian','walking_views']:
        return H['run'](stage)
    state=H['read'](H['STATE'])
    if state['document_serial']!=sc.doc.RuntimeSerialNumber:raise RuntimeError('Document changed')
    if stage in state['stages']:raise RuntimeError('Already completed '+stage)
    undo=sc.doc.BeginUndoRecord('Cliff B v03 '+stage)
    try:
        if stage=='pedestrian':pedestrian_audit(state)
        else:walk_preview(state)
        state['stages'].append(stage);H['write'](H['STATE'],state)
        H['write'](os.path.join(ROOT,'docs','CLIFF_B_SHELL_V03_REPORT.json'),state)
    finally:
        sc.doc.EndUndoRecord(undo);sc.doc.Views.Redraw()
