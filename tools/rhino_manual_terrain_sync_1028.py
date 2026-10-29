# -*- coding: utf-8 -*-
"""Staged, read-only export of the six manual terrain surfaces."""
from __future__ import unicode_literals, division
import Rhino, scriptcontext as sc, System, io, json, os
G=Rhino.Geometry
ROOT='D:/Prism Route/prism-route'
CACHE=ROOT+'/.current_map_build'
OUT=ROOT+'/assets/world/current_map_validation/review'
TAG='manual_terrain_sync_1028'
IDS=['a26c788a-585d-4a98-befc-a6c7cc8083e7','920c8a45-b23e-4260-9aab-86333f61b992',
     '95094d17-bdb0-4407-bdca-d26ab1deaad7','0280eafa-4058-40dd-8cf0-36b575adcb14',
     '0e79433e-80e9-48f1-ab77-3786fdc3819f','b0a0f593-d5d4-40ae-b182-36858b4a653a']

def fingerprint():
    options=Rhino.FileIO.SerializationOptions()
    return dict((str(o.Id),(int(o.Geometry.DataCRC(0)),o.Attributes.ToJSON(options))) for o in sc.doc.Objects)

def prepare():
    path=ROOT+'/tools/rhino_current_map_validation.py';ns={'__file__':path}
    exec(compile(open(path,'rb').read().decode('utf-8'),path,'exec'),ns)
    for sid in IDS:
        o=sc.doc.Objects.FindId(System.Guid(sid));assert o and ns['visible'](o)
        assert ns['kind'](o)=='Terrain','Manual layer needs Terrain semantics'
    sc.sticky[TAG]={'before':fingerprint(),'records':[],'probes':[],'ns':ns,'done':[]}
    stream=System.IO.FileStream(CACHE+'/manual_terrain_1028_patch.bin',System.IO.FileMode.Create);stream.Close()
    return {'surfaces':len(IDS),'cad_objects':len(sc.sticky[TAG]['before'])}

def export_one(index):
    w=sc.sticky[TAG];assert index==len(w['done'])
    sid=IDS[index];o=sc.doc.Objects.FindId(System.Guid(sid));assert o
    p=G.MeshingParameters();p.SimplePlanes=True;p.RefineGrid=True;p.JaggedSeams=False
    p.GridMinCount=4;p.GridMaxCount=40;p.MaximumEdgeLength=8;p.MinimumEdgeLength=.08
    p.Tolerance=.04;p.RelativeTolerance=0;p.RefineAngle=.10
    mesh=G.Mesh()
    for q in G.Mesh.CreateFromBrep(o.Geometry,p):mesh.Append(q)
    mesh.Faces.ConvertQuadsToTriangles();mesh.Normals.ComputeNormals();mesh.Compact();assert mesh.IsValid
    # These six objects are terrain height fields, with no underside faces.
    zsum=sum(float(n.Z)for n in mesh.Normals)
    flipped=zsum<0
    if flipped:mesh.Flip(True,True,True)
    stream=System.IO.FileStream(CACHE+'/manual_terrain_1028_patch.bin',System.IO.FileMode.Append)
    writer=System.IO.BinaryWriter(stream);offset=int(stream.Position)
    try:
        for array in [mesh.Vertices.ToFloatArray(),mesh.Faces.ToIntArray(True)]:
            raw=System.Array.CreateInstance(System.Byte,array.Length*4)
            System.Buffer.BlockCopy(array,0,raw,0,raw.Length);writer.Write(raw)
    finally:writer.Close()
    b=mesh.GetBoundingBox(True)
    xyz=lambda p:[float(p.X),float(p.Y),float(p.Z)]
    name=o.Name or 'UserAuthoredHill'
    row={'id':sid,'name':name,'layer':sc.doc.Layers[o.Attributes.LayerIndex].FullPath,'kind':'Terrain',
         'offset':offset,'vertex_count':mesh.Vertices.Count,'index_count':mesh.Faces.Count*3,
         'bounds':[xyz(b.Min),xyz(b.Max)],'collision':True}
    w['records'].append(row)
    # Independent barycentric samples on the exact game-export mesh, above the old ground.
    samples=[];ground=sc.sticky.get('microterrain1028_work',{}).get('ground')
    for k in range(0,mesh.Faces.Count,max(1,mesh.Faces.Count//1800)):
        face=mesh.Faces[k];a=G.Point3d(mesh.Vertices[face.A]);bb=G.Point3d(mesh.Vertices[face.B]);c=G.Point3d(mesh.Vertices[face.C])
        center=(a+bb+c)/3.;normal=G.Vector3d.CrossProduct(bb-a,c-a);normal.Unitize()
        if normal.Z<.65:continue
        if ground:
            t=G.Intersect.Intersection.MeshRay(ground,G.Ray3d(G.Point3d(center.X,center.Y,400),G.Vector3d(0,0,-1)))
            if t<0 or center.Z-(400-t)<1.:continue
        samples.append(xyz(center)+[float(normal.Z)])
    assert len(samples)>=8
    w['probes'].append({'id':sid,'name':name,'samples':samples})
    w['done'].append(sid)
    return {'index':index,'id':sid,'triangles':mesh.Faces.Count,'probes':len(samples),'export_winding_flipped':flipped}

def finish():
    w=sc.sticky[TAG];assert len(w['done'])==len(IDS)
    assert fingerprint()==w['before'],'CAD changed during export'
    result={'source':sc.doc.Path,'cad_object_count':len(w['before']),'cad_unchanged':True,
            'objects':w['records'],'native_center':[1450,1150,0]}
    with io.open(CACHE+'/manual_terrain_1028_patch.json','w',encoding='utf-8') as f:f.write(json.dumps(result,ensure_ascii=False,indent=2))
    with io.open(OUT+'/manual_terrain_1028_probes.json','w',encoding='utf-8') as f:f.write(json.dumps(w['probes'],ensure_ascii=False))
    return {'objects':len(w['records']),'triangles':sum(r['index_count']//3 for r in w['records']),'cad_unchanged':True}
