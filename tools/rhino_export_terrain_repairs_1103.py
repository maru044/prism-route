# -*- coding: utf-8 -*-
"""Read-only export of the three reviewed native terrain repairs."""
from __future__ import unicode_literals,division
import Rhino,scriptcontext as sc,System,io,json,os
G=Rhino.Geometry
ROOT='D:/Prism Route/prism-route'
CACHE=ROOT+'/.current_map_build/terrain_repairs_1103'
IDS=['63029da9-ce54-4539-92b0-2bd4600c85cc','71a23083-6bf7-48d6-9f40-c17f23ddc96b','e7a0e133-f284-4cd4-8796-349bb8638efc']
KEY='terrain_repairs_export_1103'

def fingerprint():
    opts=Rhino.FileIO.SerializationOptions()
    return {str(o.Id):(int(o.Geometry.DataCRC(0)),o.Attributes.ToJSON(opts)) for o in sc.doc.Objects}

def prepare():
    assert sc.doc.Path.replace('\\','/').lower()=='d:/prism route/map/map_current.3dm'
    if not os.path.isdir(CACHE):os.makedirs(CACHE)
    for sid in IDS:assert sc.doc.Objects.FindId(System.Guid(sid))
    open(CACHE+'/source.bin','wb').close()
    sc.sticky[KEY]={'before':fingerprint(),'modified':sc.doc.Modified,'rows':[]}
    return {'objects':len(IDS)}

def export_one(index):
    state=sc.sticky[KEY];assert len(state['rows'])==index
    sid=IDS[index];o=sc.doc.Objects.FindId(System.Guid(sid));geo=o.Geometry
    if isinstance(geo,G.SubD):mesh=G.Mesh.CreateFromSubD(geo,2)
    else:
        mesh=G.Mesh();mp=G.MeshingParameters();mp.Tolerance=.025;mp.MaximumEdgeLength=4.;mp.RefineGrid=True;mp.SimplePlanes=True
        for part in G.Mesh.CreateFromBrep(geo,mp):mesh.Append(part)
    mesh.UnifyNormals();mesh.Normals.ComputeNormals()
    if mesh.SolidOrientation()<0:mesh.Flip(True,True,True)
    mesh.Faces.ConvertQuadsToTriangles();mesh.Compact();assert mesh.IsValid and mesh.IsClosed
    stream=System.IO.FileStream(CACHE+'/source.bin',System.IO.FileMode.Append);writer=System.IO.BinaryWriter(stream)
    def array(values):
        raw=System.Array.CreateInstance(System.Byte,values.Length*4);System.Buffer.BlockCopy(values,0,raw,0,raw.Length);writer.Write(raw)
    try:
        offset=int(stream.Position);array(mesh.Vertices.ToFloatArray());array(mesh.Faces.ToIntArray(True))
        normal_offset=int(stream.Position);array(mesh.Normals.ToFloatArray())
    finally:writer.Close()
    bb=mesh.GetBoundingBox(True);xyz=lambda p:[float(p.X),float(p.Y),float(p.Z)]
    row={'id':sid,'name':o.Name,'kind':'Terrain','collision':True,'offset':offset,'normal_offset':normal_offset,
         'vertex_count':mesh.Vertices.Count,'index_count':mesh.Faces.Count*3,'bounds':[xyz(bb.Min),xyz(bb.Max)]}
    state['rows'].append(row)
    return {'index':index,'triangles':mesh.Faces.Count,'closed':mesh.IsClosed}

def finish():
    state=sc.sticky[KEY];assert len(state['rows'])==3
    assert state['before']==fingerprint() and state['modified']==sc.doc.Modified
    source={'source':sc.doc.Path,'native_center':[1450.,1150.,0.],'objects':state['rows'],
            'replaced_ids':[IDS[2]],'cad_unchanged':True}
    with io.open(CACHE+'/source.json','w',encoding='utf-8') as f:f.write(json.dumps(source,ensure_ascii=False,indent=2))
    return {'objects':3,'triangles':sum(r['index_count']//3 for r in state['rows']),'cad_unchanged':True}
