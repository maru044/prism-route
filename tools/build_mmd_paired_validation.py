"""Build the second supplied role of Loop 03 for the existing Ganyu VRM.

Keep authored MMD coordinates and one shared timeline; do not center roles.
The catalog separates isolated-role diagnostics from complete paired playback.
"""
import hashlib
import json
import struct
from collections import Counter
from pathlib import Path

import numpy as np
from build_motion_review import Source, transform, worlds, quaternion, numbers

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT/'assets/characters/mmd_validation'
DEST = BASE/'paired'
MOTIONS = Path('D:/模型/20261008/Public R-18 Motions')


def vmd_info(path):
    raw = path.read_bytes()
    assert raw.startswith(b'Vocaloid Motion Data 0002')
    count = struct.unpack_from('<I',raw,50)[0]
    names = Counter()
    frames = []
    for i in range(count):
        offset = 54+i*111
        names[raw[offset:offset+15].split(b'\0')[0].decode('cp932',errors='replace')] += 1
        frames.append(struct.unpack_from('<I',raw,offset+15)[0])
    return dict(file=str(path.relative_to(MOTIONS)),model=raw[30:50].split(b'\0')[0].decode('cp932',errors='replace'),
                keys=count,bones=len(names),frame_start=min(frames,default=0),frame_end=max(frames,default=0),
                animated_bones=sum(n>1 for n in names.values()),sha256=hashlib.sha256(raw).hexdigest())


def main():
    target=json.loads((DEST/'ganyu_rest.json').read_text(encoding='utf-8'))
    source=Source(DEST/'loop03_ganyu_role_b.glb')
    vrm_path=ROOT/'assets/characters/ganyu/ganyu.vrm'
    vrm=Source(vrm_path)
    assert len(source.g['animations'])==1
    source_names={n['name']:i for i,n in enumerate(source.g['nodes']) if n.get('name')}
    vrm_names={n['name']:i for i,n in enumerate(vrm.g['nodes']) if n.get('name')}
    human=vrm.g['extensions']['VRMC_vrm']['humanoid']['humanBones']
    rename={k[0].upper()+k[1:]:vrm.g['nodes'][v['node']]['name'] for k,v in human.items()}
    bones=target['bones']
    parents=[b['parent'] for b in bones]
    rest_local=[transform(b['position'],b['rotation'],b['scale']) for b in bones]
    rest_world=worlds(rest_local,parents)
    node_world=worlds(vrm.local,vrm.parents)
    indices={b['name']:i for i,b in enumerate(bones)}
    reverse_names={rename.get(b['name'],b['name']):b['name'] for b in bones}
    old=vrm.g['extensions']['VRMC_springBone']
    springs=[]
    chains=[]
    for original in old['springs']:
        source_nodes=original['joints']
        names=[vrm.g['nodes'][j['node']]['name'] for j in source_nodes]
        # Keep the supplied hair/garment chains, with a rigid attachment node.
        # Unrelated single-node body chains are outside this garment test.
        if len(names)<3 or not names[0].startswith(('发','前摆','后摆','流苏','アホ毛')): continue
        names=names[1:]
        mapped=[reverse_names[n] for n in names]
        for a,b in zip(mapped,mapped[1:]): assert parents[indices[b]]==indices[a]
        is_hair=names[0].startswith(('发','アホ毛'))
        group='Hair' if is_hair else 'Clothes'
        spring=dict(original)
        spring['name']=group+' '+names[0]
        spring['joints']=[]
        for i,old_joint in enumerate(source_nodes[1:]):
            joint=dict(old_joint)
            joint.update(stiffness=(.9 if is_hair else 1.0)*(1-.4*i/max(1,len(names)-1)),
                         gravityPower=.3 if is_hair else .4,gravityDir=[0,-1,0],
                         dragForce=.75 if is_hair else .8,hitRadius=.012 if is_hair else .014)
            spring['joints'].append(joint)
        springs.append(spring)
        chains.append({'group':group,'nodes':mapped})
    physics={name for chain in chains for name in chain['nodes']}
    mapping={}
    correction={}
    missing=[]
    for i,bone in enumerate(bones):
        name=rename.get(bone['name'],bone['name'])
        if name not in source_names or name not in vrm_names:
            if bone['name']!='Root': missing.append(bone['name'])
            continue
        mapping[i]=source_names[name]
        correction[i]=np.linalg.inv(node_world[vrm_names[name]])@rest_world[i]
    assert not missing,missing
    animated=[i for i in mapping if bones[i]['name'] not in physics]
    channels,start,end=source.prepare({})
    assert abs(start)<1e-6 and abs(end-16)<1e-6
    times=np.linspace(0,end,481)
    rotations={i:[] for i in animated}
    positions={i:[] for i in animated}
    references=[]
    for frame,time in enumerate(times):
        pose=source.pose(channels,float(time))
        output=[None]*len(bones)
        def solve(i):
            if output[i] is not None:return output[i]
            parent=np.eye(4) if parents[i]<0 else solve(parents[i])
            desired=parent@rest_local[i]
            if i in rotations:
                desired=pose[mapping[i]]@correction[i]
                local=np.linalg.inv(parent)@desired
                q=quaternion(local[:3,:3])
                if rotations[i] and np.dot(q,rotations[i][-1])<0:q=-q
                rotations[i].append(q)
                positions[i].append(local[:3,3])
            output[i]=desired
            return desired
        for i in range(len(bones)):solve(i)
        if frame in [0,1,60,120,180,240,300,360,420,479,480]:
            references.append({'frame':frame,'positions':{bones[i]['name']:output[i][:3,3].tolist() for i in animated}})
    lines=['[gd_resource type="Animation" format=3]','','[resource]','resource_name = "Loop03_Ganyu_RoleB"','length = 16.0']
    track=0
    for i in animated:
        for kind,values in [('rotation_3d',rotations[i]),('position_3d',positions[i])]:
            assert np.isfinite(values).all()
            keys=np.column_stack((times,np.ones(len(times)),values))
            lines += [f'tracks/{track}/type = "{kind}"',f'tracks/{track}/path = NodePath("{target["path"]}:{bones[i]["name"]}")',
                      f'tracks/{track}/interp = 1',f'tracks/{track}/loop_wrap = false',
                      f'tracks/{track}/keys = PackedFloat32Array({numbers(keys.ravel())})']
            track+=1
    (DEST/'ganyu_role_b.tres').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    (DEST/'ganyu_reference.json').write_text(json.dumps(references,ensure_ascii=False),encoding='utf-8')
    vrm.g['extensions']['VRMC_springBone']['springs']=springs
    encoded=json.dumps(vrm.g,ensure_ascii=False,separators=(',',':')).encode('utf-8')
    encoded+=b' '*(-len(encoded)%4)
    binary=bytes(vrm.binary)
    binary+=b'\0'*(-len(binary)%4)
    data=struct.pack('<III',0x46546c67,2,28+len(encoded)+len(binary))
    data+=struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(binary),0x004e4942)+binary
    (DEST/'ganyu_physics.vrm').write_bytes(data)
    report={'target_bones':len(bones),'mapped_bones':len(mapping),'animated_bones':len(animated),'tracks':track,
            'physics_bones':sorted(physics),'chains':chains,'missing_bones':missing,'duration':16.0,
            'source_vrm':str(vrm_path),'source_vrm_sha256':hashlib.sha256(vrm_path.read_bytes()).hexdigest(),
            'source_vmd':vmd_info(MOTIONS/'Loop 03/Kaat.vmd'),'role':'B','profile':'ganyu'}
    (DEST/'ganyu_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    inventory=[]
    for folder in sorted(MOTIONS.iterdir()):
        if not folder.is_dir():continue
        candidates=[]
        for file in sorted(folder.glob('*.vmd')):
            info=vmd_info(file)
            if info['keys']>100 and info['bones']>=20:candidates.append(info)
        if len(candidates)>=2:inventory.append({'folder':folder.name,'body_track_candidates':candidates,'classification':'needs_pair_or_alternative_review'})
    (DEST/'source_inventory.json').write_text(json.dumps(inventory,ensure_ascii=False,indent=2),encoding='utf-8')
    catalog={'schema':1,'fps':30,'default_entry':'loop03_pair','coordinate_policy':'preserve_authored_shared_world',
             'packs':[{'id':'loop03','label':'Loop 03','duration':16.0,'frame_start':0,'frame_end':480,
                       'source_tracks':[vmd_info(MOTIONS/'Loop 03/Izumi.vmd'),vmd_info(MOTIONS/'Loop 03/Kaat.vmd')],
                       'roles':[{'id':'A','label':'角色 A · 刻晴','model':'res://assets/characters/mmd_validation/keqing_physics.vrm',
                                 'motion':'res://assets/characters/mmd_validation/keqing_vrm_loop03.tres',
                                 'report':'res://assets/characters/mmd_validation/keqing_vrm_build_report.json','profile':'keqing'},
                                {'id':'B','label':'角色 B · 甘雨','model':'res://assets/characters/mmd_validation/paired/ganyu_physics.vrm',
                                 'motion':'res://assets/characters/mmd_validation/paired/ganyu_role_b.tres',
                                 'report':'res://assets/characters/mmd_validation/paired/ganyu_report.json','profile':'ganyu'}]}],
             'entries':[{'id':'loop03_pair','pack':'loop03','label':'Loop 03 · 双人同步','roles':['A','B'],'kind':'双人'},
                        {'id':'loop03_role_a','pack':'loop03','label':'Loop 03 · 角色 A 单独检查','roles':['A'],'kind':'角色拆分'},
                        {'id':'loop03_role_b','pack':'loop03','label':'Loop 03 · 角色 B 单独检查','roles':['B'],'kind':'角色拆分'}]}
    (DEST/'catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'target_bones':len(bones),'animated_bones':len(animated),'physics_bones':len(physics),
                      'spring_chains':len(chains),'tracks':track,'candidate_directories':len(inventory),'paired_roles':2}))


if __name__=='__main__':main()
