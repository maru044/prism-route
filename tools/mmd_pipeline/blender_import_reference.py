"""Run in Blender with MMD Tools enabled, before the bake/export steps."""
import bpy

scene = bpy.data.scenes.new('MMD Validation')
bpy.context.window.scene = scene
scene.render.fps = 30
scene.frame_set(0)
bpy.ops.mmd_tools.import_model(
    filepath='D:/模型/20261008/刻晴_by_原神_b0f08721a7da17df599896ac40dd2f22/刻晴/刻晴/刻晴.pmx',
    scale=0.08, types={'ARMATURE'}, save_log=False, log_level='WARNING')
arm = next(obj for obj in scene.objects if obj.type == 'ARMATURE')
arm.name = 'MMD_Source'
for obj in scene.objects:
    obj.select_set(False)
    if obj.type == 'MESH': obj.hide_set(True)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.mmd_tools.import_vmd(
    filepath='D:/模型/20261008/Public R-18 Motions/Loop 03/Izumi.vmd',
    scale=0.08, margin=0, bone_mapper='PMX', use_pose_mode=False,
    use_mirror=False, update_scene_settings=True, create_new_action=True,
    use_nla=False, save_log=False, log_level='ERROR')
arm.animation_data.action.name = 'MMD_Source_Loop03'
scene.frame_start = 0
scene.frame_end = 480
