"""Append the reviewed ring without rewriting any map, planting or grass assets."""
from pathlib import Path
import json,struct,hashlib
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
CACHE=ROOT/'.current_map_build/landmark_ring_1101'
OUT=ROOT/'assets/world/landmark_ring_1101'
PROTECTED=['assets/world/tree_planting/world_edits.json','assets/world/current_map_validation/current_region.glb',
    'assets/world/current_map_validation/metadata.json','assets/world/current_map_validation/tree_layout.json',
    'assets/world/current_map_validation/grass_cells.json','assets/world/current_map_validation/grass_bake/manifest.json',
    'assets/world/oval_atrium_1031/grass_bake/manifest.json','assets/world/oval_atrium_1031/atrium.glb',
    'assets/world/island_saddle_1031/saddle.glb','assets/world/island_saddle_1031/manifest.json',
    'assets/world/terrace_ruins_1101/ruins.glb','assets/world/upper_ring_1030/pavilion.glb',
    'scripts/world/initial_ruin.gd']
def world(p):return [p[0]-1450.,p[2],1150.-p[1]]
def build():
    CACHE.mkdir(parents=True,exist_ok=True)
    protected_path=CACHE/'import_protected_hashes.json'
    if not protected_path.exists():protected_path.write_text(json.dumps({p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in PROTECTED},indent=2))
    source=json.loads((CACHE/'source.json').read_text(encoding='utf-8'));raw=(CACHE/'source.bin').read_bytes()
    assert source['cad_unchanged'] and len(source['objects'])==7
    # These runtime resources are deliberately shared, rather than almost matching duplicates.
    saddle=json.loads((ROOT/'assets/world/island_saddle_1031/manifest.json').read_text(encoding='utf-8'))
    for key,material in source['materials'].items():
        for prop in ['color','roughness','metallic']:
            assert material[prop]==saddle['materials'][key][prop],f'Native/runtime material drift: {key}.{prop}'
    OUT.mkdir(parents=True,exist_ok=True);blob=bytearray();views=[];accessors=[];meshes=[];nodes=[]
    def array(data,component,shape,target,bounds=False):
        while len(blob)%4:blob.append(0)
        data=np.ascontiguousarray(data);offset=len(blob);blob.extend(data.tobytes())
        views.append(dict(buffer=0,byteOffset=offset,byteLength=data.nbytes,target=target))
        item=dict(bufferView=len(views)-1,componentType=component,count=len(data),type=shape)
        if bounds:item.update(min=data.min(0).astype(float).tolist(),max=data.max(0).astype(float).tolist())
        accessors.append(item);return len(accessors)-1
    for row in source['objects']:
        n=row['vertex_count'];p=np.frombuffer(raw,'<f4',count=n*3,offset=row['offset']).reshape(-1,3).copy()
        p-=np.array(source['native_center'],dtype='<f4');p=p[:,[0,2,1]];p[:,2]*=-1
        normal=np.frombuffer(raw,'<f4',count=n*3,offset=row['normal_offset']).reshape(-1,3).copy();normal=normal[:,[0,2,1]];normal[:,2]*=-1
        indices=np.frombuffer(raw,'<u4',count=row['index_count'],offset=row['offset']+n*12)
        attrs={'POSITION':array(p,5126,'VEC3',34962,True),'NORMAL':array(normal,5126,'VEC3',34962)}
        meshes.append(dict(primitives=[dict(attributes=attrs,indices=array(indices,5125,'SCALAR',34963),mode=4)]))
        nodes.append(dict(name='Structure_'+row['id'],mesh=len(meshes)-1))
    gltf=dict(asset=dict(version='2.0',generator='Prism Route reviewed landmark ring'),scene=0,scenes=[dict(nodes=list(range(len(nodes))))],nodes=nodes,meshes=meshes,buffers=[dict(byteLength=len(blob))],bufferViews=views,accessors=accessors)
    text=json.dumps(gltf,separators=(',',':')).encode();text+=b' '*((-len(text))%4);blob+=b'\0'*((-len(blob))%4)
    output=struct.pack('<III',0x46546c67,2,12+8+len(text)+8+len(blob))+struct.pack('<II',len(text),0x4e4f534a)+text+struct.pack('<II',len(blob),0x004e4942)+blob
    (OUT/'ring.glb').write_bytes(output)
    center=np.array(source['parameters']['center_native'],dtype=float)
    normal=np.array(source['parameters']['circle_plane_normal_native'],dtype=float)
    source.update(mesh_sha256=hashlib.sha256(output).hexdigest(),triangles=sum(r['index_count']//3 for r in source['objects']),
        bridge_crossing_route=[world(p) for p in source.pop('bridge_crossing_route_native')],
        review_eye=world(center-normal*560.+[0,0,210.]),review_target=world(center+[0,0,-18.]),
        site_eye=world(center-normal*520.+[-180,180,520.]),site_target=world(center+[80,20,-20.]),
        spawn_eye=world([651.970,-367.813,34.8]),spawn_target=world([1429.714,260.768,34.8]),
        spawn_view_note='Cave exit, 16 m along the existing spawn heading; floor measured at 33 m, overhead clear. Actual spawn remains unchanged.')
    (OUT/'manifest.json').write_text(json.dumps(source,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    protected=json.loads(protected_path.read_text())
    assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in protected.items())
    print(json.dumps(dict(objects=7,triangles=source['triangles'],collision_bodies=3,glb_bytes=len(output),protected_resources_unchanged=len(protected))))
if __name__=='__main__':build()
