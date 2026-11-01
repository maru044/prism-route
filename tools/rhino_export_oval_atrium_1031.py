# -*- coding: utf-8 -*-
"""Read-only delta export: reviewed atrium plus its three excavated host solids."""
from __future__ import unicode_literals, division
import Rhino,scriptcontext as sc,System,json,io
G=Rhino.Geometry
ROOT='D:/Prism Route/prism-route'
CACHE=ROOT+'/.current_map_build/oval_atrium_1031'
KEY='oval_atrium_export_1031'

def prepare():
    ns=sc.sticky['oval_atrium_builder_ns_1031'];d=sc.sticky['oval_atrium_1031']
    ns['audit']();ns['verify_exit_ground_fix']()
    with io.open(ROOT+'/assets/world/current_map_validation/metadata.json','r',encoding='utf-8-sig') as f:base=json.load(f)
    ids=sorted(d['objects'])+[ns['SOURCE'][k] for k in ['oval','roof','core']]
    before={str(o.Id):int(o.Geometry.DataCRC(0)) for o in ns['active_objects']()}
    stream=System.IO.FileStream(CACHE+'/source.bin',System.IO.FileMode.Create);stream.Close()
    sc.sticky[KEY]={'ids':ids,'before':before,'modified':sc.doc.Modified,'objects':[],'materials':{},'base':{r['id']:r for r in base['object_records']}}
    return {'objects':len(ids),'replaced_host_solids':3}

def export_batch(start,end):
    ns=sc.sticky['oval_atrium_builder_ns_1031'];d=sc.sticky[KEY]
    assert start==len(d['objects'])
    param=G.MeshingParameters();param.SimplePlanes=True;param.RefineGrid=True;param.JaggedSeams=False
    param.MaximumEdgeLength=6.;param.MinimumEdgeLength=.04;param.Tolerance=.025;param.RelativeTolerance=0.;param.RefineAngle=.15
    stream=System.IO.FileStream(CACHE+'/source.bin',System.IO.FileMode.Append);writer=System.IO.BinaryWriter(stream)
    def array(values):
        raw=System.Array.CreateInstance(System.Byte,values.Length*4)
        System.Buffer.BlockCopy(values,0,raw,0,raw.Length);writer.Write(raw)
    try:
        for sid in d['ids'][start:end]:
            o=ns['obj'](sid);assert o and not o.IsDeleted
            mesh=ns['mesh_of'](o.Geometry) if isinstance(o.Geometry,G.Mesh) else G.Mesh()
            if not isinstance(o.Geometry,G.Mesh):
                for part in G.Mesh.CreateFromBrep(o.Geometry,param):mesh.Append(part)
            mesh.Faces.ConvertQuadsToTriangles();mesh.Normals.ComputeNormals();mesh.Compact()
            assert mesh.IsValid and mesh.Faces.Count>0
            category=o.Attributes.GetUserString('category') or 'host_replacement'
            host=sid in d['base'];kind=d['base'][sid]['kind'] if host else 'Structure'
            key='source_terrain' if host else sc.doc.Materials[o.Attributes.MaterialIndex].Name.replace('PR_Atrium_','')
            if sid==ns['SOURCE']['oval']:key='source_architecture';kind='Structure'
            if not host:
                material=sc.doc.Materials[o.Attributes.MaterialIndex];color=material.DiffuseColor
                d['materials'][key]={'color':[color.R/255.,color.G/255.,color.B/255.],
                    'roughness':float(material.PhysicallyBased.Roughness),'metallic':float(material.PhysicallyBased.Metallic),'opacity':float(material.PhysicallyBased.Opacity)}
            offset=int(stream.Position);array(mesh.Vertices.ToFloatArray());array(mesh.Faces.ToIntArray(True))
            normal_offset=int(stream.Position);array(mesh.Normals.ToFloatArray())
            uv_offset=None
            if mesh.TextureCoordinates.Count==mesh.Vertices.Count:
                uv_offset=int(stream.Position);array(mesh.TextureCoordinates.ToFloatArray())
            b=mesh.GetBoundingBox(True)
            collision=host or category not in ['04_metal','05_glass']
            d['objects'].append({'id':sid,'name':o.Name,'category':category,'kind':kind,'material_key':key,
                'offset':offset,'normal_offset':normal_offset,'uv_offset':uv_offset,'vertex_count':mesh.Vertices.Count,
                'index_count':mesh.Faces.Count*3,'bounds':[ns['xyz'](b.Min),ns['xyz'](b.Max)],
                'collision':collision,'host_replacement':host,'watertight':mesh.IsClosed})
    finally:writer.Close()
    return {'done':len(d['objects']),'triangles':sum(r['index_count']//3 for r in d['objects'])}

def finish():
    ns=sc.sticky['oval_atrium_builder_ns_1031'];native=sc.sticky['oval_atrium_1031'];d=sc.sticky[KEY]
    assert len(d['objects'])==len(d['ids'])
    assert d['before']=={str(o.Id):int(o.Geometry.DataCRC(0)) for o in ns['active_objects']()} and sc.doc.Modified==d['modified']
    ramps=native['ramp_samples'];external=next(r for r in ramps if r['name']=='Exterior_sweeping_ramp')
    footprint=[r[0][:2] for r in external['samples']]+[r[1][:2] for r in reversed(external['samples'])]
    report={'source':sc.doc.Path,'feature':'oval_atrium_1031','native_center':[1450.,1150.,0.],
        'cad_unchanged':True,'objects':d['objects'],'materials':d['materials'],
        'replaced_ids':[ns['SOURCE'][k] for k in ['oval','roof','core']],
        'ramps':ramps,'tree_exclusion':{'center':[ns['CX'],ns['CY']],'roof_axes':[84.,55.8],
            'excavation_axes':[70.,48.],'roof_min_z':60.,'void_min_z':34.,'entry_ramp_polygon':footprint,
            'exit_direction':ns['xyz'](ns['EXIT_DIR']),'exit_start':ns['xyz'](native['prepared']['exit_start']),
            'exit_end':ns['xyz'](native['prepared']['exit_end'])},
        'entry_spawn':[1129.,274.,72.6],'floor_spawn':ns['xyz'](native['prepared']['exit_start']-ns['EXIT_DIR']*3),
        'entry_source_id':str(ns['named_part']('Entry_head_landing').Id),'floor_source_id':str(ns['named_part']('Lower_hall_floor').Id)}
    with io.open(CACHE+'/source.json','w',encoding='utf-8') as f:f.write(json.dumps(report,ensure_ascii=False,indent=2))
    return {'objects':len(d['objects']),'cad_unchanged':True}

def export_patch(ids):
    """Update only changed feature records; do not rerun the full review suite."""
    with io.open(CACHE+'/source.json','r',encoding='utf-8') as f:source=json.load(f)
    with io.open(ROOT+'/assets/world/current_map_validation/metadata.json','r',encoding='utf-8-sig') as f:base=json.load(f)
    previous=sc.sticky.get(KEY)
    sc.sticky[KEY]={'ids':ids,'objects':[],'materials':dict(source['materials']),'base':{r['id']:r for r in base['object_records']}}
    try:
        export_batch(0,len(ids));patch=sc.sticky[KEY]
        byid={r['id']:r for r in patch['objects']}
        source['objects']=[byid.get(r['id'],r) for r in source['objects']]
        source['materials']=patch['materials'];source['last_patch']={'ids':ids,'reason':'Trim bridge, guardrails and brackets to the actual curved road edge'}
        with io.open(CACHE+'/source.json','w',encoding='utf-8') as f:f.write(json.dumps(source,ensure_ascii=False,indent=2))
        return {'patched_objects':len(ids)}
    finally:
        if previous is not None:sc.sticky[KEY]=previous
