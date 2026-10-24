"""Read-only numerical audit of the exact GLB used by map_1021.

No geometry cleanup is performed. Open boundaries are measurements, not errors.
Cross-object duplicate detection uses two independent hashes, with witnesses.
"""
from pathlib import Path
from collections import Counter
import hashlib, json, struct, time
import sys
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/world/current_map_validation/review'

def main():
    started = time.perf_counter()
    path = OUT.parent / 'current_region.glb'
    raw = path.read_bytes()
    size, kind = struct.unpack_from('<II', raw, 12)
    gltf = json.loads(raw[20:20+size])
    binary = memoryview(raw)[28+size:]
    meta = json.loads((OUT.parent/'metadata.json').read_text(encoding='utf-8-sig'))
    records = {r['id']: r for r in meta['object_records']}
    def access(index):
        a = gltf['accessors'][index]; v = gltf['bufferViews'][a['bufferView']]
        dtype = {5126:'<f4',5125:'<u4',5123:'<u2'}[a['componentType']]
        width = {'VEC3':3,'VEC2':2,'VEC4':4,'SCALAR':1}[a['type']]
        assert 'byteStride' not in v and 'sparse' not in a
        return np.frombuffer(binary, dtype, count=a['count']*width,
                             offset=v.get('byteOffset',0)+a.get('byteOffset',0)).reshape(-1,width)
    rows=[]; hashes=[]; face_owners=[]; object_hashes={}; identical=[]
    for object_index, node in enumerate(gltf['nodes']):
        ident=node['extras']['source_id']; r=dict(records[ident])
        primitive=gltf['meshes'][node['mesh']]['primitives'][0]
        p=access(primitive['attributes']['POSITION']).astype(np.float64)
        n=access(primitive['attributes']['NORMAL']).astype(np.float64)
        tri=access(primitive['indices']).reshape(-1,3).astype(np.int32)
        assert np.isfinite(p).all() and tri.min()>=0 and tri.max()<len(p)
        a,b,c=p[tri[:,0]],p[tri[:,1]],p[tri[:,2]]
        cross=np.cross(b-a,c-a); twice=np.linalg.norm(cross,axis=1)
        fn=cross/np.maximum(twice[:,None],1e-30)
        lengths=np.stack([np.linalg.norm(b-a,axis=1),np.linalg.norm(c-b,axis=1),np.linalg.norm(a-c,axis=1)],axis=1)
        quality=2*np.sqrt(3)*twice/np.maximum((lengths**2).sum(axis=1),1e-30)
        unique, weld=np.unique(p,axis=0,return_inverse=True)
        wt=weld[tri]; canonical=np.sort(wt,axis=1)
        _, face_counts=np.unique(canonical,axis=0,return_counts=True)
        e=np.concatenate([wt[:,[0,1]],wt[:,[1,2]],wt[:,[2,0]]])
        es=np.sort(e,axis=1); code=es[:,0].astype(np.int64)*len(unique)+es[:,1]
        order=np.argsort(code,kind='stable'); se=code[order]
        start=np.r_[0,np.flatnonzero(np.diff(se))+1]; counts=np.diff(np.r_[start,len(se)])
        pairs=start[counts==2]; e1=order[pairs]; e2=order[pairs+1]
        f1=e1%len(tri); f2=e2%len(tri)
        oriented=(e[:,0]<e[:,1]); bad_winding=oriented[e1]==oriented[e2]
        smooth=(np.einsum('ij,ij->i',fn[f1],fn[f2])>np.cos(np.radians(10))) & (twice[f1]>1e-10)&(twice[f2]>1e-10)
        # Compare normals at the SAME geometric endpoint on both incident faces.
        original=np.concatenate([tri[:,[0,1]],tri[:,[1,2]],tri[:,[2,0]]])
        low_original=np.where(oriented,original[:,0],original[:,1])
        high_original=np.where(oriented,original[:,1],original[:,0])
        seam_angle=np.maximum(np.arccos(np.clip(np.einsum('ij,ij->i',n[low_original[e1]],n[low_original[e2]]),-1,1)),
                              np.arccos(np.clip(np.einsum('ij,ij->i',n[high_original[e1]],n[high_original[e2]]),-1,1)))
        seam=smooth & (seam_angle>np.radians(20)) & ~bad_winding
        seam_indices=np.flatnonzero(seam)[:8]
        boundary_edge=es[order[start[counts==1]]]
        boundary_length=np.linalg.norm(unique[boundary_edge[:,1]]-unique[boundary_edge[:,0]],axis=1).sum()
        normal_len=np.linalg.norm(n,axis=1)
        normal_face=np.einsum('ij,ij->i',n[tri].mean(axis=1),fn)
        r.update(triangles=len(tri),vertices=len(p),unique_positions=len(unique),attributes=list(primitive['attributes']),
            finite_positions=True,invalid_indices=0,nonfinite_normals=int((~np.isfinite(n)).any(axis=1).sum()),
            zero_normals=int((normal_len<.5).sum()),degenerate_triangles=int((twice<=1e-10).sum()),
            tiny_triangles_below_1mm2=int((twice<2e-6).sum()),sliver_quality_below_0_001=int((quality<.001).sum()),
            duplicates_within_object=int(np.maximum(face_counts-1,0).sum()),
            boundary_edges=int((counts==1).sum()),boundary_length_m=float(boundary_length),
            nonmanifold_edges=int((counts>2).sum()),inconsistent_winding_edges=int(bad_winding.sum()),
            smooth_surface_normal_seams_gt20deg=int(seam.sum()),normal_seam_examples=[{
                'world_position':unique[e[e1[i],0]].tolist(),'angle_deg':float(np.degrees(seam_angle[i]))} for i in seam_indices],
            face_normal_opposed=int(((normal_face<-.1)&(twice>1e-10)).sum()),
            triangle_area_m2=float(twice.sum()*.5),edge_length_percentiles_m=np.percentile(lengths,[0,5,50,95,99,100]).tolist(),
            signed_volume_m3=float(np.einsum('ij,ij->i',a,np.cross(b,c)).sum()/6),
            extent_m=np.ptp(p,axis=0).tolist(),bounds_godot=[p.min(axis=0).tolist(),p.max(axis=0).tolist()])
        digest=hashlib.sha256(np.asarray(p,'<f4').tobytes()+tri.tobytes()).hexdigest()
        if digest in object_hashes: identical.append([object_hashes[digest],ident])
        object_hashes[digest]=ident
        # Canonical coordinate triangle hashes: order-independent, exact float32 positions.
        bits=np.asarray(p,'<f4').view('<u4').reshape(-1,3).astype(np.uint64)
        vh=(bits[:,0]*np.uint64(73856093))^(bits[:,1]*np.uint64(19349663))^(bits[:,2]*np.uint64(83492791))
        vh2=(bits[:,0]*np.uint64(2654435761))^(bits[:,1]*np.uint64(805459861))^(bits[:,2]*np.uint64(3674653429))
        h=np.sort(vh[tri],axis=1); h2=np.sort(vh2[tri],axis=1)
        key=np.empty(len(tri),dtype=[('a','<u8'),('b','<u8')])
        key['a']=h[:,0]*np.uint64(31)+h[:,1]*np.uint64(131)+h[:,2]*np.uint64(8191)
        key['b']=h2[:,0]*np.uint64(31)+h2[:,1]*np.uint64(131)+h2[:,2]*np.uint64(8191)
        hashes.append(key);face_owners.append(np.full(len(tri),object_index,dtype=np.int16))
        rows.append(r)
        if object_index%25==0:print('AUDIT',object_index,len(gltf['nodes']),flush=True)
    keys=np.concatenate(hashes);owners=np.concatenate(face_owners);ix=np.argsort(keys,kind='stable')
    equal=(keys[ix[1:]]==keys[ix[:-1]]) & (owners[ix[1:]]!=owners[ix[:-1]])
    pairs=np.sort(np.stack([owners[ix[1:][equal]],owners[ix[:-1][equal]]],axis=1),axis=1)
    pairs,pc=np.unique(pairs,axis=0,return_counts=True)
    duplicate_pairs=[{'a':rows[a]['id'],'b':rows[b]['id'],'matching_triangle_hashes':int(count)} for (a,b),count in zip(pairs,pc)]
    totals={k:sum(r[k] for r in rows) for k in ['triangles','vertices','unique_positions','degenerate_triangles','zero_normals','nonfinite_normals',
        'duplicates_within_object','nonmanifold_edges','inconsistent_winding_edges','smooth_surface_normal_seams_gt20deg',
        'boundary_edges','boundary_length_m','tiny_triangles_below_1mm2','sliver_quality_below_0_001','face_normal_opposed']}
    cad_path=OUT/'mesh_audit_rhino.json'
    cad_rows={r['id']:r for r in json.loads(cad_path.read_text(encoding='utf-8'))['rows']} if cad_path.exists() else {}
    report={'source_glb':str(path),'sha256':hashlib.sha256(raw).hexdigest(),'file_bytes':len(raw),'objects':len(rows),
        'totals':totals,'identical_objects':identical,'cross_object_matching_triangle_hashes':duplicate_pairs,
        'kinds':dict(Counter(r['kind'] for r in rows)),
        'collision_triangles':sum(r['triangles'] for r in rows if r.get('collision',True) or r['kind']=='Water'),
        'objects_without_uv':sum('TEXCOORD_0' not in r['attributes'] for r in rows),
        'objects_without_uv2':sum('TEXCOORD_1' not in r['attributes'] for r in rows),
        'objects_without_tangents':sum('TANGENT' not in r['attributes'] for r in rows),
        'inward_closed_shell_candidates':[{'id':r['id'],'name':r['name'],'signed_volume_m3':r['signed_volume_m3'],
            'native_rhino_solid_orientation':cad_rows.get(r['id'],{}).get('solid_orientation')} for r in rows
            if r['boundary_edges']==0 and r['nonmanifold_edges']==0 and r['inconsistent_winding_edges']==0 and r['signed_volume_m3']<0],
        'rows':rows,'elapsed_s':time.perf_counter()-started,
        'limits':['Exact position welding within each object; unwelded close seams and T-junctions are not exhaustively classified.',
            'Open edges may be intentional CAD sheets, holes or separate object interfaces; not automatically leaks.',
            'Cross-object hashes are overlap candidates, not exhaustive coplanar or self-intersection tests.',
            'Signed volumes are meaningful only for consistently oriented closed shells; connected components not separately tested.']}
    prefix=sys.argv[1] if len(sys.argv)>1 else 'mesh_audit'
    (OUT/(prefix+'_geometry.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k not in ['rows','cross_object_matching_triangle_hashes']},ensure_ascii=False,indent=2))

if __name__=='__main__':main()
