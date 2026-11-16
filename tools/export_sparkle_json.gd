@tool
extends SceneTree
## Exports Sparkle's complete dialogue graph, reactions, character def and encounter def to assets/npc/.

const SparkleDialogueClass := preload("res://scripts/narrative/sparkle_tutorial_dialogue.gd")

func _init() -> void:
	print("Starting Sparkle data extraction to JSON...")
	
	DirAccess.make_dir_recursive_absolute("res://assets/npc/characters")
	DirAccess.make_dir_recursive_absolute("res://assets/npc/spawns")
	DirAccess.make_dir_recursive_absolute("res://assets/npc/encounters")
	DirAccess.make_dir_recursive_absolute("res://assets/npc/dialogue/sparkle")
	DirAccess.make_dir_recursive_absolute("res://assets/npc/reactions")
	
	# 1. Character Definition
	var char_def := {
		"schema_version": 1,
		"character_id": "sparkle",
		"display_name": "花火",
		"title": "假面愚者",
		"avatar_profile_id": "sparkle",
		"persona_id": "sparkle_persona",
		"presentation_profile_id": "sparkle_default"
	}
	_save_json("res://assets/npc/characters/sparkle.json", char_def)
	
	# 2. Spawn Definition
	var spawn_def := {
		"schema_version": 1,
		"spawn_id": "initial_temple_sparkle",
		"character_id": "sparkle",
		"region": "初始神殿与洞穴",
		"position": [-1015.285, 61.050, 1255.788],
		"heading": 0.38,
		"bound_furniture": [
			{"id": "seat_01", "type": "seat", "anchor": "Anchor_Seat"},
			{"id": "rest_01", "type": "bed", "anchor": "Anchor_Bed_Center"},
			{"id": "table_01", "type": "desk", "anchor": "Anchor_Desk_Surface"}
		]
	}
	_save_json("res://assets/npc/spawns/initial_temple_sparkle.json", spawn_def)
	
	# 3. Encounter Definition
	var enc_def := {
		"schema_version": 1,
		"encounter_id": "initial_temple_sparkle",
		"character_id": "sparkle",
		"spawn_id": "initial_temple_sparkle",
		"flow_behavior_id": "sparkle_temple_flow",
		"dialogue_bundle_id": "sparkle_temple_bundle",
		"combat_profile_id": "sparkle_tutorial_combat",
		"reaction_profile_id": "sparkle_temple_reactions",
		"motion_profile_id": "sparkle_temple_motions",
		"supported_entry_points": [
			"start",
			"respawn_dialogue",
			"post_spare_greeting",
			"post_kill_greeting",
			"mid_battle_manual",
			"mid_battle_edging",
			"victory_node",
			"service_virgin_start",
			"service_honban_start"
		]
	}
	_save_json("res://assets/npc/encounters/initial_temple_sparkle.json", enc_def)
	
	# 4. Dialogue Graph
	var graph_data: Dictionary = SparkleDialogueClass.get_dialogue_graph()
	var dialogue_json := {
		"schema_version": 1,
		"graph_id": graph_data.get("id", "sparkle_temple_tutorial"),
		"entry_points": {
			"world_start": "start",
			"defeat_retry": "respawn_dialogue",
			"post_spare": "post_spare_greeting",
			"post_kill": "post_kill_greeting",
			"combat_manual": "mid_battle_manual",
			"combat_edging": "mid_battle_edging",
			"victory_settlement": "victory_node",
			"service_virgin": "service_virgin_start",
			"service_honban": "service_honban_start"
		},
		"nodes": graph_data.get("nodes", {})
	}
	_save_json("res://assets/npc/dialogue/sparkle/temple_dialogue.json", dialogue_json)
	
	# 5. Reactions
	var reactions_json := {
		"schema_version": 1,
		"reaction_profile_id": "sparkle_temple_reactions",
		"speaker": "花火",
		"zones": SparkleDialogueClass.ZONE_REACTIONS,
		"attack_lines": SparkleDialogueClass.NPC_ATTACK_LINES
	}
	_save_json("res://assets/npc/reactions/sparkle_temple.json", reactions_json)
	
	print("Sparkle data extraction finished successfully!")
	quit(0)

func _save_json(path: String, data: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Failed to write to %s: %d" % [path, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	print("Saved: %s" % path)
