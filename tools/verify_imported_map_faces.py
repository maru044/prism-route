"""Prove base geometry equality despite importer vertex/triangle reordering."""
from pathlib import Path
import hashlib,json
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
CACHE=ROOT/'.current_map_build'

def oriented_keys(points):
    first=np.lexsort((points[:,:,2],points[:,:,1],points[:,:,0]),axis=1)[:,0]
    order=(first[:,None]+np.arange(3))%3
    canonical=np.take_along_axis(points,order[:,:,None],axis=1).reshape(-1,9)
    keys=np.ascontiguousarray(canonical).view(np.dtype([(str(i),'<f4') for i in range(9)])).reshape(-1)
    return np.sort(keys)

def main():
    rows=json.loads((CACHE/'imported_faces.json').read_text())
    imported=np.memmap(CACHE/'imported_faces.bin',dtype='<f4',mode='r')
    direct=np.memmap(CACHE/'direct_faces.bin',dtype='<f4',mode='r')
    results=[]
    for row in rows:
        a=imported[row['offset']//4:(row['offset']+row['bytes'])//4].reshape(-1,3,3)
        b=direct[row['source_offset']//4:(row['source_offset']+row['source_bytes'])//4].reshape(-1,3,3)
        equal=a.shape==b.shape and np.array_equal(oriented_keys(a),oriented_keys(b))
        results.append({'id':row['id'],'oriented_triangle_multiset_equal':bool(equal),'triangles':len(a)})
    assets=ROOT/'assets/world/current_map_validation'
    report={'passed':all(r['oriented_triangle_multiset_equal'] for r in results),'objects':len(results),
            'mesh_sha256':hashlib.sha256((assets/'current_region.glb').read_bytes()).hexdigest(),
            'method':'Exact float32 oriented triangle multiset equality; cyclic rotations permitted, winding reversal forbidden. Includes multiplicity.',
            'rows':results}
    (assets/'review/mesh_repair_imported_faces.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k!='rows'}));assert report['passed']

if __name__=='__main__':main()
