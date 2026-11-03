"""Build one reference-space pose resource per clip, never per target avatar.

MMD inputs are the already validated target-independent evaluated bake outputs.
No new Blender bake is performed. BodyRoot is an optional semantic carrier for
MMD rigs whose pelvis and spine branch below separate control pivots.
"""
import hashlib
import json
import re
import sys
from pathlib import Path

import numpy as np
from build_motion_review import Source, transform, worlds, quaternion, numbers

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'assets/characters/mmd_validation'
DEST=BASE/'shared'


def lca(a,b,parents):
    ancestors=set()
    while a>=0:ancestors.add(a);a=parents[a]
    while b not in ancestors and b>=0:b=parents[b]
    assert b>=0
    return b


def write_clip(name,times,rest,poses,mapping,pelvis,body_root,source_path,destination_dir=None,reference_dir=None):
    destination_dir=destination_dir or DEST
    reference_dir=reference_dir or destination_dir
    destination_dir.mkdir(parents=True,exist_ok=True);reference_dir.mkdir(parents=True,exist_ok=True)
    mapping={**mapping,'Hips':pelvis,'BodyRoot':body_root}
    height=abs(float(rest[pelvis][1,3]));assert height>.1
    lines=['[gd_resource type="Animation" format=3]','','[resource]',
           f'resource_name = "{name}"',f'length = {times[-1]:.9g}',
           'metadata/shared_humanoid_schema = 1',f'metadata/reference_height = {height:.9g}',
           f'metadata/source = "{source_path.relative_to(ROOT).as_posix()}"',
           'metadata/rotation_space = "skeleton_world_rest_delta"',
           'metadata/translation_space = "physical_pelvis_rest_delta_metres"']
    references=[];track=0;constant=0
    for semantic,index in mapping.items():
        q=[]
        for pose in poses:
            value=quaternion(pose[index][:3,:3]@np.linalg.inv(rest[index][:3,:3]))
            if q and np.dot(q[-1],value)<0:value=-value
            q.append(value)
        values=np.asarray(q)
        is_constant=np.max(np.minimum(np.linalg.norm(values-values[0],axis=1),np.linalg.norm(values+values[0],axis=1)))<1e-7
        use_times=times[:1] if is_constant else times
        use_values=values[:1] if is_constant else values
        keys=np.column_stack((use_times,np.ones(len(use_times)),use_values))
        lines += [f'tracks/{track}/type = "rotation_3d"',f'tracks/{track}/path = NodePath("GeneralSkeleton:{semantic}")',
                  f'tracks/{track}/interp = 1',f'tracks/{track}/loop_wrap = false',
                  f'tracks/{track}/keys = PackedFloat32Array({numbers(keys.ravel())})']
        track+=1;constant+=is_constant
    translation=np.asarray([p[pelvis][:3,3]-rest[pelvis][:3,3] for p in poses])
    keys=np.column_stack((times,np.ones(len(times)),translation))
    lines += [f'tracks/{track}/type = "position_3d"',f'tracks/{track}/path = NodePath("GeneralSkeleton:Hips")',
              f'tracks/{track}/interp = 1',f'tracks/{track}/loop_wrap = false',
              f'tracks/{track}/keys = PackedFloat32Array({numbers(keys.ravel())})']
    destination=destination_dir/(name+'.tres');destination.write_text('\n'.join(lines)+'\n',encoding='utf-8')
    for frame in sorted(set([0,len(times)-1]+list(range(0,len(times),max(1,len(times)//16))))):
        pose=poses[frame]
        references.append({'time':float(times[frame]),'source_pelvis':pose[pelvis][:3,3].tolist(),
                           'pelvis_delta':translation[frame].tolist(),
                           'world_delta':{n:quaternion(pose[i][:3,:3]@np.linalg.inv(rest[i][:3,:3])).tolist() for n,i in mapping.items()},
                           'source_positions':{n:pose[i][:3,3].tolist() for n,i in mapping.items()}})
    (reference_dir/(name+'_reference.json')).write_text(json.dumps({'reference_height':height,'frames':references},ensure_ascii=False,indent=2),encoding='utf-8')
    return {'id':name,'resource':'res://'+destination.relative_to(ROOT).as_posix(),'frames':len(times),'duration':float(times[-1]),
            'tracks':track+1,'constant_rotation_tracks':int(constant),'bytes':destination.stat().st_size,
            'source':source_path.relative_to(ROOT).as_posix(),'source_sha256':hashlib.sha256(source_path.read_bytes()).hexdigest(),
            'output_sha256':hashlib.sha256(destination.read_bytes()).hexdigest(),'reference_height':height}


def mmd_clip(name,animation,rest_path,vrm_path):
    data=json.loads(rest_path.read_text(encoding='utf-8'));bones=data['bones'];parents=[b['parent'] for b in bones]
    base=[transform(b['position'],b['rotation'],b['scale']) for b in bones];rest=worlds(base,parents)
    indices={b['name']:i for i,b in enumerate(bones)}
    vrm=Source(vrm_path);human=vrm.g['extensions']['VRMC_vrm']['humanoid']['humanBones']
    mapping={k[0].upper()+k[1:]:indices[k[0].upper()+k[1:]] for k in human if k[0].upper()+k[1:] in indices}
    for side in ['Left','Right']:
        for end,start,semantic in [('LowerArm','UpperArm','UpperArmTwist'),('Hand','LowerArm','ForearmTwist')]:
            index=parents[mapping[side+end]]
            stop=mapping[side+start]
            while index>=0 and index!=stop:
                if re.search(r'捩|twist',bones[index]['name'],re.I):
                    mapping[side+semantic]=index
                    break
                index=parents[index]
    pelvis=lca(mapping['LeftUpperLeg'],mapping['RightUpperLeg'],parents)
    body_root=lca(pelvis,mapping['Spine'],parents)
    text=animation.read_text(encoding='utf-8');tracks={}
    for line in text.splitlines():
        match=re.match(r'tracks/(\d+)/(type|path|keys) = (.*)',line)
        if match:tracks.setdefault(int(match[1]),{})[match[2]]=match[3]
    frames=481;rotations={};positions={}
    for item in tracks.values():
        kind=item['type'].strip('"');bone=item['path'].split(':')[-1].removesuffix('")')
        values=np.fromstring(item['keys'].removeprefix('PackedFloat32Array(').removesuffix(')'),sep=',').reshape(-1,6 if kind=='rotation_3d' else 5)
        assert len(values)==frames
        (rotations if kind=='rotation_3d' else positions)[indices[bone]]=values[:,2:]
        times=values[:,0]
    poses=[]
    for f in range(frames):
        local=[transform(positions[i][f] if i in positions else b['position'],rotations[i][f] if i in rotations else b['rotation'],b['scale']) for i,b in enumerate(bones)]
        poses.append(worlds(local,parents))
    result=write_clip(name,times,rest,poses,mapping,pelvis,body_root,animation)
    result.update(source_semantic_pelvis=bones[pelvis]['name'],source_body_root=bones[body_root]['name'])
    return result


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    DEST.mkdir(parents=True,exist_ok=True)
    path=ROOT/'assets/characters/motion_sources/independent_cc0/walk.vrma'
    source=Source(path);channels,start,end=source.prepare({})
    times=np.linspace(0,end-start,round((end-start)*30)+1)
    poses=[source.pose(channels,start+t) for t in times]
    reports=[write_clip('shared_walk',times,source.rest,poses,source.mapping,source.mapping['Hips'],source.mapping['Hips'],path),
             mmd_clip('shared_mmd_role_a',BASE/'keqing_vrm_loop03.tres',BASE/'keqing_vrm_rest.json',ROOT/'assets/characters/import_tests_local/keqing/keqing_fixed.vrm'),
             mmd_clip('shared_mmd_role_b',BASE/'paired/ganyu_role_b.tres',BASE/'paired/ganyu_rest.json',ROOT/'assets/characters/ganyu/ganyu.vrm')]
    profiles=[{'id':'keqing','label':'刻晴','model':'res://assets/characters/mmd_validation/keqing_physics.vrm'},
              {'id':'ganyu','label':'甘雨','model':'res://assets/characters/mmd_validation/paired/ganyu_physics.vrm'},
              {'id':'hutao','label':'胡桃','model':'res://assets/characters/import_tests_local/hutao/hutao_fixed.vrm'},
              {'id':'huahuo','label':'花火','model':'res://assets/characters/import_tests_local/huahuo/huahuo_fixed.vrm'}]
    for profile in profiles:
        profile['model_sha256']=hashlib.sha256((ROOT/profile['model'].removeprefix('res://')).read_bytes()).hexdigest()
    manifest={'schema':1,'profiles':profiles,'clips':reports,'build_policy':'one resource per source role clip; no target-specific Blender bake or target animation files'}
    (DEST/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    catalog_path=BASE/'paired/catalog.json';catalog=json.loads(catalog_path.read_text(encoding='utf-8'))
    catalog['packs']=[p for p in catalog['packs'] if not p['id'].startswith('shared_')]
    catalog['entries']=[e for e in catalog['entries'] if not e['id'].startswith('shared_')]
    for clip in reports:
        roles=[]
        for i,profile in enumerate(profiles):
            roles.append({'id':chr(65+i),'label':profile['label'],'model':profile['model'],'motion':clip['resource'],
                          'report':'res://assets/characters/mmd_validation/shared/manifest.json','profile':profile['id'],'shared':True,
                          'presentation_offset':[(i-1.5)*1.2,0,0],'translation_policy':'height_scaled'})
        pack_id=clip['id']
        label='共享走路' if pack_id=='shared_walk' else ('MMD 共享轨道 A' if pack_id.endswith('_a') else 'MMD 共享轨道 B')
        catalog['packs'].append({'id':pack_id,'label':label,'duration':clip['duration'],'frame_start':0,'frame_end':clip['frames']-1,
                                 'source_tracks':[{'file':clip['source']}] *4,'roles':roles,'shared':True,'loop_preview':pack_id=='shared_walk'})
        catalog['entries'].append({'id':pack_id+'_all','pack':pack_id,'label':label+' · 四角色共用','roles':['A','B','C','D'],'kind':'共享动作'})
        if pack_id=='shared_walk':
            for role in roles:
                catalog['entries'].append({'id':pack_id+'_'+role['profile'],'pack':pack_id,'label':label+' · '+role['label']+'单独检查','roles':[role['id']],'kind':'共享动作'})
    pair_roles=[]
    for i,profile in enumerate(profiles[:2]):
        pair_roles.append({'id':chr(65+i),'label':profile['label'],'model':profile['model'],'motion':reports[i+1]['resource'],
                           'report':'res://assets/characters/mmd_validation/shared/manifest.json','profile':profile['id'],'shared':True,
                           'presentation_offset':[0,0,0],'translation_policy':'shared_world'})
    catalog['packs'].append({'id':'shared_pair','label':'Loop 03 · 共享人形转换','duration':16.,'frame_start':0,'frame_end':480,
                             'source_tracks':[{'file':r['source']} for r in reports[1:]],'roles':pair_roles,'shared':True})
    catalog['entries'].append({'id':'shared_pair_all','pack':'shared_pair','label':'Loop 03 · 共享层双人同步','roles':['A','B'],'kind':'共享动作'})
    catalog['default_entry']='shared_walk_all'
    catalog_path.write_text(json.dumps(catalog,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'clips':reports,'profiles':len(profiles),'new_blender_bakes':0},ensure_ascii=False))


if __name__=='__main__':main()
