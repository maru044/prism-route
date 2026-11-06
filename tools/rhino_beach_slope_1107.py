# -*- coding: utf-8 -*-
"""Stage a local NURBS beach-to-bed transition; never rerun old lagoon builders."""
from __future__ import division, unicode_literals
import Rhino, scriptcontext as sc, System, math, json, io
G = Rhino.Geometry
TAG = 'beach_slope_1107'
BED = 'a2b4d386-d01a-4559-a8f7-28e5c8b93563'
WATER = '3861e9e6-1993-4c9a-9445-ddd4e3b687a2'
ROOT = 'D:/Prism Route/prism-route'

def smooth(x):
    x=max(0.,min(1.,x));return x*x*x*(10.+x*(-15.+6.*x))

def prepare():
    source=sc.doc.Objects.FindId(System.Guid(BED)).Geometry
    assert int(source.DataCRC(0))==4236641155, 'This patch requires the audited original bed; inspect later edits instead of applying twice'
    assert source.Faces.Count==6, 'Inspect current geometry before rebuilding'
    water=sc.doc.Objects.FindId(System.Guid(WATER)).Geometry.Faces[0].OuterLoop.To3dCurve()
    high=source.Edges[5].DuplicateCurve()
    low=source.Edges[9].DuplicateCurve()
    if high.PointAtStart.DistanceTo(low.PointAtStart)>1.:low.Reverse()
    high=high.ToNurbsCurve()
    inner=high.DuplicateCurve().ToNurbsCurve()
    length=high.GetLength()
    for i in range(high.Points.Count):
        cp=high.Points[i];p=cp.Location
        ok,t=high.ClosestPoint(p);on=high.PointAt(t)
        a=high.GetLength(G.Interval(high.Domain.T0,t))/length
        tangent=high.TangentAt(t)
        normal=G.Vector3d(-tangent.Y,tangent.X,0);normal.Unitize()
        if water.Contains(on+normal*.5,G.Plane.WorldXY,.001)==G.PointContainment.Outside:normal=-normal
        width=14.*smooth(a*length/30.)*smooth((1.-a)*length/30.)
        q=p+normal*width
        ok,u,v=source.Faces[0].ClosestPoint(q);assert ok
        q.Z=source.Faces[0].PointAt(u,v).Z
        if i==0:q=low.PointAtStart
        if i==high.Points.Count-1:q=low.PointAtEnd
        inner.Points.SetPoint(i,q,cp.Weight)
    split=source.Faces[0].Split([inner],.01)
    sc.sticky[TAG+'_debug']={'inner':inner,'split':split,'source':source,'high':high,'low':low}
    assert split and split.Faces.Count==7, 'Expected seven faces after splitting floor'
    areas=[G.AreaMassProperties.Compute(f.DuplicateFace(False)).Area for f in split.Faces]
    retained=split.Faces[areas.index(max(areas))].DuplicateFace(False)
    # Compatible control nets keep every across-shore section aligned. The
    # quintic Bezier profile has horizontal tangents at both ends and no overshoot.
    surface=G.NurbsSurface.Create(3,high.IsRational,high.Order,6,high.Points.Count,6)
    for i in range(high.Knots.Count):surface.KnotsU[i]=high.Knots[i]
    for j in range(surface.KnotsV.Count):surface.KnotsV[j]=0. if j<5 else 1.
    for i in range(high.Points.Count):
        p=high.Points[i];q=inner.Points[i]
        for j in range(6):
            t=j/5.;z=0. if j<3 else q.Location.Z
            surface.Points.SetPoint(i,j,G.Point3d(p.Location.X+(q.Location.X-p.Location.X)*t,p.Location.Y+(q.Location.Y-p.Location.Y)*t,z),p.Weight)
    strips=[surface.ToBrep()]
    sf=strips[0].Faces[0]
    if sf.NormalAt(sf.Domain(0).Mid,sf.Domain(1).Mid).Z<0:strips[0].Flip()
    sections=[]
    pieces=[retained,strips[0]]+[source.Faces[i].DuplicateFace(False) for i in [1,2,3,5]]
    joined=G.Brep.JoinBreps(pieces,.01)
    assert joined and len(joined)==1 and joined[0].IsValid, 'Unjoined shore: do not publish'
    report={'source_id':BED,'width_m':14.,'end_taper_m':30.,'strip_length_m':high.GetLength(),
        'split_areas_m2':areas,'faces_before':6,'faces_after':joined[0].Faces.Count,
        'valid':joined[0].IsValid,'stage_only':True}
    sc.sticky[TAG]={'geometry':joined[0],'source_crc':int(source.DataCRC(0)),
        'report':report,'sections':sections,'strip':strips[0]}
    return report

def objects():
    e=Rhino.DocObjects.ObjectEnumeratorSettings()
    e.NormalObjects=True;e.HiddenObjects=True;e.LockedObjects=True
    return list(sc.doc.Objects.GetObjectList(e))

def fingerprint():
    opts=Rhino.FileIO.SerializationOptions()
    return {str(o.Id):(int(o.Geometry.DataCRC(0)),o.Attributes.ToJSON(opts)) for o in objects()}

def publish():
    d=sc.sticky[TAG];o=sc.doc.Objects.FindId(System.Guid(BED))
    assert int(o.Geometry.DataCRC(0))==d['source_crc'], 'Source changed; re-inspect'
    before=fingerprint();d['before_fingerprint']=before;record=sc.doc.BeginUndoRecord('Beach gentle underwater slope 1107')
    original_attributes=o.Attributes.Duplicate()
    try:
        assert sc.doc.Objects.Replace(o.Id,d['geometry'])
        assert sc.doc.Objects.ModifyAttributes(o.Id,original_attributes,True)
        after=fingerprint()
        d['after_fingerprint']=after
        assert set(before)==set(after), 'Object ID set changed'
        assert [k for k in before if before[k]!=after[k]]==[BED], 'Changed IDs: '+str([k for k in before if before[k]!=after[k]][:20])
        assert before[BED][1]==after[BED][1], 'Target attrs changed'
        d['report'].update(stage_only=False,objects_total=len(after),changed_ids=[BED],
            unrelated_geometry_and_attributes_unchanged=True,source_crc_before=d['source_crc'],
            source_crc_after=after[BED][0])
    finally:sc.doc.EndUndoRecord(record)
    sc.doc.Views.Redraw()
    return d['report']

def export():
    d=sc.sticky[TAG];before=fingerprint();b=sc.doc.Objects.FindId(System.Guid(BED)).Geometry
    assert int(b.DataCRC(0))==d['report']['source_crc_after']
    p=G.MeshingParameters();p.SimplePlanes=True;p.RefineGrid=True;p.JaggedSeams=False
    p.GridMinCount=4;p.GridMaxCount=40;p.MaximumEdgeLength=8
    p.MinimumEdgeLength=.08;p.Tolerance=.04;p.RelativeTolerance=0;p.RefineAngle=.10
    mesh=G.Mesh()
    for part in G.Mesh.CreateFromBrep(b,p):mesh.Append(part)
    mesh.Faces.ConvertQuadsToTriangles();mesh.Normals.ComputeNormals();mesh.Compact()
    assert mesh.IsValid
    path=ROOT+'/.current_map_build/beach_slope_1107'
    System.IO.Directory.CreateDirectory(path)
    stream=System.IO.FileStream(path+'/source.bin',System.IO.FileMode.Create)
    writer=System.IO.BinaryWriter(stream)
    try:
        for array in [mesh.Vertices.ToFloatArray(),mesh.Faces.ToIntArray(True)]:
            raw=System.Array.CreateInstance(System.Byte,array.Length*4)
            System.Buffer.BlockCopy(array,0,raw,0,raw.Length);writer.Write(raw)
    finally:writer.Close()
    bb=mesh.GetBoundingBox(True)
    row={'id':BED,'kind':'Sand','name':sc.doc.Objects.FindId(System.Guid(BED)).Name,
        'offset':0,'vertex_count':mesh.Vertices.Count,'index_count':mesh.Faces.Count*3,
        'bounds':[[bb.Min.X,bb.Min.Y,bb.Min.Z],[bb.Max.X,bb.Max.Y,bb.Max.Z]],'collision':True}
    result={'source':sc.doc.Path,'native_center':[1450,1150,0],'objects':[row],
        'report':d['report']}
    # Samples support a cheap world-space shoreline-distance texture; no UV unwrap.
    edge=sc.sticky[TAG+'_debug']['high'];ts=edge.DivideByLength(.5,True)
    result['shoreline_xy']=[[edge.PointAt(t).X,edge.PointAt(t).Y]for t in ts]
    assert before==fingerprint(),'Export changed CAD'
    with io.open(path+'/source.json','w',encoding='utf-8') as f:
        f.write(json.dumps(result,ensure_ascii=False,indent=2))
    return {'triangles':mesh.Faces.Count,'vertices':mesh.Vertices.Count,'cad_unchanged':True}
