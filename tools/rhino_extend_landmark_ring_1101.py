# -*- coding: utf-8 -*-
"""Extend the live, manually positioned circular bands into actual ground.

Re-read centres and planes from current Brep arcs on every run. Never restore
the original generator pose, move the hoop or alter unrelated source objects.
Call survey(), apply(), save() in Rhino; no Godot import is performed here.
"""
from __future__ import unicode_literals,division
import Rhino,scriptcontext as sc,System,io,json,math,os,time,shutil
G=Rhino.Geometry
ROOT='D:/Prism Route/prism-route'
OUT=ROOT+'/docs/landmark_ring_1101'
KEY='landmark_ring_ground_extension_1101'
FEATURE='landmark_ring_1101'
EMBED=.40

def xyz(p):return [float(p.X),float(p.Y),float(p.Z)]
def objects():
    e=Rhino.DocObjects.ObjectEnumeratorSettings();e.NormalObjects=True;e.HiddenObjects=True;e.LockedObjects=True
    return [o for o in sc.doc.Objects.GetObjectList(e) if not o.IsDeleted]
def fingerprint():
    options=Rhino.FileIO.SerializationOptions()
    return {str(o.Id):(int(o.Geometry.DataCRC(0)),o.Attributes.ToJSON(options)) for o in objects()}
def write(name,value):
    with io.open(OUT+'/'+name,'w',encoding='utf-8') as f:f.write(json.dumps(value,ensure_ascii=False,indent=2))
def read_band(o):
    assert isinstance(o.Geometry,G.Brep) and o.Geometry.IsSolid
    arcs=[]
    for edge in o.Geometry.Edges:
        ok,arc=edge.TryGetArc(.001)
        if ok:arcs.append(arc)
    assert len(arcs)==4,'Expected the current three annular solids, without reshaping'
    ro=max(a.Radius for a in arcs);ri=min(a.Radius for a in arcs)
    outer=[a for a in arcs if abs(a.Radius-ro)<.001]
    a,b=outer
    normal=G.Vector3d(a.Plane.Normal);depth=G.Vector3d.Multiply(b.Center-a.Center,normal)
    assert depth>0,'Unexpected annular face orientation'
    return dict(id=str(o.Id),name=o.Name,frame=G.Plane(a.Plane),ro=ro,ri=ri,depth=depth,start=a.StartAngle,end=a.EndAngle,attributes=o.Attributes.Duplicate())
def attribute_signature(a):
    # Native JSON serializes component references differently after Replace.
    # Keep the live attribute copy, including document table indices and groups.
    strings=a.GetUserStrings()
    return dict(name=a.Name,layer=a.LayerIndex,material=a.MaterialIndex,material_source=str(a.MaterialSource),
        color=a.ObjectColor.ToArgb(),color_source=str(a.ColorSource),mode=str(a.Mode),wire_density=a.WireDensity,
        groups=list(a.GetGroupList() or []),user_strings={key:strings[key] for key in strings.AllKeys})
def point(band,r,a,depth=0.):
    f=band['frame'];return f.Origin+f.XAxis*(r*math.cos(a))+f.YAxis*(r*math.sin(a))+f.Normal*depth
def ground(p):
    heights=[]
    for sid,m in sc.sticky[KEY]['ground']:
        t=G.Intersect.Intersection.MeshRay(m,G.Ray3d(G.Point3d(p.X,p.Y,500),-G.Vector3d.ZAxis))
        if t>=0:heights.append((500.-t,sid))
    return max(heights) if heights else (None,None)
def cap_samples(offset,side):
    rows=[]
    for b in sc.sticky[KEY]['bands']:
        a=b[side]+offset
        for r in [b['ri'],(b['ri']+b['ro'])*.5,b['ro']]:
            for depth in [0.,b['depth']*.5,b['depth']]:
                p=point(b,r,a,depth);z,sid=ground(p)
                rows.append(dict(id=b['id'],point=xyz(p),ground_z=z,ground_id=sid,gap_m=None if z is None else p.Z-z))
    return rows
def find_offset(side):
    direction=-1. if side=='start' else 1.
    initial=cap_samples(0.,side)
    if all(r['gap_m'] is not None and r['gap_m']<=-EMBED for r in initial):return 0.,initial,initial
    for i in range(1,181):
        offset=direction*math.radians(i*.25);rows=cap_samples(offset,side)
        if all(r['gap_m'] is not None and r['gap_m']<=-EMBED for r in rows):return offset,initial,rows
    raise Exception('No supported cap within 45 degrees; current pose remains untouched')
def survey():
    assert sc.doc.Path.replace('\\','/').lower()=='d:/prism route/map/map_current.3dm'
    assert str(sc.doc.ModelUnitSystem)=='Meters'
    owned=[o for o in objects() if o.Attributes.GetUserString('feature')==FEATURE and o.Attributes.GetUserString('category')=='01_concentric_bands']
    assert len(owned)==3
    bands=[read_band(o) for o in sorted(owned,key=lambda o:o.Name)]
    # All band poses must remain concentric after the user's manipulation.
    first=bands[0];axis=first['frame'].Normal
    for b in bands[1:]:
        v=b['frame'].Origin-first['frame'].Origin
        assert (v-axis*G.Vector3d.Multiply(v,axis)).Length<.001,'Ring bands no longer concentric'
        assert abs(G.Vector3d.Multiply(axis,b['frame'].Normal)-1)<.00001
    clip=G.BoundingBox.Empty
    for b in bands:
        for side,direction in [('start',-1.),('end',1.)]:
            for i in range(46):
                for r in [b['ri'],b['ro']]:clip.Union(point(b,r,b[side]+direction*math.radians(i),b['depth']*.5))
    with io.open(ROOT+'/assets/world/current_map_validation/metadata.json','r',encoding='utf-8') as f:meta=json.load(f)
    eligible=set(row['id'] for row in meta['object_records'] if row['kind'] in ['Terrain','Sand'])
    # An engineered bridge is not terrain support for this landscape hoop.
    eligible.discard('a4c9a543-2d8a-401c-bebe-b21f45031605')
    meshes=[];mp=G.MeshingParameters.FastRenderMesh
    for o in objects():
        if str(o.Id) not in eligible:continue
        b=o.Geometry.GetBoundingBox(True)
        if b.Max.X<clip.Min.X-5 or b.Min.X>clip.Max.X+5 or b.Max.Y<clip.Min.Y-5 or b.Min.Y>clip.Max.Y+5:continue
        if isinstance(o.Geometry,G.Mesh):m=o.Geometry.DuplicateMesh()
        elif isinstance(o.Geometry,G.Brep):
            m=G.Mesh()
            for part in G.Mesh.CreateFromBrep(o.Geometry,mp):m.Append(part)
        else:continue
        m.Normals.ComputeNormals();m.Compact();meshes.append((str(o.Id),m))
    assert meshes
    sc.sticky[KEY]=dict(before=fingerprint(),bands=bands,ground=meshes,committed=False)
    start,old_start,new_start=find_offset('start');end,old_end,new_end=find_offset('end')
    d=sc.sticky[KEY];d['start_offset']=start;d['end_offset']=end
    d['report']=dict(source=sc.doc.Path,feature=FEATURE,scope='Only the three live manually placed annular solids',
        band_ids=[b['id'] for b in bands],start_extension_degrees=-math.degrees(start),end_extension_degrees=math.degrees(end),
        original_angle_degrees=math.degrees(first['end']-first['start']),new_angle_degrees=math.degrees(first['end']-first['start']+end-start),
        target_embed_m=EMBED,old_start_samples=old_start,old_end_samples=old_end,new_start_samples=new_start,new_end_samples=new_end,
        current_circle_plane_normal=xyz(axis),current_front_centres=[xyz(b['frame'].Origin) for b in bands],
        current_radii=[[b['ro'],b['ri']] for b in bands],ground_objects=[sid for sid,m in meshes])
    write('ground_extension_survey.json',d['report'])
    return dict(start_extension_degrees=-math.degrees(start),end_extension_degrees=math.degrees(end),
        start_worst_gap_before=max(r['gap_m'] for r in old_start if r['gap_m'] is not None),
        start_worst_gap_after=max(r['gap_m'] for r in new_start),
        end_worst_gap_after=max(r['gap_m'] for r in new_end),ground_meshes=len(meshes),bands=3)
def geometry(b):
    d=sc.sticky[KEY];start=b['start']+d['start_offset'];end=b['end']+d['end_offset'];f=b['frame']
    u=f.XAxis*math.cos(start)+f.YAxis*math.sin(start);v=-f.XAxis*math.sin(start)+f.YAxis*math.cos(start)
    plane=G.Plane(f.Origin,u,v);angles=G.Interval(0,end-start)
    outer=G.Arc(G.Circle(plane,b['ro']),angles).ToNurbsCurve();inner=G.Arc(G.Circle(plane,b['ri']),angles).ToNurbsCurve();inner.Reverse()
    curve=G.PolyCurve();curve.Append(outer);curve.Append(G.LineCurve(outer.PointAtEnd,inner.PointAtStart));curve.Append(inner);curve.Append(G.LineCurve(inner.PointAtEnd,outer.PointAtStart))
    assert curve.IsClosed
    ex=G.Extrusion.Create(curve,b['depth'],True);assert ex
    result=ex.ToBrep();assert result.IsValid and result.IsSolid
    if result.SolidOrientation==G.BrepSolidOrientation.Inward:result.Flip()
    return result
def apply():
    d=sc.sticky[KEY];assert not d['committed'];assert fingerprint()==d['before'],'Scene changed since survey'
    assert abs(d['start_offset'])+abs(d['end_offset'])>.000001,'Already fully supported'
    replacements=[(b,geometry(b)) for b in d['bands']]
    folder='D:/Prism Route/archive/landmark_ring_1101';stamp=time.strftime('%Y%m%d_%H%M%S')
    backup=folder+'/map_user_placement_before_extension_'+stamp+'.3dm'
    options=Rhino.FileIO.FileWriteOptions();options.SuppressDialogBoxes=True
    assert sc.doc.Write3dmFile(backup,options),'Could not back up the current unsaved user placement'
    d['backup_path']=backup
    rec=sc.doc.BeginUndoRecord('Extend current ring ends into ground')
    try:
        for b,g in replacements:
            assert sc.doc.Objects.Replace(System.Guid(b['id']),g)
            assert sc.doc.Objects.ModifyAttributes(System.Guid(b['id']),b['attributes'],True)
        d['committed']=True
    finally:sc.doc.EndUndoRecord(rec);sc.doc.Views.Redraw()
    return audit()
def audit():
    d=sc.sticky[KEY];assert d['committed']
    current=fingerprint();allowed=set(b['id'] for b in d['bands'])
    assert set(current)==set(d['before']),'Object inventory changed'
    assert all(current[sid]==row for sid,row in d['before'].items() if sid not in allowed),'Unrelated geometry or attributes changed'
    # Attributes, IDs and every original arc point must remain exactly in place.
    options=Rhino.FileIO.SerializationOptions();max_error=0.
    for b in d['bands']:
        o=sc.doc.Objects.FindId(System.Guid(b['id']));assert attribute_signature(o.Attributes)==attribute_signature(b['attributes'])
        arcs=[edge.TryGetArc(.001)[1] for edge in o.Geometry.Edges if edge.TryGetArc(.001)[0]]
        for r in [b['ri'],b['ro']]:
            old=point(b,r,(b['start']+b['end'])*.5)
            closest=min(a.ToNurbsCurve().PointAt(a.ToNurbsCurve().ClosestPoint(old)[1]).DistanceTo(old) for a in arcs if abs(a.Radius-r)<.001)
            max_error=max(max_error,closest)
    assert max_error<.001
    d['report'].update(backup=d['backup_path'],original_arc_max_error_m=max_error,unrelated_objects_unchanged=len(current)-3,object_ids_preserved=True,materials_and_attributes_preserved=True)
    write('ground_extension_report.json',d['report'])
    return dict(changed_bands=3,new_objects=0,original_arc_max_error_m=max_error,unrelated_objects_unchanged=len(current)-3,backup=d['backup_path'])
def capture():
    d=sc.sticky[KEY];first=d['bands'][0];center=first['frame'].Origin+first['frame'].Normal*first['depth']*.5
    normal=first['frame'].Normal;eye=center-normal*560+G.Vector3d(0,0,210)
    target=center+G.Vector3d(0,0,-18);vp=sc.doc.Views.ActiveView.ActiveViewport
    vp.SetCameraLocations(target,eye);vp.Camera35mmLensLength=38.;sc.doc.Objects.UnselectAll();sc.doc.Views.Redraw()
    cap=Rhino.Display.ViewCapture();cap.Width=1600;cap.Height=1000;cap.DrawAxes=False;cap.DrawGrid=False;cap.DrawGridAxes=False;cap.ScaleScreenItems=False
    bitmap=cap.CaptureToBitmap(sc.doc.Views.ActiveView);assert bitmap
    bitmap.Save(OUT+'/model_repositioned_grounded.png',System.Drawing.Imaging.ImageFormat.Png);bitmap.Dispose()
    return OUT+'/model_repositioned_grounded.png'
def save():
    d=sc.sticky[KEY];assert d['committed']
    audit()
    archive='D:/Prism Route/archive/landmark_ring_1101';stamp=time.strftime('%Y%m%d_%H%M%S')
    for name in ['landmark_ring.3dm','parameters.json','model_report.json']:
        if os.path.exists(OUT+'/'+name):shutil.copy2(OUT+'/'+name,archive+'/before_ground_extension_'+stamp+'_'+name)
    # Persist the CURRENT frame, not an inferred translation of the first prototype.
    with io.open(OUT+'/parameters.json','r',encoding='utf-8') as f:params=json.load(f)
    first=d['bands'][0];center=first['frame'].Origin+first['frame'].Normal*first['depth']*.5
    params.update(center_native=xyz(center),circle_plane_normal_native=xyz(first['frame'].Normal),
        current_pose_bands=[dict(id=b['id'],front_center=xyz(b['frame'].Origin),x_axis=xyz(b['frame'].XAxis),y_axis=xyz(b['frame'].YAxis),normal=xyz(b['frame'].Normal),
            outer_radius=b['ro'],inner_radius=b['ri'],depth=b['depth'],start_radians=b['start']+d['start_offset'],end_radians=b['end']+d['end_offset']) for b in d['bands']],
        current_visible_arc_degrees=d['report']['new_angle_degrees'],latest_revision='User moved/rotated only the three rings; extend at current pose; connection remnants stay where authored.',
        ground_extension_report='ground_extension_report.json')
    params.pop('display_arc_degrees',None);params.pop('relation',None);write('parameters.json',params)
    feature=[o for o in objects() if o.Attributes.GetUserString('feature')==FEATURE]
    bounds=G.BoundingBox.Empty;band_bounds=G.BoundingBox.Empty
    for o in feature:
        bounds.Union(o.Geometry.GetBoundingBox(True))
        if o.Attributes.GetUserString('category')=='01_concentric_bands':band_bounds.Union(o.Geometry.GetBoundingBox(True))
    write('model_report.json',dict(feature=FEATURE,objects=len(feature),object_ids=[str(o.Id) for o in feature],
        revision='Manually repositioned hoop, current-pose end extension',center_native=xyz(center),
        circle_plane_normal_native=xyz(first['frame'].Normal),outer_diameter_m=300.,
        bounds_native=[xyz(bounds.Min),xyz(bounds.Max)],band_bounds_native=[xyz(band_bounds.Min),xyz(band_bounds.Max)],
        ground_extension_report='ground_extension_report.json',changed_object_ids=[b['id'] for b in d['bands']],
        original_pose_and_arc_preserved=True,materials_and_attributes_preserved=True,
        unrelated_objects_unchanged=d['report']['unrelated_objects_unchanged'],game_import_updated=False,
        note='The previous bridge checks/cameras describe the archived first placement. This edit changes only the current three bands.',
        backup=d['backup_path']))
    options=Rhino.FileIO.FileWriteOptions();options.SuppressDialogBoxes=True;options.WriteSelectedObjectsOnly=True
    sc.doc.Objects.UnselectAll()
    try:
        for o in feature:sc.doc.Objects.Select(o.Id)
        assert sc.doc.Write3dmFile(OUT+'/landmark_ring.3dm',options)
    finally:sc.doc.Objects.UnselectAll()
    sc.doc.NamedViews.Add('LandmarkRing_CurrentPlacement_1101',sc.doc.Views.ActiveView.ActiveViewport.Id)
    assert Rhino.RhinoApp.RunScript('_-Save _Enter',False) and not sc.doc.Modified
    saved=Rhino.FileIO.File3dm.Read(sc.doc.Path);assert saved
    byid={str(o.Id):o for o in saved.Objects}
    assert all(int(byid[b['id']].Geometry.DataCRC(0))==int(sc.doc.Objects.FindId(System.Guid(b['id'])).Geometry.DataCRC(0)) for b in d['bands'])
    component=Rhino.FileIO.File3dm.Read(OUT+'/landmark_ring.3dm');assert component and len(list(component.Objects))==len(feature)
    return dict(main=sc.doc.Path,component=OUT+'/landmark_ring.3dm',saved_readback_verified=True)
