# -*- coding: utf-8 -*-
"""Read-only incremental export of the authored ruin; run through the Rhino bridge."""
from __future__ import unicode_literals, division
import Rhino,scriptcontext as sc,System,io,json,os
ROOT='D:/Prism Route/prism-route'
CACHE=ROOT+'/.current_map_build'
CAD='D:/Prism Route/plans/architecture_concepts_1028/rhino_model_1029'
TAG='initial_ruin_export_1029'
G=Rhino.Geometry

def fingerprint():
    options=Rhino.FileIO.SerializationOptions()
    return dict((str(o.Id),(int(o.Geometry.DataCRC(0)),o.Attributes.ToJSON(options))) for o in sc.doc.Objects)

def prepare():
    with io.open(CAD+'/build_state.json','r',encoding='utf-8') as f:state=json.load(f)
    with io.open(CAD+'/placement_plan.json','r',encoding='utf-8') as f:plan=json.load(f)
    assert len(state['objects'])==328
    for row in state['objects']:assert sc.doc.Objects.FindId(System.Guid(row['id']))
    stream=System.IO.FileStream(CACHE+'/initial_ruin_1029.bin',System.IO.FileMode.Create);stream.Close()
    sc.sticky[TAG]={'before':fingerprint(),'state':state,'plan':plan,'records':[],'probes':[]}
    return {'objects':len(state['objects']),'source':sc.doc.Path}

def export_batch(start,end):
    w=sc.sticky[TAG];assert start==len(w['records'])
    param=G.MeshingParameters();param.SimplePlanes=True;param.RefineGrid=True;param.JaggedSeams=False
    param.GridMinCount=0;param.GridMaxCount=32;param.MaximumEdgeLength=8.;param.MinimumEdgeLength=.035
    param.Tolerance=.025;param.RelativeTolerance=0.;param.RefineAngle=.12
    stream=System.IO.FileStream(CACHE+'/initial_ruin_1029.bin',System.IO.FileMode.Append)
    writer=System.IO.BinaryWriter(stream)
    try:
        for row in w['state']['objects'][start:end]:
            obj=sc.doc.Objects.FindId(System.Guid(row['id']));mesh=G.Mesh()
            for part in G.Mesh.CreateFromBrep(obj.Geometry,param):mesh.Append(part)
            mesh.Faces.ConvertQuadsToTriangles();mesh.Normals.ComputeNormals();mesh.Compact()
            assert mesh.IsValid and mesh.Faces.Count>0
            offset=int(stream.Position)
            for array in [mesh.Vertices.ToFloatArray(),mesh.Faces.ToIntArray(True)]:
                raw=System.Array.CreateInstance(System.Byte,array.Length*4)
                System.Buffer.BlockCopy(array,0,raw,0,raw.Length);writer.Write(raw)
            box=mesh.GetBoundingBox(True);xyz=lambda p:[float(p.X),float(p.Y),float(p.Z)]
            material=sc.doc.Materials[obj.Attributes.MaterialIndex]
            key=material.Name.replace('PR_Ruin1029_','')
            record=dict(row,layer=sc.doc.Layers[obj.Attributes.LayerIndex].FullPath,kind='Structure',
                material_key=key,collision=key!='cyan',offset=offset,
                vertex_count=mesh.Vertices.Count,index_count=mesh.Faces.Count*3,bounds=[xyz(box.Min),xyz(box.Max)])
            w['records'].append(record)
            # Independent source mesh samples for imported collision verification.
            samples=[]
            for i in range(0,mesh.Faces.Count,max(1,mesh.Faces.Count//12)):
                f=mesh.Faces[i];a=G.Point3d(mesh.Vertices[f.A]);b=G.Point3d(mesh.Vertices[f.B]);c=G.Point3d(mesh.Vertices[f.C])
                n=G.Vector3d.CrossProduct(b-a,c-a)
                if not n.Unitize() or n.Z<.72:continue
                center=(a+b+c)/3.;samples.append(xyz(center))
            if samples and key!='cyan':w['probes'].append({'id':row['id'],'name':row['name'],'samples':samples})
    finally:writer.Close()
    return {'done':len(w['records']),'triangles':sum(r['index_count']//3 for r in w['records'])}

def finish():
    w=sc.sticky[TAG];assert len(w['records'])==328
    assert fingerprint()==w['before'],'CAD changed during read-only export'
    result={'source':sc.doc.Path,'native_center':[1450,1150,0],
        'cad_unchanged':True,'cad_object_count':len(w['before']),
        'objects':w['records'],'probes':w['probes'],'placement':w['plan'],
        'summon_anchor':w['state']['checks']['summon_anchor']}
    with io.open(CACHE+'/initial_ruin_1029.json','w',encoding='utf-8') as f:f.write(json.dumps(result,ensure_ascii=False,indent=2))
    return {'objects':328,'triangles':sum(r['index_count']//3 for r in w['records']),'cad_unchanged':True}
