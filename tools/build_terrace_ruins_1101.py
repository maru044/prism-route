"""Build additive GLB and a local turf cut; never rewrite planting or base bakes."""
from pathlib import Path
import json,struct,hashlib
import numpy as np
from PIL import Image,ImageDraw,ImageFilter
ROOT=Path(__file__).resolve().parents[1]
CACHE=ROOT/'.current_map_build/terrace_ruins_1101'
OUT=ROOT/'assets/world/terrace_ruins_1101'
PROTECTED=['assets/world/tree_planting/world_edits.json','assets/world/current_map_validation/current_region.glb',
    'assets/world/current_map_validation/metadata.json','assets/world/current_map_validation/grass_cells.json',
    'assets/world/current_map_validation/tree_layout.json','assets/world/current_map_validation/grass_bake/manifest.json',
    'assets/world/oval_atrium_1031/grass_bake/manifest.json','assets/world/oval_atrium_1031/atrium.glb',
    'assets/world/island_saddle_1031/saddle.glb','assets/world/upper_ring_1030/pavilion.glb']
def snapshot():
    path=CACHE/'import_protected_hashes.json'
    if not path.exists():path.write_text(json.dumps({p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in PROTECTED},indent=2))
def world(p):return [p[0]-1450.,p[2],1150.-p[1]]
def build():
    snapshot();source=json.loads((CACHE/'source.json').read_text(encoding='utf-8'));raw=(CACHE/'source.bin').read_bytes()
    assert source['cad_unchanged'] and len(source['objects'])==31
    OUT.mkdir(parents=True,exist_ok=True)
    blob=bytearray();views=[];accessors=[];meshes=[];nodes=[];mask_triangles=[]
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
        if row['category'] in ['01_foundation','05_paths']:
            t=p[indices.reshape(-1,3)];cross=np.cross(t[:,1]-t[:,0],t[:,2]-t[:,0]);up=cross[:,1]/np.maximum(np.linalg.norm(cross,axis=1),1e-9)>.85
            mask_triangles.extend(t[up][:,:,[0,2]].tolist())
    gltf=dict(asset=dict(version='2.0',generator='Prism Route reviewed terrace ruins'),scene=0,scenes=[dict(nodes=list(range(len(nodes))))],nodes=nodes,meshes=meshes,buffers=[dict(byteLength=len(blob))],bufferViews=views,accessors=accessors)
    text=json.dumps(gltf,separators=(',',':')).encode();text+=b' '*((-len(text))%4);blob+=b'\0'*((-len(blob))%4)
    output=struct.pack('<III',0x46546c67,2,12+8+len(text)+8+len(blob))+struct.pack('<II',len(text),0x4e4f534a)+text+struct.pack('<II',len(blob),0x004e4942)+blob
    (OUT/'ruins.glb').write_bytes(output)
    allxy=np.array(mask_triangles).reshape(-1,2);lo=np.floor(allxy.min(0))-2;hi=np.ceil(allxy.max(0))+2
    im=Image.new('L',(256,1024),0);draw=ImageDraw.Draw(im);scale=(np.array(im.size)-1)/(hi-lo)
    for t in mask_triangles:draw.polygon([tuple(q) for q in (np.array(t)-lo)*scale],fill=255)
    im=im.filter(ImageFilter.MaxFilter(3));im.save(OUT/'grass_cut.png')
    source['grass_cut']=dict(origin_xz=lo.tolist(),extent_xz=(hi-lo).tolist(),height_range=[85.,101.],image='res://assets/world/terrace_ruins_1101/grass_cut.png')
    for name,pts in source['routes'].items():source['routes'][name]=[world(p) for p in pts]
    for row in source['probes']:row['samples']=[world(p) for p in row['samples']]
    byname={r['name'].replace('PR_TerraceRuins_',''):r['id'] for r in source['objects']}
    source.update(spawns=[dict(key='terrace_ruins_a',name='台地曲面遗构 · 主组',position=world([1847.5,160.,95.18]),look_direction=[1,0,0],source_id=byname['A_Terrain_fitted_foundation']),
                          dict(key='terrace_ruins_b',name='台地曲面遗构 · 次组',position=world([1862.1,233.,92.32]),look_direction=[1,0,0],source_id=byname['B_Terrain_fitted_foundation'])],
        review_eye=world([1940.,45.,165.]),review_target=world([1852.,202.,93.]),
        detail_eye=world([1870.,141.,107.]),detail_target=world([1844.,160.,97.]),
        mesh_sha256=hashlib.sha256(output).hexdigest(),triangles=sum(r['index_count']//3 for r in source['objects']))
    (OUT/'manifest.json').write_text(json.dumps(source,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    protected=json.loads((CACHE/'import_protected_hashes.json').read_text())
    assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in protected.items())
    print(json.dumps(dict(objects=len(nodes),triangles=source['triangles'],collision_meshes=sum(r['collision'] for r in source['objects']),planting_and_bakes_unchanged=True)))
if __name__=='__main__':build()
