@tool
extends SceneTree
## Automated validator for all NPC content files under assets/npc/.
## Validates JSON syntax, schema completeness, graph targets, action registrations,
## and cross-file reference integrity across Characters, Spawns, Encounters, Dialogues, Reactions, and Motions.

const CATALOG_PATH := "res://assets/characters/roster/catalog.json"
const NPC_ROOT := "res://assets/npc"
const PERSONA_DIR := "res://assets/ai/personas"
const ActionRegistryClass := preload("res://scripts/narrative/action_registry.gd")

var errors: Array[String] = []
var warnings: Array[String] = []
var catalog_ids: Dictionary = {}
var action_registry: ActionRegistryClass

var loaded_characters: Dictionary = {}
var loaded_spawns: Dictionary = {}
var loaded_encounters: Dictionary = {}
var loaded_dialogues: Dictionary = {}
var loaded_reactions: Dictionary = {}
var loaded_motions: Dictionary = {}
var loaded_personas: Dictionary = {}

func _init() -> void:
	action_registry = ActionRegistryClass.new()
	print("==================================================")
	print("[Validator] Starting Comprehensive NPC Content Validation...")

	_load_catalog()
	_validate_all()

	print("\n[Validator Report]")
	print("  Warnings: %d" % warnings.size())
	for w in warnings:
		print("    [WARN] %s" % w)

	print("  Errors:   %d" % errors.size())
	for e in errors:
		print("    [ERROR] %s" % e)

	if errors.is_empty():
		print("\n[Validator SUCCESS] All NPC content and cross-references are valid and healthy!")
		print("==================================================")
		quit(0)
	else:
		push_error("[Validator FAILED] Found %d error(s)" % errors.size())
		print("==================================================")
		quit(1)

func _load_catalog() -> void:
	catalog_ids["ganyu"] = true
	catalog_ids["keqing"] = true
	catalog_ids["hutao"] = true
	catalog_ids["sparkle"] = true
	if not FileAccess.file_exists(CATALOG_PATH):
		errors.append("Character catalog not found at: %s" % CATALOG_PATH)
		return
	var text := FileAccess.get_file_as_string(CATALOG_PATH)
	var json := JSON.new()
	if json.parse(text) != OK:
		errors.append("Failed to parse catalog.json: %s at line %d" % [json.get_error_message(), json.get_error_line()])
		return
	var data: Dictionary = json.data
	for p in data.get("profiles", []):
		catalog_ids[p.get("id", "")] = true
	print("Loaded %d profiles from catalog.json" % catalog_ids.size())

func _validate_all() -> void:
	_validate_personas()
	_validate_characters()
	_validate_spawns()
	_validate_motions()
	_validate_reactions()
	_validate_dialogues()
	_validate_encounters()

func _validate_personas() -> void:
	if not DirAccess.dir_exists_absolute(PERSONA_DIR):
		warnings.append("Persona directory not found: %s" % PERSONA_DIR)
		return
	var da := DirAccess.open(PERSONA_DIR)
	if da == null:
		return
	for file in da.get_files():
		if not file.ends_with(".md"):
			continue
		var path := PERSONA_DIR + "/" + file
		var raw := FileAccess.get_file_as_string(path).trim_prefix("\ufeff").replace("\r\n", "\n")
		var separator := raw.find("\n---")
		if separator < 0:
			errors.append("[%s] Persona markdown missing '---' separator" % file)
			continue
		var json := JSON.new()
		if json.parse(raw.left(separator)) != OK or not (json.data is Dictionary):
			errors.append("[%s] Invalid JSON header in persona markdown" % file)
			continue
		var header: Dictionary = json.data
		if not header.has("depth") or not header.has("name"):
			errors.append("[%s] Persona header missing 'depth' or 'name'" % file)
		var body_start := separator + 4
		var content := raw.substr(body_start).strip_edges()
		if content.is_empty():
			errors.append("[%s] Persona body content is empty" % file)
		var pid := file.get_basename()
		loaded_personas[pid] = header
		loaded_personas[pid + "_persona"] = header

func _validate_characters() -> void:
	var dir := NPC_ROOT + "/characters"
	if not DirAccess.dir_exists_absolute(dir):
		warnings.append("Directory not found: %s" % dir)
		return
	var da := DirAccess.open(dir)
	if da == null:
		return
	for file in da.get_files():
		if not file.ends_with(".json"):
			continue
		var path := dir + "/" + file
		var d := _parse_json(path)
		if d.is_empty():
			continue
		var req := ["character_id", "display_name", "avatar_profile_id", "schema_version"]
		for k in req:
			if not d.has(k):
				errors.append("[%s] Missing required field '%s' in CharacterDefinition" % [file, k])
		var cid: String = d.get("character_id", "")
		var avatar_id: String = d.get("avatar_profile_id", "")
		if not avatar_id.is_empty() and not catalog_ids.has(avatar_id):
			warnings.append("[%s] avatar_profile_id '%s' not in catalog.json" % [file, avatar_id])
		var persona_id: String = d.get("persona_id", "")
		if not persona_id.is_empty() and not loaded_personas.has(persona_id) and not loaded_personas.has(cid):
			errors.append("[%s] persona_id '%s' does not exist in %s" % [file, persona_id, PERSONA_DIR])
		if not cid.is_empty():
			loaded_characters[cid] = d

func _validate_spawns() -> void:
	var dir := NPC_ROOT + "/spawns"
	if not DirAccess.dir_exists_absolute(dir):
		warnings.append("Directory not found: %s" % dir)
		return
	var da := DirAccess.open(dir)
	if da == null:
		return
	for file in da.get_files():
		if not file.ends_with(".json"):
			continue
		var path := dir + "/" + file
		var d := _parse_json(path)
		if d.is_empty():
			continue
		var req := ["spawn_id", "character_id", "region", "position", "heading", "schema_version"]
		for k in req:
			if not d.has(k):
				errors.append("[%s] Missing required field '%s' in SpawnDefinition" % [file, k])
		if d.has("position") and not (d["position"] is Array and d["position"].size() == 3):
			errors.append("[%s] 'position' must be a 3-element Array" % file)
		var cid: String = d.get("character_id", "")
		if not cid.is_empty() and not loaded_characters.has(cid):
			errors.append("[%s] Cross-reference error: character_id '%s' does not exist in characters!" % [file, cid])
		var sid: String = d.get("spawn_id", "")
		if not sid.is_empty():
			loaded_spawns[sid] = d

func _validate_motions() -> void:
	var dir := NPC_ROOT + "/motions"
	if not DirAccess.dir_exists_absolute(dir):
		warnings.append("Directory not found: %s" % dir)
		return
	var da := DirAccess.open(dir)
	if da == null:
		return
	for file in da.get_files():
		if not file.ends_with(".json"):
			continue
		var path := dir + "/" + file
		var d := _parse_json(path)
		if d.is_empty():
			continue
		var req := ["motion_profile_id", "schema_version", "bindings"]
		for k in req:
			if not d.has(k):
				errors.append("[%s] Missing required field '%s' in MotionProfile" % [file, k])
		var bindings: Dictionary = d.get("bindings", {})
		for bname: String in bindings:
			var b: Dictionary = bindings[bname]
			for bk in ["interaction_type", "required_anchors", "role_a_motion", "role_b_motion"]:
				if not b.has(bk):
					errors.append("[%s:%s] Missing motion binding field '%s'" % [file, bname, bk])
			var ra: String = b.get("role_a_motion", "")
			var rb: String = b.get("role_b_motion", "")
			if not ra.is_empty() and not FileAccess.file_exists(ra):
				errors.append("[%s:%s] Animation resource does not exist on disk: %s" % [file, bname, ra])
			if not rb.is_empty() and not FileAccess.file_exists(rb):
				errors.append("[%s:%s] Animation resource does not exist on disk: %s" % [file, bname, rb])
		var mpid: String = d.get("motion_profile_id", "")
		if not mpid.is_empty():
			loaded_motions[mpid] = d
			loaded_motions[file.get_basename()] = d

func _validate_reactions() -> void:
	var dir := NPC_ROOT + "/reactions"
	if not DirAccess.dir_exists_absolute(dir):
		warnings.append("Directory not found: %s" % dir)
		return
	var da := DirAccess.open(dir)
	if da == null:
		return
	for file in da.get_files():
		if not file.ends_with(".json"):
			continue
		var path := dir + "/" + file
		var d := _parse_json(path)
		if d.is_empty():
			continue
		if not d.has("reaction_profile_id") or not d.has("zones") or not d.has("attack_lines"):
			errors.append("[%s] Missing required fields in ReactionProfile" % file)
		var zones: Dictionary = d.get("zones", {})
		for zname: String in zones:
			var ztiers: Dictionary = zones[zname]
			for tier in ["low", "mid", "high"]:
				if not ztiers.has(tier):
					errors.append("[%s:zone:%s] Missing tier '%s'" % [file, zname, tier])
				elif not ztiers[tier].has("text") or ztiers[tier]["text"].is_empty():
					errors.append("[%s:zone:%s:%s] Empty or missing text" % [file, zname, tier])
		var rpid: String = d.get("reaction_profile_id", "")
		if not rpid.is_empty():
			loaded_reactions[rpid] = d
			loaded_reactions[file.get_basename()] = d

func _validate_dialogues() -> void:
	var root_dir := NPC_ROOT + "/dialogue"
	if not DirAccess.dir_exists_absolute(root_dir):
		warnings.append("Directory not found: %s" % root_dir)
		return
	_scan_dialogues_recursive(root_dir)

func _scan_dialogues_recursive(path: String) -> void:
	var da := DirAccess.open(path)
	if da == null:
		return
	for file in da.get_files():
		if file.ends_with(".json"):
			_validate_single_dialogue(path + "/" + file)
	for sub in da.get_directories():
		_scan_dialogues_recursive(path + "/" + sub)

func _validate_single_dialogue(file_path: String) -> void:
	var d := _parse_json(file_path)
	if d.is_empty():
		return
	var fname := file_path.get_file()
	if not d.has("graph_id") or not d.has("nodes"):
		errors.append("[%s] Dialogue file missing graph_id or nodes" % fname)
		return
	var graph_id: String = d.get("graph_id", "")
	var nodes: Dictionary = d.get("nodes", {})
	if nodes.is_empty():
		errors.append("[%s] Dialogue graph has 0 nodes" % fname)
		return

	loaded_dialogues[graph_id] = d
	loaded_dialogues[fname.get_basename()] = d

	for node_id: String in nodes:
		var node: Dictionary = nodes[node_id]
		var ntype: String = node.get("type", "")
		if ntype != "text" and ntype != "choice" and ntype != "command":
			errors.append("[%s:%s] Unknown node type '%s'" % [fname, node_id, ntype])

		if node.has("next"):
			var next_id: String = node.get("next", "")
			if not nodes.has(next_id):
				errors.append("[%s:%s] Target next node does not exist: '%s'" % [fname, node_id, next_id])

		if node.has("action"):
			var act: String = node.get("action", "")
			if not action_registry.has_action(act):
				errors.append("[%s:%s] Unregistered action '%s'" % [fname, node_id, act])

		if ntype == "choice":
			var choices: Array = node.get("choices", [])
			if choices.is_empty() and not node.has("choice_provider_id"):
				warnings.append("[%s:%s] Choice node has empty choices and no choice_provider_id" % [fname, node_id])
			for i in range(choices.size()):
				var c: Dictionary = choices[i]
				if not c.has("text"):
					errors.append("[%s:%s:choice_%d] Choice missing 'text'" % [fname, node_id, i])
				if c.has("target"):
					var target_id: String = c.get("target", "")
					if not nodes.has(target_id):
						errors.append("[%s:%s:choice_%d] Target node does not exist: '%s'" % [fname, node_id, i, target_id])
				if c.has("action"):
					var act: String = c.get("action", "")
					if not action_registry.has_action(act):
						errors.append("[%s:%s:choice_%d] Unregistered action '%s'" % [fname, node_id, i, act])

func _validate_encounters() -> void:
	var dir := NPC_ROOT + "/encounters"
	if not DirAccess.dir_exists_absolute(dir):
		return
	var da := DirAccess.open(dir)
	if da == null:
		return
	for file in da.get_files():
		if not file.ends_with(".json"):
			continue
		var path := dir + "/" + file
		var d := _parse_json(path)
		if d.is_empty():
			continue
		var req := ["encounter_id", "character_id", "spawn_id", "dialogue_bundle_id", "supported_entry_points", "schema_version"]
		for k in req:
			if not d.has(k):
				errors.append("[%s] Missing required field '%s' in EncounterDefinition" % [file, k])

		var enc_id: String = d.get("encounter_id", "")
		var cid: String = d.get("character_id", "")
		var sid: String = d.get("spawn_id", "")
		var bundle_id: String = d.get("dialogue_bundle_id", "")
		var rpid: String = d.get("reaction_profile_id", "")
		var mpid: String = d.get("motion_profile_id", "")

		# 1. Character Cross-Ref
		if not cid.is_empty() and not loaded_characters.has(cid):
			errors.append("[%s] Cross-reference error: character_id '%s' does not exist in characters!" % [file, cid])

		# 2. Spawn Cross-Ref
		if not sid.is_empty() and not loaded_spawns.has(sid):
			errors.append("[%s] Cross-reference error: spawn_id '%s' does not exist in spawns!" % [file, sid])

		# 3. Dialogue Bundle Cross-Ref
		if not bundle_id.is_empty():
			if not loaded_dialogues.has(bundle_id):
				errors.append("[%s] Cross-reference error: dialogue_bundle_id '%s' does not exist in dialogue graphs!" % [file, bundle_id])
			else:
				var diag: Dictionary = loaded_dialogues[bundle_id]
				var d_nodes: Dictionary = diag.get("nodes", {})
				var d_entries: Dictionary = diag.get("entry_points", {})
				for entry: String in d.get("supported_entry_points", []):
					if not d_entries.has(entry) and not d_nodes.has(entry) and not d_entries.values().has(entry):
						errors.append("[%s] Dialogue entry point missing: '%s' not found in bundle '%s'" % [file, entry, bundle_id])

		# 4. Reaction Profile Cross-Ref
		if not rpid.is_empty() and not loaded_reactions.has(rpid):
			errors.append("[%s] Cross-reference error: reaction_profile_id '%s' does not exist in reactions!" % [file, rpid])

		# 5. Motion Profile Cross-Ref
		if not mpid.is_empty() and not loaded_motions.has(mpid):
			errors.append("[%s] Cross-reference error: motion_profile_id '%s' does not exist in motions!" % [file, mpid])

		if not enc_id.is_empty():
			loaded_encounters[enc_id] = d

func _parse_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		errors.append("[%s] JSON Syntax Error: %s at line %d" % [path.get_file(), json.get_error_message(), json.get_error_line()])
		return {}
	if not (json.data is Dictionary):
		errors.append("[%s] Root of JSON must be a Dictionary object" % path.get_file())
		return {}
	return json.data
