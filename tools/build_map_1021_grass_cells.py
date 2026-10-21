"""Index potentially plantable 24 m volumes; no grass density/geometry changes."""
from pathlib import Path
import hashlib, itertools, json
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
CACHE=ROOT/'.current_map_build'
OUT=ROOT/'assets/world/current_map_validation'

def main():
    source=json.loads((CACHE/'source.json').read_text(encoding='utf-8-sig'))
    metadata=json.loads((OUT/'metadata.json').read_text(encoding='utf-8'))
    kinds={r['id']:r['kind'] for r in metadata['object_records']}
    center=np.asarray(source['native_center'],dtype=np.float32)
    cells=set();sources=0
    for row in source['objects']:
        if kinds[row['id']]!='Terrain':continue
        vertices=np.memmap(CACHE/'source.bin',dtype='<f4',mode='r',offset=row['offset'],shape=(row['vertex_count'],3))
        faces=np.memmap(CACHE/'source.bin',dtype='<u4',mode='r',offset=row['offset']+row['vertex_count']*12,shape=(row['index_count']//3,3))
        for start in range(0,len(faces),100000):
            tri=np.asarray(vertices[faces[start:start+100000]],dtype=np.float32)
            normal=np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0]);length=np.linalg.norm(normal,axis=1)
            tri=tri[(length>1e-8)&(np.abs(normal[:,2])>=length*.72)]
            if not len(tri):continue
            tri-=center;tri=tri[:,:,[0,2,1]];tri[:,:,2]*=-1
            # Small padding makes surfaces on cell boundaries discoverable;
            # the runtime assigns each accepted root to exactly one Y cell.
            low=np.floor((tri.min(1)-.002)/24).astype(np.int32)
            high=np.floor((tri.max(1)+.002)/24).astype(np.int32)
            single=(low==high).all(1)
            cells.update(map(tuple,np.unique(low[single],axis=0).tolist()))
            ranges=np.unique(np.concatenate([low[~single],high[~single]],axis=1),axis=0)
            for r in ranges:
                cells.update(itertools.product(*(range(int(r[i]),int(r[i+3])+1) for i in range(3))))
        sources+=1
    rows=sorted(cells)
    path=OUT/'grass_cells.json'
    path.write_text(json.dumps({'cell_size_m':24,'cells':rows,'source_mesh_sha256':metadata['mesh_sha256'],'surface_roles_sha256':hashlib.sha256((OUT/'surface_roles.json').read_bytes()).hexdigest(),'terrain_objects':sources},separators=(',',':')),encoding='utf-8')
    print(json.dumps({'grass_volume_cells':len(rows),'terrain_objects':sources,'bytes':path.stat().st_size}))

if __name__=='__main__':main()
