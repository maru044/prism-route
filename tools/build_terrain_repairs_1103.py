"""Package the three terrain repairs and index complete local grass cells."""
from pathlib import Path
import hashlib,json,struct
import numpy as np
from build_east_earth_pavilion_1102 import raster
ROOT=Path(__file__).resolve().parents[1]
CACHE=ROOT/'.current_map_build/terrain_repairs_1103'
OUT=ROOT/'assets/world/terrain_repairs_1103'

def sha(path):
    with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()

def build():
    OUT.mkdir(parents=True,exist_ok=True)
    protected=[ROOT/'assets/world/tree_planting/world_edits.json']
    protected+=list((ROOT/'assets/world').rglob('*.glb'))
    protected+=[p for p in (ROOT/'assets/world').rglob('*.json') if 'terrain_repairs_1103' not in p.parts]
    snapshot=CACHE/'protected.json'
    if not snapshot.exists():snapshot.write_text(json.dumps({p.relative_to(ROOT).as_posix():sha(p) for p in protected},indent=2))
    source=json.loads((CACHE/'source.json').read_text(encoding='utf-8'))
    assert source['cad_unchanged'] and len(source['objects'])==3
    raw=(CACHE/'source.bin').read_bytes();blob=bytearray();views=[];accessors=[];meshes=[];nodes=[];terrain=[]
    def array(data,component,shape,target,bounds=False):
        while len(blob)%4:blob.append(0)
        data=np.ascontiguousarray(data);offset=len(blob);blob.extend(data.tobytes())
        views.append(dict(buffer=0,byteOffset=offset,byteLength=data.nbytes,target=target))
        row=dict(bufferView=len(views)-1,componentType=component,count=len(data),type=shape)
        if bounds:row.update(min=data.min(0).astype(float).tolist(),max=data.max(0).astype(float).tolist())
        accessors.append(row);return len(accessors)-1
    for row in source['objects']:
        n=row['vertex_count'];p=np.frombuffer(raw,'<f4',n*3,row['offset']).reshape(-1,3).copy()
        p-=np.array(source['native_center'],dtype='<f4');p=p[:,[0,2,1]];p[:,2]*=-1
        normal=np.frombuffer(raw,'<f4',n*3,row['normal_offset']).reshape(-1,3).copy();normal=normal[:,[0,2,1]];normal[:,2]*=-1
        indices=np.frombuffer(raw,'<u4',row['index_count'],row['offset']+n*12)
        assert np.isfinite(p).all() and np.isfinite(normal).all()
        attrs={'POSITION':array(p,5126,'VEC3',34962,True),'NORMAL':array(normal,5126,'VEC3',34962)}
        meshes.append(dict(primitives=[dict(attributes=attrs,indices=array(indices,5125,'SCALAR',34963),mode=4)]))
        nodes.append(dict(name='Terrain_'+row['id'],mesh=len(meshes)-1))
        triangles=p[indices.reshape(-1,3)];terrain.append(triangles)
        row['world_bounds']=[p.min(0).tolist(),p.max(0).tolist()]
    gltf=dict(asset=dict(version='2.0',generator='Prism Route reviewed terrain seams'),scene=0,scenes=[dict(nodes=list(range(3)))],
              nodes=nodes,meshes=meshes,buffers=[dict(byteLength=len(blob))],bufferViews=views,accessors=accessors)
    text=json.dumps(gltf,separators=(',',':')).encode();text+=b' '*((-len(text))%4);blob+=b'\0'*((-len(blob))%4)
    output=struct.pack('<III',0x46546c67,2,28+len(text)+len(blob))+struct.pack('<II',len(text),0x4e4f534a)+text+struct.pack('<II',len(blob),0x004e4942)+blob
    (OUT/'terrain.glb').write_bytes(output)
    # One compact height grid per separate site; don't rasterize the whole lake.
    support=[];columns=set();new_cells=set()
    for index,triangles in enumerate(terrain):
        lo=triangles[:,:,[0,2]].min((0,1))-1.;hi=triangles[:,:,[0,2]].max((0,1))+1.
        step=1.;size=np.ceil((hi-lo)/step).astype(int)+1
        field=np.full((size[1],size[0]),-10000.,np.float32);raster(triangles,lo,step,field)
        z,x=np.nonzero(field>-9999.)
        wx=lo[0]+x;wz=lo[1]+z
        cx=np.floor(wx/24).astype(int);cz=np.floor(wz/24).astype(int);cy=np.floor(field[z,x]/24).astype(int)
        # Include neighbors at the perimeter so no partially changed cell keeps
        # an old root buffer. Complete cells are rebuilt with the real sampler.
        cols=set(zip(cx.tolist(),cz.tolist()))
        columns.update((a+da,b+db) for a,b in cols for da in [-1,0,1] for db in [-1,0,1])
        new_cells.update(zip(cx.tolist(),cy.tolist(),cz.tolist()))
        path=f'support_{index}.rf';(OUT/path).write_bytes(field.astype('<f4').tobytes())
        support.append(dict(path=path,size=size.tolist(),origin_xz=lo.tolist(),pixel_size=step,source_id=source['objects'][index]['id']))
    cells=set(new_cells)
    for path in [ROOT/'assets/world/current_map_validation/grass_cells.json',ROOT/'assets/world/east_earth_pavilion_1102/ground_grass.json',ROOT/'assets/world/oval_atrium_1031/ground_grass.json']:
        config=json.loads(path.read_text(encoding='utf-8'))
        cells.update(tuple(c) for c in config['cells'] if (c[0],c[2]) in columns)
    config=dict(version=1,cell_size_m=24,cells=sorted(cells),columns=len(columns),grass_mesh='res://assets/vegetation/models/grass_star_3card_v6.glb')
    (OUT/'ground_grass.json').write_text(json.dumps(config,indent=2)+'\n')
    source.update(mesh_sha256=hashlib.sha256(output).hexdigest(),triangles=sum(r['index_count']//3 for r in source['objects']),support=support)
    (OUT/'manifest.json').write_text(json.dumps(source,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(meshes=3,triangles=source['triangles'],glb_mib=len(output)/1048576,grass_cells=len(cells),columns=len(columns))))

if __name__=='__main__':build()
