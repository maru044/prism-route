extends RefCounted
## Validate the production NPC content or a fixture with the same layout.

const Registry := preload("res://scripts/npc/npc_registry.gd")
const Actions := preload("res://scripts/narrative/action_registry.gd")
const CONTENT := "res://assets/npc"
const COLLECTIONS := {
	"avatars": ["avatar", "avatar_profile_id"],
	"presentation": ["presentation", "presentation_profile_id"],
	"characters": ["character", "character_id"],
	"spawns": ["spawn", "spawn_id"],
	"dialogue": ["dialogue", "graph_id"],
	"reactions": ["reaction", "reaction_profile_id"],
	"motions": ["motion", "motion_profile_id"],
	"combat": ["combat", "combat_profile_id"],
	"encounters": ["encounter", "encounter_id"],
}

var errors: Array[String] = []
var records := {}
var personas := {}
var actions := Actions.new()
var resource_types := {}

func validate(content_root := CONTENT, persona_root := Registry.PERSONA_DIR) -> bool:
	errors.clear()
	records.clear()
	personas.clear()
	if not DirAccess.dir_exists_absolute(content_root):
		errors.append("NPC content directory does not exist: " + content_root)
		return false
	if not DirAccess.dir_exists_absolute(persona_root):
		errors.append("NPC persona directory does not exist: " + persona_root)
		return false
	for file in DirAccess.get_files_at(persona_root):
		if file.ends_with(".md"):
			var raw := FileAccess.get_file_as_string(persona_root.path_join(file)).trim_prefix("\ufeff").replace("\r\n", "\n")
			var separator := raw.find("\n---")
			var header = JSON.parse_string(raw.left(separator)) if separator >= 0 else null
			if not header is Dictionary or not header.has("depth") or not header.has("name") or raw.substr(separator + 4).strip_edges().is_empty():
				errors.append("Invalid persona: " + file)
			else:
				personas[file.get_basename()] = true
				personas[file.get_basename() + "_persona"] = true
	for collection: String in COLLECTIONS:
		var descriptor: Array = COLLECTIONS[collection]
		var schema := _read_object(CONTENT.path_join("schemas/%s.schema.json" % descriptor[0]))
		records[collection] = {}
		var paths := _json_files(content_root.path_join(collection), collection == "dialogue")
		if paths.is_empty():
			errors.append("No %s definitions in %s" % [collection, content_root])
		for path in paths:
			var data := _read_object(path)
			if not _check_schema(data, schema, path):
				continue
			var id: String = data[descriptor[1]]
			if id.is_empty() or records[collection].has(id):
				errors.append("%s: empty or duplicate %s '%s'" % [path, descriptor[1], id])
			else:
				records[collection][id] = data
	_check_references()
	return errors.is_empty()

func _json_files(directory: String, recursive: bool) -> Array[String]:
	var files: Array[String] = []
	if not DirAccess.dir_exists_absolute(directory):
		return files
	for file in DirAccess.get_files_at(directory):
		if file.ends_with(".json"):
			files.append(directory.path_join(file))
	if recursive:
		for child in DirAccess.get_directories_at(directory):
			files.append_array(_json_files(directory.path_join(child), true))
	return files

func _read_object(path: String) -> Dictionary:
	var parsed := JSON.new()
	if parsed.parse(FileAccess.get_file_as_string(path).trim_prefix("\ufeff")) != OK or not parsed.data is Dictionary:
		errors.append("%s:%d: invalid JSON object (%s)" % [path, parsed.get_error_line(), parsed.get_error_message()])
		return {}
	return parsed.data

# JSON Schema keywords used by the checked-in NPC schema files.
func _check_schema(value: Variant, schema: Dictionary, location: String) -> bool:
	var count := errors.size()
	var kind: String = schema.get("type", "")
	match kind:
		"object":
			if not value is Dictionary:
				return _wrong_type(location, kind)
			for key: String in schema.get("required", []):
				if not value.has(key):
					errors.append("%s: missing required field '%s'" % [location, key])
			var properties: Dictionary = schema.get("properties", {})
			var additional = schema.get("additionalProperties", true)
			for key: String in value:
				var member := location + "." + key
				if properties.has(key):
					_check_schema(value[key], properties[key], member)
				elif additional is Dictionary:
					_check_schema(value[key], additional, member)
				elif additional == false:
					errors.append(member + ": unknown field")
		"array":
			if not value is Array:
				return _wrong_type(location, kind)
			if value.size() < schema.get("minItems", 0) or value.size() > schema.get("maxItems", value.size()):
				errors.append(location + ": invalid array length")
			for i in range(value.size()):
				_check_schema(value[i], schema.get("items", {}), "%s[%d]" % [location, i])
		"string":
			if not value is String:
				return _wrong_type(location, kind)
		"number", "integer":
			if not (value is int or value is float) or not is_finite(value) or (kind == "integer" and floorf(value) != value):
				return _wrong_type(location, kind)
			if schema.has("minimum") and value < schema.minimum:
				errors.append(location + ": below minimum")
		"boolean":
			if not value is bool:
				return _wrong_type(location, kind)
	if schema.has("enum") and value not in schema["enum"]:
		errors.append(location + ": unsupported value")
	return errors.size() == count

func _wrong_type(location: String, expected: String) -> bool:
	errors.append("%s: expected %s" % [location, expected])
	return false

func _ref(source: String, row: Dictionary, field: String, collection: String) -> Dictionary:
	var id: String = row[field]
	var definition: Dictionary = records[collection].get(id, {})
	if definition.is_empty():
		errors.append("%s: %s '%s' not found in %s" % [source, field, id, collection])
	return definition

func _resource(source: String, path: String, kind: String) -> void:
	if not path.begins_with("res://") or not ResourceLoader.exists(path):
		errors.append("%s: missing %s resource '%s'" % [source, kind, path])
		return
	if not resource_types.has(path):
		var resource := ResourceLoader.load(path)
		resource_types[path] = resource.get_class() if resource != null else ""
		if resource != null and resource.get_script() != null:
			resource_types[path] = resource.get_script().resource_path
	var actual: String = resource_types[path]
	if actual != kind:
		errors.append("%s: resource '%s' must be %s (found %s)" % [source, path, kind, actual])

func _check_references() -> void:
	for id: String in records.avatars:
		_resource(id, records.avatars[id].model_resource, "PackedScene")
		_resource(id, records.avatars[id].idle_motion, "Animation")
	for id: String in records.presentation:
		_resource(id, records.presentation[id].ui_palette, "res://scenes/combat/encounter_ui_palette.gd")
	for id: String in records.characters:
		var row: Dictionary = records.characters[id]
		_ref(id, row, "avatar_profile_id", "avatars")
		_ref(id, row, "presentation_profile_id", "presentation")
		if not personas.has(row.persona_id):
			errors.append("%s: persona_id '%s' not found" % [id, row.persona_id])
	for id: String in records.spawns:
		_ref(id, records.spawns[id], "character_id", "characters")
	for id: String in records.combat:
		var strategy: String = records.combat[id].strategy_id
		if not Registry.COMBAT_STRATEGIES.has(strategy):
			errors.append("%s: unregistered strategy_id '%s'" % [id, strategy])
	for id: String in records.motions:
		var bindings: Dictionary = records.motions[id].bindings
		for key: String in bindings:
			var binding: Dictionary = bindings[key]
			var source := id + "." + key
			_resource(source, binding.role_a_motion, "Animation")
			_resource(source, binding.role_b_motion, "Animation")
			for field in ["contact_anchor", "approach_anchor"]:
				if key != "ground_service" and binding.get(field) not in binding.required_anchors:
					errors.append("%s: %s must be declared in required_anchors" % [source, field])
			if key != "ground_service" and binding.get("fallback_to_ground", false) and not bindings.has("ground_service"):
				errors.append(source + ": ground fallback has no ground_service binding")
	for id: String in records.dialogue:
		_check_graph(id, records.dialogue[id])
	for id: String in records.encounters:
		_check_encounter(id, records.encounters[id])

func _check_graph(id: String, graph: Dictionary) -> void:
	var nodes: Dictionary = graph.nodes
	if nodes.is_empty():
		errors.append(id + ": dialogue graph has no nodes")
	for entry: String in graph.entry_points:
		if not nodes.has(graph.entry_points[entry]):
			errors.append("%s: invalid dialogue entry point '%s'" % [id, entry])
	for key: String in nodes:
		var node: Dictionary = nodes[key]
		var source := id + "." + key
		if node.type == "text" and not node.has("text"):
			errors.append(source + ": missing text")
		if node.type == "command" and not node.has("action"):
			errors.append(source + ": missing action")
		if node.type == "choice" and node.get("choices", []).is_empty() and not node.has("choice_provider_id"):
			errors.append(source + ": choice has no options or provider")
		_check_transition(source, node, nodes, "next")
		for choice: Dictionary in node.get("choices", []):
			_check_transition(source, choice, nodes, "target")

func _check_transition(source: String, row: Dictionary, nodes: Dictionary, target_key: String) -> void:
	if row.has(target_key) and not nodes.has(row[target_key]):
		errors.append("%s: unknown node target '%s'" % [source, row[target_key]])
	if row.has("action"):
		var check := actions.validate_action(row.action, row.get("action_params", {}))
		if not check.valid:
			errors.append("%s: %s" % [source, check.reason])

func _check_encounter(id: String, row: Dictionary) -> void:
	_ref(id, row, "character_id", "characters")
	var spawn := _ref(id, row, "spawn_id", "spawns")
	if not spawn.is_empty() and spawn.character_id != row.character_id:
		errors.append(id + ": spawn character_id mismatch")
	var graph := _ref(id, row, "dialogue_bundle_id", "dialogue")
	var reactions := _ref(id, row, "reaction_profile_id", "reactions")
	var combat := _ref(id, row, "combat_profile_id", "combat")
	_ref(id, row, "motion_profile_id", "motions")
	if not Registry.FLOW_ADAPTERS.has(row.flow_behavior_id):
		errors.append("%s: unregistered flow_behavior_id '%s'" % [id, row.flow_behavior_id])
	else:
		_resource(id, Registry.FLOW_ADAPTERS[row.flow_behavior_id], "GDScript")
	if not combat.is_empty() and not reactions.is_empty():
		for skill: String in combat.skill_ids:
			if not reactions.attack_lines.has(skill):
				errors.append("%s: combat skill '%s' missing from reaction profile" % [id, skill])
	if not graph.is_empty():
		for entry: String in row.supported_entry_points:
			if not graph.entry_points.has(entry) and not graph.nodes.has(entry):
				errors.append("%s: missing dialogue entry point '%s'" % [id, entry])
		var required := ["world_start", "victory_settlement"]
		if row.flow_behavior_id == "standard_duel":
			required.append("defeat_settlement")
		for entry: String in required:
			if not graph.entry_points.has(entry):
				errors.append("%s: missing dialogue entry point '%s'" % [id, entry])
