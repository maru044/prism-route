# -*- coding: utf-8 -*-
"""Read-only current Rhino context and footprint export for the Blender study."""
from __future__ import division, unicode_literals
import Rhino,scriptcontext as sc,System,json,io,os,math
G=Rhino.Geometry
OUT='D:/Prism Route/prism-route/docs/concepts/blender_terrain_1016_v01'
IDS=['9ed1bc59-e9fa-4024-8095-564d74c4c87c','92714fcc-8762-4105-8ee9-d6796c31dc9f',
     'c1228167-d010-44ad-8775-757dd4984934','e7a0e133-f284-4cd4-8796-349bb8638efc',
     '9c6e4638-fa65-4d06-b84d-21feb0ab3b1b','7f48c0e6-3eff-429b-b3b0-92d2ba679c0f',
     '0bec2de6-c09c-4d63-86b6-3c6a48d6f3bb','1d532d53-1e77-48a8-97d9-8eff168923b9',
     'adac435c-fe23-4fb1-98d3-e151d881ee4c']
FEATURE='9c6e4638-fa65-4d06-b84d-21feb0ab3b1b'

def poly(c,spacing=10):
    n=max(12,int(math.ceil(c.GetLength()/spacing)))
    return [[c.PointAtNormalizedLength(i/n).X,c.PointAtNormalizedLength(i/n).Y]for i in range(n)]

def run():
    if not os.path.isdir(OUT):os.makedirs(OUT)
    before=sc.doc.Modified;crc={str(o.Id):int(o.Geometry.DataCRC(0))for o in sc.doc.Objects if not o.IsDeleted}
    records=[];loops=[];feature=[];skipped=[]
    mp=G.MeshingParameters();mp.Tolerance=.20;mp.RelativeTolerance=0;mp.MaximumEdgeLength=22;mp.MinimumEdgeLength=.3
    mp.RefineGrid=True;mp.JaggedSeams=False;mp.SimplePlanes=True
    for o in sc.doc.Objects:
        if o.IsDeleted or o.IsHidden:continue
        a=o.Attributes;l=sc.doc.Layers[a.LayerIndex];visible=True;cur=l
        while cur:
            visible=visible and cur.IsVisible
            if cur.ParentLayerId==System.Guid.Empty:break
            cur=sc.doc.Layers.FindId(cur.ParentLayerId)
        if not visible:continue
        sid=str(o.Id);geo=o.Geometry;path=l.FullPath
        if isinstance(geo,G.Extrusion):geo=geo.ToBrep()
        if isinstance(geo,G.Mesh):parts=[geo.DuplicateMesh()]
        elif isinstance(geo,G.Brep):parts=G.Mesh.CreateFromBrep(geo,mp)
        elif isinstance(geo,G.SubD):parts=[G.Mesh.CreateFromSubD(geo,2)]
        else:
            skipped.append({'id':sid,'type':str(geo.ObjectType),'layer':path});continue
        mesh=G.Mesh()
        for part in parts or []:
            if part:mesh.Append(part)
        mesh.Faces.ConvertQuadsToTriangles();mesh.Vertices.CombineIdentical(True,True)
        mesh.Faces.CullDegenerateFaces();mesh.Normals.ComputeNormals();mesh.Compact()
        if not mesh.IsValid and isinstance(geo,G.Brep):
            mesh=G.Mesh()
            for part in G.Mesh.CreateFromBrep(geo,G.MeshingParameters.FastRenderMesh)or[]:mesh.Append(part)
            mesh.Faces.ConvertQuadsToTriangles();mesh.Normals.ComputeNormals();mesh.Compact()
        if not mesh.IsValid:
            if sid in IDS:raise RuntimeError('Invalid study source mesh: '+sid)
            skipped.append({'id':sid,'type':str(geo.ObjectType),'layer':path,'reason':'Invalid display mesh'});continue
        records.append({'id':sid,'name':a.Name or path,'layer':path,'study_source':sid in IDS,'feature_source':sid==FEATURE,
                        'vertices':[[float(v.X),float(v.Y),float(v.Z)]for v in mesh.Vertices],'triangles':[[int(f.A),int(f.B),int(f.C)]for f in mesh.Faces]})
        if sid in IDS:
            floor=min(geo.Faces,key=lambda f:f.NormalAt(f.Domain(0).Mid,f.Domain(1).Mid).Z)
            for loop in floor.Loops:
                c=loop.To3dCurve();c.Transform(G.Transform.PlanarProjection(G.Plane.WorldXY));loops.append(c)
                if sid==FEATURE:feature.append(c.DuplicateCurve())
    union=G.Curve.CreateBooleanUnion(loops,.02)
    footprints=[]
    for c in union:
        area=G.AreaMassProperties.Compute(c).Area
        if area<2:continue
        footprints.append({'points':poly(c,4),'area':area,'hole':c.ClosedCurveOrientation(G.Plane.WorldXY)==G.CurveOrientation.CounterClockwise})
    enlarged=[]
    for c in feature:
        area=G.AreaMassProperties.Compute(c).Area
        options=[]
        for signed in [-28.,28.]:
            for q in c.Offset(G.Plane.WorldXY,signed,.03,G.CurveOffsetCornerStyle.Round)or[]:
                ap=G.AreaMassProperties.Compute(q)
                if q.IsClosed and ap and ap.Area>area:options.append((ap.Area,q))
        q=min(options,key=lambda r:r[0])[1]if options else c
        enlarged.append({'points':poly(q,5),'area':G.AreaMassProperties.Compute(q).Area,'hole':False})
    vp=sc.doc.Views.ActiveView.ActiveViewport
    result={'source_document':sc.doc.Path,'units':str(sc.doc.ModelUnitSystem),'source_ids':IDS,'feature_id':FEATURE,
            'objects':records,'base_footprints':footprints,'feature_footprints':enlarged,
            'camera':{'location':[vp.CameraLocation.X,vp.CameraLocation.Y,vp.CameraLocation.Z],
                      'target':[vp.CameraTarget.X,vp.CameraTarget.Y,vp.CameraTarget.Z],'lens':vp.Camera35mmLensLength}}
    with io.open(OUT+'/rhino_input.json','w',encoding='utf-8')as h:h.write(unicode(json.dumps(result,ensure_ascii=False,separators=(',',':'))))
    unchanged=all(int(sc.doc.Objects.FindId(System.Guid(sid)).Geometry.DataCRC(0))==v for sid,v in crc.items())
    report={'objects':len(records),'triangles':sum(len(r['triangles'])for r in records),'footprints':[{'area':r['area'],'hole':r['hole']}for r in footprints],
            'all_source_geometry_unchanged':unchanged,'modified_flag_preserved':sc.doc.Modified==before,'skipped':skipped}
    with io.open(OUT+'/rhino_export_report.json','w',encoding='utf-8')as h:h.write(unicode(json.dumps(report,ensure_ascii=False,indent=2)))
    print(json.dumps(report,ensure_ascii=False))

if __name__=='__main__':run()
