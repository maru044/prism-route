"""Reference import for the supplied Loop03 companion role, on its own model rig."""
import bpy

scene = bpy.data.scenes.new('MMD Pair Loop03 Role B')
bpy.context.window.scene = scene
scene.render.fps = 30
scene.frame_set(0)
bpy.ops.mmd_tools.import_model(
    filepath='D:/模型/ganyu_by_原神_7381ccd84ee8763ce63b3ad638e1c49b/甘雨.pmx',
    scale=0.08, types={'ARMATURE'}, save_log=False, log_level='ERROR')
source = next(obj for obj in scene.objects if obj.type == 'ARMATURE')
source.name = 'Ganyu_Pair_Source'
for obj in scene.objects:
    obj.select_set(obj == source)
    if obj.type == 'MESH': obj.hide_set(True)
bpy.context.view_layer.objects.active = source
bpy.ops.mmd_tools.import_vmd(
    filepath='D:/模型/20261008/Public R-18 Motions/Loop 03/Kaat.vmd',
    scale=0.08, margin=0, bone_mapper='PMX', use_pose_mode=False,
    use_mirror=False, update_scene_settings=True, create_new_action=True,
    use_nla=False, save_log=False, log_level='ERROR')
scene.frame_start = 0
scene.frame_end = 480
source.animation_data.action.name = 'Ganyu_Pair_Kaat_Source'
