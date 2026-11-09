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


def build_road_shoulder():
    """Classify one existing host locally and bake a road-edge SDF; no mesh rewrite."""
    import cv2
    from scipy.spatial import cKDTree
    from PIL import Image
    path=ROOT/'assets/world/current_map_validation/current_region.glb'
    data=path.read_bytes();size=struct.unpack_from('<I',data,12)[0]
    gltf=json.loads(data[20:20+size]);binary=memoryview(data)[28+size:]
    def accessor(index):
        a=gltf['accessors'][index];v=gltf['bufferViews'][a['bufferView']]
        offset=v.get('byteOffset',0)+a.get('byteOffset',0)
        dtype={5126:'<f4',5125:'<u4',5123:'<u2'}[a['componentType']]
        n={'SCALAR':1,'VEC3':3}[a['type']]
        return np.frombuffer(binary,dtype,count=a['count']*n,offset=offset).reshape(-1,n).copy()
    def geometry(ident):
        node=next(n for n in gltf['nodes'] if n.get('name','').endswith(ident))
        primitive=gltf['meshes'][node['mesh']]['primitives'][0]
        p=accessor(primitive['attributes']['POSITION'])
        ix=accessor(primitive['indices']).reshape(-1,3)
        tri=p[ix];cross=np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0])
        good=cross[:,1]>.72*np.linalg.norm(cross,axis=1)
        return p,ix,tri[good]
    host='1da83a02-adcc-4ab8-9e5b-0beafdabdb96'
    road='3f760bb7-a390-4660-9289-81f18adc3f48'
    p,ix,tri=geometry(host);rp,rix,rt=geometry(road)
    step=.5;origin=np.floor(p[:,[0,2]].min(0))-2
    extent=np.ceil(p[:,[0,2]].max(0))-origin+2
    shape=np.ceil(extent/step).astype(int)
    field=np.full((shape[1],shape[0]),-10000.,np.float32)
    print('SHOULDER_RASTER_START',len(tri),shape.tolist(),flush=True)
    raster(tri,origin+step*.5,step,field)
    # Top-surface boundary edges; weld split vertices before edge counting.
    projected=rt[:,:,[0,2]].reshape(-1,2)
    unique,inverse=np.unique(np.round(projected,5),axis=0,return_inverse=True)
    faces=inverse.reshape(-1,3)
    edges=np.concatenate([faces[:,[0,1]],faces[:,[1,2]],faces[:,[2,0]]])
    edges.sort(1);edges,counts=np.unique(edges,axis=0,return_counts=True)
    edges=edges[counts==1];a=unique[edges[:,0]];b=unique[edges[:,1]]
    # Split long source edges for a provably bounded nearest-segment search.
    aa=[];bb=[]
    for first,last in zip(a,b):
        n=max(1,int(np.ceil(np.linalg.norm(last-first)/.5)))
        t=np.linspace(0,1,n+1);points=first[None,:]+t[:,None]*(last-first)
        aa.append(points[:-1]);bb.append(points[1:])
    a=np.concatenate(aa);b=np.concatenate(bb);ab=b-a
    tree=cKDTree((a+b)*.5)
    inside=np.zeros(field.shape,np.uint8)
    for t in rt:
        pixels=np.round((t[:,[0,2]]-origin)/step-.5).astype(np.int32)
        cv2.fillConvexPoly(inside,pixels,1)
    distance=np.empty(field.shape,np.float32);max_error=0.
    for start in range(0,field.size,50000):
        end=min(start+50000,field.size);index=np.arange(start,end)
        points=origin+(np.c_[index%shape[0],index//shape[0]]+.5)*step
        _,near=tree.query(points,k=8,workers=2)
        ap=points[:,None,:]-a[near];edge=ab[near]
        t=np.clip((ap*edge).sum(2)/np.maximum((edge*edge).sum(2),1e-12),0,1)
        value=np.sqrt(((ap-t[:,:,None]*edge)**2).sum(2).min(1))
        distance.flat[start:end]=value
        if start==0:
            sample=points[::max(1,len(points)//64)]
            delta=sample[:,None,:]-a
            tt=np.clip((delta*ab).sum(2)/np.maximum((ab*ab).sum(1),1e-12),0,1)
            exact=np.sqrt(((delta-tt[:,:,None]*ab)**2).sum(2).min(1))
            max_error=float(np.abs(exact-value[::max(1,len(points)//64)]).max())
    assert max_error<.01,max_error
    distance[inside>0]*=-1
    curb=1.0;sdf=np.clip(distance-curb,-18,18)
    packed=np.stack([sdf,field],-1).astype('<f2')
    mask=OUT/'road_shoulder_mask.rgh';mask.write_bytes(packed.tobytes())
    # Native Rhino bitmap, same world projection as the game SDF.
    white=np.clip(.5-sdf/.12,0,1)
    colors=np.array([143,160,105])[None,None,:]*(1-white[:,:,None])+np.array([235,232,220])[None,None,:]*white[:,:,None]
    preview=OUT/'road_shoulder_preview.png'
    Image.fromarray(np.uint8(colors)).save(preview)
    z,x=np.nonzero((field>.17)&(sdf>.55))
    wx=origin[0]+(x+.5)*step;wz=origin[1]+(z+.5)*step
    base_columns=set(zip(np.floor(wx/24).astype(int).tolist(),np.floor(wz/24).astype(int).tolist()))
    columns={(x+dx,z+dz) for x,z in base_columns for dx in [-1,0,1] for dz in [-1,0,1]}
    cells={(x,0,z) for x,z in columns}
    for config_path in [ROOT/'assets/world/current_map_validation/grass_cells.json',OUT/'ground_grass.json',
                        ROOT/'assets/world/east_earth_pavilion_1102/ground_grass.json',ROOT/'assets/world/oval_atrium_1031/ground_grass.json']:
        config=json.loads(config_path.read_text(encoding='utf8'))
        cells.update(tuple(c) for c in config['cells'] if (c[0],c[2]) in columns)
    manifest_path=OUT/'manifest.json';manifest=json.loads(manifest_path.read_text(encoding='utf8'))
    manifest['road_shoulder']=dict(source_id=host,road_id=road,mask_path=mask.name,preview_path=preview.name,
        mask_sha256=sha(mask),source_mesh_sha256=sha(path),size=shape.tolist(),origin_xz=origin.tolist(),
        pixel_size=step,curb_width_m=curb,grass_clearance_m=.55,source_crc=3550652282,
        bounds=[p.min(0).tolist(),p.max(0).tolist()],cells=sorted(cells),boundary_error_m=max_error,
        review_eye=[-365,22,-534],review_target=[-290,1,-570])
    manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(json.dumps(dict(mask_size=shape.tolist(),cells=len(cells),columns=len(columns),
        host_triangles=len(tri),road_boundary_segments=len(a),boundary_error_m=max_error)),flush=True)


if __name__=='__main__':
    import sys
    if '--road-shoulder' in sys.argv:build_road_shoulder()
    else:build()
