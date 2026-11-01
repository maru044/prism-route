# -*- coding: utf-8 -*-
"""Read-only export of the 31 reviewed native terrace pieces."""
from __future__ import unicode_literals, division
import Rhino,scriptcontext as sc,System,io,json,os
G=Rhino.Geometry
ROOT='D:/Prism Route/prism-route'
CACHE=ROOT+'/.current_map_build/terrace_ruins_1101'
TAG='terrace_curved_ruins_1101'
def objects():
    e=Rhino.DocObjects.ObjectEnumeratorSettings();e.NormalObjects=True;e.HiddenObjects=True;e.LockedObjects=True
    return [o for o in sc.doc.Objects.GetObjectList(e) if not o.IsDeleted]
def fingerprint():
    opts=Rhino.FileIO.SerializationOptions()
    return {str(o.Id):(int(o.Geometry.DataCRC(0)),o.Attributes.ToJSON(opts)) for o in objects()}
def xyz(p):return [float(p.X),float(p.Y),float(p.Z)]
def export():
    before=fingerprint();modified=sc.doc.Modified
    owned=sorted([o for o in objects() if o.Attributes.GetUserString('feature')==TAG],key=lambda o:o.Name)
    assert len(owned)==31,'Unexpected native inventory'
    if not os.path.exists(CACHE):os.makedirs(CACHE)
    source=dict(source=sc.doc.Path,feature=TAG,native_center=[1450.,1150.,0.],objects=[],materials={},routes={},probes=[])
    builder={};path=ROOT+'/tools/rhino_terrace_curved_ruins_1101.py'
    exec(compile(open(path,'rb').read(),path,'exec'),builder)
    path_controls={name:pts for name,pts,zs,ze in builder['PATH_DEFINITIONS']}
    stream=System.IO.FileStream(CACHE+'/source.bin',System.IO.FileMode.Create);writer=System.IO.BinaryWriter(stream)
    def array(values):
        raw=System.Array.CreateInstance(System.Byte,values.Length*4);System.Buffer.BlockCopy(values,0,raw,0,raw.Length);writer.Write(raw)
    mp=G.MeshingParameters();mp.Tolerance=.01;mp.MaximumEdgeLength=.5;mp.RefineGrid=True
    try:
        for o in owned:
            mesh=o.Geometry.DuplicateMesh() if isinstance(o.Geometry,G.Mesh) else G.Mesh()
            if not isinstance(o.Geometry,G.Mesh):
                for part in G.Mesh.CreateFromBrep(o.Geometry,mp):mesh.Append(part)
            mesh.Faces.ConvertQuadsToTriangles();mesh.Normals.ComputeNormals();mesh.Compact()
            assert mesh.IsValid and mesh.IsClosed
            cat=o.Attributes.GetUserString('category');key=o.Attributes.GetUserString('material_key')
            mat=sc.doc.Materials[o.Attributes.MaterialIndex];c=mat.DiffuseColor
            source['materials'][key]=dict(color=[c.R/255.,c.G/255.,c.B/255.],roughness=float(mat.PhysicallyBased.Roughness),metallic=float(mat.PhysicallyBased.Metallic))
            offset=int(stream.Position);array(mesh.Vertices.ToFloatArray());array(mesh.Faces.ToIntArray(True))
            normal_offset=int(stream.Position);array(mesh.Normals.ToFloatArray())
            b=mesh.GetBoundingBox(True)
            source['objects'].append(dict(id=str(o.Id),name=o.Name,category=cat,kind='Structure',material_key=key,
                offset=offset,normal_offset=normal_offset,vertex_count=mesh.Vertices.Count,index_count=mesh.Faces.Count*3,
                bounds=[xyz(b.Min),xyz(b.Max)],collision=cat!='04_metal',watertight=True))
            if cat=='05_paths':
                # Unwelding duplicates and reorders mesh vertices. Reconstruct
                # the exact analytic XY centreline, then sample this real mesh.
                name=o.Name.replace('PR_TerraceRuins_','');pts=[G.Point3d(x,y,0) for x,y in path_controls[name]]
                route=[]
                for i in range(201):
                    p=builder['bezier'](pts,i/200.);p.Z=150.
                    t=G.Intersect.Intersection.MeshRay(mesh,G.Ray3d(p,-G.Vector3d.ZAxis));assert t>=0
                    p.Z=150.-t;route.append(xyz(p))
                source['routes'][name]=route
            if cat in ['01_foundation','05_paths']:
                samples=[]
                for i in range(0,mesh.Faces.Count,max(1,mesh.Faces.Count//160)):
                    f=mesh.Faces[i];a=G.Point3d(mesh.Vertices[f.A]);b=G.Point3d(mesh.Vertices[f.B]);c=G.Point3d(mesh.Vertices[f.C]);n=G.Vector3d.CrossProduct(b-a,c-a)
                    if n.Unitize() and n.Z>.85:samples.append(xyz(a+(b-a)/3.+(c-a)/3.))
                source['probes'].append(dict(id=str(o.Id),name=o.Name,samples=samples))
    finally:writer.Close()
    assert before==fingerprint() and sc.doc.Modified==modified,'Read-only export changed CAD'
    source['cad_unchanged']=True
    with io.open(CACHE+'/source.json','w',encoding='utf-8') as f:f.write(json.dumps(source,ensure_ascii=False,indent=2))
    return dict(objects=len(owned),triangles=sum(r['index_count']//3 for r in source['objects']),cad_unchanged=True)
