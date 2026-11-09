extends SceneTree
## Comprehensive verification tool for all character models, locomotion animations, MMD paired motions, humanoid rig pose retargeting, and ragdoll physics.

const CAPTURE_DIR := "C:/Users/PC/.gemini/antigravity/brain/51c58479-72e8-436c-a199-d13ab3cac199/"
const HUMANOID_RIG := preload("res://scripts/characters/humanoid_rig.gd")
const CORPSE_CONTROLLER := preload("res://scripts/characters/corpse_ragdoll_controller.gd")

var failures: Array[String] = []
var results: Dictionary = {
	"ganyu_model_clean": false,
	"ganyu_locomotion": {},
	"models_audit": {},
	"poses_retargeting": {},
	"corpse_ragdoll": {},
	"captures": []
}

var camera: Camera3D
var light: DirectionalLight3D
var env_node: WorldEnvironment
var stage_root: Node3D

func _init() -> void:
	call_deferred("_run_audit")

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("AUDIT_ERROR: " + message)

func _setup_stage() -> void:
	root.size = Vector2i(1920, 1080)
	stage_root = Node3D.new()
	stage_root.name = "StageRoot"
	root.add_child(stage_root)

	env_node = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.18, 0.20, 0.24)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.88, 0.90, 0.95)
	env.ambient_light_energy = 0.9
	env_node.environment = env
	stage_root.add_child(env_node)

	light = DirectionalLight3D.new()
	light.light_energy = 1.3
	light.rotation = Vector3(-0.55, 0.65, 0.0)
	stage_root.add_child(light)

	var fill_light := DirectionalLight3D.new()
	fill_light.light_energy = 0.6
	fill_light.rotation = Vector3(0.4, -2.5, 0.0)
	stage_root.add_child(fill_light)

	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20.0, 20.0)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.22, 0.24, 0.28)
	floor_mat.roughness = 0.8
	floor_mesh.material_override = floor_mat
	floor_mesh.position.y = -0.06
	stage_root.add_child(floor_mesh)

	# Static collision floor so physical bodies settle naturally at Y=0
	var static_body := StaticBody3D.new()
	var col_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(20.0, 0.2, 20.0)
	col_shape.shape = box_shape
	col_shape.position.y = -0.1
	static_body.add_child(col_shape)
	stage_root.add_child(static_body)

	camera = Camera3D.new()
	camera.fov = 42.0
	stage_root.add_child(camera)
	camera.position = Vector3(0.0, 1.05, 2.5)
	camera.look_at(Vector3(0.0, 0.85, 0.0), Vector3.UP)
	camera.current = true

func _capture_screenshot(filename: String) -> void:
	for f in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img != null:
		var target_path := CAPTURE_DIR + filename
		var err := img.save_png(target_path)
		if err == OK:
			results.captures.append(filename)
			print("AUDIT_CAPTURE_SAVED: ", filename)
		else:
			push_error("Failed to save capture: " + filename)

func _run_audit() -> void:
	print("=== STARTING COMPREHENSIVE MODEL AND ANIMATION AUDIT ===")
	_setup_stage()

	await _audit_ganyu_cleanliness()
	await _audit_ganyu_locomotion()
	await _audit_all_core_models()
	await _audit_humanoid_pose_retargeting()
	await _audit_corpse_ragdoll_system()

	print("=== AUDIT COMPLETE ===")
	var passed: bool = failures.is_empty()
	results["passed"] = passed
	results["failures"] = failures
	print("AUDIT_RESULT: passed=", passed, " failures_count=", failures.size())
	if not passed:
		for fail in failures:
			print("  FAIL: ", fail)

	var report_file := FileAccess.open("res://docs/models_and_motions_audit_report.json", FileAccess.WRITE)
	if report_file != null:
		report_file.store_string(JSON.stringify(results, "  ") + "\n")
		report_file.close()

	quit(0 if passed else 1)

func _audit_ganyu_cleanliness() -> void:
	print("\n--- 1. Auditing Ganyu Model Integrity & Cleanliness ---")
	var ganyu_packed: PackedScene = load("res://scenes/characters/ganyu.tscn")
	_expect(ganyu_packed != null, "scenes/characters/ganyu.tscn failed to load")
	if ganyu_packed == null:
		return

	var ganyu_inst: Node3D = ganyu_packed.instantiate()
	stage_root.add_child(ganyu_inst)

	var skel: Skeleton3D = ganyu_inst.find_child("GeneralSkeleton", true, false)
	_expect(skel != null, "GeneralSkeleton not found in Ganyu model")
	if skel == null:
		ganyu_inst.queue_free()
		return

	var bone_count := skel.get_bone_count()
	print("Ganyu bone count: ", bone_count)
	_expect(bone_count >= 200, "Ganyu skeleton has fewer bones than expected")

	var key_bones := [
		"Root", "Hips", "Spine", "Chest", "Neck", "Head",
		"LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand",
		"RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand",
		"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes",
		"RightUpperLeg", "RightLowerLeg", "RightFoot", "RightToes"
	]

	var all_finite := true
	var any_rest_nan := false
	for b_name in key_bones:
		var idx := skel.find_bone(b_name)
		_expect(idx >= 0, "Missing key semantic bone: " + b_name)
		if idx >= 0:
			var rest := skel.get_bone_rest(idx)
			var g_rest := skel.get_bone_global_rest(idx)
			var pose_p := skel.get_bone_pose_position(idx)
			var pose_r := skel.get_bone_pose_rotation(idx)
			var pose_s := skel.get_bone_pose_scale(idx)

			if not rest.origin.is_finite() or not g_rest.origin.is_finite():
				all_finite = false
				any_rest_nan = true
			if not pose_p.is_finite() or not pose_r.is_finite() or not pose_s.is_finite():
				all_finite = false

			# Verify that in newly instantiated clean Ganyu, local pose pos matches rest origin
			var p_diff := pose_p.distance_to(rest.origin)
			_expect(p_diff < 0.0001, "Bone " + b_name + " has non-zero editor offset: " + str(p_diff))

	_expect(all_finite, "Ganyu bones contain non-finite transforms")
	_expect(not any_rest_nan, "Ganyu rest transforms contain NaN")

	# Rig setup check
	var rig := HUMANOID_RIG.new()
	var rig_ok: bool = rig.setup(skel)
	_expect(rig_ok, "HumanoidRig.setup failed on Ganyu skeleton")
	_expect(rig.pelvis >= 0, "HumanoidRig failed to identify Ganyu pelvis")
	_expect(rig.body_root >= 0, "HumanoidRig failed to identify Ganyu body_root")

	# Capture Ganyu Rest Pose Screenshot
	camera.position = Vector3(0.0, 1.0, 2.2)
	camera.look_at(Vector3(0.0, 0.85, 0.0), Vector3.UP)
	await _capture_screenshot("audit_ganyu_rest_pose_front.png")

	# Close up on head and upper body
	camera.position = Vector3(0.0, 1.25, 1.1)
	camera.look_at(Vector3(0.0, 1.2, 0.0), Vector3.UP)
	await _capture_screenshot("audit_ganyu_rest_pose_closeup.png")

	# Reset camera
	camera.position = Vector3(0.0, 1.05, 2.5)
	camera.look_at(Vector3(0.0, 0.85, 0.0), Vector3.UP)

	results["ganyu_model_clean"] = (all_finite and rig_ok and failures.is_empty())
	ganyu_inst.queue_free()
	await process_frame

func _audit_ganyu_locomotion() -> void:
	print("\n--- 2. Auditing Ganyu Locomotion Animations in World Controller ---")
	var world_ganyu_packed: PackedScene = load("res://scenes/characters/world_ganyu.tscn")
	_expect(world_ganyu_packed != null, "world_ganyu.tscn failed to load")
	if world_ganyu_packed == null:
		return

	var world_ganyu = world_ganyu_packed.instantiate()
	stage_root.add_child(world_ganyu)
	world_ganyu.set_physics_process(false)
	world_ganyu.set_process(false)
	world_ganyu.set_process_unhandled_input(false)
	world_ganyu.position = Vector3(0.0, 0.0, 0.0)
	world_ganyu.velocity = Vector3.ZERO

	var player: AnimationPlayer = world_ganyu.player
	_expect(player != null, "AnimationPlayer not found on WorldGanyu")
	var skel: Skeleton3D = world_ganyu.skeleton
	_expect(skel != null, "Skeleton3D not found on WorldGanyu")

	var motion_clips := ["idle", "walk", "run", "jump_start", "jump_air", "jump_land"]
	for m_id in motion_clips:
		_expect(player.has_animation(m_id), "WorldGanyu missing animation: " + m_id)
		if not player.has_animation(m_id):
			continue

		player.play(m_id)
		player.seek(0.0, true)

		var max_bone_dist := 0.0
		var all_bones_finite := true

		# Step through 20 frames
		for step in 20:
			player.advance(0.05)
			skel.force_update_all_bone_transforms()
			for b in skel.get_bone_count():
				var g_pose := skel.get_bone_global_pose(b)
				if not g_pose.origin.is_finite():
					all_bones_finite = false
				max_bone_dist = maxf(max_bone_dist, g_pose.origin.length())

		_expect(all_bones_finite, "Animation " + m_id + " generated non-finite bone transform")
		_expect(max_bone_dist < 4.0, "Animation " + m_id + " bone exploded to distance: " + str(max_bone_dist))
		results.ganyu_locomotion[m_id] = {
			"finite": all_bones_finite,
			"max_bone_dist": max_bone_dist
		}

	# Capture Idle, Walk, and Run in stage with proper reset and framing
	camera.position = Vector3(0.0, 0.85, 2.7)
	camera.look_at(Vector3(0.0, 0.75, 0.0), Vector3.UP)

	skel.reset_bone_poses()
	world_ganyu.position = Vector3.ZERO
	player.play("idle", 0.0)
	player.seek(0.5, true)
	player.advance(0.0)
	skel.force_update_all_bone_transforms()
	await _capture_screenshot("audit_ganyu_motion_idle.png")

	skel.reset_bone_poses()
	world_ganyu.position = Vector3.ZERO
	player.play("walk", 0.0)
	player.seek(0.4, true)
	player.advance(0.0)
	skel.force_update_all_bone_transforms()
	await _capture_screenshot("audit_ganyu_motion_walk.png")

	skel.reset_bone_poses()
	world_ganyu.position = Vector3.ZERO
	player.play("run", 0.0)
	player.seek(0.3, true)
	player.advance(0.0)
	skel.force_update_all_bone_transforms()
	await _capture_screenshot("audit_ganyu_motion_run.png")

	world_ganyu.queue_free()
	await process_frame

func _audit_all_core_models() -> void:
	print("\n--- 3. Auditing All Core Characters (Ganyu, Sparkle, Keqing, Hutao, Lumine, Stelle, Firefly) ---")
	var models_to_check := [
		{"id": "ganyu", "label": "甘雨", "path": "res://scenes/characters/ganyu.tscn"},
		{"id": "huahuo", "label": "花火", "path": "res://assets/characters/import_tests_local/huahuo/huahuo_fixed.vrm"},
		{"id": "keqing", "label": "刻晴", "path": "res://assets/characters/mmd_validation/keqing_physics.vrm"},
		{"id": "hutao", "label": "胡桃", "path": "res://assets/characters/import_tests_local/hutao/hutao_fixed.vrm"},
		{"id": "lumine", "label": "荧", "path": "res://assets/characters/roster/lumine/lumine.vrm"},
		{"id": "stelle", "label": "星", "path": "res://assets/characters/roster/stelle/stelle.vrm"},
		{"id": "firefly", "label": "流萤", "path": "res://assets/characters/roster/firefly/firefly.vrm"}
	]

	for entry in models_to_check:
		var c_id: String = entry.id
		var path: String = entry.path
		_expect(ResourceLoader.exists(path), "Model resource does not exist: " + path)
		if not ResourceLoader.exists(path):
			continue

		var scene_res = load(path)
		var instance: Node3D = scene_res.instantiate()
		stage_root.add_child(instance)

		var skel: Skeleton3D = instance.find_child("GeneralSkeleton", true, false)
		_expect(skel != null, "GeneralSkeleton not found for model: " + c_id)
		if skel == null:
			instance.queue_free()
			continue

		var rig := HUMANOID_RIG.new()
		var rig_ok: bool = rig.setup(skel)
		_expect(rig_ok, "HumanoidRig setup failed for model: " + c_id)

		var bone_count := skel.get_bone_count()
		var mesh_count := 0
		var material_count := 0
		for child in instance.find_children("*", "MeshInstance3D", true, false):
			var mesh_inst := child as MeshInstance3D
			if mesh_inst != null and mesh_inst.mesh != null:
				mesh_count += 1
				material_count += mesh_inst.mesh.get_surface_count()

		_expect(mesh_count > 0, "No meshes found for model: " + c_id)
		_expect(bone_count > 50, "Abnormally low bone count for model: " + c_id)

		results.models_audit[c_id] = {
			"label": entry.label,
			"path": path,
			"bone_count": bone_count,
			"mesh_count": mesh_count,
			"material_surfaces": material_count,
			"rig_valid": rig_ok,
			"pelvis_name": skel.get_bone_name(rig.pelvis) if rig_ok else "NONE",
			"body_root_name": skel.get_bone_name(rig.body_root) if rig_ok else "NONE"
		}
		print("Model checked: ", entry.label, " (", c_id, ") bones=", bone_count, " meshes=", mesh_count, " rig_ok=", rig_ok)

		instance.queue_free()
		await process_frame

func _audit_humanoid_pose_retargeting() -> void:
	print("\n--- 4. Auditing HumanoidRig Pose Retargeting on Ganyu, Sparkle, Keqing ---")
	var pose_files := [
		{"file": "res://assets/characters/poses/pose_M字开腿.json", "name": "pose_m_legs"},
		{"file": "res://assets/characters/poses/pose_跪趴在地上.json", "name": "pose_kneeling"},
		{"file": "res://assets/characters/poses/pose_躺地M开腿.json", "name": "pose_recline_m_legs"}
	]

	var targets := [
		{"id": "ganyu", "path": "res://scenes/characters/ganyu.tscn"},
		{"id": "huahuo", "path": "res://assets/characters/import_tests_local/huahuo/huahuo_fixed.vrm"},
		{"id": "keqing", "path": "res://assets/characters/mmd_validation/keqing_physics.vrm"}
	]

	for p_info in pose_files:
		var p_path: String = p_info.file
		var p_key: String = p_info.name
		_expect(FileAccess.file_exists(p_path), "Pose file missing: " + p_path)
		if not FileAccess.file_exists(p_path):
			continue

		var p_raw := FileAccess.get_file_as_string(p_path)
		var p_data: Dictionary = JSON.parse_string(p_raw)
		var payload := HUMANOID_RIG.pose_payload(p_data)
		_expect(not payload.is_empty(), "HUMANOID_RIG.pose_payload failed for: " + p_key)
		if payload.is_empty():
			continue

		results.poses_retargeting[p_key] = {}

		for t_info in targets:
			var t_id: String = t_info.id
			var inst: Node3D = load(t_info.path).instantiate()
			stage_root.add_child(inst)

			var skel: Skeleton3D = inst.find_child("GeneralSkeleton", true, false)
			var rig := HUMANOID_RIG.new()
			var rig_ok: bool = rig.setup(skel)
			_expect(rig_ok, "Rig setup failed on " + t_id + " for pose " + p_key)

			if rig_ok:
				var solution: Dictionary = rig.solve_pose(payload)
				_expect(solution.has("rotations") and solution.has("root_displacement"), "Invalid solve_pose solution for " + t_id)

				rig.apply_solution(solution)
				var skel_in_model: Transform3D = inst.global_transform.affine_inverse() * skel.global_transform
				inst.position = skel_in_model.basis * solution.root_displacement

				var all_finite := true
				var max_dist := 0.0
				for b in skel.get_bone_count():
					var gp := skel.get_bone_global_pose(b)
					if not gp.origin.is_finite():
						all_finite = false
					max_dist = maxf(max_dist, gp.origin.length())

				_expect(all_finite, "Pose " + p_key + " produced non-finite bone on " + t_id)
				_expect(max_dist < 4.0, "Pose " + p_key + " exploded bones on " + t_id + ": " + str(max_dist))

				results.poses_retargeting[p_key][t_id] = {
					"valid": all_finite and max_dist < 4.0,
					"max_bone_dist": max_dist,
					"root_disp": solution.root_displacement
				}

				# Dynamically center camera on the posed model using pelvis position
				var target_center: Vector3 = solution.pelvis_position
				camera.position = target_center + Vector3(0.0, 0.2, 1.8)
				camera.look_at(target_center, Vector3.UP)
				await _capture_screenshot("audit_" + t_id + "_" + p_key + ".png")

			inst.queue_free()
			await process_frame

func _audit_corpse_ragdoll_system() -> void:
	print("\n--- 5. Auditing Corpse Ragdoll Physics System with Ganyu & Sparkle ---")
	var corpse_packed: PackedScene = load("res://scenes/characters/corpse_character.tscn")
	_expect(corpse_packed != null, "corpse_character.tscn failed to load")
	if corpse_packed == null:
		return

	var corpse_inst = corpse_packed.instantiate()
	corpse_inst.auto_start_ragdoll = false
	stage_root.add_child(corpse_inst)

	# Verify Ganyu load and natural collapse
	var ganyu_load_ok: bool = corpse_inst.load_character("res://scenes/characters/ganyu.tscn", "ganyu", "甘雨")
	_expect(ganyu_load_ok, "CorpseCharacter failed to load Ganyu")
	_expect(corpse_inst.skeleton != null, "CorpseCharacter skeleton is null")
	_expect(corpse_inst.physical_bones.size() == 16, "CorpseCharacter does not have 16 physical bones")
	_expect(corpse_inst.current_state == CORPSE_CONTROLLER.State.RAGDOLL, "Corpse ragdoll failed to activate")

	for step in 120:
		await physics_frame

	var all_simulating := true
	for role in corpse_inst.physical_bones:
		var pb: PhysicalBone3D = corpse_inst.physical_bones[role]
		if not pb.is_simulating_physics() or not pb.global_position.is_finite():
			all_simulating = false

	_expect(all_simulating, "Not all physical bones are actively simulating physics")

	# Capture Ganyu Corpse Ragdoll screenshot
	var hips_pos: Vector3 = corpse_inst.physical_bones["Hips"].global_position if corpse_inst.physical_bones.has("Hips") else Vector3.ZERO
	camera.position = hips_pos + Vector3(0.0, 1.4, 1.8)
	camera.look_at(hips_pos, Vector3.UP)
	await _capture_screenshot("audit_ganyu_corpse_ragdoll.png")

	# Test switching to Huahuo model
	var switch_ok: bool = corpse_inst.load_character("res://assets/characters/import_tests_local/huahuo/huahuo_fixed.vrm", "huahuo", "花火")
	_expect(switch_ok, "CorpseCharacter failed to switch to Huahuo model")
	corpse_inst.start_ragdoll()
	if corpse_inst.physical_bones.has("Chest"):
		var huahuo_chest: PhysicalBone3D = corpse_inst.physical_bones["Chest"]
		huahuo_chest.apply_central_impulse(Vector3(-0.2, -0.6, -2.0))
	for step in 160:
		await physics_frame

	_expect(corpse_inst.physical_bones.size() == 16, "Huahuo corpse does not have 16 physical bones")
	var h_hips_pos: Vector3 = corpse_inst.physical_bones["Hips"].global_position if corpse_inst.physical_bones.has("Hips") else Vector3.ZERO
	camera.position = h_hips_pos + Vector3(0.0, 1.3, 1.8)
	camera.look_at(h_hips_pos, Vector3.UP)
	await _capture_screenshot("audit_sparkle_corpse_ragdoll.png")

	results.corpse_ragdoll = {
		"bones_count": corpse_inst.physical_bones.size(),
		"ganyu_simulating": all_simulating,
		"huahuo_switch": switch_ok
	}

	corpse_inst.queue_free()
	await process_frame
