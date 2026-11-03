import bpy, json
from mathutils import Matrix
scene=bpy.context.scene
source=bpy.data.objects['MMD_Source']
target=source.copy()
target.data=source.data.copy()
target.animation_data_clear()
target.parent=None
target.name='MMD_Baked'
scene.collection.objects.link(target)
for constraint in list(target.constraints):
    target.constraints.remove(constraint)
constraint_types=[i.identifier for i in bpy.types.Constraint.bl_rna.properties['type'].enum_items]
assert 'COPY_TRANSFORMS' in constraint_types
for bone in target.pose.bones:
    for constraint in list(bone.constraints):
        bone.constraints.remove(constraint)
    bone.matrix_basis=Matrix.Identity(4)
    constraint=bone.constraints.new('COPY_TRANSFORMS')
    constraint.target=source
    constraint.subtarget=bone.name
for obj in scene.objects:
    obj.select_set(False)
target.select_set(True)
bpy.context.view_layer.objects.active=target
options={p.identifier:[i.identifier for i in p.enum_items] for p in bpy.ops.nla.bake.get_rna_type().properties if p.type=='ENUM'}
assert 'POSE' in options['bake_types']
result=bpy.ops.nla.bake(frame_start=0,frame_end=480,step=1,only_selected=False,visual_keying=True,clear_constraints=True,clear_parents=False,use_current_action=False,clean_curves=False,bake_types={'POSE'})
target.animation_data.action.name='MMD_Loop03_Baked'
print('BAKE_RESULT '+json.dumps({'result':list(result),'bones':len(target.data.bones),'remaining_constraints':sum(len(b.constraints) for b in target.pose.bones),'range':list(target.animation_data.action.frame_range)},ensure_ascii=False))
