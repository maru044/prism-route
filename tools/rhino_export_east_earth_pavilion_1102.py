# -*- coding: utf-8 -*-
"""Read-only, resumable export of the reviewed pavilion and excavated hill."""
from __future__ import unicode_literals,division
import Rhino,scriptcontext as sc,System,io,json,os
G=Rhino.Geometry
ROOT='D:/Prism Route/prism-route'
CACHE=ROOT+'/.current_map_build/east_earth_pavilion_1102'
TAG='east_earth_pavilion_1102'
HILL='920c8a45-b23e-4260-9aab-86333f61b992'
KEY=TAG+'_export'

def objects():
    e=Rhino.DocObjects.ObjectEnumeratorSettings();e.NormalObjects=True;e.HiddenObjects=True;e.LockedObjects=True
    return [o for o in sc.doc.Objects.GetObjectList(e) if not o.IsDeleted]
def fingerprint():
    opts=Rhino.FileIO.SerializationOptions()
    return {str(o.Id):(int(o.Geometry.DataCRC(0)),o.Attributes.ToJSON(opts)) for o in objects()}
def xyz(p):return [float(p.X),float(p.Y),float(p.Z)]
def prepare():
    assert sc.doc.Path.replace('\\','/').lower()=='d:/prism route/map/map_current.3dm'
    owned=sorted([o for o in objects() if o.Attributes.GetUserString('feature')==TAG],key=lambda o:o.Name)
    reviewed=json.load(open(ROOT+'/docs/'+TAG+'/model_report.json','r'))
    assert set(str(o.Id) for o in owned)==set(reviewed['object_ids'])
    owned.append(sc.doc.Objects.FindId(System.Guid(HILL)))
    if not os.path.isdir(CACHE):os.makedirs(CACHE)
    open(CACHE+'/source.bin','wb').close()
    sc.sticky[KEY]=dict(before=fingerprint(),modified=sc.doc.Modified,ids=[str(o.Id) for o in owned],
        source=dict(source=sc.doc.Path,feature=TAG,native_center=[1450.,1150.,0.],objects=[],materials={},
        parameters=json.load(open(ROOT+'/docs/'+TAG+'/parameters.json','r')),replaced_ids=[HILL]))
    return dict(objects=len(owned))
def export_batch(start,end):
    d=sc.sticky[KEY];source=d['source'];assert start==len(source['objects'])
    stream=System.IO.FileStream(CACHE+'/source.bin',System.IO.FileMode.Append);writer=System.IO.BinaryWriter(stream)
    def array(values):
        raw=System.Array.CreateInstance(System.Byte,values.Length*4);System.Buffer.BlockCopy(values,0,raw,0,raw.Length);writer.Write(raw)
    try:
        for id in d['ids'][start:end]:
            o=sc.doc.Objects.FindId(System.Guid(id));g=o.Geometry
            if isinstance(g,G.Mesh):m=g.DuplicateMesh()
            else:
                m=G.Mesh();mp=G.MeshingParameters();mp.Tolerance=.025;mp.MaximumEdgeLength=3.;mp.RefineGrid=True;mp.GridAspectRatio=1000.;mp.SimplePlanes=True
                for p in G.Mesh.CreateFromBrep(g,mp):m.Append(p)
            m.Faces.ConvertQuadsToTriangles()
            if m.Normals.Count!=m.Vertices.Count:m.Normals.ComputeNormals()
            m.Compact();assert m.IsValid and (m.IsClosed or id==HILL),o.Name
            cat='host_replacement' if id==HILL else o.Attributes.GetUserString('category')
            key='grass' if id==HILL else o.Attributes.GetUserString('material_key')
            mat=sc.doc.Materials[o.Attributes.MaterialIndex];c=mat.DiffuseColor;pbr=mat.PhysicallyBased
            source['materials'][key]=dict(color=[c.R/255.,c.G/255.,c.B/255.],roughness=float(pbr.Roughness),metallic=float(pbr.Metallic),opacity=float(pbr.Opacity))
            offset=int(stream.Position);array(m.Vertices.ToFloatArray());array(m.Faces.ToIntArray(True))
            normal_offset=int(stream.Position);array(m.Normals.ToFloatArray());b=m.GetBoundingBox(True)
            source['objects'].append(dict(id=id,name=o.Name,category=cat,material_key=key,offset=offset,normal_offset=normal_offset,
                vertex_count=m.Vertices.Count,index_count=m.Faces.Count*3,bounds=[xyz(b.Min),xyz(b.Max)],watertight=m.IsClosed,
                collision=cat!='05_frame',kind='Terrain' if key=='grass' else 'Structure'))
    finally:writer.Close()
    return dict(exported=len(source['objects']),total=len(d['ids']))
def finish():
    d=sc.sticky[KEY];source=d['source'];assert len(source['objects'])==len(d['ids'])
    ns=sc.sticky['east_earth_pavilion_ns_1102'];P=ns['P'];frame=ns['path_frame'];height=ns['path_z'];ramp=ns['ramp_point']
    source['routes']={}
    source['routes']['entry']=[xyz(G.Point3d(frame(i/100.)[0].X,frame(i/100.)[0].Y,height(i/100.))) for i in range(101)]
    source['routes']['atrium']=[xyz(ramp(i/100.)+G.Vector3d(0,0,.15)) for i in range(101)]
    source['routes']['hall']=[xyz(P(16.,2.+26.*i/26.,62.025)) for i in range(27)]
    source['routes']['upper']=[xyz(P(16.,55.-14.5*i/30.,69.64)) for i in range(31)]
    source['spawn']=xyz(P(16.,5.,62.));source['look_direction']=[1.,0.,0.]
    source['review_eye']=[1715.,680.,200.];source['review_target']=xyz(P(0.,36.,68.))
    source['court_eye']=xyz(P(5.,10.,88.));source['court_target']=xyz(P(16.,28.,63.5))
    source['entry_eye']=xyz(P(16.,-45.,65.));source['entry_target']=xyz(P(16.,26.,64.))
    assert d['before']==fingerprint() and d['modified']==sc.doc.Modified
    source['cad_unchanged']=True
    with io.open(CACHE+'/source.json','w',encoding='utf-8') as f:f.write(json.dumps(source,ensure_ascii=False,indent=2))
    return dict(objects=len(source['objects']),triangles=sum(r['index_count']//3 for r in source['objects']),cad_unchanged=True)
