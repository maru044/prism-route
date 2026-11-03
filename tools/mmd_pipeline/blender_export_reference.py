import bpy, json
scene=bpy.context.scene
target=bpy.data.objects['MMD_Baked']
verts=[]
faces=[]
for bone in target.data.bones:
    p=bone.head_local
    i=len(verts)
    verts.extend([(p.x-0.002,p.y,p.z),(p.x+0.002,p.y,p.z),(p.x,p.y,p.z+0.004)])
    faces.append((i,i+1,i+2))
mesh=bpy.data.meshes.new('RigValidationMarkers')
mesh.from_pydata(verts,[],faces)
mesh.update()
markers=bpy.data.objects.new('RigValidationMarkers',mesh)
scene.collection.objects.link(markers)
for i,bone in enumerate(target.data.bones):
    group=markers.vertex_groups.new(name=bone.name)
    group.add([i*3,i*3+1,i*3+2],1.0,'REPLACE')
modifier=markers.modifiers.new('BakedSkin','ARMATURE')
modifier.object=target
markers.parent=target
for obj in scene.objects:
    obj.select_set(False)
target.select_set(True)
markers.select_set(True)
bpy.context.view_layer.objects.active=target
scene.frame_set(0)
properties=bpy.ops.export_scene.gltf.get_rna_type().properties
assert 'ACTIVE_ACTIONS' in [i.identifier for i in properties['export_animation_mode'].enum_items]
assert 'NONE' in [i.identifier for i in properties['export_materials'].enum_items]
result=bpy.ops.export_scene.gltf(filepath='D:/Prism Route/prism-route/assets/characters/mmd_validation/loop03_baked.glb',use_selection=True,use_active_scene=True,export_animations=True,export_animation_mode='ACTIVE_ACTIONS',export_frame_range=True,export_frame_step=1,export_force_sampling=True,export_rest_position_armature=True,export_optimize_animation_size=False,export_skins=True,export_morph=False,export_materials='NONE',export_yup=True,export_cameras=False,export_lights=False)
print('EXPORT_RESULT '+json.dumps({'result':list(result),'mesh_vertices':len(mesh.vertices),'bones':len(target.data.bones)},ensure_ascii=False))
