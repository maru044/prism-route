"""Build additive native geometry; preserve all existing map and planting inputs."""
from pathlib import Path
import json,struct,hashlib
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
CACHE=ROOT/'.current_map_build/water_court_1101'
OUT=ROOT/'assets/world/water_court_1101'
PROTECTED=['assets/world/tree_planting/world_edits.json','assets/world/current_map_validation/current_region.glb',
    'assets/world/current_map_validation/metadata.json','assets/world/current_map_validation/tree_layout.json',
    'assets/world/current_map_validation/grass_cells.json','assets/world/current_map_validation/grass_bake/manifest.json',
    'assets/world/oval_atrium_1031/grass_bake/manifest.json','assets/world/oval_atrium_1031/atrium.glb',
    'assets/world/island_saddle_1031/saddle.glb','assets/world/island_saddle_1031/manifest.json',
    'assets/world/terrace_ruins_1101/ruins.glb','assets/world/upper_ring_1030/pavilion.glb',
    'assets/world/landmark_ring_1101/ring.glb','assets/world/landmark_ring_1101/manifest.json','scripts/world/initial_ruin.gd']
def world(p):return [p[0]-1450.,p[2],1150.-p[1]]
def build():
    CACHE.mkdir(parents=True,exist_ok=True);protected_path=CACHE/'import_protected_hashes.json'
    if not protected_path.exists():protected_path.write_text(json.dumps({p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in PROTECTED},indent=2))
    protected=json.loads(protected_path.read_text())
    assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in protected.items())
    source=json.loads((CACHE/'source.json').read_text(encoding='utf-8'));raw=(CACHE/'source.bin').read_bytes()
    assert source['cad_unchanged'] and len(source['objects'])==31
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
        normal=np.frombuffer(raw,'<f4',count=n*3,offset=row['normal_offset']).reshape(-1,3).copy()
        assert np.isfinite(p).all() and np.isfinite(normal).all()
        normal=normal[:,[0,2,1]];normal[:,2]*=-1
        indices=np.frombuffer(raw,'<u4',count=row['index_count'],offset=row['offset']+n*12)
        attrs={'POSITION':array(p,5126,'VEC3',34962,True),'NORMAL':array(normal,5126,'VEC3',34962)}
        meshes.append(dict(primitives=[dict(attributes=attrs,indices=array(indices,5125,'SCALAR',34963),mode=4)]))
        nodes.append(dict(name='Structure_'+row['id'],mesh=len(meshes)-1))
    gltf=dict(asset=dict(version='2.0',generator='Prism Route reviewed shallow water court'),scene=0,
        scenes=[dict(nodes=list(range(len(nodes))))],nodes=nodes,meshes=meshes,
        buffers=[dict(byteLength=len(blob))],bufferViews=views,accessors=accessors)
    text=json.dumps(gltf,separators=(',',':')).encode();text+=b' '*((-len(text))%4);blob+=b'\0'*((-len(blob))%4)
    output=struct.pack('<III',0x46546c67,2,12+8+len(text)+8+len(blob))+struct.pack('<II',len(text),0x4e4f534a)+text+struct.pack('<II',len(blob),0x004e4942)+blob
    (OUT/'court.glb').write_bytes(output)
    source['ramp_route']=[world(p) for p in source['ramp_route']]
    for row in source['probes']:row['samples']=[world(p) for p in row['samples']]
    byname={r['name'].replace('PR_WaterCourt_',''):r['id'] for r in source['objects']}
    source.update(spawn=world([536.16,521.61,.28]),spawn_source_id=byname['Crescent_dry_gallery'],look_direction=[1.,0.,0.],
        review_eye=world([655.,430.,70.]),review_target=world([567.,518.,5.]),
        court_eye=world([559.,463.,8.]),court_target=world([548.,520.,5.]),
        underpass_eye=world([600.,495.,3.2]),underpass_target=world([599.,548.,3.6]),
        mesh_sha256=hashlib.sha256(output).hexdigest(),triangles=sum(r['index_count']//3 for r in source['objects']))
    (OUT/'manifest.json').write_text(json.dumps(source,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in protected.items())
    print(json.dumps(dict(objects=len(nodes),triangles=source['triangles'],glb_bytes=len(output),
        collision_bodies=sum(r['collision'] for r in source['objects']),protected_resources_unchanged=len(protected))))
if __name__=='__main__':build()
