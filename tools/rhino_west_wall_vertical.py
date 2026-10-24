# -*- coding: utf-8 -*-
"""Replace only the old twisted right wall; keep the existing B tunnel intact.

Current live Rhino stages: prepare(), build(), publish(), verify(), save().
The adjoining already-cut left face is retained verbatim. No duplicate CAD.
"""
from __future__ import unicode_literals, division
import Rhino,scriptcontext as sc,System,json,io
G=Rhino.Geometry
TAG='west_wall_vertical_1020'
WALL='27172e67-243a-4398-9933-89de8ecae12d'
PRIOR='west_semi_open_tunnel_B_1020'
OUT='D:/Prism Route/prism-route/docs/concepts/west_wall_vertical_2026-10-20'

def objects():
    e=Rhino.DocObjects.ObjectEnumeratorSettings()
    e.NormalObjects=True;e.HiddenObjects=True;e.LockedObjects=True
    return list(sc.doc.Objects.GetObjectList(e))

def obj(key):return sc.doc.Objects.FindId(System.Guid(key))

def mesh(g):
    if isinstance(g,G.SubD):return G.Mesh.CreateFromSubD(g,2)
    m=G.Mesh()
    for q in G.Mesh.CreateFromBrep(g,G.MeshingParameters.FastRenderMesh):m.Append(q)
    return m

def prepare():
    assert TAG not in sc.sticky,'Do not reset staged originals'
    assert PRIOR in sc.sticky,'Need the existing tunnel excavation envelope'
    o=obj(WALL);assert o and o.Geometry.Faces.Count==2
    d={'before':{str(o.Id):int(o.Geometry.DataCRC(0))for o in objects()},
       'original':o.Geometry.DuplicateBrep(),
       'view':Rhino.DocObjects.ViewportInfo(sc.doc.Views.ActiveView.ActiveViewport),
       'display':sc.doc.Views.ActiveView.ActiveViewport.DisplayMode,
       'attrs':o.Attributes.Duplicate()}
    # Source profile predates tunnel trimming; final clipping uses its current envelope.
    source=sc.sticky[PRIOR]['source'][WALL]
    top=source.Edges[6].DuplicateCurve()
    b=top.GetBoundingBox(True);assert abs(b.Min.Z-60)<1e-6 and abs(b.Max.Z-60)<1e-6
    d['top']=top;d['cutter']=sc.sticky[PRIOR]['cutter'].DuplicateBrep()
    d['left']=o.Geometry.Faces[0].DuplicateFace(False)
    d['left_crc']=int(d['left'].DataCRC(0));sc.sticky[TAG]=d
    return {'wall':WALL,'rebuild_face':1,'top_length_m':top.GetLength(),
            'unchanged_tunnel':sc.sticky[PRIOR]['body_id'],'original_objects':len(d['before'])}

def build():
    d=sc.sticky[TAG];surface=G.Surface.CreateExtrusion(d['top'],G.Vector3d(0,0,-60.))
    assert surface;full=surface.ToBrep();assert full.IsValid
    # Match the original face orientation with a corresponding top-edge sample.
    old=d['original'].Faces[1]
    center=surface.PointAt(surface.Domain(0).Mid,surface.Domain(1).Mid)
    ok,u,v=old.ClosestPoint(center);assert ok
    if G.Vector3d.Multiply(surface.NormalAt(surface.Domain(0).Mid,surface.Domain(1).Mid),old.NormalAt(u,v))<0:full.Flip()
    pieces=full.Split(d['cutter'],.01)
    assert pieces and len(pieces)>1,'Tunnel excavation failed to split vertical wall'
    kept=[];removed=[];classify=[]
    for q in pieces:
        m=mesh(q);inside=0;total=0;step=max(1,int(m.Faces.Count/100))
        for i in range(0,m.Faces.Count,step):
            f=m.Faces[i]
            p=(G.Point3d(m.Vertices[f.A])+G.Point3d(m.Vertices[f.B])+G.Point3d(m.Vertices[f.C]))/3.
            p=q.ClosestPoint(p);total+=1
            if d['cutter'].IsPointInside(p,.015,False):inside+=1
        assert total
        remove=inside>total*.5
        (removed if remove else kept).append(q)
        classify.append({'samples':total,'inside':inside,'removed':remove})
    assert kept and removed
    result=G.Brep()
    result.Append(d['left'])
    for q in kept:result.Append(q)
    joined=G.Brep.JoinBreps([result],.005)
    if joined and len(joined)==1:result=joined[0]
    assert result.IsValid
    d.update(full_vertical=full,result=result,classification=classify)
    return {'pieces':len(pieces),'removed':len(removed),'kept':len(kept),
            'result_faces':result.Faces.Count,'valid':result.IsValid,'classification':classify}

def publish():
    d=sc.sticky[TAG];undo=sc.doc.BeginUndoRecord('旧扭转岸墙改为竖直侧壁并保留现有隧道开口')
    try:
        assert sc.doc.Objects.Replace(System.Guid(WALL),d['result'])
        a=d['attrs'].Duplicate();a.Name='西侧高台_竖直岸墙与现有隧道开口'
        a.SetUserString('vertical_wall_recipe',TAG)
        a.SetUserString('retained_face','Original adjacent left face, including existing gallery slot')
        assert sc.doc.Objects.ModifyAttributes(System.Guid(WALL),a,True)
    finally:sc.doc.EndUndoRecord(undo)
    sc.doc.Objects.UnselectAll();sc.doc.Views.Redraw()
    return {'replaced':WALL,'added_objects':0}

def verify():
    d=sc.sticky[TAG];now={str(o.Id):o for o in objects()}
    assert set(now)==set(d['before'])
    changed=[k for k,c in d['before'].items()if int(now[k].Geometry.DataCRC(0))!=c]
    assert changed==[WALL],changed
    assert now[WALL].Geometry.IsValid
    # Exact construction check: corresponding upper/lower locations have the same XY.
    s=d['full_vertical'].Faces[0];error=[];normals=[]
    for i in range(101):
        v=s.Domain(1).ParameterAt(i/100.)
        a=s.PointAt(s.Domain(0).T0,v);b=s.PointAt(s.Domain(0).T1,v)
        error.append(((a.X-b.X)**2+(a.Y-b.Y)**2)**.5)
        normals.append(abs(s.NormalAt(s.Domain(0).Mid,v).Z))
    assert max(error)<1e-7 and max(normals)<1e-7
    # Retained face copy, compared geometrically after joins can renumber topology.
    left=now[WALL].Geometry.Faces[0].DuplicateFace(False)
    a=G.AreaMassProperties.Compute(left);b=G.AreaMassProperties.Compute(d['left'])
    left_delta=abs(a.Area-b.Area);assert left_delta<1e-5
    # Reuse the actual road coordinates, but only test the changed wall here.
    ns={};p='D:/Prism Route/prism-route/tools/rhino_west_semi_open_tunnel.py'
    exec(compile(open(p,'rb').read().decode('utf-8'),p,'exec'),ns)
    prior=sc.sticky[PRIOR];m=mesh(now[WALL].Geometry);hits=[]
    for i in range(301):
        station=prior['length']*i/300.
        for y in [-9.6,0.,9.6]:
            p=ns['point'](station,y,35.30)
            q=G.Intersect.Intersection.MeshLine(m,G.Line(p,p+G.Vector3d(0,0,6.)))
            if q and len(q):hits.append([station,y])
    sightlines=[]
    for a,b in ns['WINDOWS']:
        station=(a+b)*.5
        for z in [38.,42.,47.]:
            p=ns['point'](station,-9.8,z);q=ns['point'](station,-ns['radius'](station)-10.,z)
            h=G.Intersect.Intersection.MeshLine(m,G.Line(p,q))
            sightlines.append({'station':station,'height':z,'blocked':bool(h and len(h))})
    report={'changed_originals':changed,'object_count':len(now),'added_objects':0,
            'vertical_xy_deviation_max_m':max(error),'normal_z_max':max(normals),
            'retained_face_area_difference':left_delta,
            'road_clearance_samples':903,'wall_intrusions':hits,'gallery_sightlines':sightlines,
            'tunnel_and_floor_geometry_unchanged':True,'wall_valid':True}
    d['report']=report;return report

def capture(name):
    d=sc.sticky[TAG];view=sc.doc.Views.ActiveView
    vc=Rhino.Display.ViewCapture();vc.Width=1600;vc.Height=1050
    vc.DrawAxes=False;vc.DrawGrid=False;vc.DrawGridAxes=False;vc.ScaleScreenItems=False
    bitmap=vc.CaptureToBitmap(view);assert bitmap
    path=OUT+'/'+name+'.png';bitmap.Save(path,System.Drawing.Imaging.ImageFormat.Png);bitmap.Dispose()
    return path

def save():
    d=sc.sticky[TAG];r=verify()
    assert not r['wall_intrusions']
    assert not any(s['blocked']for s in r['gallery_sightlines'])
    assert Rhino.RhinoApp.RunScript('_Save',False)
    return {'saved':sc.doc.Path,'modified':sc.doc.Modified}

def verify_saved():
    d=sc.sticky[TAG];file=Rhino.FileIO.File3dm.Read(sc.doc.Path);assert file
    saved={str(o.Id):int(o.Geometry.DataCRC(0))for o in file.Objects}
    current={str(o.Id):int(o.Geometry.DataCRC(0))for o in objects()}
    assert saved==current;file.Dispose()
    d['report']['saved_geometry_match']=True
    with io.open(OUT+'/validation.json','w',encoding='utf-8')as f:f.write(json.dumps(d['report'],ensure_ascii=False,indent=2))
    return {'saved_geometry_match':True,'objects':len(saved)}
