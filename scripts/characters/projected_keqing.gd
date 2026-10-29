extends Node3D
## Keqing remains an independent NPC; printing reuses the reviewed MToon light-layer mask.
const EFFECT := preload("res://scripts/characters/hologram_effect.gd")
const IDLE := preload("res://assets/characters/import_tests_local/keqing/motions/A01.tres")
@onready var model: Node3D=$KeqingModel
var skeleton: Skeleton3D
var motion: AnimationPlayer
var effect

func _ready() -> void:
	skeleton=model.find_child("GeneralSkeleton",true,false);skeleton.motion_scale=1.
	var original: AnimationPlayer=model.find_child("AnimationPlayer",true,false)
	if original:original.stop()
	skeleton.reset_bone_poses()
	var controller=model.find_child("VRMSpringBoneController",true,false)
	if controller:controller.process_mode=Node.PROCESS_MODE_DISABLED
	_disable_modifiers();_disable_modifiers.call_deferred()
	motion=AnimationPlayer.new();motion.name="ProjectionMotion"
	motion.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL;model.add_child(motion)
	var library:=AnimationLibrary.new();var clip: Animation=IDLE.duplicate(true)
	clip.loop_mode=Animation.LOOP_LINEAR;library.add_animation("idle",clip)
	motion.add_animation_library("",library);motion.play("idle");motion.seek(.6,true)
	_center_model()
	effect=EFFECT.new();effect.name="HologramEffect";add_child(effect)
	effect.bind(model,"keqing")

func _disable_modifiers() -> void:
	for modifier: SkeletonModifier3D in model.find_children("*","SkeletonModifier3D",true,false):modifier.active=false

func _center_model() -> void:
	var hips:=skeleton.get_bone_global_pose(skeleton.find_bone("Hips")).origin
	model.position=Vector3(-hips.x,.025,-hips.z)

func _process(delta: float) -> void:
	if motion!=null:
		motion.advance(delta);_center_model()
