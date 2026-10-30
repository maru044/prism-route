# -*- coding: utf-8 -*-
"""Read-only, staged export of the tagged upper ring and its terrain."""
from __future__ import unicode_literals, division
import Rhino, scriptcontext as sc, System, io, json
G=Rhino.Geometry
ROOT='D:/Prism Route/prism-route'
CACHE=ROOT+'/.current_map_build'
TAG='upper_ring_export_1030'

def fingerprint():
    opts=Rhino.FileIO.SerializationOptions()
    settings=Rhino.DocObjects.ObjectEnumeratorSettings();settings.NormalObjects=True;settings.HiddenObjects=True;settings.LockedObjects=True
    return dict((str(o.Id),(int(o.Geometry.DataCRC(0)),o.Attributes.ToJSON(opts))) for o in sc.doc.Objects.GetObjectList(settings))

def prepare():
    objects=[o for o in sc.doc.Objects if o.Attributes.GetUserString('feature')=='upper_ring_pavilion_1030']
    assert len(objects)==539
    objects.sort(key=lambda o:o.Name)
    stream=System.IO.FileStream(CACHE+'/upper_ring_1030.bin',System.IO.FileMode.Create);stream.Close()
    sc.sticky[TAG]={'before':fingerprint(),'ids':[str(o.Id) for o in objects],'records':[],'probes':[]}
    return {'objects':len(objects),'source':sc.doc.Path}

def export_batch(start,end):
    d=sc.sticky[TAG];assert start==len(d['records'])
    param=G.MeshingParameters();param.SimplePlanes=True;param.RefineGrid=True;param.JaggedSeams=False
    param.GridMinCount=0;param.GridMaxCount=24;param.MaximumEdgeLength=4;param.MinimumEdgeLength=.04
    param.Tolerance=.025;param.RelativeTolerance=0.;param.RefineAngle=.12
    stream=System.IO.FileStream(CACHE+'/upper_ring_1030.bin',System.IO.FileMode.Append);writer=System.IO.BinaryWriter(stream)
    try:
        for sid in d['ids'][start:end]:
            obj=sc.doc.Objects.FindId(System.Guid(sid));category=obj.Attributes.GetUserString('category')
            if isinstance(obj.Geometry,G.Mesh):mesh=obj.Geometry.DuplicateMesh()
            else:
                mesh=G.Mesh()
                for part in G.Mesh.CreateFromBrep(obj.Geometry,param):mesh.Append(part)
            mesh.Faces.ConvertQuadsToTriangles();mesh.Normals.ComputeNormals();mesh.Compact()
            assert mesh.IsValid and mesh.Faces.Count>0
            offset=int(stream.Position)
            for array in [mesh.Vertices.ToFloatArray(),mesh.Faces.ToIntArray(True)]:
                raw=System.Array.CreateInstance(System.Byte,array.Length*4)
                System.Buffer.BlockCopy(array,0,raw,0,raw.Length);writer.Write(raw)
            b=mesh.GetBoundingBox(True);xyz=lambda p:[float(p.X),float(p.Y),float(p.Z)]
            material=sc.doc.Materials[obj.Attributes.MaterialIndex]
            row={'id':sid,'name':obj.Name,'category':category,'kind':'Terrain' if category=='terrain' else 'Structure',
                'material_key':material.Name.replace('PR_Ring_',''),'offset':offset,
                'vertex_count':mesh.Vertices.Count,'index_count':mesh.Faces.Count*3,
                'bounds':[xyz(b.Min),xyz(b.Max)],'collision':True}
            d['records'].append(row)
            samples=[]
            if category in ['terrain','08_paths','01_foundation','09_courtyard']:
                for i in range(0,mesh.Faces.Count,max(1,mesh.Faces.Count//32)):
                    f=mesh.Faces[i];a=G.Point3d(mesh.Vertices[f.A]);bb=G.Point3d(mesh.Vertices[f.B]);c=G.Point3d(mesh.Vertices[f.C])
                    n=G.Vector3d.CrossProduct(bb-a,c-a)
                    if n.Unitize() and n.Z>.75:samples.append(xyz((a+bb+c)/3.))
            if samples:d['probes'].append({'id':sid,'category':category,'name':obj.Name,'samples':samples})
    finally:writer.Close()
    return {'done':len(d['records']),'triangles':sum(r['index_count']//3 for r in d['records'])}

def finish():
    d=sc.sticky[TAG];assert len(d['records'])==539
    assert fingerprint()==d['before'],'Read-only export changed CAD'
    result={'source':sc.doc.Path,'cad_unchanged':True,'native_center':[1450,1150,0],'objects':d['records'],'probes':d['probes']}
    with io.open(CACHE+'/upper_ring_1030.json','w',encoding='utf-8') as f:f.write(json.dumps(result,ensure_ascii=False,indent=2))
    return {'objects':539,'triangles':sum(r['index_count']//3 for r in d['records']),'cad_unchanged':True}
