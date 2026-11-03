"""Read existing outputs to estimate batch scale; no source/animation modification."""
import ctypes
import importlib.util
import json
import os
import re
import sys
import time
from collections import Counter
from pathlib import Path

import numpy as np
from build_motion_review import Source, transform, worlds, quaternion

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/research/mmd_batch_20261103'


def inspect_animation(path):
    text=path.read_text(encoding='utf-8')
    kinds=dict((int(i),kind) for i,kind in re.findall(r'tracks/(\d+)/type = "([^"]+)"',text))
    tracks=[]
    for track,values in re.findall(r'tracks/(\d+)/keys = PackedFloat32Array\(([^\n]+)\)',text):
        kind=kinds[int(track)]
        data=np.fromstring(values,sep=',').reshape(-1,6 if kind=='rotation_3d' else 5)[:,2:]
        if kind=='rotation_3d':
            data/=np.linalg.norm(data,axis=1)[:,None]
            deviation=float(np.minimum(np.linalg.norm(data-data[0],axis=1),np.linalg.norm(data+data[0],axis=1)).max())
        else:deviation=float(np.linalg.norm(data-data[0],axis=1).max())
        tracks.append({'kind':kind,'keys':len(data),'constant_within_1e_5':deviation<=1e-5,'max_deviation':deviation})
    return {'file':str(path.relative_to(ROOT)),'bytes':path.stat().st_size,'tracks':len(tracks),
            'keys':sum(t['keys'] for t in tracks),'constant_tracks_within_1e_5':sum(t['constant_within_1e_5'] for t in tracks),
            'constant_by_kind':dict(Counter(t['kind'] for t in tracks if t['constant_within_1e_5'])),
            'note':'Candidate single-key tracks only. Constant non-rest poses must remain; this is not a verified compression ratio.'}


def benchmark():
    base=ROOT/'assets/characters/mmd_validation'
    target=json.loads((base/'keqing_vrm_rest.json').read_text(encoding='utf-8'))
    source=Source(base/'loop03_baked.glb')
    vrm=Source(ROOT/'assets/characters/import_tests_local/keqing/keqing_fixed.vrm')
    report=json.loads((base/'keqing_vrm_build_report.json').read_text(encoding='utf-8'))
    sn={n['name']:i for i,n in enumerate(source.g['nodes']) if n.get('name')}
    vn={n['name']:i for i,n in enumerate(vrm.g['nodes']) if n.get('name')}
    rename={k[0].upper()+k[1:]:vrm.g['nodes'][v['node']]['name'] for k,v in vrm.g['extensions']['VRMC_vrm']['humanoid']['humanBones'].items()}
    bones=target['bones'];parents=[b['parent'] for b in bones]
    local=[transform(b['position'],b['rotation'],b['scale']) for b in bones]
    rest=worlds(local,parents);node=worlds(vrm.local,vrm.parents)
    mapping={};correction={}
    for i,bone in enumerate(bones):
        name=rename.get(bone['name'],bone['name'])
        if name in sn and name in vn:
            mapping[i]=sn[name];correction[i]=np.linalg.inv(node[vn[name]])@rest[i]
    animated={i for i in mapping if bones[i]['name'] not in report['physics_bones']}
    channels,start,end=source.prepare({})
    durations=[]
    for repeat in range(3):
        begin=time.perf_counter()
        for t in np.linspace(start,end,41):
            pose=source.pose(channels,float(t));output=[None]*len(bones)
            def solve(i):
                if output[i] is not None:return output[i]
                parent=np.eye(4) if parents[i]<0 else solve(parents[i])
                desired=parent@local[i]
                if i in animated:
                    desired=pose[mapping[i]]@correction[i]
                    result=np.linalg.inv(parent)@desired
                    q=quaternion(result[:3,:3])
                    assert np.isfinite(q).all()
                output[i]=desired
                return desired
            for i in range(len(bones)):solve(i)
        durations.append(time.perf_counter()-begin)
    return {'sample_frames_per_repeat':41,'repeats':3,'elapsed_s':durations,
            'median_seconds_per_frame':float(np.median(durations)/41),
            'scope':'Existing Keqing GLB pose sampling + existing retarget math only; excludes Blender import/bake/export, output serialization and Godot QA.'}


def crosscheck():
    module_path=Path(os.environ['APPDATA'])/'Blender Foundation/Blender/5.1/extensions/blender_org/mmd_tools/core/vmd/__init__.py'
    spec=importlib.util.spec_from_file_location('installed_vmd_reader',module_path)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    rows=json.loads((OUT/'files.json').read_text(encoding='utf-8'))
    source=Path(json.loads((OUT/'summary.json').read_text(encoding='utf-8'))['source'])
    mismatches=[];begin=time.perf_counter()
    for row in rows:
        data=module.File();data.load(filepath=str(source/row['file']))
        official={'bone':sum(map(len,data.boneAnimation.values())),
                  'morph':sum(map(len,data.shapeKeyAnimation.values())),
                  'camera':len(data.cameraAnimation),'light':len(data.lightAnimation),'shadow':len(data.selfShadowAnimation)}
        if official!=row['sections'] or len(data.propertyAnimation)!=row['property_frames']:
            mismatches.append(row['file'])
    return {'reader':str(module_path),'files_checked':len(rows),'section_count_mismatches':mismatches,'elapsed_s':time.perf_counter()-begin}


def memory():
    class Status(ctypes.Structure):
        _fields_=[('length',ctypes.c_ulong),('load',ctypes.c_ulong)]+[(n,ctypes.c_ulonglong) for n in ['total_phys','avail_phys','total_page','avail_page','total_virtual','avail_virtual','avail_extended']]
    value=Status();value.length=ctypes.sizeof(value)
    if not ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(value)):return {'unavailable':True}
    return {'logical_processors':os.cpu_count(),'total_physical_bytes':value.total_phys,'available_physical_bytes':value.avail_phys}


if __name__=='__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    result={'scope':'read existing resources only; no actual batch conversion',
            'animations':[inspect_animation(ROOT/p) for p in ['assets/characters/mmd_validation/keqing_vrm_loop03.tres','assets/characters/mmd_validation/paired/ganyu_role_b.tres']],
            'memory_snapshot':memory(),'retarget_microbenchmark':benchmark(),'installed_reader_crosscheck':crosscheck()}
    (OUT/'cost_and_crosscheck.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False,indent=2))
