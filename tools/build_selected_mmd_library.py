"""Standardize evaluated source bakes into the shared, avatar-independent library."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys
import time
import numpy as np
from build_motion_review import Source, transform, worlds
from build_shared_humanoid_validation import write_clip,lca
from apply_motion_metadata import METADATA

ROOT=Path(__file__).resolve().parents[1]
CACHE=ROOT/'.model_import_build/mmd_selected'
DEST=ROOT/'assets/characters/mmd_selected'
QA=ROOT/'docs/validation/mmd_selected_20261103'


def dense_poses(source,channels,times,start):
    nodes=source.g['nodes'];frames=len(times);count=len(nodes)
    p=np.broadcast_to(np.asarray([n.get('translation',[0,0,0]) for n in nodes],dtype=float),(frames,count,3)).copy()
    q=np.broadcast_to(np.asarray([n.get('rotation',[0,0,0,1]) for n in nodes],dtype=float),(frames,count,4)).copy()
    s=np.broadcast_to(np.asarray([n.get('scale',[1,1,1]) for n in nodes],dtype=float),(frames,count,3)).copy()
    for node,path,t,values,_ in channels:
        if len(t)==1:values=np.broadcast_to(values,(frames,values.shape[1]))
        else:assert len(t)==frames and np.max(np.abs((t-start)-times))<.00005
        {'translation':p,'rotation':q,'scale':s}[path][:,node]=values
    q/=np.linalg.norm(q,axis=2)[:,:,None]
    x,y,z,w=np.moveaxis(q,2,0)
    local=np.zeros((frames,count,4,4));local[:,:,3,3]=1
    local[:,:,0,0]=1-2*(y*y+z*z);local[:,:,0,1]=2*(x*y-z*w);local[:,:,0,2]=2*(x*z+y*w)
    local[:,:,1,0]=2*(x*y+z*w);local[:,:,1,1]=1-2*(x*x+z*z);local[:,:,1,2]=2*(y*z-x*w)
    local[:,:,2,0]=2*(x*z-y*w);local[:,:,2,1]=2*(y*z+x*w);local[:,:,2,2]=1-2*(x*x+y*y)
    local[:,:,:3,:3]*=s[:,:,None,:];local[:,:,:3,3]=p
    result=np.empty_like(local);done=set()
    def solve(i):
        if i in done:return
        parent=source.parents[i]
        if parent<0:result[:,i]=local[:,i]
        else:solve(parent);result[:,i]=result[:,parent]@local[:,i]
        done.add(i)
    for i in range(count):solve(i)
    error=0.0
    for f in sorted({0,frames//2,frames-1}):error=max(error,float(np.max(np.abs(result[f]-np.asarray(source.pose(channels,start+float(times[f])))))))
    assert error<.00005,error
    return result,error


def profile(reference):
    base=ROOT/'assets/characters/mmd_validation'
    rest_path=base/('keqing_vrm_rest.json' if reference=='A' else 'paired/ganyu_rest.json')
    vrm_path=ROOT/('assets/characters/import_tests_local/keqing/keqing_fixed.vrm' if reference=='A' else 'assets/characters/ganyu/ganyu.vrm')
    bones=json.loads(rest_path.read_text(encoding='utf-8'))['bones'];parents=[b['parent'] for b in bones]
    rest=worlds([transform(b['position'],b['rotation'],b['scale']) for b in bones],parents)
    indices={b['name']:i for i,b in enumerate(bones)}
    vrm=Source(vrm_path);node_world=worlds(vrm.local,vrm.parents)
    vn={n['name']:i for i,n in enumerate(vrm.g['nodes']) if n.get('name')}
    human=vrm.g['extensions']['VRMC_vrm']['humanoid']['humanBones']
    rename={k[0].upper()+k[1:]:vrm.g['nodes'][v['node']]['name'] for k,v in human.items()}
    semantic={n:indices[n] for n in rename if n in indices}
    for side in ['Left','Right']:
        for end,start,label in [('LowerArm','UpperArm','UpperArmTwist'),('Hand','LowerArm','ForearmTwist')]:
            i=parents[semantic[side+end]];stop=semantic[side+start]
            while i>=0 and i!=stop:
                if re.search(r'捩|twist',bones[i]['name'],re.I):semantic[side+label]=i;break
                i=parents[i]
    pelvis=lca(semantic['LeftUpperLeg'],semantic['RightUpperLeg'],parents)
    body_root=lca(pelvis,semantic['Spine'],parents)
    semantic.update(Hips=pelvis,BodyRoot=body_root)
    originals={i:rename.get(bones[i]['name'],bones[i]['name']) for i in semantic.values()}
    corrections={i:np.linalg.inv(node_world[vn[name]])@rest[i] for i,name in originals.items()}
    return rest,semantic,pelvis,body_root,originals,corrections


def main():
    sys.stdout.reconfigure(encoding='utf-8');DEST.mkdir(parents=True,exist_ok=True);QA.mkdir(parents=True,exist_ok=True)
    plan=json.loads((CACHE/'plan.json').read_text(encoding='utf-8'))
    journal=json.loads((CACHE/'bake_journal.json').read_text(encoding='utf-8'))
    templates={r:profile(r) for r in ['A','B']};reports=[];packs=[]
    existing=json.loads((ROOT/'assets/characters/mmd_validation/shared/manifest.json').read_text(encoding='utf-8'))
    existing_reports={r['resource']:r for r in existing['clips']}
    for item in plan['packs']:
        if item['decision']!='KEEP':continue
        roles=[];clip_reports=[]
        for role in item['roles']:
            if 'reused_resource' in role:
                record={**existing_reports[role['reused_resource']],'id':role['clip_id'],'reference':role['reused_reference'],'reused':True}
            else:
                started=time.perf_counter();job=journal['jobs'][role['clip_id']];assert job['status']=='passed'
                path=Path(role['baked_glb']);assert hashlib.sha256(path.read_bytes()).hexdigest()==job['output_sha256']
                source=Source(path);assert len(source.g['animations'])==1
                channels,start,end=source.prepare({});frames=item['frame_end']-item['frame_start']+1
                times=np.linspace(0,(item['frame_end']-item['frame_start'])/30,frames)
                assert abs((end-start)-times[-1])<.00005
                sampled,dense_error=dense_poses(source,channels,times,start)
                rest,semantic,pelvis,body_root,originals,corrections=templates[role['reference']]
                sn={n['name']:i for i,n in enumerate(source.g['nodes']) if n.get('name')}
                poses=np.broadcast_to(np.asarray(rest),(frames,len(rest),4,4)).copy()
                for index,name in originals.items():poses[:,index]=sampled[:,sn[name]]@corrections[index]
                record=write_clip(role['clip_id'],times,rest,poses,semantic,pelvis,body_root,path,DEST/'animations',QA/'references')
                record.update(reference='res://'+(QA/'references'/(role['clip_id']+'_reference.json')).relative_to(ROOT).as_posix(),
                              reused=False,dense_sampling_max_matrix_error=dense_error,standardize_elapsed_s=time.perf_counter()-started,
                              bake_position_checks=job['bake_position_checks'],max_bake_position_error_m=job['max_bake_position_error_m'])
            record.update(pack=item['id'],role=role['id'],source_file=role['source_file'],source_vmd_sha256=role['source_sha256'])
            reports.append(record);clip_reports.append(record)
            default_profile='ganyu' if role['id']=='B' else 'keqing'
            avatar=next(p for p in existing['profiles'] if p['id']==default_profile)
            roles.append({'id':role['id'],'label':'角色 '+role['id'],'model':avatar['model'],'motion':record['resource'],
                          'report':'res://assets/characters/mmd_selected/manifest.json','profile':default_profile,'shared':True,
                          'translation_policy':'shared_world','presentation_offset':[0,0,0]})
            print('SHARED_SELECTED '+json.dumps({'clip':record['id'],'bytes':record['bytes'],'reused':record['reused']}),flush=True)
        pack_record = {'id':item['id'],'source_library':'mmd',
                      'label':item['label'],'selected':True,'shared':True,'duration':item['duration'],
                      'frame_start':item['frame_start'],'frame_end':item['frame_end'],'loop_preview':False,'loop_status':'source segment; seam not modified',
                      'source_tracks':[{'file':r['source_file'],'sha256':r['source_sha256']} for r in item['roles']],
                      'roles':roles,'references':[r['reference'] for r in clip_reports],
                      'dependency_note':'Body animation only; source expressions, custom deformations and props are separate.'}
        if item['id'] in METADATA:
            meta = METADATA[item['id']]
            pack_record.update({
                'title_zh': meta['title_zh'],
                'category': meta['category'],
                'category_zh': meta['category_zh'],
                'placement': meta['placement'],
                'roles_desc': meta['roles_desc'],
                'description_zh': meta['description_zh'],
                'display_label': f"【{meta['category_zh']}】{meta['title_zh']} ({item['label']})"
            })
            for r in roles:
                if r['id'] in meta['roles_desc']:
                    r['label_zh'] = meta['roles_desc'][r['id']]
        packs.append(pack_record)
    assert len(packs)==20 and len(reports)==40 and sum(not r['reused'] for r in reports)==38
    manifest={'schema':1,'profiles':existing['profiles'],'readme_sha256':plan['readme_sha256'],'packs':packs,'clips':reports,
              'counts':{'groups':20,'tracks':40,'new_tracks':38,'reused_tracks':2,'deferred_groups':1},'source_selection':'docs/motion_selection/README.md'}
    (DEST/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    catalog_path=ROOT/'assets/characters/mmd_validation/paired/catalog.json';catalog=json.loads(catalog_path.read_text(encoding='utf-8'))
    ids={p['id'] for p in packs}
    catalog['packs']=[p for p in catalog['packs'] if p['id'] not in ids]+packs
    catalog['entries']=[e for e in catalog['entries'] if e['pack'] not in ids]+[
        {'id':p['id']+'_all','pack':p['id'],'label':p['label'],'roles':[r['id'] for r in p['roles']],'kind':'入选动作',
         **({'title_zh': p['title_zh'], 'category': p['category'], 'category_zh': p['category_zh'], 'display_label': p['display_label']} if 'title_zh' in p else {})} for p in packs]
    # Start with an inexpensive solo; legacy/sample IDs remain available for regression.
    solo=next(p for p in packs if len(p['roles'])==1)
    catalog['default_entry']=solo['id']+'_all'
    catalog_path.write_text(json.dumps(catalog,ensure_ascii=False,indent=2),encoding='utf-8')
    (QA/'build_summary.json').write_text(json.dumps({'counts':manifest['counts'],'animation_bytes':sum(r['bytes'] for r in reports),
       'max_source_bake_position_error_m':max(r.get('max_bake_position_error_m',0) for r in reports),'new_target_specific_animation_files':0,
       'new_source_role_bakes':20,'maybe_groups_imported':0,'source_seams_modified':False},indent=2),encoding='utf-8')
    shutil.copyfile(CACHE/'plan.json',QA/'production_plan.json')
    shutil.copyfile(CACHE/'bake_journal.json',QA/'source_bake_journal.json')
    print('SELECTED_LIBRARY_COMPLETE '+json.dumps(manifest['counts']))


if __name__=='__main__':main()
