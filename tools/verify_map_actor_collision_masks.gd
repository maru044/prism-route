extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- VERIFYING MAP 1021 ACTOR MASKS & NPC INTEGRATION ---")
	var map_scene = load("res://scenes/map_1021.tscn")
	var map = map_scene.instantiate()
	map.automation_enabled = true
	map.vegetation_bake_only = true
	root.add_child(map)
	
	while not map.test_ready:
		await process_frame
		
	print("Character collision_mask: ", map.character.collision_mask, " (Expected: 96)")
	print("Camper collision_mask: ", map.camper.collision_mask, " (Expected: 96)")
	print("Camper ground_query_mask: ", map.camper.ground_query_mask, " (Expected: 32)")
	
	assert(map.character.collision_mask == (32 | 64), "Character collision mask must be 96")
	assert(map.camper.collision_mask == (32 | 64), "Camper collision mask must be 96")
	assert(map.camper.ground_query_mask == 32, "Camper ground query mask must be 32")
	
	var ruin = map.initial_ruin
	assert(ruin != null, "Initial ruin must exist in map")
	assert(ruin.npc_body.collision_layer == 64, "Initial ruin NPCBody collision_layer must be 64")
	assert(ruin.avatar.environment_mask == 33, "Initial ruin Avatar environment_mask must be 33")
	
	print("MAP 1021 FULL INTEGRATION CHECKS PASSED!")
	quit(0)
