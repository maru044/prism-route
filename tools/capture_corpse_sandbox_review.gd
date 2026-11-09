extends SceneTree

const SANDBOX_SCENE := "res://scenes/test/corpse_interaction_sandbox.tscn"
const SCREENSHOT_DIR := "res://screenshots"
const HUMANOID_RIG := preload("res://scripts/characters/humanoid_rig.gd")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if "--verify" in OS.get_cmdline_user_args():
		await _verify_hips()
		return
	print("--- Capturing Corpse Sandbox Pure Natural Physics Screenshots ---")
	root.size = Vector2i(1280, 720)
	var dir := DirAccess.open("res://")
	if not dir.dir_exists("screenshots"):
		dir.make_dir("screenshots")
		
	var packed: PackedScene = load(SANDBOX_SCENE)
	var sandbox = packed.instantiate()
	root.add_child(sandbox)
	
	# Settle physics
	for i in 35:
		await physics_frame
		
	# 1. Natural Ragdoll on Ground
	await _capture("corpse_01_natural_ragdoll.png")
	
	# 2. Start Dragging Foot (Pure physical joint drag)
	sandbox.current_drag_bone = "LeftFoot"
	sandbox._unhandled_input(_make_key_event(KEY_E))
	for i in 25:
		sandbox.player.global_position += Vector3(0, 0, 0.04)
		await physics_frame
	await _capture("corpse_02_dragging_foot.png")
	
	# Drop foot
	sandbox._unhandled_input(_make_key_event(KEY_E))
	for i in 20: await physics_frame
	
	# 3. Open Character Selection Panel via [C]
	sandbox._unhandled_input(_make_key_event(KEY_C))
	for i in 10: await process_frame
	await _capture("corpse_03_character_panel.png")
	sandbox._unhandled_input(_make_key_event(KEY_C))
	for i in 10: await process_frame
	
	# 4. Quick Cycle Next Character via [Q]
	sandbox._unhandled_input(_make_key_event(KEY_Q))
	for i in 35: await physics_frame
	await _capture("corpse_04_switched_character.png")
	
	print("All pure natural physics review screenshots captured successfully!")
	quit()

func _capture(filename: String) -> void:
	for frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img != null:
		var path := ProjectSettings.globalize_path(SCREENSHOT_DIR + "/" + filename)
		img.save_png(path)
		print("Saved screenshot: ", path)

func _make_key_event(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	return ev

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _verify_hips() -> void:
	Engine.max_fps = 0
	var sandbox = load(SANDBOX_SCENE).instantiate()
	sandbox.get_node("CorpseCharacter").auto_start_ragdoll = false
	root.add_child(sandbox)
	sandbox.player.set_physics_process(false)
	sandbox.player.set_process_unhandled_input(false)
	var capture_contact := "--capture-contact" in OS.get_cmdline_user_args()
	if capture_contact:
		root.size = Vector2i(1280, 720)
		var camera := Camera3D.new()
		sandbox.add_child(camera)
		camera.position = Vector3(-0.7, 1.8, 2.5)
		camera.look_at(Vector3(-0.7, 0.3, 0), Vector3.UP)
		camera.current = true
	var corpse = sandbox.corpse
	# A neutral synthetic pose exercises a rotating body root, physical pelvis and Center.
	var source = load("res://assets/characters/mmd_validation/keqing_physics.vrm").instantiate()
	source.visible = false
	root.add_child(source)
	var source_skeleton: Skeleton3D = source.find_child("GeneralSkeleton", true, false)
	for node in source.find_children("*", "AnimationPlayer", true, false): node.stop()
	for node in source_skeleton.get_children():
		if node is SkeletonModifier3D: node.active = false
	var source_rig := HUMANOID_RIG.new()
	_expect(source_rig.setup(source_skeleton), "Source rig could not be resolved")
	source_skeleton.reset_bone_poses()
	source_skeleton.set_bone_pose_rotation(source_rig.body_root, Quaternion(Vector3.FORWARD, 0.12) * source_rig.rest_local[source_rig.body_root].basis.get_rotation_quaternion())
	source_skeleton.set_bone_pose_rotation(source_rig.pelvis, Quaternion(Vector3.RIGHT, 0.17) * source_rig.rest_local[source_rig.pelvis].basis.get_rotation_quaternion())
	source_skeleton.force_update_all_bone_transforms()
	var payload := source_rig.capture_pose(Vector3(0.08, 0.04, -0.05))
	var identity_solution := source_rig.solve_pose(payload)
	var source_rotations: Dictionary = {}
	for role: String in source_rig.semantic_bones:
		source_rotations[role] = source_skeleton.get_bone_global_pose(source_rig.semantic_bones[role]).basis
	source_rig.apply_solution(identity_solution)
	var rotation_error := 0.0
	for role: String in source_rig.semantic_bones:
		var a: Basis = source_rotations[role]
		var b := source_skeleton.get_bone_global_pose(source_rig.semantic_bones[role]).basis
		rotation_error = maxf(rotation_error, maxf(a.x.distance_to(b.x), maxf(a.y.distance_to(b.y), a.z.distance_to(b.z))))
	_expect(rotation_error < 0.001, "Neutral pose source rotation fidelity failed")
	var rows: Array = []
	for model_path in ["res://scenes/characters/ganyu.tscn", "res://assets/characters/mmd_validation/keqing_physics.vrm"]:
		if model_path != "res://scenes/characters/ganyu.tscn":
			_expect(corpse.load_character(model_path, "keqing", "Keqing"), "Control model failed to load")
			corpse.stop_ragdoll()
			await process_frame
		corpse.character_instance.transform = Transform3D.IDENTITY
		var skel: Skeleton3D = corpse.skeleton
		_expect(_local_position_error(corpse) < 0.000001, "Fresh actor contains an editor-saved pose offset")
		skel.reset_bone_poses()
		skel.force_update_all_bone_transforms()
		var root_body: PhysicalBone3D = corpse.physical_bones.Hips
		_expect(root_body.get_bone_id() == corpse.rig.body_root, "Physical Hips is not the common body root")
		var body_center_error: float = root_body.global_position.distance_to(skel.global_transform * corpse.rig.rest_world[corpse.rig.pelvis].origin)
		_expect(body_center_error < 0.0001, "Pelvis body center does not match physical pelvis")
		var roles_by_index: Dictionary = {}
		for role in corpse.physical_bones:
			var pb: PhysicalBone3D = corpse.physical_bones[role]
			_expect(pb.get_bone_id() >= 0 and pb.get_parent() == corpse.simulator, "Invalid physical binding: " + role)
			roles_by_index[pb.get_bone_id()] = role
		_expect(roles_by_index.size() == 16, "Expected 16 unique physical bone bindings")
		var anchors: Dictionary = {}
		for role in corpse.physical_bones:
			if role == "Hips": continue
			var pb: PhysicalBone3D = corpse.physical_bones[role]
			var parent: int = skel.get_bone_parent(pb.get_bone_id())
			while parent >= 0 and not roles_by_index.has(parent): parent = skel.get_bone_parent(parent)
			_expect(parent >= 0, "Disconnected physical branch: " + role)
			if parent < 0: continue
			var parent_role: String = roles_by_index[parent]
			if role in ["Spine", "LeftUpperLeg", "RightUpperLeg"]:
				_expect(parent_role == "Hips", "Torso/leg branch does not connect to Hips: " + role)
			var parent_pb: PhysicalBone3D = corpse.physical_bones[parent_role]
			anchors[role] = {"parent": parent_role, "point": parent_pb.global_transform.affine_inverse() * (pb.global_transform * pb.joint_offset).origin}
		corpse.start_ragdoll()
		var max_anchor_error := 0.0
		var min_settled_bottom := INF
		for frame in 360:
			await physics_frame
			max_anchor_error = maxf(max_anchor_error, _anchor_error(corpse, anchors))
			if frame >= 300: min_settled_bottom = minf(min_settled_bottom, _lowest_capsule(corpse))
		for role: String in corpse.physical_bones:
			var pb: PhysicalBone3D = corpse.physical_bones[role]
			if _capsule_bottom(pb) < -0.02:
				print("CONTACT_DIAGNOSTIC ", role, " bottom=", _capsule_bottom(pb), " speed=", pb.linear_velocity.length())
		if capture_contact:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.current_map_build/hips_repair_contact_%d.png" % rows.size())
		for pb: PhysicalBone3D in corpse.physical_bones.values():
			_expect(pb.is_simulating_physics() and pb.global_position.is_finite(), "Physical body not simulating or nonfinite")
		var anchor := Node3D.new()
		root.add_child(anchor)
		var foot: PhysicalBone3D = corpse.physical_bones.LeftFoot
		var initial_relative: Vector3 = foot.global_position - root_body.global_position
		anchor.global_position = foot.global_position + Vector3(0.2, 0.4, 0)
		_expect(corpse.start_drag("LeftFoot", anchor), "Foot drag did not start")
		for frame in 45:
			anchor.position.x += 0.002
			await physics_frame
			max_anchor_error = maxf(max_anchor_error, _anchor_error(corpse, anchors))
		var relative_change: float = initial_relative.distance_to(foot.global_position - root_body.global_position)
		_expect(relative_change > 0.02, "Dragged limb remained rigid relative to Hips")
		corpse.stop_drag()
		anchor.free()
		for frame in 90:
			await physics_frame
			max_anchor_error = maxf(max_anchor_error, _anchor_error(corpse, anchors))
		_expect(max_anchor_error < 0.06, "Physical joint separation exceeds 6 cm: " + str(max_anchor_error))
		_expect(min_settled_bottom > -0.03, "Settled collision capsule remains below floor: " + str(min_settled_bottom))
		_expect(corpse.apply_pose_data({"name": "neutral_verification", "humanoid_pose": payload}, 0.0), "Semantic pose application failed")
		var position_error := _local_position_error(corpse)
		_expect(position_error < 0.000001, "Pose copied another character's bone lengths")
		var first_pelvis: Vector3 = corpse.get_pelvis_world_position()
		corpse.apply_pose_data({"name": "neutral_verification", "humanoid_pose": payload}, 0.0)
		_expect(first_pelvis.distance_to(corpse.get_pelvis_world_position()) < 0.0001, "Repeated pose accumulated root displacement")
		# Verify cancellation: only the latest tween may continue writing bones.
		corpse.apply_pose_data({"name": "interrupted", "humanoid_pose": payload}, 0.4)
		corpse.apply_pose_data({"name": "replacement", "humanoid_pose": payload}, 0.0)
		for frame in 3: await process_frame
		_expect(not corpse.tween_active, "Cancelled pose tween is still active")
		var saved_count := 0
		for file in DirAccess.get_files_at("res://assets/characters/poses"):
			if not file.ends_with(".json"): continue
			_expect(corpse.apply_pose_file("res://assets/characters/poses/" + file, 0.0), "Existing pose migration failed")
			_expect(_local_position_error(corpse) < 0.000001, "Existing pose changed target rest positions")
			saved_count += 1
		# Use the actual sandbox furniture, whose mattress top is at 0.46 m.
		skel.reset_bone_poses()
		skel.force_update_all_bone_transforms()
		var bed: Node3D = sandbox.get_node("PrismGeoBed")
		var support_y: float = bed.global_position.y + bed.seat_surface_height
		corpse.character_instance.global_transform = Transform3D(Basis.IDENTITY, bed.global_position + Vector3(0, bed.seat_surface_height + 0.01, 0.15))
		corpse.start_ragdoll()
		for frame in 3: await physics_frame
		corpse.apply_pose_data({"name": "neutral_support_verification", "humanoid_pose": payload}, 0.0)
		var support_error: float = absf(corpse.to_global(corpse._pose_anchor.origin).y - support_y)
		_expect(support_error < 0.001, "Pose transition lost the elevated furniture support height")
		rows.append({"model": model_path, "physical_bones": roles_by_index.size(), "body_root": skel.get_bone_name(corpse.rig.body_root), "pelvis_center_error_m": body_center_error, "max_joint_anchor_error_m": max_anchor_error, "min_settled_capsule_bottom_m": min_settled_bottom, "drag_relative_change_m": relative_change, "pose_local_position_error_m": position_error, "saved_poses": saved_count, "furniture_support_height_error_m": support_error})
	source.free()
	sandbox.free()
	await process_frame
	print("HIPS_REPAIR_VERIFICATION ", JSON.stringify({"passed": failures.is_empty(), "failures": failures, "neutral_source_rotation_axis_error": rotation_error, "models": rows}))
	quit(0 if failures.is_empty() else 1)

func _anchor_error(corpse, anchors: Dictionary) -> float:
	var worst := 0.0
	for role: String in anchors:
		var pb: PhysicalBone3D = corpse.physical_bones[role]
		var parent: PhysicalBone3D = corpse.physical_bones[anchors[role].parent]
		worst = maxf(worst, (pb.global_transform * pb.joint_offset).origin.distance_to(parent.global_transform * anchors[role].point))
	return worst

func _lowest_capsule(corpse) -> float:
	var lowest := INF
	for pb: PhysicalBone3D in corpse.physical_bones.values():
		lowest = minf(lowest, _capsule_bottom(pb))
	return lowest

func _capsule_bottom(pb: PhysicalBone3D) -> float:
	var shape: CollisionShape3D = pb.get_child(0)
	var cap: CapsuleShape3D = shape.shape
	var t := shape.global_transform
	return t.origin.y - absf(t.basis.y.y) * (cap.height * 0.5 - cap.radius) - cap.radius

func _local_position_error(corpse) -> float:
	var worst := 0.0
	for i in corpse.rig.order:
		worst = maxf(worst, corpse.skeleton.get_bone_pose_position(i).distance_to(corpse.rig.rest_local[i].origin))
	return worst
