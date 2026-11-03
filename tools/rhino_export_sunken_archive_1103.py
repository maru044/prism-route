# -*- coding: utf-8 -*-
"""Staged read-only export, including the four locally excavated source objects."""
from __future__ import division,unicode_literals
import Rhino,scriptcontext as sc,System,json,io,os
G=Rhino.Geometry
ROOT='D:/Prism Route/prism-route';CACHE=ROOT+'/.current_map_build/sunken_archive_1103';KEY='sunken_archive_export'
def prep():
    n=sc.sticky['sunken_archive_ns'];s=n['state']();n['audit']()
    ids=s['ids']+list(s['replacements']);open(CACHE+'/source.bin','wb').close()
    sc.sticky[KEY]={'ids':ids,'before':n['fingerprint'](),'modified':sc.doc.Modified,'source':{'objects':[],'materials':{},'native_center':[1450,1150,0],
        'replaced_ids':list(s['replacements']),'floor':n['FLOOR'],'roof':n['ROOF'],'routes':{},'views':{},'cad_unchanged':True}}
    return {'objects':len(ids)}
def batch(start,end):
    d=sc.sticky[KEY];source=d['source'];assert len(source['objects'])==start
    stream=System.IO.FileStream(CACHE+'/source.bin',System.IO.FileMode.Append);w=System.IO.BinaryWriter(stream)
    def array(a):
        b=System.Array.CreateInstance(System.Byte,a.Length*4);System.Buffer.BlockCopy(a,0,b,0,b.Length);w.Write(b)
    try:
        for sid in d['ids'][start:end]:
            o=sc.doc.Objects.FindId(System.Guid(sid));g=o.Geometry
            if isinstance(g,G.Mesh):m=g.DuplicateMesh()
            else:
                m=G.Mesh();mp=G.MeshingParameters();mp.Tolerance=.035;mp.MaximumEdgeLength=3;mp.RefineGrid=True;mp.SimplePlanes=True
                for q in G.Mesh.CreateFromBrep(g,mp):m.Append(q)
            m.Faces.ConvertQuadsToTriangles();m.Normals.ComputeNormals();m.Compact();assert m.IsValid,o.Name
            host=sid in source['replaced_ids'];key='host' if host else o.Attributes.GetUserString('material_key')
            cat='host_replacement' if host else o.Attributes.GetUserString('category')
            if not host:
                mat=sc.doc.Materials[o.Attributes.MaterialIndex];c=mat.DiffuseColor;p=mat.PhysicallyBased
                source['materials'][key]={'color':[c.R/255.,c.G/255.,c.B/255.],'roughness':p.Roughness,'metallic':p.Metallic,'opacity':p.Opacity}
            offset=int(stream.Position);array(m.Vertices.ToFloatArray());array(m.Faces.ToIntArray(True));normal_offset=int(stream.Position);array(m.Normals.ToFloatArray());b=m.GetBoundingBox(True)
            source['objects'].append({'id':sid,'name':o.Name,'category':cat,'material_key':key,'collision':host or o.Attributes.GetUserString('collision')=='1',
                'kind':'Terrain' if host or cat=='terrain' else 'Structure','offset':offset,'normal_offset':normal_offset,'vertex_count':m.Vertices.Count,'index_count':m.Faces.Count*3,
                'bounds':[list(b.Min),list(b.Max)]})
    finally:w.Close()
    return {'done':len(source['objects']),'total':len(d['ids'])}
def finish():
    d=sc.sticky[KEY];source=d['source'];n=sc.sticky['sunken_archive_ns'];s=n['state']();assert len(source['objects'])==len(d['ids'])
    source['routes']['entry_landing']=s['access_route'];source['routes']['stairs']=s['stair_route']+[[98,1162,11.5],[98,1159,11.5],[98,1155,11.5]]
    source['routes']['gallery']=[list(n['ep'](27.5,20.5,__import__('math').radians(a),11.5)) for a in range(185,356,5)]
    source['cut_polygons']={key:[list(c.PointAtNormalizedLength(i/256.))[:2] for i in range(256)] for key,c in [('occupied',s['outer']),('opening',s['opening']),('sky',s['sky'])]}
    source['access_max_grade']=s.get('access_max_grade')
    source['spawn']=[98,1160,11.5];source['look_direction']=[0,0,1]
    for name in ['overview','road','entry','court','gallery','coast']:
        n['camera'](name);v=sc.doc.Views.ActiveView.ActiveViewport
        source['views'][name]={'eye':list(v.CameraLocation),'target':list(v.CameraTarget),'lens':v.Camera35mmLensLength}
    source['spawn_source_id']=s['ids'][0]
    assert d['before']==n['fingerprint']() and d['modified']==sc.doc.Modified
    with io.open(CACHE+'/source.json','w',encoding='utf-8') as f:f.write(json.dumps(source,ensure_ascii=False,indent=2))
    return {'objects':len(source['objects']),'triangles':sum(r['index_count']//3 for r in source['objects'])}
