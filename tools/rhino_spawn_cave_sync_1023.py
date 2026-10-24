# -*- coding: utf-8 -*-
"""Read-only delta export of the four completed starting-area CAD objects."""
from __future__ import unicode_literals, division
import Rhino, scriptcontext as sc, System, io, json
G=Rhino.Geometry
ROOT='D:/Prism Route/prism-route'
CACHE=ROOT+'/.current_map_build'
IDS=['577d868b-7597-4058-83f8-4b630606b305','9713e301-b5a7-4acb-821d-d98484bc52de','4b6d5fc4-59f9-490c-9eaf-ecc252b3de46','66bd60fa-4f5b-458a-aa30-ad164b0f5d70']

def export():
 ns={'__file__':ROOT+'/tools/rhino_current_map_validation.py'}
 exec(compile(open(ns['__file__'],'rb').read().decode('utf-8'),ns['__file__'],'exec'),ns)
 opts=Rhino.FileIO.SerializationOptions()
 before={str(o.Id):(int(o.Geometry.DataCRC(0)),o.Attributes.ToJSON(opts))for o in ns['objects']()}
 records=[];stream=System.IO.FileStream(CACHE+'/spawn_cave_1023_patch.bin',System.IO.FileMode.Create);writer=System.IO.BinaryWriter(stream)
 p=G.MeshingParameters();p.SimplePlanes=True;p.RefineGrid=True;p.JaggedSeams=False
 p.GridMinCount=4;p.GridMaxCount=40;p.MaximumEdgeLength=2.;p.MinimumEdgeLength=.02;p.Tolerance=.008;p.RelativeTolerance=0;p.RefineAngle=.10
 try:
  for key in IDS:
   o=sc.doc.Objects.FindId(System.Guid(key));assert o and ns['visible'](o)
   for export_id,g,kind,extra in ns['mesh_parts'](o):
    m=G.Mesh()
    for q in G.Mesh.CreateFromBrep(g,p):m.Append(q)
    m.Faces.ConvertQuadsToTriangles();m.Normals.ComputeNormals();m.Compact();assert m.IsValid
    offset=stream.Position
    for array in [m.Vertices.ToFloatArray(),m.Faces.ToIntArray(True)]:
     raw=System.Array.CreateInstance(System.Byte,array.Length*4);System.Buffer.BlockCopy(array,0,raw,0,raw.Length);writer.Write(raw)
    row={'id':export_id,'name':(o.Name or'')+('_'+extra['mesh_part']if extra else''),'layer':sc.doc.Layers[o.Attributes.LayerIndex].FullPath,'kind':kind,
     'offset':int(offset),'vertex_count':m.Vertices.Count,'index_count':m.Faces.Count*3,'bounds':[ns['xyz'](m.GetBoundingBox(True).Min),ns['xyz'](m.GetBoundingBox(True).Max)],'collision':True}
    row.update(extra);records.append(row)
 finally:writer.Close()
 after={str(o.Id):(int(o.Geometry.DataCRC(0)),o.Attributes.ToJSON(opts))for o in ns['objects']()}
 assert before==after,'CAD changed during read-only export'
 result={'source':sc.doc.Path,'cad_object_count':len(before),'cad_unchanged':True,'objects':records,'native_center':[1450,1150,0]}
 with io.open(CACHE+'/spawn_cave_1023_patch.json','w',encoding='utf-8')as f:f.write(json.dumps(result,ensure_ascii=False,indent=2))
 return {'objects':len(records),'triangles':sum(r['index_count']//3 for r in records),'cad_unchanged':True,'parts':[{'id':r['id'],'kind':r['kind'],'triangles':r['index_count']//3}for r in records]}
