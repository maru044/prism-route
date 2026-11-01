"""Package reviewed CAD and a local grass-support field, without rewriting the base map."""
from pathlib import Path
import json,struct,hashlib
import numpy as np
from build_water_court_1101 import PROTECTED,world
ROOT=Path(__file__).resolve().parents[1]
CACHE=ROOT/'.current_map_build/east_earth_pavilion_1102'
OUT=ROOT/'assets/world/east_earth_pavilion_1102'

def raster(triangles,origin,step,field):
    height,width=field.shape
    for a,b,c in triangles:
        normal=np.cross(b-a,c-a)
        if normal[1]<=.72*np.linalg.norm(normal):continue
        q=(np.array([a[[0,2]],b[[0,2]],c[[0,2]]])-origin)/step
        lo=np.maximum(0,np.ceil(q.min(0)).astype(int));hi=np.minimum([width-1,height-1],np.floor(q.max(0)).astype(int))
        if np.any(hi<lo):continue
        x,z=np.meshgrid(np.arange(lo[0],hi[0]+1),np.arange(lo[1],hi[1]+1))
        den=(q[1,1]-q[2,1])*(q[0,0]-q[2,0])+(q[2,0]-q[1,0])*(q[0,1]-q[2,1])
        if abs(den)<1e-8:continue
        u=((q[1,1]-q[2,1])*(x-q[2,0])+(q[2,0]-q[1,0])*(z-q[2,1]))/den
        v=((q[2,1]-q[0,1])*(x-q[2,0])+(q[0,0]-q[2,0])*(z-q[2,1]))/den
        inside=(u>=-1e-6)&(v>=-1e-6)&(u+v<=1.000001)
        surface=u*a[1]+v*b[1]+(1-u-v)*c[1]
        region=field[lo[1]:hi[1]+1,lo[0]:hi[0]+1]
        np.maximum(region,np.where(inside,surface,-10000.),out=region)

def build(protection_snapshot='import_protected_hashes.json'):
    OUT.mkdir(parents=True,exist_ok=True)
    assert Path(protection_snapshot).name==protection_snapshot and protection_snapshot.endswith('.json')
    protected_path=CACHE/protection_snapshot
    protected_files=PROTECTED+['assets/world/water_court_1101/court.glb','assets/world/water_court_1101/manifest.json']
    if not protected_path.exists():protected_path.write_text(json.dumps({p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in protected_files},indent=2))
    protected=json.loads(protected_path.read_text());assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in protected.items())
    source=json.loads((CACHE/'source.json').read_text(encoding='utf-8'));raw=(CACHE/'source.bin').read_bytes()
    assert source['cad_unchanged'] and len(source['objects'])==89
    blob=bytearray();views=[];accessors=[];meshes=[];nodes=[];terrain=[];paving=[];new_soil=[]
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
        if row['kind']=='Terrain':
            triangles=p[indices.reshape(-1,3)];terrain.append(triangles)
            if row['category']!='host_replacement':new_soil.append(triangles)
        elif row['category'] in ['08_ramps','02_floors']:paving.append(p[indices.reshape(-1,3)])
        attrs={'POSITION':array(p,5126,'VEC3',34962,True),'NORMAL':array(normal,5126,'VEC3',34962)}
        meshes.append(dict(primitives=[dict(attributes=attrs,indices=array(indices,5125,'SCALAR',34963),mode=4)]))
        nodes.append(dict(name=row['kind']+'_'+row['id'],mesh=len(meshes)-1))
    gltf=dict(asset=dict(version='2.0',generator='Prism Route reviewed earth pavilion'),scene=0,scenes=[dict(nodes=list(range(len(nodes))))],
        nodes=nodes,meshes=meshes,buffers=[dict(byteLength=len(blob))],bufferViews=views,accessors=accessors)
    text=json.dumps(gltf,separators=(',',':')).encode();text+=b' '*((-len(text))%4);blob+=b'\0'*((-len(blob))%4)
    output=struct.pack('<III',0x46546c67,2,12+8+len(text)+8+len(blob))+struct.pack('<II',len(text),0x4e4f534a)+text+struct.pack('<II',len(blob),0x004e4942)+blob
    (OUT/'pavilion.glb').write_bytes(output)
    # A height field hides obsolete baked roots only where their supporting earth moved.
    terrain=np.concatenate(terrain);lo=terrain[:,:,[0,2]].min((0,1))-1.;hi=terrain[:,:,[0,2]].max((0,1))+1.
    step=.75;size=np.ceil((hi-lo)/step).astype(int)+1
    support=np.full((size[1],size[0]),-10000.,np.float32);roof=support.copy()
    raster(terrain,lo,step,support)
    for triangles in paving:raster(triangles,lo,step,roof)
    valid=(support>-9999)&~((roof>=support-.02)&(roof<=support+1.55))
    # The rectangle is storage only. Preserve roots outside the actual excavation
    # and added berm, including lower terraces underneath this projected region.
    added=np.full_like(support,-10000.)
    for triangles in new_soil:raster(triangles,lo,step,added)
    wx,wz=np.meshgrid(lo[0]+step*np.arange(size[0]),lo[1]+step*np.arange(size[1]))
    u=285.-wz;stations=np.array(source['parameters']['contour_stations'])
    k=np.clip(np.floor((865.+u-stations[0,0])/5.).astype(int),0,len(stations)-2)
    t=(865.+u-stations[k,0])/5.;x0=stations[k,1];x1=stations[k+1,1]
    d0=(stations[k+1,1]-stations[np.maximum(0,k-1),1])/np.where(k==0,1.,2.)
    d1=(stations[np.minimum(len(stations)-1,k+2),1]-stations[k,1])/np.where(k+2<len(stations),2.,1.)
    front=(2*t**3-3*t*t+1)*x0+(t**3-2*t*t+t)*d0+(-2*t**3+3*t*t)*x1+(t**3-t*t)*d1
    v=wx+1450.-front;affected=(u/130.)**2+((v-45.)/90.)**2<=1.
    affected|=added>-9999.
    status=np.where(affected,valid.astype(np.float32),2.)
    data=np.stack([support,status],axis=-1)
    (OUT/'grass_support.rgf').write_bytes(data.astype('<f4').tobytes())
    source['grass_support']=dict(origin_xz=lo.tolist(),extent_xz=(step*size).tolist(),size=size.tolist(),pixel_size=step,
        valid_samples=int((valid&affected).sum()),affected_samples=int(affected.sum()),outside_samples=int((~affected).sum()))
    for key in ['spawn','review_eye','review_target','court_eye','court_target','entry_eye','entry_target']:source[key]=world(source[key])
    source['routes']={key:[world(p) for p in route] for key,route in source['routes'].items()}
    source['spawn_source_id']=next(r['id'] for r in source['objects'] if r['name'].endswith('Lower_continuous_floor'))
    source.update(mesh_sha256=hashlib.sha256(output).hexdigest(),triangles=sum(r['index_count']//3 for r in source['objects']))
    (OUT/'manifest.json').write_text(json.dumps(source,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in protected.items())
    print(json.dumps(dict(meshes=len(nodes),triangles=source['triangles'],collision_bodies=sum(r['collision'] for r in source['objects']),glb_bytes=len(output),protected=len(protected))))
if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument('--protection-snapshot',default='import_protected_hashes.json')
    build(parser.parse_args().protection_snapshot)
