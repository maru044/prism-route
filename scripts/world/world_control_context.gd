class_name WorldControlContext
extends RefCounted
## Centralized arbiter for World Control Leases and global input blocking.
## Ensures map shortcuts (e.g. Tab switch, 1-9 spawns, F, V, C) are blocked during dialogues, combat, and staging.

const GROUP_INPUT_BLOCKERS := "world_input_blockers"
const DIALOGUE_PANEL_CLASS := preload("res://scenes/narrative/dialogue_panel.gd")

static func is_world_input_blocked(tree: SceneTree) -> bool:
	if tree == null:
		return false
		
	# 1. Check if any dialogue panel is actively displaying
	if DIALOGUE_PANEL_CLASS.has_active_dialogue(tree):
		return true
		
	# 2. Check all registered input blockers (e.g. EncounterController in combat or staging)
	for node in tree.get_nodes_in_group(GROUP_INPUT_BLOCKERS):
		if node != null and is_instance_valid(node) and node.has_method("is_world_input_locked"):
			if node.is_world_input_locked():
				return true
				
	return false
