extends "res://scripts/character_motion_test.gd"
## Neutral PMX conversion review with versioned private-project test assets.

@export var model_id := "keqing"
@export var model_label := "刻晴"
@export var sleeve_dynamics_available := true
var local: String
var variant: OptionButton

func _ready() -> void:
	local = "res://assets/characters/import_tests_local/" + model_id + "/"
	character_resource = local + model_id + "_fixed.vrm"
	motion_directory = local + "motions"
	review_title = model_label + "动作测试"
	spring_physics_enabled = sleeve_dynamics_available
	spring_controls_available = sleeve_dynamics_available
	if not ResourceLoader.exists(character_resource) or not FileAccess.file_exists(motion_directory + "/catalog.json"):
		var message := Label.new()
		message.position = Vector2(32, 32)
		message.text = "本地测试模型尚未生成。\n请按 docs/MMD_VRM_IMPORT_TEST.md 运行转换和动作烘焙。"
		add_child(message)
		set_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)
		return
	super._ready()
	timeline.value_changed.connect(func(_value):
		if not update_timeline: _reset_sleeve_simulation.call_deferred())
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := VBoxContainer.new()
	panel.position = Vector2(390, 14)
	layer.add_child(panel)
	variant = OptionButton.new()
	variant.add_item("处理后：D 权重转普通骨，EX 合并到脚踝")
	variant.add_item("处理前：保留原始 D / EX 权重")
	variant.item_selected.connect(_switch_variant)
	panel.add_child(variant)
	var note := Label.new()
	note.text = "袖尾动态已启用 · 关闭左侧服饰物理可对比\n头发、裙摆物理和表情绑定尚未配置"
	if not sleeve_dynamics_available:
		note.text = "头发、衣摆物理和表情绑定尚未配置"
	panel.add_child(note)

func _switch_variant(index: int) -> void:
	var time := player.current_animation_position
	var was_playing := playing
	var speed := player.speed_scale
	var library := player.get_animation_library("")
	player.stop()
	character.free()
	character_resource = local + model_id + ("_fixed.vrm" if index == 0 else "_before.vrm")
	character = load(character_resource).instantiate()
	add_child(character)
	skeleton = character.find_child("GeneralSkeleton", true, false)
	skeleton.motion_scale = 1.0
	var original: AnimationPlayer = character.find_child("AnimationPlayer", true, false)
	if original: original.stop()
	skeleton.reset_bone_poses()
	_set_springs(spring_physics_enabled)
	player = AnimationPlayer.new()
	player.name = "MotionReviewPlayer"
	character.add_child(player)
	player.add_animation_library("", library)
	player.speed_scale = speed
	_select(selected)
	player.seek(time, true)
	if not was_playing: _pause()
	_center_character()
	variant.select(index)

func _select(index: int) -> void:
	super._select(index)
	_reset_sleeve_simulation.call_deferred()

func _reset_sleeve_simulation() -> void:
	if not is_instance_valid(character): return
	var controller = character.find_child("VRMSpringBoneController", true, false)
	var simulation = skeleton.get_node_or_null("VRMSpringBoneSimulation")
	if controller and simulation:
		simulation.setup(controller.spring_bones, controller.collider_groups)
		simulation.active = spring_physics_enabled
