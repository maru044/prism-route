"""Fit a local Z-only bridge repair, then package its reviewed native mesh."""
from pathlib import Path
import json, struct
import numpy as np
from scipy.interpolate import BSpline

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / '.current_map_build/road_junction_1104'
OUT = ROOT / 'assets/world/road_junction_1104'

def fit():
    data = json.loads((CACHE/'fit_input.json').read_text())
    road = np.array(json.loads((CACHE/'road_samples.json').read_text()))
    road = road[(road[:,1]>=715) & (road[:,1]<=795)]
    def polynomial(xy):
        x,y = ((xy-np.array([1675.,755.]))/50.).T
        return np.array([x**i*y**j for i in range(4) for j in range(4-i)]).T
    coefficients = np.linalg.lstsq(polynomial(road[:,:2]),road[:,2],rcond=None)[0]
    road_error = float(np.max(np.abs(polynomial(road[:,:2])@coefficients-road[:,2])))
    assert road_error < .003, road_error
    samples = np.array(data['samples']);cp = np.array(data['cp'])
    def basis(axis, parameters):
        k = data['knots_'+axis];k = np.array([k[0]]+k+[k[-1]])
        return BSpline.design_matrix(parameters,k,data['degree_'+axis]).toarray(),k
    bu,ku = basis('u',samples[:,0]);bv,kv = basis('v',samples[:,1])
    assert np.max(np.abs(np.einsum('ni,nj,ijc->nc',bu,bv,cp)-samples[:,2:])) < 1e-8
    back = data['end']-samples[:,1]
    t = np.clip((55-back)/(55-18),0,1)
    t = t*t*t  # Keep the existing approach clear of the sculpted bridge support.
    blend = t*t*t*(10-15*t+6*t*t)
    target = (polynomial(samples[:,2:4])@coefficients-samples[:,4])*blend
    active = [j for j in range(cp.shape[1]) if kv[j]>=data['end']-55-1e-8]
    matrix = np.einsum('ni,nj->nij',bu,bv[:,active]).reshape(len(samples),-1)
    weights = np.where(back<=18,5.,1.)
    delta = np.linalg.lstsq(matrix*weights[:,None],target*weights,rcond=None)[0]
    cp[:,active,2] += delta.reshape(4,len(active))
    repaired = np.einsum('ni,nj,ijc->nc',bu,bv,cp)
    overlaps = back<=14
    error = float(np.max(np.abs(repaired[overlaps,2]-polynomial(repaired[overlaps,:2])@coefficients)))
    assert error < .005,error
    report = dict(changed_id='0808d32c-6ebc-4105-9258-a0f755ac2752',
                  transition_length_m=55.,full_match_last_m=18.,xy_unchanged=True,
                  road_fit_error_m=road_error,overlap_fit_error_m=error,
                  max_z_correction_m=float(np.max(np.abs(repaired[:,2]-samples[:,4]))),
                  original_overlap_step_m=float(np.max(np.abs(samples[overlaps,4]-polynomial(samples[overlaps,2:4])@coefficients))))
    (CACHE/'fit_output.json').write_text(json.dumps(dict(cp=cp.tolist(),report=report),indent=2)+'\n')
    print(json.dumps(report))

def package():
    OUT.mkdir(parents=True,exist_ok=True)
    source=json.loads((CACHE/'source.json').read_text(encoding='utf-8'))
    raw=(CACHE/'source.bin').read_bytes();row=source['objects'][0];n=row['vertex_count']
    p=np.frombuffer(raw,'<f4',n*3,row['offset']).reshape(-1,3).copy()
    p-=np.array([1450,1150,0],np.float32);p=p[:,[0,2,1]];p[:,2]*=-1
    normals=np.frombuffer(raw,'<f4',n*3,row['normal_offset']).reshape(-1,3).copy()
    normals=normals[:,[0,2,1]];normals[:,2]*=-1
    indices=np.frombuffer(raw,'<u4',row['index_count'],row['offset']+n*12)
    blob=bytearray();views=[];accessors=[]
    def array(data,component,kind,target,bounds=False):
        data=np.ascontiguousarray(data);offset=len(blob);blob.extend(data.tobytes())
        views.append(dict(buffer=0,byteOffset=offset,byteLength=data.nbytes,target=target))
        a=dict(bufferView=len(views)-1,componentType=component,count=len(data),type=kind)
        if bounds:a.update(min=data.min(0).tolist(),max=data.max(0).tolist())
        accessors.append(a);return len(accessors)-1
    primitive=dict(attributes=dict(POSITION=array(p,5126,'VEC3',34962,True),NORMAL=array(normals,5126,'VEC3',34962)),indices=array(indices,5125,'SCALAR',34963),mode=4)
    gltf=dict(asset=dict(version='2.0',generator='Prism Route local bridge junction repair'),scene=0,
              scenes=[dict(nodes=[0])],nodes=[dict(name='Road_'+row['id'],mesh=0)],meshes=[dict(primitives=[primitive])],
              buffers=[dict(byteLength=len(blob))],bufferViews=views,accessors=accessors)
    text=json.dumps(gltf,separators=(',',':')).encode();text+=b' '*((-len(text))%4)
    (OUT/'junction.glb').write_bytes(struct.pack('<III',0x46546c67,2,28+len(text)+len(blob))+struct.pack('<II',len(text),0x4e4f534a)+text+struct.pack('<II',len(blob),0x004e4942)+blob)
    (OUT/'manifest.json').write_text(json.dumps(source,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('packaged',row['index_count']//3,'triangles')

if __name__=='__main__':
    import sys
    package() if '--package' in sys.argv else fit()
