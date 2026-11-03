"""Independent Blender worker: one reference solve per source role, no avatar matrix."""
import addon_utils
import bpy
import hashlib
import json
from pathlib import Path
import sys
import time
import traceback
from mathutils import Matrix

ROOT=Path(__file__).resolve().parents[2]
CACHE=ROOT/'.model_import_build/mmd_selected'
sys.stdout.reconfigure(encoding='utf-8')
plan=json.loads((CACHE/'jobs.json').read_text(encoding='utf-8'))
module=next(m.__name__ for m in addon_utils.modules() if m.__name__.endswith('mmd_tools'))
addon_utils.enable(module,default_set=False,persistent=True)
scene=bpy.data.scenes.new('Selected MMD Bake Worker');bpy.context.window.scene=scene
scene.render.fps=30;scene.render.fps_base=1.0
references={}
journal={'schema':1,'jobs':{}}
journal_path=CACHE/'bake_journal.json'
if journal_path.exists():journal=json.loads(journal_path.read_text(encoding='utf-8'))


def save_journal():
    temp=journal_path.with_suffix('.json.tmp');temp.write_text(json.dumps(journal,ensure_ascii=False,indent=2),encoding='utf-8');temp.replace(journal_path)


def reference(name):
    if name in references:return references[name]
    before=set(bpy.data.objects)
    bpy.ops.mmd_tools.import_model(filepath=plan['reference_models'][name],scale=.08,types={'ARMATURE'},save_log=False,log_level='ERROR')
    objects=set(bpy.data.objects)-before;arm=next(o for o in objects if o.type=='ARMATURE')
    arm.name='Selected_Reference_'+name
    references[name]=(arm,objects,{b.name:bool(b.mmd_ik_toggle) for b in arm.pose.bones})
    return references[name]


def reset(arm,objects,defaults):
    for obj in objects:
        if obj.animation_data:
            obj.animation_data.action=None
            for track in list(obj.animation_data.nla_tracks):obj.animation_data.nla_tracks.remove(track)
    for bone in arm.pose.bones:
        bone.matrix_basis=Matrix.Identity(4)
        if bone.mmd_ik_toggle!=defaults[bone.name]:bone.mmd_ik_toggle=defaults[bone.name]
    for action in list(bpy.data.actions):
        if action.users==0 and action.get('selected_mmd_worker'):bpy.data.actions.remove(action)


failed=[]
for index,job in enumerate(plan['jobs']):
    identifier=job['clip_id'];output=Path(job['baked_glb'])
    fingerprint=hashlib.sha256(json.dumps({'job':job,'model':plan['reference_model_sha256'][job['reference']],
                                         'worker':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'blender':bpy.app.version_string},sort_keys=True).encode('utf-8')).hexdigest()
    previous=journal['jobs'].get(identifier,{})
    if previous.get('status')=='passed' and previous.get('fingerprint')==fingerprint and output.is_file():
        print('SELECTED_BAKE_CACHE '+identifier,flush=True);continue
    started=time.perf_counter();target=None;marker=None;arm=None
    record={'status':'running','source':job['source_file'],'fingerprint':fingerprint,'frame_start':job['frame_start'],'frame_end':job['frame_end']}
    journal['jobs'][identifier]=record;save_journal()
    try:
        assert hashlib.sha256(Path(job['source_path']).read_bytes()).hexdigest()==job['source_sha256']
        arm,objects,defaults=reference(job['reference']);reset(arm,objects,defaults)
        scene.frame_set(0)
        for obj in scene.objects:obj.select_set(False)
        arm.select_set(True);bpy.context.view_layer.objects.active=arm
        result=bpy.ops.mmd_tools.import_vmd(filepath=job['source_path'],scale=.08,margin=0,bone_mapper='PMX',use_pose_mode=False,
                                         use_mirror=False,update_scene_settings=False,create_new_action=True,use_nla=False,save_log=False,log_level='ERROR')
        assert 'FINISHED' in result
        arm.animation_data.action['selected_mmd_worker']=True
        source_constraints=sum(len(b.constraints) for b in arm.pose.bones)
        target=arm.copy();target.data=arm.data.copy();target.animation_data_clear();target.parent=None
        target.name='Selected_Baked_'+identifier;scene.collection.objects.link(target)
        for constraint in list(target.constraints):target.constraints.remove(constraint)
        for bone in target.pose.bones:
            for constraint in list(bone.constraints):bone.constraints.remove(constraint)
            bone.matrix_basis=Matrix.Identity(4)
            constraint=bone.constraints.new('COPY_TRANSFORMS');constraint.target=arm;constraint.subtarget=bone.name
        for obj in scene.objects:obj.select_set(obj==target)
        bpy.context.view_layer.objects.active=target
        scene.frame_start=job['frame_start'];scene.frame_end=job['frame_end']
        result=bpy.ops.nla.bake(frame_start=job['frame_start'],frame_end=job['frame_end'],step=1,only_selected=False,visual_keying=True,
                              clear_constraints=True,clear_parents=False,use_current_action=False,clean_curves=False,bake_types={'POSE'})
        assert 'FINISHED' in result
        target.animation_data.action.name=identifier;target.animation_data.action['selected_mmd_worker']=True
        assert sum(len(b.constraints) for b in target.pose.bones)==0
        maximum=0.0;comparisons=0
        for frame in sorted({job['frame_start'],job['frame_end'],*[round(job['frame_start']+(job['frame_end']-job['frame_start'])*i/8) for i in range(1,8)]}):
            scene.frame_set(frame);bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
            src=arm.evaluated_get(deps);dst=target.evaluated_get(deps)
            for bone in src.pose.bones:
                difference=((src.matrix_world@bone.matrix).translation-(dst.matrix_world@dst.pose.bones[bone.name].matrix).translation).length
                maximum=max(maximum,difference);comparisons+=1
        assert maximum<.0001,(identifier,maximum)
        vertices=[];faces=[]
        for bone in target.data.bones:
            p=bone.head_local;i=len(vertices);vertices.extend([(p.x-.002,p.y,p.z),(p.x+.002,p.y,p.z),(p.x,p.y,p.z+.004)]);faces.append((i,i+1,i+2))
        mesh=bpy.data.meshes.new(identifier+'_markers');mesh.from_pydata(vertices,[],faces)
        marker=bpy.data.objects.new(identifier+'_skin',mesh);scene.collection.objects.link(marker)
        for i,bone in enumerate(target.data.bones):marker.vertex_groups.new(name=bone.name).add([3*i,3*i+1,3*i+2],1.0,'REPLACE')
        modifier=marker.modifiers.new('Skin','ARMATURE');modifier.object=target;marker.parent=target
        for obj in scene.objects:obj.select_set(obj in [target,marker])
        bpy.context.view_layer.objects.active=target;scene.frame_set(job['frame_start'])
        result=bpy.ops.export_scene.gltf(filepath=str(output),use_selection=True,use_active_scene=True,export_animations=True,
            export_animation_mode='ACTIVE_ACTIONS',export_frame_range=True,export_frame_step=1,export_force_sampling=True,
            export_rest_position_armature=True,export_optimize_animation_size=False,export_skins=True,export_morph=False,
            export_materials='NONE',export_yup=True,export_cameras=False,export_lights=False)
        assert 'FINISHED' in result and output.is_file()
        record.update(status='passed',elapsed_s=time.perf_counter()-started,source_constraints=source_constraints,baked_constraints=0,
                      bake_position_checks=comparisons,max_bake_position_error_m=maximum,bytes=output.stat().st_size,output_sha256=hashlib.sha256(output.read_bytes()).hexdigest())
        print('SELECTED_BAKE_DONE '+json.dumps({'index':index+1,'total':len(plan['jobs']),'id':identifier,'seconds':record['elapsed_s'],'max_error_m':maximum}),flush=True)
    except Exception as error:
        record.update(status='failed',error=str(error),traceback=traceback.format_exc());failed.append(identifier)
        print('SELECTED_BAKE_FAILED '+identifier+' '+str(error),flush=True)
    finally:
        for obj in [marker,target]:
            if obj:
                data=obj.data;bpy.data.objects.remove(obj,do_unlink=True)
                if data.users==0:
                    (bpy.data.meshes if isinstance(data,bpy.types.Mesh) else bpy.data.armatures).remove(data)
        if arm:reset(*references[job['reference']])
        save_journal()
if failed:raise RuntimeError('Selected bake failures: '+','.join(failed))
print('SELECTED_BAKE_COMPLETE '+str(len(plan['jobs'])),flush=True)
