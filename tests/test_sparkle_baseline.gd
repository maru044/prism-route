@tool
extends SceneTree
## Phase 0: Baseline verification of Sparkle's dialogue graph, entries, reactions and attack lines.

const SparkleDialogueClass := preload("res://scripts/narrative/sparkle_tutorial_dialogue.gd")

func _init() -> void:
	print("==================================================")
	print("[Phase 0] Verifying Sparkle baseline dialogue & reactions...")
	
	var graph: Dictionary = SparkleDialogueClass.get_dialogue_graph()
	assert(graph.has("id") and graph["id"] == "sparkle_temple_tutorial", "Graph ID should be sparkle_temple_tutorial")
	assert(graph.has("nodes"), "Graph must have nodes")
	var nodes: Dictionary = graph["nodes"]
	print("Total dialogue nodes in baseline: %d" % nodes.size())
	assert(nodes.size() >= 30, "Should have at least 30 nodes")
	
	# Verify key entry points
	var required_entries := [
		"start",
		"respawn_dialogue",
		"post_spare_greeting",
		"post_kill_greeting",
		"mid_battle_manual",
		"mid_battle_edging",
		"victory_node",
		"service_virgin_start",
		"service_honban_start",
	]
	for entry_name in required_entries:
		assert(nodes.has(entry_name), "Node missing: %s" % entry_name)
		print("  ✓ Entry point exists: %s (type=%s)" % [entry_name, nodes[entry_name].get("type")])
		
	# Verify sensitive zone reactions
	var test_zones := ["clitoris", "nipples", "mouth", "thighs", "anal"]
	for zone in test_zones:
		var low_r: Dictionary = SparkleDialogueClass.get_zone_reaction(zone, 10.0)
		var mid_r: Dictionary = SparkleDialogueClass.get_zone_reaction(zone, 50.0)
		var high_r: Dictionary = SparkleDialogueClass.get_zone_reaction(zone, 85.0)
		assert(not low_r["text"].is_empty(), "Low reaction missing for %s" % zone)
		assert(not mid_r["text"].is_empty(), "Mid reaction missing for %s" % zone)
		assert(not high_r["text"].is_empty(), "High reaction missing for %s" % zone)
	print("  ✓ Zone reactions verified for all 5 zones across 3 tiers (low, mid, high)")
	
	# Verify attack lines
	var attack_skills := ["tongue", "deep_throat", "eye_contact", "teaching_kill"]
	for skill in attack_skills:
		var line: Dictionary = SparkleDialogueClass.get_npc_attack_line(skill)
		assert(not line["text"].is_empty(), "Attack line missing for %s" % skill)
	print("  ✓ Attack lines verified for all 4 skills")
	
	print("[Phase 0 SUCCESS] Sparkle baseline verified cleanly!")
	print("==================================================")
	quit(0)
