# -*- coding: utf-8 -*-
"""Read-only delta export of the completed lagoon CAD edits."""
from __future__ import unicode_literals, division
import Rhino, scriptcontext as sc, System, io, json
G=Rhino.Geometry
ROOT='D:/Prism Route/prism-route'
CACHE=ROOT+'/.current_map_build'

def export():
    with io.open(ROOT+'/docs/concepts/lagoon_1025/model_report.json','r',encoding='utf-8') as f:
        report=json.load(f)
    ids=sorted(set(report['modified']+report['added']))
    path=ROOT+'/tools/rhino_current_map_validation.py'
    ns={'__file__':path}
    exec(compile(open(path,'rb').read().decode('utf-8'),path,'exec'),ns)
    opts=Rhino.FileIO.SerializationOptions()
    def fingerprint():
        return {str(o.Id):(int(o.Geometry.DataCRC(0)),o.Attributes.ToJSON(opts)) for o in ns['objects']()}
    before=fingerprint()
    records=[]
    stream=System.IO.FileStream(CACHE+'/lagoon_1026_patch.bin',System.IO.FileMode.Create)
    writer=System.IO.BinaryWriter(stream)
    p=G.MeshingParameters()
    p.SimplePlanes=True;p.RefineGrid=True;p.JaggedSeams=False
    p.GridMinCount=4;p.GridMaxCount=40;p.MaximumEdgeLength=8
    p.MinimumEdgeLength=.08;p.Tolerance=.04;p.RelativeTolerance=0;p.RefineAngle=.10
    try:
        for key in ids:
            o=sc.doc.Objects.FindId(System.Guid(key))
            assert o and ns['visible'](o)
            for export_id,g,kind,extra in ns['mesh_parts'](o):
                mesh=G.Mesh()
                for part in G.Mesh.CreateFromBrep(g,p):mesh.Append(part)
                mesh.Faces.ConvertQuadsToTriangles();mesh.Normals.ComputeNormals();mesh.Compact()
                assert mesh.IsValid
                offset=stream.Position
                for array in [mesh.Vertices.ToFloatArray(),mesh.Faces.ToIntArray(True)]:
                    raw=System.Array.CreateInstance(System.Byte,array.Length*4)
                    System.Buffer.BlockCopy(array,0,raw,0,raw.Length);writer.Write(raw)
                row={'id':export_id,'name':o.Name or '','layer':sc.doc.Layers[o.Attributes.LayerIndex].FullPath,
                    'kind':kind,'offset':int(offset),'vertex_count':mesh.Vertices.Count,
                    'index_count':mesh.Faces.Count*3,'bounds':[ns['xyz'](mesh.GetBoundingBox(True).Min),
                    ns['xyz'](mesh.GetBoundingBox(True).Max)],'collision':kind!='Water'}
                row.update(extra);records.append(row)
    finally:writer.Close()
    assert fingerprint()==before,'CAD changed during export'
    assert all(not sc.doc.Objects.FindId(System.Guid(k))for k in report['removed'])
    result={'source':sc.doc.Path,'cad_object_count':len(before),'cad_unchanged':True,
        'objects':records,'removed':report['removed'],'native_center':[1450,1150,0]}
    with io.open(CACHE+'/lagoon_1026_patch.json','w',encoding='utf-8')as f:
        f.write(json.dumps(result,ensure_ascii=False,indent=2))
    return {'objects':len(records),'triangles':sum(r['index_count']//3 for r in records),
        'removed':len(report['removed']),'cad_unchanged':True,
        'parts':[{'id':r['id'],'kind':r['kind'],'triangles':r['index_count']//3}for r in records]}
