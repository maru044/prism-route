"""Keep one exact, same-facing copy of the six audited CAD overlap patches.

CAD solids retain their construction faces/UUIDs. This pass operates on the
export only, preserves original vertex positions and shading normals, and
never deletes an entire object or approximately matches nearby geometry.
"""
import json
import numpy as np

PAIRS = [
    ('6ff4660f-d023-461f-a4ac-9f0038a79c6d','1df69efa-10ae-4af3-bf52-c8510f167429'),
    ('f6bf901b-4e02-49c2-8a1c-6382c255c941','3a784408-92fe-4bef-aa04-2c2e3f2bd05a'),
    ('f6bf901b-4e02-49c2-8a1c-6382c255c941','9f4e6ec5-912a-4884-9c5a-4be69f1ff211'),
    ('de6391b1-e6fa-48bf-978c-b261e0d6d4b4','d01b8d98-9f3d-46e7-8737-7b60ad7a5657'),
    ('f0fd81ff-2de8-49cb-be97-a312dd9b3933','ecb36196-315f-4c98-9a41-9fada2f0724f'),
    ('f0fd81ff-2de8-49cb-be97-a312dd9b3933','ff65d92e-54e8-4420-94f7-6103ab69480c'),
]

def canonical(points):
    order=np.lexsort((points[:,:,2],points[:,:,1],points[:,:,0]),axis=1)
    values=np.take_along_axis(points,order[:,:,None],axis=1).reshape(-1,9)
    return np.ascontiguousarray(values).view(np.dtype([(str(i),'<f4') for i in range(9)])).reshape(-1)

class ExportRepairs:
    def __init__(self,source,raw):
        records={r['id']:r for r in source['objects']};center=np.asarray(source['native_center'],np.float32)
        self.masks={};self.rows=[];cache={}
        def geometry(ident):
            if ident not in cache:
                r=records[ident]
                p=np.frombuffer(raw,'<f4',count=r['vertex_count']*3,offset=r['offset']).reshape(-1,3).copy()
                p-=center;p=p[:,[0,2,1]];p[:,2]*=-1
                tri=np.frombuffer(raw,'<u4',count=r['index_count'],offset=r['offset']+r['vertex_count']*12).reshape(-1,3)
                points=p[tri];normal=np.cross(points[:,1]-points[:,0],points[:,2]-points[:,0])
                cache[ident]=(canonical(points),normal,len(tri))
            return cache[ident]
        for owner,duplicate in PAIRS:
            if owner not in records or duplicate not in records:continue
            assert records[owner]['kind']==records[duplicate]['kind'], 'Overlap semantics differ; review ownership'
            a,an,_=geometry(owner);b,bn,count=geometry(duplicate)
            _,ai,bi=np.intersect1d(a,b,return_indices=True)
            same=np.einsum('ij,ij->i',an[ai],bn[bi])>0
            remove=bi[same]
            mask=self.masks.setdefault(duplicate,np.ones(count,dtype=bool));mask[remove]=False
            assert mask.any(), 'Repair must preserve independent portions of every CAD object'
            self.rows.append({'owner':owner,'duplicate':duplicate,'removed_triangles':len(remove)})
        # The audit also confirmed eight same-facing duplicates within this
        # one support assembly. Opposite-facing sheets are deliberately kept.
        ident='37cde2e1-e1e8-431f-a80a-697f4a61017a'
        if ident in records:
            keys,normals,count=geometry(ident)
            _,first,inverse=np.unique(keys,return_index=True,return_inverse=True)
            repeated=np.flatnonzero(np.arange(count)!=first[inverse])
            remove=repeated[np.einsum('ij,ij->i',normals[repeated],normals[first[inverse[repeated]]])>0]
            keep=self.masks.setdefault(ident,np.ones(count,dtype=bool));keep[remove]=False
            self.rows.append({'owner':ident,'duplicate':ident,'removed_triangles':len(remove)})

    def mask(self,item,positions,triangles):
        keep=self.masks.get(item['id'],np.ones(len(triangles),dtype=bool))
        item['export_index_count']=int(keep.sum())*3
        return keep

    def write_report(self,path):
        report={'method':'Exact nine-coordinate triangle equality, same winding, explicit owner; no vertex displacement or normal recomputation after removal.',
                'pairs':self.rows,'removed_triangles':sum(r['removed_triangles'] for r in self.rows),
                'cad_overlap_solids_preserved':True,'all_object_ids_preserved':True}
        path.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
