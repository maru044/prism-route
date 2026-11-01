# -*- coding: utf-8 -*-
"""Read-only native export: three circular bands and four connection remnants."""
from __future__ import unicode_literals,division
import Rhino,scriptcontext as sc,System,json,io,os
G=Rhino.Geometry
ROOT='D:/Prism Route/prism-route'
CACHE=ROOT+'/.current_map_build/landmark_ring_1101'
TAG='landmark_ring_1101'
def objects():
    e=Rhino.DocObjects.ObjectEnumeratorSettings();e.NormalObjects=True;e.HiddenObjects=True;e.LockedObjects=True
    return [o for o in sc.doc.Objects.GetObjectList(e) if not o.IsDeleted]
def fingerprint():
    opt=Rhino.FileIO.SerializationOptions()
    return {str(o.Id):(int(o.Geometry.DataCRC(0)),o.Attributes.ToJSON(opt)) for o in objects()}
def xyz(p):return [float(p.X),float(p.Y),float(p.Z)]
def mesh_of(geo,mp):
    if isinstance(geo,G.Mesh):m=geo.DuplicateMesh()
    else:
        m=G.Mesh()
        for piece in G.Mesh.CreateFromBrep(geo,mp):m.Append(piece)
    m.Faces.ConvertQuadsToTriangles();m.Normals.ComputeNormals();m.Compact()
    assert m.IsValid and m.Faces.Count>0
    return m
def export():
    before=fingerprint();modified=sc.doc.Modified
    owned=sorted([o for o in objects() if o.Attributes.GetUserString('feature')==TAG],key=lambda o:o.Name)
    assert len(owned)==7,'Unexpected ring inventory'
    if not os.path.exists(CACHE):os.makedirs(CACHE)
    with io.open(ROOT+'/docs/landmark_ring_1101/parameters.json','r',encoding='utf-8') as f:parameters=json.load(f)
    source=dict(source=sc.doc.Path,feature=TAG,native_center=[1450.,1150.,0.],objects=[],materials={},parameters=parameters)
    mp=G.MeshingParameters();mp.Tolerance=.02;mp.RelativeTolerance=0.;mp.MaximumEdgeLength=5.;mp.MinimumEdgeLength=.04
    mp.RefineAngle=.05;mp.RefineGrid=True;mp.SimplePlanes=True;mp.JaggedSeams=False
    stream=System.IO.FileStream(CACHE+'/source.bin',System.IO.FileMode.Create);writer=System.IO.BinaryWriter(stream)
    def array(values):
        data=System.Array.CreateInstance(System.Byte,values.Length*4)
        System.Buffer.BlockCopy(values,0,data,0,data.Length);writer.Write(data)
    try:
        for o in owned:
            m=mesh_of(o.Geometry,mp);assert m.IsClosed
            material=sc.doc.Materials[o.Attributes.MaterialIndex];key=material.Name.replace('PR_Saddle_','');c=material.DiffuseColor
            source['materials'][key]=dict(color=[c.R/255.,c.G/255.,c.B/255.],roughness=float(material.PhysicallyBased.Roughness),metallic=float(material.PhysicallyBased.Metallic),opacity=1.)
            offset=int(stream.Position);array(m.Vertices.ToFloatArray());array(m.Faces.ToIntArray(True))
            normal_offset=int(stream.Position);array(m.Normals.ToFloatArray());b=m.GetBoundingBox(True)
            category=o.Attributes.GetUserString('category')
            source['objects'].append(dict(id=str(o.Id),name=o.Name,kind='Structure',category=category,material_key=key,
                offset=offset,normal_offset=normal_offset,vertex_count=m.Vertices.Count,index_count=m.Faces.Count*3,
                bounds=[xyz(b.Min),xyz(b.Max)],collision=category=='01_concentric_bands',watertight=True))
    finally:writer.Close()
    # Locate the crossing from the CURRENT ring plane, including manual moves/rotations.
    road=sc.doc.Objects.FindId(System.Guid('0808d32c-6ebc-4105-9258-a0f755ac2752'));assert road
    deck=mesh_of(road.Geometry,mp);route=[]
    center=G.Point3d(*parameters['center_native']);normal=G.Vector3d(*parameters['circle_plane_normal_native'])
    sections=G.Intersect.Intersection.MeshPlane(deck,G.Plane(center,normal))
    assert sections,'Current ring plane does not cross the existing bridge'
    candidates=[poly.BoundingBox.Center for poly in sections]
    crossing=min(candidates,key=lambda p:(p.X-center.X)**2+(p.Y-center.Y)**2)
    for x in range(int(round(crossing.X))-32,int(round(crossing.X))+33,2):
        ys=[]
        for y in range(int(crossing.Y)-55,int(crossing.Y)+56):
            t=G.Intersect.Intersection.MeshRay(deck,G.Ray3d(G.Point3d(x,y,200),-G.Vector3d.ZAxis))
            if t>=0:ys.append(y)
        assert ys,'Missing bridge section'
        y=(min(ys)+max(ys))*.5;t=G.Intersect.Intersection.MeshRay(deck,G.Ray3d(G.Point3d(x,y,200),-G.Vector3d.ZAxis));assert t>=0
        route.append([float(x),y,200.-t])
    source['bridge_crossing_route_native']=route
    source['bridge_crossing_native']=xyz(crossing)
    assert before==fingerprint() and sc.doc.Modified==modified,'Export changed CAD'
    source['cad_unchanged']=True
    with io.open(CACHE+'/source.json','w',encoding='utf-8') as f:f.write(json.dumps(source,ensure_ascii=False,indent=2))
    return dict(objects=7,triangles=sum(r['index_count']//3 for r in source['objects']),bridge_samples=len(route),cad_unchanged=True)
