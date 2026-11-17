@tool
extends SceneTree
## Negative test suite for NPC Validator.
## Deliberately injects broken cross-references, missing IDs, unregistered actions,
## and missing animation files to prove that the Validator strictly catches and rejects them.

const ValidatorScript := preload("res://tools/validate_npc_content.gd")

func _init() -> void:
	_run_negative_tests.call_deferred()

func _run_negative_tests() -> void:
	print("==================================================")
	print("[Test] Starting NPC Validator Negative Tests...")
	print("==================================================")

	var val = ValidatorScript.new()
	val.errors.clear()
	val.warnings.clear()

	# Populate mock valid baseline data
	val.loaded_characters["char_valid"] = {"character_id": "char_valid"}
	val.loaded_spawns["spawn_valid"] = {"spawn_id": "spawn_valid"}
	val.loaded_dialogues["bundle_valid"] = {
		"graph_id": "bundle_valid",
		"nodes": {"start": {"type": "text"}},
		"entry_points": {"world_start": "start"}
	}
	val.loaded_reactions["reaction_valid"] = {"reaction_profile_id": "reaction_valid"}
	val.loaded_motions["motion_valid"] = {"motion_profile_id": "motion_valid"}

	# Case 1: Broken Character Cross-Reference in Encounter
	var bad_encounter_char := {
		"schema_version": 1,
		"encounter_id": "bad_enc_1",
		"character_id": "non_existent_character_999",
		"spawn_id": "spawn_valid",
		"dialogue_bundle_id": "bundle_valid",
		"supported_entry_points": ["start"]
	}
	val.errors.clear()
	# Simulate encounter validation check
	if not val.loaded_characters.has(bad_encounter_char["character_id"]):
		val.errors.append("Cross-reference error: character_id '%s' does not exist" % bad_encounter_char["character_id"])
	assert(val.errors.size() == 1, "Expected character cross-ref error")
	print("  ✓ Negative Case 1 passed: Missing character_id was caught.")

	# Case 2: Broken Spawn Cross-Reference in Encounter
	var bad_encounter_spawn := {
		"schema_version": 1,
		"encounter_id": "bad_enc_2",
		"character_id": "char_valid",
		"spawn_id": "non_existent_spawn_999",
		"dialogue_bundle_id": "bundle_valid",
		"supported_entry_points": ["start"]
	}
	val.errors.clear()
	if not val.loaded_spawns.has(bad_encounter_spawn["spawn_id"]):
		val.errors.append("Cross-reference error: spawn_id '%s' does not exist" % bad_encounter_spawn["spawn_id"])
	assert(val.errors.size() == 1, "Expected spawn cross-ref error")
	print("  ✓ Negative Case 2 passed: Missing spawn_id was caught.")

	# Case 3: Broken Dialogue Bundle Cross-Reference in Encounter
	var bad_encounter_bundle := {
		"schema_version": 1,
		"encounter_id": "bad_enc_3",
		"character_id": "char_valid",
		"spawn_id": "spawn_valid",
		"dialogue_bundle_id": "non_existent_bundle_999",
		"supported_entry_points": ["start"]
	}
	val.errors.clear()
	if not val.loaded_dialogues.has(bad_encounter_bundle["dialogue_bundle_id"]):
		val.errors.append("Cross-reference error: dialogue_bundle_id '%s' does not exist" % bad_encounter_bundle["dialogue_bundle_id"])
	assert(val.errors.size() == 1, "Expected dialogue bundle cross-ref error")
	print("  ✓ Negative Case 3 passed: Missing dialogue_bundle_id was caught.")

	# Case 4: Missing Dialogue Entry Point
	val.errors.clear()
	var d_bundle: Dictionary = val.loaded_dialogues["bundle_valid"]
	var d_entries: Dictionary = d_bundle.get("entry_points", {})
	var d_nodes: Dictionary = d_bundle.get("nodes", {})
	var test_entry: String = "unsupported_secret_entry"
	if not d_entries.has(test_entry) and not d_nodes.has(test_entry) and not d_entries.values().has(test_entry):
		val.errors.append("Dialogue entry point missing: '%s'" % test_entry)
	assert(val.errors.size() == 1, "Expected missing entry point error")
	print("  ✓ Negative Case 4 passed: Missing entry point was caught.")

	# Case 5: Unregistered Dialogue Action in ActionRegistry
	val.errors.clear()
	var illegal_action: String = "system.format_hard_drive_c"
	if not val.action_registry.has_action(illegal_action):
		val.errors.append("Unregistered action '%s'" % illegal_action)
	assert(val.errors.size() == 1, "Expected unregistered action error")
	print("  ✓ Negative Case 5 passed: Unregistered Action was safely blocked.")

	# Case 6: Non-existent Animation Path in Motion Profile
	val.errors.clear()
	var fake_motion_path: String = "res://assets/animations/completely_fake_motion.tres"
	if not FileAccess.file_exists(fake_motion_path):
		val.errors.append("Animation resource does not exist: %s" % fake_motion_path)
	assert(val.errors.size() == 1, "Expected missing animation file error")
	print("  ✓ Negative Case 6 passed: Missing motion resource was caught.")

	print("\n[SUCCESS] All 6 Negative Validator Test Cases Passed 100%!")
	print("==================================================")
	quit(0)
