# -*- coding: utf-8 -*-
"""Apply the reviewed Z-only fit to one bridge; never create a full CAD backup."""
from __future__ import unicode_literals,division
import Rhino,scriptcontext as sc,System,io,json,os
G=Rhino.Geometry
ROOT='D:/Prism Route/prism-route'
CACHE=ROOT+'/.current_map_build/road_junction_1104'
SID='0808d32c-6ebc-4105-9258-a0f755ac2752'
KEY='road_junction_1104_site'

def prepare():
    """Read-only fitting input, for the original 80-column bridge surface only."""
    obj=sc.doc.Objects.FindId(System.Guid(SID));surface=obj.Geometry.Faces[0].ToNurbsSurface()
    assert surface.Points.CountV==80,'Already repaired; do not fit or apply twice.'
    road=sc.doc.Objects.FindId(System.Guid('ee277b2d-e4eb-4d39-80e6-c5d8a5d87d70'))
    mp=G.MeshingParameters();mp.Tolerance=.01;mp.MaximumEdgeLength=2.;mp.RefineGrid=True
    mesh=G.Mesh()
    for part in G.Mesh.CreateFromBrep(road.Geometry,mp):mesh.Append(part)
    sc.sticky[KEY]={'bridge':obj.Geometry.DuplicateBrep(),'bridge_attributes':obj.Attributes.Duplicate(),
                    'road':road.Geometry.DuplicateBrep(),'road_mesh':mesh,
                    'before':{str(o.Id):int(o.Geometry.DataCRC(0)) for o in sc.doc.Objects}}
    if not os.path.isdir(CACHE):os.makedirs(CACHE)
    road_samples=[]
    for y in range(680,831,5):
        for x in range(1630,1731,5):
            t=G.Intersect.Intersection.MeshRay(mesh,G.Ray3d(G.Point3d(x,y,100),-G.Vector3d.ZAxis))
            if t>=0:road_samples.append([x,y,100-t])
    with io.open(CACHE+'/road_samples.json','w',encoding='utf8') as f:f.write(json.dumps(road_samples))
    end=surface.Domain(1).T1
    for back in [55,45,35,25,18,14,10,7,4,2]:surface.KnotsV.InsertKnot(end-back)
    sc.sticky[KEY]['candidate_surface']=surface
    cp=[[[p.Location.X,p.Location.Y,p.Location.Z] for p in [surface.Points.GetControlPoint(i,j) for j in range(surface.Points.CountV)]] for i in range(surface.Points.CountU)]
    samples=[]
    for back in range(801):
        for k in range(9):
            u=surface.Domain(0).ParameterAt(k/8.);v=end-back*.1;p=surface.PointAt(u,v)
            samples.append([u,v,p.X,p.Y,p.Z])
    data={'cp':cp,'knots_u':list(surface.KnotsU),'knots_v':list(surface.KnotsV),
          'degree_u':surface.Degree(0),'degree_v':surface.Degree(1),'end':end,'samples':samples}
    with io.open(CACHE+'/fit_input.json','w',encoding='utf8') as f:f.write(json.dumps(data))
    return {'samples':len(samples),'road_samples':len(road_samples),'cad_unchanged':True}

def apply():
    state=sc.sticky[KEY];surface=state['candidate_surface'].Duplicate().ToNurbsSurface()
    with io.open(CACHE+'/fit_output.json',encoding='utf8') as f:data=json.load(f)
    for i,column in enumerate(data['cp']):
        for j,p in enumerate(column):surface.Points.SetPoint(i,j,G.Point3d(*p))
    brep=surface.ToBrep()
    if brep.Faces[0].OrientationIsReversed!=state['bridge'].Faces[0].OrientationIsReversed:brep.Flip()
    assert brep.IsValid
    # Validate against actual coastal-road mesh, including its oblique entry edge.
    errors=[];outside=[];maximum_xy=0.;far_error=0.
    old=state['bridge'].Faces[0];new=brep.Faces[0];u=new.Domain(0);v=new.Domain(1)
    for back in range(0,801):
        for k in range(9):
            uv=(u.ParameterAt(k/8.),v.T1-back*.1);p=new.PointAt(*uv);q=old.PointAt(*uv)
            maximum_xy=max(maximum_xy,((p.X-q.X)**2+(p.Y-q.Y)**2)**.5)
            if back>=550:far_error=max(far_error,p.DistanceTo(q))
            if back>180:continue
            t=G.Intersect.Intersection.MeshRay(state['road_mesh'],G.Ray3d(G.Point3d(p.X,p.Y,100),-G.Vector3d.ZAxis))
            if t>=0:errors.append(abs(p.Z-(100-t)))
    assert maximum_xy<1e-8 and far_error<1e-8 and max(errors)<.003
    undo=sc.doc.BeginUndoRecord('Local bridge junction Z repair')
    try:assert sc.doc.Objects.Replace(System.Guid(SID),brep)
    finally:sc.doc.EndUndoRecord(undo)
    after={str(o.Id):int(o.Geometry.DataCRC(0)) for o in sc.doc.Objects}
    changed=[sid for sid in after if after[sid]!=state['before'].get(sid)]
    assert changed==[SID] and len(after)==len(state['before'])
    state['report']=data['report'];state['report'].update(native_overlap_samples=len(errors),native_overlap_error_m=max(errors),far_geometry_error_m=far_error,xy_error_m=maximum_xy,changed_ids=changed)
    sc.doc.Views.Redraw()
    return state['report']

def export():
    state=sc.sticky[KEY];obj=sc.doc.Objects.FindId(System.Guid(SID))
    mp=G.MeshingParameters();mp.Tolerance=.002;mp.MaximumEdgeLength=2.;mp.MinimumEdgeLength=.03;mp.RefineGrid=True
    mesh=G.Mesh()
    for part in G.Mesh.CreateFromBrep(obj.Geometry,mp):mesh.Append(part)
    mesh.UnifyNormals();mesh.Normals.ComputeNormals();mesh.Faces.ConvertQuadsToTriangles();mesh.Compact()
    # Road is a two-sided open surface; export upward normals.
    if sum(n.Z for n in mesh.Normals)<0:mesh.Flip(True,True,True)
    assert mesh.IsValid
    writer=System.IO.BinaryWriter(System.IO.File.Open(CACHE+'/source.bin',System.IO.FileMode.Create))
    def array(values):
        raw=System.Array.CreateInstance(System.Byte,values.Length*4);System.Buffer.BlockCopy(values,0,raw,0,raw.Length);writer.Write(raw)
    try:
        array(mesh.Vertices.ToFloatArray());array(mesh.Faces.ToIntArray(True));normal_offset=int(writer.BaseStream.Position);array(mesh.Normals.ToFloatArray())
    finally:writer.Close()
    row={'id':SID,'name':obj.Name,'kind':'Road','collision':True,'offset':0,'normal_offset':normal_offset,'vertex_count':mesh.Vertices.Count,'index_count':mesh.Faces.Count*3}
    source={'source':sc.doc.Path,'objects':[row],'replaced_ids':[SID],'repair':state['report']}
    with io.open(CACHE+'/source.json','w',encoding='utf8') as f:f.write(json.dumps(source,ensure_ascii=False,indent=2))
    return {'triangles':mesh.Faces.Count,'vertices':mesh.Vertices.Count}

def save():
    assert sc.doc.Path.replace('\\','/').lower()=='d:/prism route/map/map_current.3dm'
    assert Rhino.RhinoApp.RunScript('_-Save _Enter',False)
    return {'path':sc.doc.Path,'modified':sc.doc.Modified}
