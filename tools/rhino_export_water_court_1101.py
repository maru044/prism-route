# -*- coding: utf-8 -*-
"""Read-only export of the reviewed shallow-water court and real exit ramp."""
from __future__ import unicode_literals, division
import Rhino,scriptcontext as sc,System,io,json,os,math
G=Rhino.Geometry
ROOT='D:/Prism Route/prism-route'
CACHE=ROOT+'/.current_map_build/water_court_1101'
TAG='water_court_1101'
RAMP='3ece7c15-82db-4301-920c-2f1cd7097101'
BED='c5ae764e-2995-42f9-96a6-f0bf6c7420a6'

def objects():
    e=Rhino.DocObjects.ObjectEnumeratorSettings();e.NormalObjects=True;e.HiddenObjects=True;e.LockedObjects=True
    return [o for o in sc.doc.Objects.GetObjectList(e) if not o.IsDeleted]
def fingerprint():
    opts=Rhino.FileIO.SerializationOptions()
    return {str(o.Id):(int(o.Geometry.DataCRC(0)),o.Attributes.ToJSON(opts)) for o in objects()}
def xyz(p):return [float(p.X),float(p.Y),float(p.Z)]
def mesh_of(g,closed=True,max_edge=1.):
    if isinstance(g,G.Mesh):m=g.DuplicateMesh()
    else:
        m=G.Mesh();mp=G.MeshingParameters();mp.Tolerance=.01;mp.MaximumEdgeLength=max_edge;mp.RefineGrid=True
        for part in G.Mesh.CreateFromBrep(g,mp):m.Append(part)
    m.Faces.ConvertQuadsToTriangles();m.Normals.ComputeNormals();m.Compact()
    assert m.IsValid and (m.IsClosed or not closed)
    return m
def export():
    assert sc.doc.Path.replace('\\','/').lower()=='d:/prism route/map/map_current.3dm'
    before=fingerprint();modified=sc.doc.Modified
    owned=sorted([o for o in objects() if o.Attributes.GetUserString('feature')==TAG],key=lambda o:o.Name)
    reviewed=json.load(open(ROOT+'/docs/water_court_1101/model_report.json','r'))
    assert set(str(o.Id) for o in owned)==set(reviewed['object_ids']),'Native inventory changed; review before exporting'
    if not os.path.isdir(CACHE):os.makedirs(CACHE)
    source=dict(source=sc.doc.Path,feature=TAG,native_center=[1450.,1150.,0.],objects=[],materials={},probes=[],
        parameters=json.load(open(ROOT+'/docs/water_court_1101/parameters.json','r')),
        ramp_id=RAMP,bed_id=BED)
    stream=System.IO.FileStream(CACHE+'/source.bin',System.IO.FileMode.Create);writer=System.IO.BinaryWriter(stream)
    def array(values):
        raw=System.Array.CreateInstance(System.Byte,values.Length*4);System.Buffer.BlockCopy(values,0,raw,0,raw.Length);writer.Write(raw)
    try:
        for o in owned:
            m=mesh_of(o.Geometry);key=o.Attributes.GetUserString('material_key');cat=o.Attributes.GetUserString('category')
            mat=sc.doc.Materials[o.Attributes.MaterialIndex];c=mat.DiffuseColor;pbr=mat.PhysicallyBased
            row=dict(color=[c.R/255.,c.G/255.,c.B/255.],roughness=float(pbr.Roughness),metallic=float(pbr.Metallic),opacity=float(pbr.Opacity))
            if key in source['materials']:assert source['materials'][key]==row,'Material variants need individual keys'
            source['materials'][key]=row
            offset=int(stream.Position);array(m.Vertices.ToFloatArray());array(m.Faces.ToIntArray(True))
            normal_offset=int(stream.Position);array(m.Normals.ToFloatArray());b=m.GetBoundingBox(True)
            source['objects'].append(dict(id=str(o.Id),name=o.Name,category=cat,material_key=key,
                offset=offset,normal_offset=normal_offset,vertex_count=m.Vertices.Count,index_count=m.Faces.Count*3,
                bounds=[xyz(b.Min),xyz(b.Max)],watertight=True,
                collision=cat in ['01_shells','02_platforms','04_glazing','06_foundations']))
            if cat=='02_platforms':
                samples=[]
                for i in range(0,m.Faces.Count,max(1,m.Faces.Count//100)):
                    f=m.Faces[i];a=G.Point3d(m.Vertices[f.A]);b=G.Point3d(m.Vertices[f.B]);c=G.Point3d(m.Vertices[f.C])
                    n=G.Vector3d.CrossProduct(b-a,c-a)
                    if n.Unitize() and n.Z>.85:samples.append(xyz(a+(b-a)/3.+(c-a)/3.))
                source['probes'].append(dict(id=str(o.Id),samples=samples))
    finally:writer.Close()
    measured=sc.sticky.get('water_cove_measure_1101',{})
    ramp=measured.get(RAMP)
    if ramp is None:ramp=mesh_of(sc.doc.Objects.FindId(System.Guid(RAMP)).Geometry,max_edge=3.)
    bed=measured.get(BED)
    if bed is None:bed=mesh_of(sc.doc.Objects.FindId(System.Guid(BED)).Geometry,closed=False,max_edge=5.)
    route=[]
    for y in range(504,585,2):
        x=600.-9.*math.sin(math.pi*(y-500.)/240.)**2;z=[]
        for m in [ramp,bed]:
            t=G.Intersect.Intersection.MeshRay(m,G.Ray3d(G.Point3d(x,y,20.),-G.Vector3d.ZAxis))
            if t>=0:z.append(20.-t)
        assert z;route.append([x,float(y),max(z)])
    source['ramp_route']=route
    source['site_check']=json.load(open(ROOT+'/docs/water_court_1101/site_check.json','r'))
    assert before==fingerprint() and modified==sc.doc.Modified,'Read-only export changed CAD'
    source['cad_unchanged']=True
    with io.open(CACHE+'/source.json','w',encoding='utf-8') as f:f.write(json.dumps(source,ensure_ascii=False,indent=2))
    return dict(objects=len(owned),triangles=sum(r['index_count']//3 for r in source['objects']),cad_unchanged=True,ramp_samples=len(route))
