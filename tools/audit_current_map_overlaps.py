"""Verify hash candidates with complete float32 triangle coordinates."""
from pathlib import Path
import json, struct, sys
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/world/current_map_validation/review'

def main():
    raw=(OUT.parent/'current_region.glb').read_bytes();size=struct.unpack_from('<I',raw,12)[0]
    gltf=json.loads(raw[20:20+size]);binary=memoryview(raw)[28+size:]
    prefix=sys.argv[1] if len(sys.argv)>1 else 'mesh_audit'
    data=json.loads((OUT/(prefix+'_geometry.json')).read_text(encoding='utf-8'))
    rows={r['id']:r for r in data['rows']};nodes={n['extras']['source_id']:n for n in gltf['nodes']}
    def access(index,width):
        a=gltf['accessors'][index];v=gltf['bufferViews'][a['bufferView']]
        return np.frombuffer(binary,{5126:'<f4',5125:'<u4'}[a['componentType']],count=a['count']*width,offset=v.get('byteOffset',0)+a.get('byteOffset',0)).reshape(-1,width)
    def triangles(ident):
        primitive=gltf['meshes'][nodes[ident]['mesh']]['primitives'][0]
        p=access(primitive['attributes']['POSITION'],3);tri=access(primitive['indices'],1).reshape(-1,3)
        pts=p[tri];normals=np.cross(pts[:,1]-pts[:,0],pts[:,2]-pts[:,0])
        # Lexicographic vertex ordering; retain original triangle normal separately.
        order=np.lexsort((pts[:,:,2],pts[:,:,1],pts[:,:,0]),axis=1)
        canonical=np.take_along_axis(pts,order[:,:,None],axis=1).reshape(-1,9)
        dtype=np.dtype([(str(i),'<f4') for i in range(9)])
        return np.ascontiguousarray(canonical).view(dtype).reshape(-1),pts,normals
    report=[]
    for candidate in data['cross_object_matching_triangle_hashes']:
        a,b=candidate['a'],candidate['b'];ak,ap,an=triangles(a);bk,bp,bn=triangles(b)
        _,ai,bi=np.intersect1d(ak,bk,return_indices=True)
        dots=np.einsum('ij,ij->i',an[ai],bn[bi]);area=np.linalg.norm(an[ai],axis=1)*.5
        report.append({'a':a,'b':b,'a_name':rows[a]['name'],'b_name':rows[b]['name'],'a_kind':rows[a]['kind'],'b_kind':rows[b]['kind'],
            'exact_duplicate_triangles':len(ai),'same_winding':int((dots>0).sum()),'opposite_winding':int((dots<0).sum()),
            'overlap_area_m2':float(area.sum()),'examples':[{'world_position':ap[i].mean(axis=0).tolist(),'triangle_a':int(i),'triangle_b':int(j)} for i,j in list(zip(ai,bi))[:5]]})
    output={'method':'All nine float32 coordinates compared exactly after canonical vertex sort; winding checked separately. This verifies candidate duplicates, not all coplanar overlaps.','pairs':report}
    (OUT/(prefix+'_overlaps.json')).write_text(json.dumps(output,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(output,ensure_ascii=False,indent=2))

if __name__=='__main__':main()
