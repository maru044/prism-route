"""Run with Blender --background --factory-startup --python-exit-code 1 --python.
Uses an isolated scene and separate decision fixture, never real user decisions.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import time

import bpy
from mathutils import Vector

sys.stdout.reconfigure(encoding='utf-8')
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
OUT=ROOT/'docs/validation/mmd_source_browser_20261103'
OUT.mkdir(parents=True,exist_ok=True)
spec=importlib.util.spec_from_file_location('prism_mmd_source_browser',HERE/'blender_source_browser.py')
browser=importlib.util.module_from_spec(spec);sys.modules[spec.name]=browser;spec.loader.exec_module(browser)
browser.register();scene=browser.ensure_scene();s=browser.state(scene)
real_selection=browser.CONFIG['selection_file'];fixture=OUT/'selection_fixture.json'
browser.CONFIG['selection_file']=str(fixture)
fixture.write_text(json.dumps({'schema':1,'source_root':browser.CATALOG['source_root'],'takes':{}}),encoding='utf-8')
model_hashes={p:hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in browser.CONFIG['reference_models'].values()}
source_hashes={}


def choose(folder):
    s.group_index=next(i for i,item in enumerate(s.groups) if browser.FOLDERS[item.key]['folder']==folder)
    browser.on_group(s,bpy.context)


def constraints(role):
    arm=browser.role_armature(scene,role)
    return sum(len(b.constraints) for b in arm.pose.bones),len(arm.animation_data.drivers) if arm.animation_data else 0


def action_count():return len([a for a in bpy.data.actions if a.get('pr_source_preview_action')])


def compare_reference(role,path,field):
    arm=browser.role_armature(scene,role);error=0.0;count=0;worst={}
    reference=json.loads(path.read_text(encoding='utf-8'))['reference_frames']
    for item in reference:
        scene.frame_set(item['frame']);bpy.context.view_layer.update()
        evaluated=arm.evaluated_get(bpy.context.evaluated_depsgraph_get())
        for name,expected in item[field].items():
            p=evaluated.matrix_world@evaluated.pose.bones[name].head
            p=Vector((p.x,p.z,-p.y))
            value=(p-Vector(expected)).length
            if value>error:worst={'frame':item['frame'],'bone':name,'actual':list(p),'expected':expected}
            error=max(error,value);count+=1
    return {'checks':count,'max_error_m':error,'worst':worst}


report={'passed':False,'formal_bakes':0,'library_files':len(browser.FILES),'candidate_folders':len(browser.FOLDERS)}
try:
    before={r:constraints(r) for r in ['A','B']}
    report['constraints_and_drivers']=before
    report['ik_iterations']={r:[(b.name,c.iterations) for b in browser.role_armature(scene,r).pose.bones for c in b.constraints if c.type=='IK'] for r in before}
    choose('Loop 03');start=time.perf_counter();browser.load_selected(bpy.context)
    report['first_pair_load_s']=time.perf_counter()-start
    report['source_comparison_a']=compare_reference('A',ROOT/'assets/characters/mmd_validation/loop03_reference.json','positions_y_up')
    report['source_comparison_b']=compare_reference('B',ROOT/'assets/characters/mmd_validation/paired/role_b_blender_reference.json','positions')
    assert report['source_comparison_a']['max_error_m']<.0001
    assert report['source_comparison_b']['max_error_m']<.0001
    assert all(constraints(r)==before[r] for r in before),'Constraint/driver state changed'
    assert scene.frame_start==0 and scene.frame_end==480
    for _,key in browser.selection_ids(scene):
        path=Path(browser.CATALOG['source_root'])/browser.FILES[key]['file'];source_hashes[str(path)]=browser.FILES[key]['sha256']
    s.trim_start=0;s.trim_end=120;s.note='test fixture only';browser.mark_take(scene,'KEEP')
    s.trim_end=360;s.trim_start=240;browser.mark_take(scene,'MAYBE')
    records=browser.read_decisions()['takes'];assert len(records)==2
    assert sorted((r['frame_start'],r['frame_end']) for r in records.values())==[(0,120),(240,360)]
    report['multiple_segments_persisted']=True
    first=next(r for r in records.values() if r['decision']=='KEEP')
    assert bpy.ops.pr_mmd_source.recall(take_id=first['id'])=={'FINISHED'}
    assert s.trim_start==0 and s.trim_end==120
    report['recall_preserved_roles_and_range']=True
    choose('Loop 05');browser.load_selected(bpy.context)
    assert scene.frame_end==610 and s.loaded_max_frame==610
    report['non_480_frame_range_tested']=610
    choose('Motorcycle Photoshoot 2nd pose')
    group=browser.group_for(scene)
    static=next(k for k in group['files'] if browser.FILES[k]['kind']=='body_pose')
    s.role_c=static;browser.load_selected(bpy.context)
    assert len(browser.selection_ids(scene))==3
    arm=browser.role_armature(scene,'C')
    poses=[]
    for frame in [0,100,1000]:
        scene.frame_set(frame);bpy.context.view_layer.update()
        poses.append([tuple(b.matrix.translation) for b in arm.evaluated_get(bpy.context.evaluated_depsgraph_get()).pose.bones])
    assert poses[0]==poses[1]==poses[2]
    report['static_third_role_preserved']=True
    choose('Loop 28 - 69-V2')
    count_before=action_count();blocked=False
    try:browser.load_selected(bpy.context)
    except ValueError:blocked=True
    assert blocked and action_count()==count_before
    report['unsupported_controls_blocked_before_mutation']=True
    choose('Reverse Stradle - By Ademar440');browser.load_selected(bpy.context);scene.frame_set(scene.frame_end)
    choose('Loop 03');browser.load_selected(bpy.context)
    assert all(constraints(r)==before[r] for r in before)
    report['ik_switch_then_reload_preserved_constraints']=True
    counts=[]
    for _ in range(4):browser.load_selected(bpy.context);counts.append(action_count())
    assert counts==[2,2,2,2],counts
    report['repeated_load_action_counts']=counts
    s.trim_end=999999
    assert s.trim_end==480 and scene.frame_preview_end==480
    report['range_clamped_to_source']=True
    assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==h for p,h in {**model_hashes,**source_hashes}.items())
    report['reference_models_and_test_sources_unchanged']=True
    report['real_selection_file_modified']=False
    # Initial interactive file shows a normal photoshoot source, no test decisions.
    browser.CONFIG['selection_file']=real_selection
    choose('Motorcycle Photoshoot 1st pose');browser.load_selected(bpy.context)
    s.trim_start=0;s.trim_end=s.loaded_max_frame;scene.frame_set(0)
    browser.refresh_decision_badges(scene)
    destination=Path(browser.CONFIG['preview_blend']);destination.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(destination),compress=True)
    report['preview_blend']=str(destination)
    report['passed']=True
except Exception as error:
    report['error']=repr(error)
    raise
finally:
    browser.CONFIG['selection_file']=real_selection
    (OUT/'verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print('SOURCE_BROWSER_VERIFICATION '+json.dumps(report,ensure_ascii=False))
