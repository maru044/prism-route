"""Compare repaired export to the saved original, including surface coverage."""
from pathlib import Path
import json,struct,hashlib
import numpy as np
from current_map_mesh_repairs import PAIRS,canonical
ROOT=Path(__file__).resolve().parents[1]

class GLB:
    def __init__(self,path):
        self.raw=path.read_bytes();size=struct.unpack_from('<I',self.raw,12)[0]
        self.json=json.loads(self.raw[20:20+size]);self.binary=memoryview(self.raw)[28+size:]
        self.nodes={n['extras']['source_id']:n for n in self.json['nodes']}
    def array(self,index,width,dtype):
        a=self.json['accessors'][index];v=self.json['bufferViews'][a['bufferView']]
        return np.frombuffer(self.binary,dtype,count=a['count']*width,offset=v.get('byteOffset',0)+a.get('byteOffset',0)).reshape(-1,width)
    def mesh(self,ident):
        pr=self.json['meshes'][self.nodes[ident]['mesh']]['primitives'][0]
        return (self.array(pr['attributes']['POSITION'],3,'<f4'),self.array(pr['attributes']['NORMAL'],3,'<f4'),self.array(pr['indices'],1,'<u4').reshape(-1,3))

def main():
    out=ROOT/'assets/world/current_map_validation/review'
    before=GLB(ROOT/'.current_map_build/mesh_repair_20261022_before/current_region.glb')
    after=GLB(out.parent/'current_region.glb');assert set(before.nodes)==set(after.nodes)
    shoulder='9571ee7f-ce6e-40f7-b13a-d1a647bb9b66'
    duplicate_targets={b for a,b in PAIRS}|{'37cde2e1-e1e8-431f-a80a-697f4a61017a'}
    rows=[]
    for ident in before.nodes:
        p,n,t=before.mesh(ident);q,m,u=after.mesh(ident)
        assert np.array_equal(p,q), 'A vertex moved: '+ident
        if ident!=shoulder:assert np.array_equal(n,m), 'Unexpected shading change: '+ident
        if ident not in duplicate_targets and ident!=shoulder:assert np.array_equal(t,u), 'Unrelated mesh changed: '+ident
        if ident==shoulder:
            assert np.array_equal(np.sort(canonical(p[t])),np.sort(canonical(q[u]))),'Shoulder surface changed'
            x=q[u].astype(np.float64);assert np.einsum('ij,ij->i',x[:,0],np.cross(x[:,1],x[:,2])).sum()>0
        rows.append({'id':ident,'positions_unchanged':True,'triangles_before':len(t),'triangles_after':len(u)})
    coverage=[]
    for a,b in PAIRS:
        old=[];new=[]
        for ident in [a,b]:
            p,_,t=before.mesh(ident);q,_,u=after.mesh(ident);old.append(canonical(p[t]));new.append(canonical(q[u]))
        equal=np.array_equal(np.unique(np.concatenate(old)),np.unique(np.concatenate(new)))
        assert equal, 'Overlap repair removed unique surface: '+b
        coverage.append({'owner':a,'duplicate':b,'surface_union_preserved':True})
    ident='37cde2e1-e1e8-431f-a80a-697f4a61017a'
    p,_,t=before.mesh(ident);q,_,u=after.mesh(ident)
    assert np.array_equal(np.unique(canonical(p[t])),np.unique(canonical(q[u])))
    report={'passed':True,'objects':len(rows),'all_positions_unchanged':True,'unrelated_indices_and_normals_unchanged':True,
            'removed_triangles':sum(r['triangles_before']-r['triangles_after'] for r in rows),
            'source_sha256':hashlib.sha256(before.raw).hexdigest(),'repaired_sha256':hashlib.sha256(after.raw).hexdigest(),
            'coverage':coverage,'rows':rows}
    (out/'mesh_repair_preservation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k not in ['coverage','rows']}))

if __name__=='__main__':main()
