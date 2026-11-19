extends SceneTree

const Runtime := preload("res://scripts/world/npc_encounter_runtime.gd")
const Combat := preload("res://scripts/combat/turn_combat_manager.gd")
const Motion := preload("res://scripts/world/motion_resolver.gd")
const NPCSites := preload("res://scripts/world/npc_preview_sites.gd")

func _initialize() -> void:
	_run.call_deferred()

func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		print("FAILED: " + message)
		quit(1)
	return condition

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)

func _run() -> void:
	print("--- Running test_ganyu_world_encounter ---")
	var world = load("res://scenes/main.tscn").instantiate()
	world.automation_enabled = true
	root.add_child(world)
	current_scene = world
	var deadline := Time.get_ticks_msec() + 120000
	while not world.test_ready:
		if not _expect(Time.get_ticks_msec() < deadline, "World initialization timed out"):
			return
		await process_frame

	# 1. Verify Ganyu and Keqing both mounted in Sandbar Pavilion (Multi-NPC coexistence)
	if not _expect(is_instance_valid(world.sandbar_ganyu_duel) and is_instance_valid(world.sandbar_ganyu_runtime),
			"Ganyu duel flow adapter was not mounted in map_1021"):
		return
	if not _expect(is_instance_valid(world.sandbar_duel) and is_instance_valid(world.sandbar_duel_runtime),
			"Keqing duel flow adapter missing; multi-NPC coexistence broken"):
		return
		
	var duel = world.sandbar_ganyu_duel
	var runtime: Runtime = world.sandbar_ganyu_runtime
	
	# 2. Verify registered Avatar, Model, Position and Heading
	if not _expect(is_instance_valid(duel.actor.character) and is_instance_valid(duel.actor.skeleton),
			"Ganyu actor character instance or skeleton invalid"):
		return
	if not _expect(duel.actor.model_resource == runtime.encounter_bundle.avatar.model_resource,
			"Ganyu model resource does not match registered avatar profile"):
		return
	if not _expect(duel.anchor.global_position.is_equal_approx(runtime.spawn_position),
			"Ganyu world anchor position does not match spawn definition"):
		return
	if not _expect(is_equal_approx(duel.anchor.global_rotation.y, deg_to_rad(runtime.spawn_heading)),
			"Ganyu world anchor heading does not match spawn definition"):
		return
	print("  ✓ Ganyu avatar and world anchor verified at: ", duel.anchor.global_position)

	# 3. Verify static capsule collision on NPC_SOLID_LAYER = 64
	if not _expect(is_instance_valid(duel.npc_body) and duel.npc_body.collision_layer == 64,
			"Ganyu NPC body collision layer must be 64 (NPC_SOLID_LAYER)"):
		return
	print("  ✓ NPC_SOLID_LAYER = 64 capsule collision verified")

	# 3b. Verify environment collision disabled to prevent Jolt zero-radius capsule spam
	if not _expect(duel.actor.environment_collision_enabled == false,
			"Ganyu actor must have environment_collision_enabled set to false"):
		return
	for spring in duel.actor.all_springs:
		if not _expect(spring.enable_environment_collision == false,
				"All Ganyu springs must have enable_environment_collision disabled"):
			return
	print("  ✓ Zero-radius Jolt physics guard verified (environment collision disabled)")

	# 4. Verify bound furniture seat_01 resolution
	var seat = world.sandbar_pavilion.furniture_instances.get("seat_01")
	if not _expect(seat != null, "seat_01 furniture instance missing in Sandbar Pavilion"):
		return
	var motion_res := runtime.resolve_bound_service_motion("seat_service", world.sandbar_pavilion.furniture_instances, duel.anchor.global_transform)
	if not _expect(motion_res.get("found", false) and motion_res.get("type") == "furniture" and motion_res.furniture == seat
			and motion_res.approach_anchor == seat.get_node("Anchor_Front")
			and motion_res.contact_anchor == seat.get_node("Anchor_Seat"),
			"Ganyu seat_service did not resolve to real seat_01 with Anchor_Seat and Anchor_Front"):
		return
	print("  ✓ Bound furniture resolution verified on seat_01")

	# 5. Verify proximity interaction prompt
	world.character.global_position = duel.anchor.global_position + Vector3(0.5, 0.0, 1.2)
	await process_frame
	await process_frame
	if not _expect(duel.prompt.visible, "Ganyu interaction prompt was not shown within range"):
		return
	if not _expect(duel.prompt.text == "【E】与甘雨交涉", "Prompt text should be '【E】与甘雨交涉', got: " + duel.prompt.text):
		return
	print("  ✓ Proximity prompt verified: ", duel.prompt.text)

	# 5b. Verify E-key priority arbitration between Keqing and Ganyu
	var k_duel = world.sandbar_duel
	var g_pos: Vector3 = duel.anchor.global_position
	var k_pos: Vector3 = k_duel.anchor.global_position
	var mid_pt: Vector3 = (g_pos + k_pos) * 0.5
	
	# Stand closer to Keqing (dist to Keqing < dist to Ganyu, both < 2.8m)
	world.character.global_position = mid_pt + (k_pos - g_pos).normalized() * 0.25
	await process_frame
	await process_frame
	if not _expect(k_duel._can_interact() and k_duel.prompt.visible,
			"Keqing prompt should be visible when player is closer to Keqing"):
		return
	if not _expect(not duel._can_interact() and not duel.prompt.visible,
			"Ganyu prompt must be suppressed when player is closer to Keqing"):
		return
	_key(KEY_E)
	await process_frame
	if not _expect(k_duel.runtime.dialogue_manager.session_active and not runtime.dialogue_manager.session_active,
			"Pressing E near Keqing must open Keqing dialogue, not Ganyu"):
		return
	k_duel.runtime.dialogue_manager.cancel_session()
	await process_frame
	
	# Stand closer to Ganyu (dist to Ganyu < dist to Keqing, both < 2.8m)
	world.character.global_position = mid_pt + (g_pos - k_pos).normalized() * 0.25
	await process_frame
	await process_frame
	if not _expect(duel._can_interact() and duel.prompt.visible,
			"Ganyu prompt should be visible when player is closer to Ganyu"):
		return
	if not _expect(not k_duel._can_interact() and not k_duel.prompt.visible,
			"Keqing prompt must be suppressed when player is closer to Ganyu"):
		return
	_key(KEY_E)
	await process_frame
	if not _expect(runtime.dialogue_manager.session_active and not k_duel.runtime.dialogue_manager.session_active,
			"Pressing E near Ganyu must open Ganyu dialogue, not Keqing"):
		return
	runtime.dialogue_manager.cancel_session()
	await process_frame
	print("  ✓ E-key priority arbitration verified (closer NPC wins prompt and input)")

	# 6. Verify Dialogue Interaction
	_key(KEY_E)
	await process_frame
	var dialogue := runtime.dialogue_manager
	if not _expect(duel.panel.visible and dialogue.session_active
			and dialogue.current_session.character_id == "ganyu"
			and dialogue.current_session.spawn_id == "sandbar_ganyu"
			and dialogue.current_session.encounter_id == "sandbar_ganyu",
			"Ganyu world dialogue session failed to initialize"):
		return
	dialogue.cancel_session()
	await process_frame
	print("  ✓ Dialogue session start and cancellation verified")

	# 7. Verify Furniture Service Staging & Restore
	duel.begin_furniture_service_staging("seat_service")
	if not _expect(duel.is_service_active, "Furniture service staging failed to activate"):
		return
	if not _expect(is_instance_valid(duel.npc_paired_actor) and is_instance_valid(duel.master_paired_actor),
		"Paired actors not spawned for furniture service"):
		return
	if not _expect(duel.npc_paired_actor.name == "GanyuPairedActor",
		"Paired actor name should be GanyuPairedActor, got: " + duel.npc_paired_actor.name):
		return

	var rig_ganyu: Skeleton3D = duel.npc_paired_actor.skeleton
	var left_knee_id: int = duel.npc_paired_actor.semantic_bones.get("LeftLowerLeg", -1)
	var right_knee_id: int = duel.npc_paired_actor.semantic_bones.get("RightLowerLeg", -1)

	if not _expect(left_knee_id >= 0 and right_knee_id >= 0, "LowerLeg bones not mapped for Ganyu"):
		return

	var floor_y: float = seat.global_position.y
	var seat_anchor: Node3D = seat.get_node("Anchor_Seat")
	var seat_front := seat_anchor.global_basis.z.normalized()

	for fraction in [0.0, 0.25, 0.5, 0.75, 0.999]:
		duel.npc_paired_actor.sample_time(duel.npc_paired_actor.duration * fraction)
		duel.master_paired_actor.sample_time(duel.master_paired_actor.duration * fraction)
		rig_ganyu.force_update_all_bone_transforms()

		var left_knee := rig_ganyu.global_transform * rig_ganyu.get_bone_global_pose(left_knee_id).origin
		var right_knee := rig_ganyu.global_transform * rig_ganyu.get_bone_global_pose(right_knee_id).origin
		var hips := rig_ganyu.global_transform * rig_ganyu.get_bone_global_pose(duel.npc_paired_actor.semantic_bones.Hips).origin
		var knees := (left_knee + right_knee) * 0.5
		if not _expect((hips - seat_anchor.global_position).dot(seat_front) > 0.2
				and (knees - hips).dot(seat_front) < 0.0,
				"Ganyu must be in front of the chair and face the seated player"):
			return
		var l_knee_y := left_knee.y
		var r_knee_y := right_knee.y

		# Ganyu's knees must be grounded near floor (floor_y=0.10, knee bone joint center within 0.12 - 0.22)
		if not _expect(l_knee_y >= floor_y and l_knee_y <= floor_y + 0.15,
				"Ganyu left knee floating or clipping: Y=%.3f, floor=%.3f" % [l_knee_y, floor_y]):
			return
		if not _expect(r_knee_y >= floor_y and r_knee_y <= floor_y + 0.15,
				"Ganyu right knee floating or clipping: Y=%.3f, floor=%.3f" % [r_knee_y, floor_y]):
			return

		if not _check_seated_mesh(duel.master_paired_actor, seat_anchor, floor_y, fraction):
			return
	print("  ✓ Contact verified across 5 frames: Ganyu's knee height and Lumine's skinned feet/seat clearance")

	duel.finish_furniture_service()
	if not _expect(not duel.is_service_active and duel.actor.visible,
		"Furniture service finish failed to restore actor"):
		return
	print("  ✓ Furniture service staging and finish verified")

	# 8. Verify Physical Ragdoll Corpse & 30m Respawn
	duel._execute_settlement_kill()
	if not _expect(duel.is_ragdoll_active and duel.corpse_actor.visible,
		"Corpse ragdoll failed to activate on settlement kill"):
		return
	if not _expect(duel.corpse_actor.name == "GanyuCorpse",
		"Corpse actor name should be GanyuCorpse, got: " + duel.corpse_actor.name):
		return
	duel._respawn_npc_after_kill()
	if not _expect(not duel.is_ragdoll_active and duel.actor.visible and not duel.corpse_actor.visible,
		"NPC respawn after kill failed to restore active actor"):
		return
	print("  ✓ Physical ragdoll corpse and 30m respawn verified")

	print("\nALL GANYU WORLD ENCOUNTER TESTS PASSED!")
	quit(0)

func _check_seated_mesh(actor: Node3D, seat_anchor: Node3D, floor_y: float, fraction: float) -> bool:
	var contact_gap := INF
	var feet := Vector2(INF, INF)
	var seat_y := seat_anchor.global_position.y
	var space := actor.get_world_3d().direct_space_state
	var skeleton: Skeleton3D = actor.skeleton
	var seat_bones := [actor.semantic_bones.Hips, actor.semantic_bones.LeftUpperLeg, actor.semantic_bones.RightUpperLeg]
	var foot_bones := [actor.semantic_bones.LeftFoot, actor.semantic_bones.RightFoot]
	for node in actor.character.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.skin == null:
			continue
		# Skin on the CPU because headless rendering doesn't register GPU skin poses.
		var skin_matrices: Array[Transform3D] = []
		var skin_bones: Array[int] = []
		for i in mesh_instance.skin.get_bind_count():
			var bone := mesh_instance.skin.get_bind_bone(i)
			var bone_name := mesh_instance.skin.get_bind_name(i)
			if not bone_name.is_empty():
				bone = skeleton.find_bone(bone_name)
			skin_bones.append(bone)
			skin_matrices.append(skeleton.get_bone_global_pose(bone) * mesh_instance.skin.get_bind_pose(i)
				if bone >= 0 else Transform3D.IDENTITY)
		for surface in mesh_instance.mesh.get_surface_count():
			var arrays := mesh_instance.mesh.surface_get_arrays(surface)
			if not arrays[Mesh.ARRAY_BONES] or not arrays[Mesh.ARRAY_WEIGHTS]:
				continue
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var count := bones.size() / vertices.size()
			for i in vertices.size():
				var skinned := Vector3.ZERO
				var dominant_bone := -1
				var dominant_weight := 0.0
				for j in count:
					var index := i * count + j
					var weight := weights[index]
					if weight <= 0.0:
						continue
					var bind := bones[index]
					skinned += (skin_matrices[bind] * vertices[i]) * weight
					if weight > dominant_weight:
						dominant_weight = weight
						dominant_bone = skin_bones[bind]
				while dominant_bone >= 0 and dominant_bone not in seat_bones and dominant_bone not in foot_bones:
					dominant_bone = skeleton.get_bone_parent(dominant_bone)
				if dominant_bone < 0:
					continue
				var p := skeleton.global_transform * skinned
				if dominant_bone in foot_bones:
					var foot := foot_bones.find(dominant_bone)
					feet[foot] = minf(feet[foot], p.y)
					continue
				var local := seat_anchor.to_local(p)
				if absf(local.x) > 0.45 or absf(local.z) > 0.225 or local.y > 0.03:
					continue
				var top := Vector3(p.x, seat_y + 0.04, p.z)
				var ray := PhysicsRayQueryParameters3D.create(top, top - Vector3.UP * 0.075, 32)
				var hit := space.intersect_ray(ray)
				if not hit.is_empty() and absf(hit.position.y - seat_y) < 0.01:
					contact_gap = minf(contact_gap, p.y - hit.position.y)
	return _expect(absf(feet.x - floor_y) < 0.010 and absf(feet.y - floor_y) < 0.010
		and contact_gap >= -0.008 and contact_gap < 0.02,
		"Lumine contact at %.2f: feet=%s floor=%.3f, seat gap=%.3f" % [fraction, feet, floor_y, contact_gap])
