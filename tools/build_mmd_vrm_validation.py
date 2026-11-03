"""Retarget the baked PMX clip to the existing VRM, and add model-specific springs.

Uses the VRM's pre-normalization node hierarchy to undo the importer's bone-axis
rewrite. Inverse-bind matrices alone describe the original A-pose, not that hierarchy.
Run inspect_motion_skeleton.gd for the existing VRM if its import settings change.
"""
import json
import hashlib
import math
import struct
from pathlib import Path

import numpy as np
from build_motion_review import Source, transform, worlds, quaternion, numbers

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'assets/characters/mmd_validation'
ORIGINAL_VRM = ROOT / 'assets/characters/import_tests_local/keqing/keqing_fixed.vrm'


def main():
    target = json.loads((DEST / 'keqing_vrm_rest.json').read_text(encoding='utf-8'))
    source = Source(DEST / 'loop03_baked.glb')
    assert len(source.g.get('animations', [])) == 1, 'Export only the active scene and one selected action.'
    vrm = Source(ORIGINAL_VRM)
    source_names = {n['name']: i for i, n in enumerate(source.g['nodes']) if n.get('name')}
    vrm_names = {n['name']: i for i, n in enumerate(vrm.g['nodes']) if n.get('name')}
    human = vrm.g['extensions']['VRMC_vrm']['humanoid']['humanBones']
    rename = {k[0].upper() + k[1:]: vrm.g['nodes'][v['node']]['name'] for k, v in human.items()}
    bones = target['bones']
    parents = [b['parent'] for b in bones]
    target_local = [transform(b['position'], b['rotation'], b['scale']) for b in bones]
    target_world = worlds(target_local, parents)
    vrm_node_world = worlds(vrm.local, vrm.parents)
    indices = {b['name']: i for i, b in enumerate(bones)}
    chains = []

    def chain(group, names, stiffness, gravity, drag, radius):
        assert all(n in indices for n in names)
        for a, b in zip(names, names[1:]):
            assert parents[indices[b]] == indices[a], (a, b)
        chains.append(dict(group=group, nodes=names, stiffness=stiffness,
                           gravity=gravity, drag=drag, radius=radius))

    for side in ['L', 'R']:
        chain('Hair', [f'发_{i}_1.{side}' for i in range(1, 9)], .9, .35, .7, .012)
        chain('SideHair', [f'侧发_{i}_1.{side}' for i in range(1, 6)], 1.2, .25, .75, .01)
        chain('Sleeves', [f'袖_{i}_1.{side}' for i in range(1, 8)], .7, .35, .75, .014)
        # Two rigid attachment segments keep torso-mounted ribbons out of
        # contradictory constraints between their attachment and hip colliders.
        chain('Ribbons', [f'带_{i}_1.{side}' for i in range(2, 10)], .6, .35, .75, .01)
    for column in range(12):
        chain('Skirt', [f'スカート_{i}_{column}' for i in range(1, 7)], 1.2, .45, .8, .018)
    chain('Tassel', [f'流苏_{i}_1' for i in range(1, 5)], .5, .35, .75, .008)
    physics = {name for c in chains for name in c['nodes']}
    mapping = {}
    corrections = {}
    missing = []
    for i, bone in enumerate(bones):
        original_name = rename.get(bone['name'], bone['name'])
        if original_name not in source_names or original_name not in vrm_names:
            if bone['name'] != 'Root': missing.append(bone['name'])
            continue
        mapping[i] = source_names[original_name]
        corrections[i] = np.linalg.inv(vrm_node_world[vrm_names[original_name]]) @ target_world[i]
    assert not missing, missing
    channels, start, end = source.prepare({})
    times = np.linspace(0, end - start, round((end-start)*30) + 1)
    animated = [i for i in mapping if bones[i]['name'] not in physics]
    rotations = {i: [] for i in animated}
    positions = {i: [] for i in animated}
    references = []
    for frame, time in enumerate(times):
        source_pose = source.pose(channels, start + time)
        output = [None] * len(bones)

        def solve(i):
            if output[i] is not None: return output[i]
            parent = np.eye(4) if parents[i] < 0 else solve(parents[i])
            desired = parent @ target_local[i]
            if i in rotations:
                desired = source_pose[mapping[i]] @ corrections[i]
                local = np.linalg.inv(parent) @ desired
                q = quaternion(local[:3, :3])
                if rotations[i] and np.dot(q, rotations[i][-1]) < 0: q = -q
                rotations[i].append(q)
                positions[i].append(local[:3, 3].copy())
            output[i] = desired
            return desired

        for i in range(len(bones)): solve(i)
        if frame in [0, 1, 60, 120, 180, 240, 300, 360, 420, 479, 480]:
            references.append({'frame': frame, 'bones': {
                bones[i]['name']: {'position': output[i][:3, 3].tolist(),
                                  'rotation': quaternion(output[i][:3, :3]).tolist()}
                for i in animated}})
    lines = ['[gd_resource type="Animation" format=3]', '', '[resource]',
             'resource_name = "Keqing_MMD_Loop03"', f'length = {end-start:.8g}']
    track = 0
    for i in animated:
        for kind, values in [('rotation_3d', rotations[i]), ('position_3d', positions[i])]:
            assert np.isfinite(values).all()
            keys = np.column_stack((times, np.ones(len(times)), values))
            path = target['path'] + ':' + bones[i]['name']
            lines += [f'tracks/{track}/type = "{kind}"', f'tracks/{track}/path = NodePath("{path}")',
                      f'tracks/{track}/interp = 1', f'tracks/{track}/loop_wrap = false',
                      f'tracks/{track}/keys = PackedFloat32Array({numbers(keys.ravel())})']
            track += 1
    (DEST / 'keqing_vrm_loop03.tres').write_text('\n'.join(lines)+'\n', encoding='utf-8')
    (DEST / 'keqing_vrm_reference.json').write_text(json.dumps(references, ensure_ascii=False), encoding='utf-8')

    colliders = []
    collider_groups = {'Hair': [], 'Clothes': [], 'Skirt': [], 'Tassel': []}

    def collider(name, end_name, radius, groups, offset_world=None):
        i = indices[name]
        original_name = rename.get(name, name)
        node = vrm_names[original_name]
        # Write collider coordinates in original VRM node space. The importer
        # subsequently applies the same axis correction as it does to skins.
        conversion = np.linalg.inv(vrm_node_world[node]) @ target_world[i]
        offset = np.zeros(3) if offset_world is None else np.linalg.inv(target_world[i])[:3,:3] @ np.asarray(offset_world)
        offset = conversion @ np.r_[offset, 1]
        if end_name:
            tail_world = target_world[indices[end_name]][:3, 3]
            tail = np.linalg.inv(vrm_node_world[node]) @ np.r_[tail_world, 1]
            shape = {'capsule': {'offset': offset[:3].tolist(), 'tail': tail[:3].tolist(), 'radius': radius}}
        else:
            shape = {'sphere': {'offset': offset[:3].tolist(), 'radius': radius}}
        index = len(colliders)
        colliders.append({'node': node, 'shape': shape})
        for group in groups: collider_groups[group].append(index)

    collider('Head', None, .105, ['Hair', 'Clothes'], (0,.08,0))
    collider('Neck', 'Head', .045, ['Hair', 'Clothes'])
    collider('Chest', 'Neck', .105, ['Hair', 'Clothes'])
    collider('Hips', 'Chest', .105, ['Clothes','Tassel'])
    collider('Hips', None, .115, ['Clothes','Tassel'], (0,.025,0))
    for side in ['Left', 'Right']:
        collider(side+'UpperArm', side+'LowerArm', .038, ['Hair', 'Clothes','Tassel'])
        collider(side+'LowerArm', side+'Hand', .03, ['Hair', 'Clothes','Tassel'])
        collider(side+'UpperLeg', side+'LowerLeg', .065, ['Clothes','Skirt','Tassel'])
        collider(side+'LowerLeg', side+'Foot', .045, ['Clothes','Skirt','Tassel'])
    groups = [{'name': k+' body', 'colliders': v} for k,v in collider_groups.items()]
    spring_data = []
    for c in chains:
        spring_data.append({'name': c['group']+' '+c['nodes'][0],
            'center': vrm_names['頭' if 'Hair' in c['group'] else '腰'],
            'colliderGroups': [0 if 'Hair' in c['group'] else (2 if c['group']=='Skirt' else (3 if c['group']=='Tassel' else 1))],
            'joints': [{'node': vrm_names[name], 'stiffness': c['stiffness'] * (1-.4*i/max(1,len(c['nodes'])-1)),
                        'gravityPower': c['gravity'], 'gravityDir': [0,-1,0], 'dragForce': c['drag'], 'hitRadius': c['radius']}
                       for i,name in enumerate(c['nodes'])]})
    vrm.g['extensions']['VRMC_springBone'] = {'specVersion':'1.0', 'colliders':colliders,
                                            'colliderGroups':groups, 'springs':spring_data}
    encoded = json.dumps(vrm.g, ensure_ascii=False, separators=(',',':')).encode('utf-8')
    encoded += b' ' * (-len(encoded) % 4)
    binary = bytes(vrm.binary)
    binary += b'\0' * (-len(binary) % 4)
    result = struct.pack('<III',0x46546c67,2,12+8+len(encoded)+8+len(binary))
    result += struct.pack('<II',len(encoded),0x4e4f534a)+encoded
    result += struct.pack('<II',len(binary),0x004e4942)+binary
    (DEST/'keqing_physics.vrm').write_bytes(result)
    report = {'source_vrm':str(ORIGINAL_VRM), 'output_vrm':'keqing_physics.vrm',
              'target_bones':len(bones), 'mapped_bones':len(mapping), 'animated_bones':len(animated),
              'tracks':track, 'frames':len(times), 'duration':end-start,
              'physics_bones':sorted(physics), 'chains':chains, 'colliders':len(colliders),
              'missing_bones':missing, 'method':'source evaluated world pose * inverse(VRM node world rest) * imported world rest'}
    report['sha256'] = {
        'original_vrm':hashlib.sha256(ORIGINAL_VRM.read_bytes()).hexdigest(),
        'source_baked_glb':hashlib.sha256((DEST/'loop03_baked.glb').read_bytes()).hexdigest(),
        'target_rest':hashlib.sha256((DEST/'keqing_vrm_rest.json').read_bytes()).hexdigest(),
        'physics_vrm':hashlib.sha256(result).hexdigest(),
        'animation':hashlib.sha256((DEST/'keqing_vrm_loop03.tres').read_bytes()).hexdigest()}
    (DEST/'keqing_vrm_build_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k not in ['chains','physics_bones']},ensure_ascii=False))


if __name__ == '__main__': main()
