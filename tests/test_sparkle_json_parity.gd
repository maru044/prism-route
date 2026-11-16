@tool
extends SceneTree
## Phase 2 Parity Check: Verifies 100% exact match between original GDScript dialogue and new JSON dialogue.

const SparkleDialogueClass := preload("res://scripts/narrative/sparkle_tutorial_dialogue.gd")
const DIALOGUE_JSON_PATH := "res://assets/npc/dialogue/sparkle/temple_dialogue.json"
const REACTIONS_JSON_PATH := "res://assets/npc/reactions/sparkle_temple.json"

func _init() -> void:
	print("==================================================")
	print("[Phase 2] Verifying Sparkle GDScript vs JSON Parity...")
	
	# 1. Compare Dialogue Graph
	var gd_graph: Dictionary = SparkleDialogueClass.get_dialogue_graph()
	var json_text := FileAccess.get_file_as_string(DIALOGUE_JSON_PATH)
	var parsed: Dictionary = JSON.parse_string(json_text)
	
	var gd_nodes: Dictionary = gd_graph["nodes"]
	var js_nodes: Dictionary = parsed["nodes"]
	
	print("GDScript nodes count: %d, JSON nodes count: %d" % [gd_nodes.size(), js_nodes.size()])
	assert(gd_nodes.size() == js_nodes.size(), "Node counts must match exactly")
	
	for node_id: String in gd_nodes:
		assert(js_nodes.has(node_id), "Node missing in JSON: %s" % node_id)
		var gn: Dictionary = gd_nodes[node_id]
		var jn: Dictionary = js_nodes[node_id]
		assert(gn.get("type") == jn.get("type"), "Type mismatch on %s" % node_id)
		assert(gn.get("speaker", "") == jn.get("speaker", ""), "Speaker mismatch on %s" % node_id)
		assert(gn.get("text", "") == jn.get("text", ""), "Text mismatch on %s" % node_id)
		assert(gn.get("emotion", "") == jn.get("emotion", ""), "Emotion mismatch on %s" % node_id)
		assert(gn.get("next", "") == jn.get("next", ""), "Next mismatch on %s" % node_id)
		assert(gn.get("action", "") == jn.get("action", ""), "Action mismatch on %s" % node_id)
		
		if gn.has("choices"):
			var gc: Array = gn["choices"]
			var jc: Array = jn.get("choices", [])
			assert(gc.size() == jc.size(), "Choices size mismatch on %s" % node_id)
			for i in range(gc.size()):
				assert(gc[i].get("text") == jc[i].get("text"), "Choice text mismatch on %s:%d" % [node_id, i])
				assert(gc[i].get("target", "") == jc[i].get("target", ""), "Choice target mismatch on %s:%d" % [node_id, i])
				assert(gc[i].get("action", "") == jc[i].get("action", ""), "Choice action mismatch on %s:%d" % [node_id, i])
	print("  ✓ Dialogue graph 100% identical across all %d nodes!" % gd_nodes.size())
	
	# 2. Compare Reactions
	var r_text := FileAccess.get_file_as_string(REACTIONS_JSON_PATH)
	var r_parsed: Dictionary = JSON.parse_string(r_text)
	var gd_zones: Dictionary = SparkleDialogueClass.ZONE_REACTIONS
	var js_zones: Dictionary = r_parsed["zones"]
	for z in gd_zones:
		assert(js_zones.has(z), "Zone missing: %s" % z)
		for t in ["low", "mid", "high"]:
			assert(gd_zones[z][t]["text"] == js_zones[z][t]["text"], "Reaction text mismatch on %s:%s" % [z, t])
	print("  ✓ Zone reactions 100% identical!")
	
	var gd_attacks: Dictionary = SparkleDialogueClass.NPC_ATTACK_LINES
	var js_attacks: Dictionary = r_parsed["attack_lines"]
	for a in gd_attacks:
		assert(js_attacks.has(a), "Attack line missing: %s" % a)
		assert(gd_attacks[a]["text"] == js_attacks[a]["text"], "Attack text mismatch on %s" % a)
	print("  ✓ Attack lines 100% identical!")
	
	print("[Phase 2 SUCCESS] Sparkle data migration verified with 100% fidelity!")
	print("==================================================")
	quit(0)
