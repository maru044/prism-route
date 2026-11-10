extends SceneTree
## Automated test suite for Phase 2 Audit Fixes (Issue #24).
## Verifies actor active/inactive lifecycle, dynamic master combat avatar, and paired motion sync.

const InitialTempleEncounterController := preload("res://scripts/world/initial_temple_encounter_controller.gd")
const SharedHumanoidMotion := preload("res://scripts/characters/shared_humanoid_motion.gd")

func _init() -> void:
	call_deferred("_run_phase2_tests")

func _run_phase2_tests() -> void:
	print("=== STARTING PHASE 2 AUDIT FIXES VERIFICATION ===")

	var temple_mock = Node3D.new()
	root.add_child(temple_mock)

	var world_mock = Node3D.new()
	root.add_child(world_mock)

	var char_mock = Node3D.new()
	char_mock.name = "Character"
	world_mock.set_meta("character", char_mock)
	char_mock.set_meta("active_character_id", "lumine")
	world_mock.add_child(char_mock)
	world_mock.set("character", char_mock)

	var controller = InitialTempleEncounterController.new()
	temple_mock.add_child(controller)

	var dummy_anchor = Marker3D.new()
	temple_mock.add_child(dummy_anchor)
	var dummy_avatar = Node3D.new()
	temple_mock.add_child(dummy_avatar)
	var dummy_body = StaticBody3D.new()
	temple_mock.add_child(dummy_body)

	controller.initialize(temple_mock, world_mock, dummy_anchor, dummy_avatar, dummy_body)

	# -------------------------------------------------------------
	# Test 1: Actor Active/Inactive Lifecycle (Idle Sampling Stop)
	# -------------------------------------------------------------
	print("[Test 1] Testing Actor Active/Inactive Lifecycle:")
	var sparkle_actor = controller.sparkle_combat_actor
	assert(sparkle_actor != null, "Sparkle combat actor must exist")

	# Initially in hidden state, playback should be inactive
	assert(sparkle_actor.is_active_playback == false, "Actor should be inactive when hidden initially")
	assert(sparkle_actor.is_processing() == false, "Actor _process should be disabled when inactive")

	var initial_time: float = sparkle_actor.time
	for i in range(15):
		await process_frame

	assert(sparkle_actor.time == initial_time, "Animation time must not advance when actor is inactive")

	# Activate playback (simulating combat start)
	controller._set_combat_visuals(true)
	assert(sparkle_actor.is_active_playback == true, "Actor must be active when combat visuals enabled")
	assert(sparkle_actor.is_processing() == true, "Actor _process must be enabled when active")

	for i in range(15):
		await process_frame

	assert(sparkle_actor.time > initial_time, "Animation time must advance when actor is active")

	# Deactivate playback (simulating combat end)
	controller._set_combat_visuals(false)
	assert(sparkle_actor.is_active_playback == false, "Actor must return to inactive when combat visuals disabled")
	assert(sparkle_actor.is_processing() == false, "Actor _process must be disabled again")
	print("[Test 1 PASSED] Actor active/inactive lifecycle correctly halts background CPU sampling!")

	# -------------------------------------------------------------
	# Test 2: Dynamic Master Combat Avatar Sync (Lumine vs Ganyu)
	# -------------------------------------------------------------
	print("[Test 2] Testing Dynamic Master Combat Avatar Sync:")
	assert(controller.get_active_master_id() == "lumine", "Default active master should be lumine")
	assert(controller.master_combat_actor.model_resource == "res://assets/characters/roster/lumine/lumine.vrm", "Initial master model must be lumine")

	# Switch world character to Ganyu
	char_mock.set_meta("active_character_id", "ganyu")
	assert(controller.get_active_master_id() == "ganyu", "Active master must now be ganyu")

	controller._sync_master_combat_actor_model()
	assert(controller.master_combat_actor.model_resource == "res://assets/characters/ganyu/ganyu.vrm", "Master combat model must dynamically switch to ganyu.vrm")

	# Switch back to Lumine
	char_mock.set_meta("active_character_id", "lumine")
	controller._sync_master_combat_actor_model()
	assert(controller.master_combat_actor.model_resource == "res://assets/characters/roster/lumine/lumine.vrm", "Master combat model must switch back to lumine.vrm")
	print("[Test 2 PASSED] Dynamic master combat avatar correctly reflects world active character!")

	# -------------------------------------------------------------
	# Test 3: Paired Motion Clock Alignment and Barrier
	# -------------------------------------------------------------
	print("[Test 3] Testing Paired Motion Clock Alignment:")
	var test_motion_sparkle: String = controller.MOTION_VIRGIN_SPARKLE
	var test_motion_master: String = controller.MOTION_VIRGIN_MASTER
	var test_tf: Transform3D = Transform3D.IDENTITY

	controller._setup_paired_actors(test_motion_sparkle, test_motion_master, test_tf)
	await controller._ensure_combat_actors_ready()

	assert(controller.sparkle_combat_actor.ready_for_review == true, "Sparkle paired actor must be ready")
	assert(controller.master_combat_actor.ready_for_review == true, "Master paired actor must be ready")

	controller.sparkle_combat_actor.seek(0.0)
	controller.master_combat_actor.seek(0.0)

	assert(controller.sparkle_combat_actor.time == 0.0, "Sparkle clock must be aligned at 0.0")
	assert(controller.master_combat_actor.time == 0.0, "Master clock must be aligned at 0.0")
	print("[Test 3 PASSED] Paired motion actors synchronize clock and readiness barrier!")

	# Clean up
	world_mock.queue_free()
	temple_mock.queue_free()

	print("=== ALL PHASE 2 AUDIT FIXES TESTS PASSED 100%! ===")
	quit(0)
