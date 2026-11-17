@tool
extends SceneTree
## Verifies DialogueSession absolute scope isolation, ActionRegistry lifecycle contracts,
## and MotionResolver strict fallback rules.

const Registry := preload("res://scripts/npc/npc_registry.gd")
const DialogueManagerClass := preload("res://scripts/narrative/dialogue_manager.gd")
const ActionRegistryClass := preload("res://scripts/narrative/action_registry.gd")
const MotionResolverClass := preload("res://scripts/world/motion_resolver.gd")

func _init() -> void:
	_run_tests.call_deferred()

func _run_tests() -> void:
	print("==================================================")
	print("[Test] Starting Session Isolation, Action Lifecycle & MotionResolver Fallback Tests...")
	print("==================================================")

	var mgr := DialogueManagerClass.new()
	root.add_child(mgr)

	var graph_sparkle := {
		"graph_id": "sparkle_bundle",
		"character_id": "sparkle",
		"encounter_id": "temple_sparkle",
		"nodes": {
			"start": {
				"type": "text",
				"speaker": "花火",
				"text": "愚者在此！",
				"next": "choice_node"
			},
			"choice_node": {
				"type": "choice",
				"speaker": "花火",
				"text": "挑一个作弊吧",
				"choices": [
					{
						"text": "开启乐子锁精",
						"set_blackboard": {
							"meta_cheat_enabled": true,
							"encounter.sparkle_secret_token": 9999
						},
						"target": "end_node"
					}
				]
			},
			"end_node": {
				"type": "text",
				"speaker": "花火",
				"text": "作弊已生效！",
				"action": "close"
			}
		}
	}

	var graph_keqing := {
		"graph_id": "keqing_bundle",
		"character_id": "keqing",
		"encounter_id": "sandbar_keqing",
		"nodes": {
			"start": {
				"type": "text",
				"speaker": "刻晴",
				"text": "斩尽芜杂！",
				"action": "close"
			}
		}
	}

	# --- Test 1: Absolute Session Isolation ---
	print("\n--- Test 1: Session Isolation between Different Encounters ---")
	mgr.start_dialogue(graph_sparkle, "start", DialogueManagerClass.DialogueSource.WORLD_INTERACTION, DialogueManagerClass.ResumePolicy.RETURN_TO_WORLD, {
		"encounter_id": "temple_sparkle",
		"sparkle_local_var": "sparkle_only_data"
	})

	assert(mgr.has_variable("sparkle_local_var"))
	assert(mgr.get_variable("sparkle_local_var") == "sparkle_only_data")

	# Select choice modifying encounter variables
	mgr.advance_text()
	mgr.choose_option(0)
	assert(mgr.get_variable("sparkle_secret_token") == 9999)
	assert(mgr.get_variable("meta_cheat_enabled") == true)

	# Crucial: Global blackboard must NOT contain encounter-local variables!
	assert(not mgr.blackboard.has("sparkle_local_var"), "Blackboard must NOT leak encounter variables!")
	assert(not mgr.blackboard.has("sparkle_secret_token"), "Blackboard must NOT leak secret tokens!")
	print("  ✓ Encounter variables isolated from global blackboard during active session.")

	# Close Sparkle's session
	mgr.advance_text() # hits end_node action: close
	assert(not mgr.session_active, "Session must be closed.")

	# Start Keqing's session
	mgr.start_dialogue(graph_keqing, "start", DialogueManagerClass.DialogueSource.WORLD_INTERACTION, DialogueManagerClass.ResumePolicy.RETURN_TO_WORLD, {
		"encounter_id": "sandbar_keqing",
		"keqing_stamina": 120
	})

	# Verify Keqing does NOT have Sparkle's variables
	assert(mgr.has_variable("keqing_stamina"), "Keqing should have her own variable.")
	assert(not mgr.has_variable("sparkle_local_var"), "Sparkle's variable must NOT leak into Keqing's session!")
	assert(not mgr.has_variable("sparkle_secret_token"), "Sparkle's secret token must NOT leak into Keqing's session!")
	# Global blackboard meta_cheat_enabled must be false
	assert(mgr.blackboard.get("meta_cheat_enabled", false) == false, "Global blackboard cheat flag must remain false!")
	print("  ✓ Absolute zero-leakage verified between Sparkle and Keqing sessions!")

	# End Keqing's session
	mgr.advance_text()
	assert(not mgr.session_active)
	assert(not mgr.blackboard.has("keqing_stamina"), "Keqing stamina must NOT leak into blackboard.")

	# --- Test 2: Explicit World Scope Writing ---
	print("\n--- Test 2: Explicit World Scope Writing ---")
	mgr.start_dialogue(graph_keqing, "start")
	mgr.set_variable("world.global_story_flag", "island_unlocked")
	assert(mgr.get_variable("global_story_flag") == "island_unlocked")
	assert(mgr.blackboard.get("global_story_flag") == "island_unlocked", "Explicit world scope must write to blackboard.")
	mgr.advance_text() # finish
	assert(mgr.blackboard.get("global_story_flag") == "island_unlocked", "World variable persists across sessions.")
	print("  ✓ Explicit world-scoped variable correctly updates persistent blackboard.")

	# --- Test 3: ActionRegistry Independent Lifecycle & Validation ---
	print("\n--- Test 3: ActionRegistry Validation & Async Lifecycle ---")
	var async_holder := {"complete": Callable()}

	# Register custom async action
	mgr.register_action(
		"encounter.custom_cinematic_walk",
		func(exec_ctx: Dictionary):
			print("    [ActionHandler] custom_cinematic_walk is now RUNNING asynchronously...")
			async_holder["complete"] = exec_ctx["complete"],
		true,
		["destination_anchor"]
	)

	var graph_async_action := {
		"graph_id": "async_test",
		"nodes": {
			"start": {
				"type": "text",
				"speaker": "系统",
				"text": "开始走向目的地",
				"action": "encounter.custom_cinematic_walk",
				"action_params": {"destination_anchor": "Anchor_Bed"}
			}
		}
	}

	mgr.start_dialogue(graph_async_action, "start")
	assert(mgr.session_active, "Session must still be active while async action starts.")

	# Trigger action execution
	mgr.advance_text()
	assert(mgr.session_active, "Session MUST REMAIN ACTIVE while async action is running!")
	assert(mgr.current_session.is_waiting_action == true, "Session must be in is_waiting_action state.")
	print("  ✓ Dialogue session held in WAITING state during async action execution.")

	# Complete the async action
	assert(async_holder["complete"].is_valid(), "Holder must have valid callback")
	async_holder["complete"].call(ActionRegistryClass.ActionStatus.SUCCEEDED, {"moved_meters": 5.2})
	assert(not mgr.session_active, "Session must cleanly end once async action reports SUCCEEDED!")
	print("  ✓ Dialogue session cleanly concluded upon async SUCCEEDED.")

	# Test 3b: Illegal/Unknown Action Safe Interception
	var graph_bad_action := {
		"graph_id": "bad_action_test",
		"nodes": {
			"start": {
				"type": "text",
				"speaker": "系统",
				"text": "非法操作",
				"action": "unregistered.dangerous_operation"
			}
		}
	}
	var failed_action_holder := {"detected": false}
	mgr.action_failed.connect(func(act, res):
		if act == "unregistered.dangerous_operation":
			failed_action_holder["detected"] = true
	)
	mgr.start_dialogue(graph_bad_action, "start")
	mgr.advance_text()
	assert(failed_action_holder["detected"], "Illegal action must be intercepted and emit action_failed!")
	assert(not mgr.session_active, "Session must be safely closed without throwing uncaught exceptions.")
	print("  ✓ Unregistered action safely intercepted with error and safe fallback.")

	await _verify_action_ownership(mgr)

	# --- Test 4: MotionResolver fallback_to_ground: false strict enforcement ---
	print("\n--- Test 4: MotionResolver fallback_to_ground: false Enforcement ---")
	var motion_profile_strict := {
		"schema_version": 1,
		"motion_profile_id": "strict_bed_motion",
		"bindings": {
			"bed_service": {
				"interaction_type": "bed",
				"required_anchors": ["Anchor_Bed_Center", "Anchor_Front"],
				"role_a_motion": "res://assets/characters/mmd_selected/animations/mmd_87e004f6db53_a.tres",
				"role_b_motion": "res://assets/characters/mmd_selected/animations/mmd_87e004f6db53_b.tres",
				"fallback_to_ground": false # Strictly forbid fallback!
			},
			"ground_service": {
				"interaction_type": "ground",
				"required_anchors": [],
				"role_a_motion": "res://assets/characters/mmd_selected/animations/mmd_781d8c87fd79_a.tres",
				"role_b_motion": "res://assets/characters/mmd_selected/animations/mmd_781d8c87fd79_b.tres",
				"fallback_to_ground": true
			}
		}
	}

	# Empty furniture list (no bed available)
	var strict_res := MotionResolverClass.resolve_motion(motion_profile_strict, "bed_service", [])
	assert(strict_res["found"] == false, "Must NOT fall back to ground when fallback_to_ground is false!")
	assert(strict_res["reason"] == "anchor_missing_and_fallback_prohibited")
	print("  ✓ MotionResolver strictly refused fallback when fallback_to_ground: false.")

	# Now test when fallback_to_ground: true
	var motion_profile_fallback := motion_profile_strict.duplicate(true)
	motion_profile_fallback["bindings"]["bed_service"]["fallback_to_ground"] = true
	var fallback_res := MotionResolverClass.resolve_motion(motion_profile_fallback, "bed_service", [])
	assert(fallback_res["found"] == true, "Must fall back to ground when fallback_to_ground is true!")
	assert(fallback_res["type"] == "ground")
	print("  ✓ MotionResolver cleanly fell back to ground when fallback_to_ground: true.")

	print("\n[SUCCESS] All Session Isolation, Action Lifecycle & Motion Fallback Tests Passed 100%!")
	print("==================================================")
	quit(0)


func _verify_action_ownership(mgr: DialogueManagerClass) -> void:
	var keqing := Registry.assemble_encounter("sandbar_keqing")
	var sparkle := Registry.assemble_encounter("initial_temple_sparkle")
	var calls: Array[Dictionary] = []
	var cancelled: Array[int] = []
	var ended: Array[Dictionary] = []
	var failed: Array[Dictionary] = []
	mgr.dialogue_ended.connect(func(payload: Dictionary): ended.append(payload))
	mgr.action_failed.connect(func(_id: String, result: Dictionary): failed.append(result))
	mgr.register_action("test_wait", func(run: Dictionary):
		calls.append(run)
		var id: int = run.execution_id
		run.on_cancel.call(func(): cancelled.append(id)),
		true, ["destination"], func(_params: Dictionary, context: Dictionary):
			return context.character_id == "keqing",
		{"destination": TYPE_STRING, "count": TYPE_INT}, 0.10)

	_begin_wait(mgr, keqing, {"destination": "floor"})
	var first: Dictionary = calls.back()
	assert(first.session_id == mgr.current_session.session_id)
	assert(first.is_running.call())
	first.complete.call(ActionRegistryClass.ActionStatus.SUCCEEDED, {"mark": 42})
	first.complete.call(ActionRegistryClass.ActionStatus.FAILED)
	assert(ended.size() == 1 and ended[0].result.mark == 42 and failed.is_empty())
	assert(ended[0].result.execution_id == first.execution_id and not first.is_running.call())

	_begin_wait(mgr, keqing, {"destination": "floor"})
	var second: Dictionary = calls.back()
	second.complete.call(ActionRegistryClass.ActionStatus.FAILED, {"error": "failed_on_purpose"})
	assert(failed.size() == 1 and failed[0].error == "failed_on_purpose")
	assert(second.execution_id != first.execution_id and not mgr.session_active)

	_begin_wait(mgr, keqing, {"destination": "floor"})
	var third: Dictionary = calls.back()
	mgr.cancel_session()
	assert(cancelled == [third.execution_id] and not third.is_running.call() and not mgr.session_active)
	assert(ended.back().cancelled)

	_begin_wait(mgr, keqing, {"destination": "floor"})
	var stale: Dictionary = calls.back()
	assert(mgr.current_session.character_id == "keqing")
	assert(mgr.current_session.spawn_id == "sandbar_keqing")
	assert(mgr.current_session.encounter_id == "sandbar_keqing")
	var graph: Dictionary = sparkle.dialogue
	mgr.start_dialogue(graph, graph.entry_points.world_start, DialogueManagerClass.DialogueSource.WORLD_INTERACTION,
		DialogueManagerClass.ResumePolicy.RETURN_TO_WORLD, {}, {}, {}, sparkle.identity)
	var session_b = mgr.current_session
	var end_count := ended.size()
	stale.complete.call(ActionRegistryClass.ActionStatus.SUCCEEDED, {"action": "close"})
	assert(mgr.session_active and mgr.current_session == session_b and ended.size() == end_count)
	assert(cancelled == [third.execution_id, stale.execution_id])
	assert(session_b.character_id == "sparkle" and session_b.spawn_id == "initial_temple_sparkle")
	assert(session_b.encounter_id == "initial_temple_sparkle")

	var before := calls.size()
	for item in [
		[keqing, {}, "missing_required_param"],
		[keqing, {"destination": "floor", "extra": 1}, "unknown_param"],
		[keqing, {"destination": 1}, "invalid_param_type"],
		[sparkle, {"destination": "floor"}, "custom_validation_failed"],
	]:
		_begin_wait(mgr, item[0], item[1])
		assert(calls.size() == before and not mgr.session_active)
		assert(item[2] in failed.back().error)

	_begin_wait(mgr, keqing, {"destination": "floor", "count": 2.0})
	var timeout: Dictionary = calls.back()
	await create_timer(0.16).timeout
	assert(not mgr.session_active and failed.back().error == "action_timeout")
	assert(cancelled.back() == timeout.execution_id and not timeout.is_running.call())
	print("ACTION_OWNERSHIP_PASS success failure duplicate cancellation stale parameters context timeout")

func _begin_wait(mgr: DialogueManagerClass, bundle: Dictionary, params: Dictionary) -> void:
	var graph := {"nodes": {"start": {"type": "text", "text": "fixture", "action": "test_wait", "action_params": params}}}
	mgr.start_dialogue(graph, "start", DialogueManagerClass.DialogueSource.WORLD_INTERACTION,
		DialogueManagerClass.ResumePolicy.RETURN_TO_WORLD, {}, {}, {}, bundle.identity)
	mgr.advance_text()
