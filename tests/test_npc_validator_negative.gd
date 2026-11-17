extends SceneTree

const Validator := preload("res://tools/npc_content_validator.gd")

var fixture: String
var copied: Array[String] = []
var directories: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	fixture = OS.get_environment("TEMP").path_join("prism-npc-validator-%d" % OS.get_process_id())
	for collection: String in Validator.COLLECTIONS:
		_copy_collection(collection)
	var validator := Validator.new()
	if not validator.validate(fixture):
		printerr("Valid fixture failed: ", validator.errors)
		_finish(1)
		return
	var enc := "encounters/sandbar_keqing.json"
	var graph := "dialogue/keqing/sandbar_dialogue.json"
	var cases := [
		[enc, ["character_id"], "absent", "character_id 'absent'"],
		[enc, ["spawn_id"], "absent", "spawn_id 'absent'"],
		[enc, ["spawn_id"], "initial_temple_sparkle", "spawn character_id mismatch"],
		[graph, ["graph_id"], "renamed_graph", "dialogue_bundle_id 'keqing_sandbar_bundle'"],
		[graph, ["entry_points", "world_start"], "missing_node", "invalid dialogue entry point 'world_start'"],
		[graph, ["entry_points", "defeat_settlement"], null, "missing dialogue entry point 'defeat_settlement'"],
		[enc, ["reaction_profile_id"], "absent", "reaction_profile_id 'absent'"],
		[enc, ["motion_profile_id"], "keqing_combat", "motion_profile_id 'keqing_combat'"],
		[enc, ["combat_profile_id"], "absent", "combat_profile_id 'absent'"],
		[enc, ["flow_behavior_id"], "absent", "unregistered flow_behavior_id 'absent'"],
		[enc, ["supported_entry_points"], ["missing_entry"], "missing dialogue entry point 'missing_entry'"],
		[enc, ["combat_profile_id"], null, "missing required field 'combat_profile_id'"],
		[graph, ["nodes", "start", "next"], "absent", "unknown node target 'absent'"],
		[graph, ["nodes", "start", "action"], "unregistered_fixture_action", "unregistered_action"],
		[graph, ["nodes", "start", "text"], [], "text: expected string"],
		["spawns/sandbar_keqing.json", ["position", 0], "wrong", "position[0]: expected number"],
		["motions/keqing_motions.json", ["bindings", "desk_service", "role_a_motion"], "res://missing.tres", "missing Animation resource"],
		["motions/keqing_motions.json", ["bindings", "desk_service", "role_a_motion"], "res://scenes/combat/temple_paper_palette.tres", "must be Animation"],
		["combat/keqing_combat.json", ["skill_ids"], ["not_a_skill"], "missing from reaction profile"],
		["combat/keqing_combat.json", ["strategy_id"], "not_a_strategy", "unregistered strategy_id"],
		["characters/keqing.json", ["avatar_profile_id"], "absent", "avatar_profile_id 'absent'"],
		["characters/keqing.json", ["presentation_profile_id"], "absent", "presentation_profile_id 'absent'"],
		["characters/keqing.json", ["persona_id"], "absent", "persona_id 'absent'"],
	]
	for test: Array in cases:
		var path := fixture.path_join(test[0])
		var original := FileAccess.get_file_as_string(path)
		var data = JSON.parse_string(original)
		var cursor = data
		var keys: Array = test[1]
		for i in range(keys.size() - 1):
			cursor = cursor[keys[i]]
		if test[2] == null:
			cursor.erase(keys.back())
		else:
			cursor[keys.back()] = test[2]
		_write(path, JSON.stringify(data))
		var accepted := validator.validate(fixture)
		var diagnostic := "\n".join(validator.errors)
		_write(path, original)
		if accepted or test[3] not in diagnostic:
			printerr("Negative fixture did not report ", test[3], "\n", diagnostic)
			_finish(1)
			return
	print("NPC_VALIDATOR_NEGATIVE_PASS valid=1 invalid=", cases.size())
	_finish(0)

func _copy_collection(relative: String) -> void:
	var source := Validator.CONTENT.path_join(relative)
	var target := fixture.path_join(relative)
	DirAccess.make_dir_recursive_absolute(target)
	directories.append(target)
	for file in DirAccess.get_files_at(source):
		if file.ends_with(".json"):
			var output := target.path_join(file)
			_write(output, FileAccess.get_file_as_string(source.path_join(file)))
			copied.append(output)
	for dir in DirAccess.get_directories_at(source):
		_copy_collection(relative.path_join(dir))

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)

func _finish(code: int) -> void:
	for file in copied:
		DirAccess.remove_absolute(file)
	directories.reverse()
	for dir in directories:
		DirAccess.remove_absolute(dir)
	DirAccess.remove_absolute(fixture)
	quit(code)
