import bpy,json
from mathutils import Matrix
scene=bpy.context.scene
source=bpy.data.objects['Ganyu_Pair_Source']
target=source.copy()
target.data=source.data.copy()
target.animation_data_clear()
target.parent=None
target.name='Ganyu_Pair_Baked'
scene.collection.objects.link(target)
for constraint in list(target.constraints): target.constraints.remove(constraint)
assert 'COPY_TRANSFORMS' in [i.identifier for i in bpy.types.Constraint.bl_rna.properties['type'].enum_items]
for bone in target.pose.bones:
    for constraint in list(bone.constraints): bone.constraints.remove(constraint)
    bone.matrix_basis=Matrix.Identity(4)
    constraint=bone.constraints.new('COPY_TRANSFORMS')
    constraint.target=source
    constraint.subtarget=bone.name
for obj in scene.objects: obj.select_set(obj==target)
bpy.context.view_layer.objects.active=target
result=bpy.ops.nla.bake(frame_start=0,frame_end=480,step=1,only_selected=False,visual_keying=True,clear_constraints=True,clear_parents=False,use_current_action=False,clean_curves=False,bake_types={'POSE'})
target.animation_data.action.name='Loop03_RoleB_Baked'
vertices=[]
faces=[]
for bone in target.data.bones:
    p=bone.head_local
    i=len(vertices)
    vertices.extend([(p.x-.002,p.y,p.z),(p.x+.002,p.y,p.z),(p.x,p.y,p.z+.004)])
    faces.append((i,i+1,i+2))
mesh=bpy.data.meshes.new('GanyuPairRigMarkers')
mesh.from_pydata(vertices,[],faces)
obj=bpy.data.objects.new('GanyuPairRigMarkers',mesh)
scene.collection.objects.link(obj)
for i,bone in enumerate(target.data.bones):
    group=obj.vertex_groups.new(name=bone.name)
    group.add([i*3,i*3+1,i*3+2],1.0,'REPLACE')
modifier=obj.modifiers.new('Skin','ARMATURE')
modifier.object=target
obj.parent=target
for item in scene.objects: item.select_set(item in [target,obj])
bpy.context.view_layer.objects.active=target
scene.frame_set(0)
result=bpy.ops.export_scene.gltf(filepath='D:/Prism Route/prism-route/assets/characters/mmd_validation/paired/loop03_ganyu_role_b.glb',use_selection=True,use_active_scene=True,export_animations=True,export_animation_mode='ACTIVE_ACTIONS',export_frame_range=True,export_frame_step=1,export_force_sampling=True,export_rest_position_armature=True,export_optimize_animation_size=False,export_skins=True,export_morph=False,export_materials='NONE',export_yup=True,export_cameras=False,export_lights=False)
print('PAIR_BAKE '+json.dumps({'result':list(result),'bones':len(target.data.bones),'constraints':sum(len(b.constraints) for b in target.pose.bones)}))
