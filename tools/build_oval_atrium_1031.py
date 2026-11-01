"""Build an additive runtime replacement; preserve the base GLB and grass bake."""
from pathlib import Path
import hashlib,json,struct,shutil
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
CACHE=ROOT/'.current_map_build/oval_atrium_1031'
OUT=ROOT/'assets/world/oval_atrium_1031'
DOC=ROOT/'docs/oval_atrium_1031/game'
PROTECTED=['assets/world/current_map_validation/current_region.glb','assets/world/current_map_validation/metadata.json',
    'assets/world/current_map_validation/tree_layout.json','assets/world/current_map_validation/tree_layout_metadata.json',
    'assets/world/current_map_validation/grass_bake/manifest.json','assets/world/upper_ring_1030/manifest.json',
    'assets/world/island_saddle_1031/manifest.json']
def world(p):return [p[0]-1450.,p[2],1150.-p[1]]
def snapshot():
    CACHE.mkdir(parents=True,exist_ok=True);DOC.mkdir(parents=True,exist_ok=True)
    path=CACHE/'protected_hashes.json'
    if not path.exists():path.write_text(json.dumps({p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in PROTECTED},indent=2))
    backup=CACHE/'world_edits_before.json'
    if not backup.exists():shutil.copy2(ROOT/'assets/world/tree_planting/world_edits.json',backup)
def build():
    source=json.loads((CACHE/'source.json').read_text(encoding='utf-8'));raw=(CACHE/'source.bin').read_bytes()
    OUT.mkdir(parents=True,exist_ok=True);blob=bytearray();views=[];accessors=[];meshes=[];nodes=[]
    def array(data,component,shape,target,bounds=False):
        while len(blob)%4:blob.append(0)
        data=np.ascontiguousarray(data);offset=len(blob);blob.extend(data.tobytes())
        views.append({'buffer':0,'byteOffset':offset,'byteLength':data.nbytes,'target':target})
        row={'bufferView':len(views)-1,'componentType':component,'count':len(data),'type':shape}
        if bounds:row.update(min=data.min(axis=0).astype(float).tolist(),max=data.max(axis=0).astype(float).tolist())
        accessors.append(row);return len(accessors)-1
    for item in source['objects']:
        count=item['vertex_count'];offset=item['offset']
        p=np.frombuffer(raw,'<f4',count=count*3,offset=offset).reshape(-1,3).copy()
        p-=np.array(source['native_center'],dtype='<f4');p=p[:,[0,2,1]];p[:,2]*=-1
        normal=np.frombuffer(raw,'<f4',count=count*3,offset=item['normal_offset']).reshape(-1,3).copy()
        normal=normal[:,[0,2,1]];normal[:,2]*=-1
        indices=np.frombuffer(raw,'<u4',count=item['index_count'],offset=offset+count*12)
        attributes={'POSITION':array(p.astype('<f4'),5126,'VEC3',34962,True),'NORMAL':array(normal.astype('<f4'),5126,'VEC3',34962)}
        if item['uv_offset'] is not None:
            uv=np.frombuffer(raw,'<f4',count=count*2,offset=item['uv_offset']).reshape(-1,2).copy();uv[:,1]=1.-uv[:,1]
            attributes['TEXCOORD_0']=array(uv.astype('<f4'),5126,'VEC2',34962)
        primitive={'attributes':attributes,'indices':array(indices,5125,'SCALAR',34963),'mode':4}
        meshes.append({'primitives':[primitive]});nodes.append({'name':item['kind']+'_'+item['id'],'mesh':len(meshes)-1})
    gltf={'asset':{'version':'2.0','generator':'Prism Route reviewed oval atrium'},'scene':0,'scenes':[{'nodes':list(range(len(nodes)))}],
        'nodes':nodes,'meshes':meshes,'buffers':[{'byteLength':len(blob)}],'bufferViews':views,'accessors':accessors}
    text=json.dumps(gltf,separators=(',',':')).encode();text+=b' '*((-len(text))%4);blob+=b'\0'*((-len(blob))%4)
    output=struct.pack('<III',0x46546c67,2,12+8+len(text)+8+len(blob))+struct.pack('<II',len(text),0x4e4f534a)+text+struct.pack('<II',len(blob),0x004e4942)+blob
    (OUT/'atrium.glb').write_bytes(output)
    source.update(entry_spawn=world(source['entry_spawn']),floor_spawn=world(source['floor_spawn']),
        look_direction=[-.7,0.,-.7],review_eye=world([1210.,150.,190.]),review_target=world([1086.01,302.52,52.]),
        floor_eye=world([1087.64,285.30,65.78]),floor_target=world([1068.05,328.28,38.84]),
        mesh_sha256=hashlib.sha256(output).hexdigest(),triangles=sum(r['index_count']//3 for r in source['objects']))
    for row in source['ramps']:row['samples']=[[world(a),world(b)] for a,b in row['samples']]
    (OUT/'manifest.json').write_text(json.dumps(source,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    protected=json.loads((CACHE/'protected_hashes.json').read_text())
    assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in protected.items())
    print(json.dumps({'objects':len(nodes),'triangles':source['triangles'],'base_and_bake_unchanged':True}))
def inside_polygon(p,poly):
    x,y=p;inside=False
    for a,b in zip(poly,poly[1:]+poly[:1]):
        if (a[1]>y)!=(b[1]>y) and x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]:inside=not inside
    return inside
def blocks_tree(p,mask):
    x,y,z=p[0]+1450.,1150.-p[2],p[1];cx,cy=mask['center'];dx=x-cx;dy=y-cy
    if z<mask['void_min_z']:return False
    a,b=mask['roof_axes'] if z>=mask['roof_min_z'] else mask['excavation_axes']
    if (dx/(a+1.))**2+(dy/(b+1.))**2<=1:return True
    if z>=60 and inside_polygon([x,y],mask['entry_ramp_polygon']):return True
    if 34<=z<=41:
        start=mask['exit_start'];end=mask['exit_end'];vx=end[0]-start[0];vy=end[1]-start[1]
        t=((x-start[0])*vx+(y-start[1])*vy)/(vx*vx+vy*vy)
        if 0<=t<=1 and abs((x-start[0])*vy-(y-start[1])*vx)/(vx*vx+vy*vy)**.5<4.9:return True
    return False
def prune_trees():
    source=json.loads((CACHE/'source.json').read_text(encoding='utf-8'));mask=source['tree_exclusion']
    path=ROOT/'assets/world/tree_planting/world_edits.json';before=json.loads((CACHE/'world_edits_before.json').read_text(encoding='utf-8-sig'))
    current=json.loads(path.read_text(encoding='utf-8-sig'));assert current==before,'Planting changed while importing; merge current layout before pruning'
    baseline=json.loads((ROOT/'assets/world/current_map_validation/tree_layout.json').read_text(encoding='utf-8-sig'))
    effective={r.get('id') if isinstance(r,dict) else f'base_{i:06d}':r.get('position') if isinstance(r,dict) else r[:3] for i,r in enumerate(baseline)}
    for ident in before['removed']:effective.pop(ident,None)
    effective.update({r['id']:r['position'] for r in before['trees']})
    affected={ident for ident,p in effective.items() if blocks_tree(p,mask)}
    data=dict(before);data['trees']=[r for r in before['trees'] if r['id'] not in affected]
    data['removed']=list(before['removed'])+sorted(affected-set(before['removed']))
    preserved=[r for r in before['trees'] if r['id'] not in affected]
    assert data['trees']==preserved
    path.write_text(json.dumps(data,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')
    report={'removed_tree_count':len(affected),'removed_ids':sorted(affected),'removed_saved_edits':len(before['trees'])-len(data['trees']),
        'unrelated_saved_edits_preserved':len(preserved),'before_edits':len(before['trees']),'after_edits':len(data['trees']),
        'before_removed':len(before['removed']),'after_removed':len(data['removed']),'interior_plants_added':0,'baseline_unchanged':True}
    (DOC/'tree_cleanup.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print(json.dumps(report))
if __name__=='__main__':
    import sys
    snapshot()
    if '--prune-trees' in sys.argv:prune_trees()
    elif '--snapshot' not in sys.argv:build()
