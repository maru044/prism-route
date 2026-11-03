"""Package the native court and replacement hosts without rewriting the base map."""
from pathlib import Path
import json,struct,hashlib
import numpy as np
from build_water_court_1101 import world,PROTECTED
ROOT=Path(__file__).resolve().parents[1]
CACHE=ROOT/'.current_map_build/sunken_archive_1103';OUT=ROOT/'assets/world/sunken_archive_1103'

def build():
    OUT.mkdir(parents=True,exist_ok=True)
    protected={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in PROTECTED}
    source=json.loads((CACHE/'source.json').read_text(encoding='utf-8'));raw=(CACHE/'source.bin').read_bytes()
    assert source['cad_unchanged'] and len(source['objects'])==96
    blob=bytearray();views=[];accessors=[];meshes=[];nodes=[]
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
        assert np.isfinite(p).all() and np.isfinite(normal).all()
        attrs={'POSITION':array(p,5126,'VEC3',34962,True),'NORMAL':array(normal,5126,'VEC3',34962)}
        meshes.append(dict(primitives=[dict(attributes=attrs,indices=array(indices,5125,'SCALAR',34963),mode=4)]))
        nodes.append(dict(name=row['name'] if row['category']=='collision_helpers' else row['kind']+'_'+row['id'],mesh=len(meshes)-1))
    gltf=dict(asset=dict(version='2.0',generator='Prism Route native buried court'),scene=0,scenes=[dict(nodes=list(range(len(nodes))))],nodes=nodes,meshes=meshes,buffers=[dict(byteLength=len(blob))],bufferViews=views,accessors=accessors)
    text=json.dumps(gltf,separators=(',',':')).encode();text+=b' '*((-len(text))%4);blob+=b'\0'*((-len(blob))%4)
    output=struct.pack('<III',0x46546c67,2,12+8+len(text)+8+len(blob))+struct.pack('<II',len(text),0x4e4f534a)+text+struct.pack('<II',len(blob),0x004e4942)+blob
    (OUT/'court.glb').write_bytes(output)
    # Cut only the genuine openings from existing immutable grass roots.
    origin=np.array([-1396.,-38.]);extent=np.array([92.,84.]);size=256
    wx,wz=np.meshgrid(origin[0]+(np.arange(size)+.5)*extent[0]/size,origin[1]+(np.arange(size)+.5)*extent[1]/size)
    native=np.column_stack([(wx+1450.).ravel(),(1150.-wz).ravel()]);mask=np.zeros(len(native),np.float32)
    for key in ['occupied','opening','sky']:
        points=source['cut_polygons'][key]
        polygon=np.array(points);inside=np.zeros(len(native),bool);x,y=native.T
        for a,b in zip(polygon,np.roll(polygon,-1,axis=0)):
            if abs(b[1]-a[1])<1e-12:continue
            inside^=((a[1]>y)!=(b[1]>y))&(x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0])
        mask[inside]=2. if key=='occupied' else 1.
    (OUT/'grass_cut.rf').write_bytes(mask.astype('<f4').tobytes())
    source['grass_cut']={'origin_xz':origin.tolist(),'extent_xz':extent.tolist(),'size':[size,size]}
    source['routes']={k:[world(p) for p in v] for k,v in source['routes'].items()}
    source['spawn']=world(source['spawn'])
    source['views']={k:{**v,'eye':world(v['eye']),'target':world(v['target'])} for k,v in source['views'].items()}
    source.update(triangles=sum(r['index_count']//3 for r in source['objects']),mesh_sha256=hashlib.sha256(output).hexdigest(),glb_bytes=len(output))
    (OUT/'manifest.json').write_text(json.dumps(source,ensure_ascii=False,indent=2),encoding='utf-8')
    assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in protected.items())
    print(json.dumps({'objects':len(nodes),'triangles':source['triangles'],'glb_bytes':len(output),'protected_files_unchanged':len(protected)}))
if __name__=='__main__':build()
