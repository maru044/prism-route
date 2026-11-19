extends SceneTree

const MAP_SCENE := preload("res://scenes/map_1021.tscn")

func _init() -> void:
	print("--- Running benchmark_npc_loading ---")
	call_deferred("_run")

func _run() -> void:
	var root_node := Node3D.new()
	root_node.name = "BenchmarkRoot"
	root.add_child(root_node)

	var map := MAP_SCENE.instantiate()
	root_node.add_child(map)

	for i in range(10):
		await process_frame

	print("Map loaded. Checking interactive NPCs count...")
	var npcs := get_nodes_in_group("world_interactive_npcs")
	print("Total interactive NPCs in group: %d" % npcs.size())

	# Measure baseline frame time over 60 frames with all NPCs active
	var start_time := Time.get_ticks_usec()
	for i in range(60):
		await process_frame
	var elapsed_all := (Time.get_ticks_usec() - start_time) / 1000.0 # ms
	var avg_frame_all := elapsed_all / 60.0
	print("ALL 47 NPCs ACTIVE: Total 60 frames: %.2f ms (Avg: %.2f ms/frame, est. FPS: %.1f)" % [elapsed_all, avg_frame_all, 1000.0 / avg_frame_all])

	# Test various player positions with actual coords
	var test_positions := {
		"Cape Town Shrine (Yae Miko)": Vector3(657.112, 1.77, -1223.655),
		"Cape Town Shopping Area (March 7th)": Vector3(676.177, 8.24, -1033.088),
		"Sandbar Pavilion (Keqing & Ganyu)": Vector3(-828.462, 0.1, -129.634),
		"Church Ruins (Barbara)": Vector3(-1326.0, 42.5, 88.0),
		"Sunken Archive (Faruzan)": Vector3(-1358.0, 11.5, 15.0),
		"Water Court (Furina)": Vector3(-904.0, 0.28, 624.0),
		"Earth Pavilion (Tingyun)": Vector3(455.29, 62.025, 269.0),
		"Oval Atrium (Fu Xuan)": Vector3(-415.0, 57.8, 875.5),
	}

	var test_radii := [25.0, 40.0, 60.0, 80.0, 100.0, 120.0, 150.0]

	print("\n--- Radius Coverage Analysis ---")
	for pos_name in test_positions:
		var pos: Vector3 = test_positions[pos_name]
		print("[%s at (%.1f, %.1f, %.1f)]:" % [pos_name, pos.x, pos.y, pos.z])
		for r in test_radii:
			var count := 0
			var names := []
			for npc in npcs:
				var anchor: Node3D = npc.get("anchor")
				if is_instance_valid(anchor):
					var d := pos.distance_to(anchor.global_position)
					if d <= r:
						count += 1
						if npc.get("runtime"):
							names.append(npc.runtime.character_id)
			print("   Radius <= %3.0fm: %2d NPCs (%s)" % [r, count, ", ".join(names)])

	# Benchmark performance at Cape Town Shrine under different distances
	var player_pos: Vector3 = test_positions["Cape Town Shrine (Yae Miko)"]
	print("\n--- Benchmark Frame Times at Cape Town Shrine ---")
	for r in [30.0, 50.0, 80.0, 100.0, 150.0]:
		var active_count := 0
		for npc in npcs:
			var anchor: Node3D = npc.get("anchor")
			var actor: Node3D = npc.get("actor")
			var should_be_active := false
			if is_instance_valid(anchor):
				should_be_active = (player_pos.distance_to(anchor.global_position) <= r)
			if should_be_active:
				active_count += 1
			if is_instance_valid(actor) and actor.has_method("set_playback_active"):
				actor.set_playback_active(should_be_active)
				actor.visible = should_be_active

		# Measure 60 frames
		start_time = Time.get_ticks_usec()
		for i in range(60):
			await process_frame
		var elapsed_r := (Time.get_ticks_usec() - start_time) / 1000.0
		var avg_frame_r := elapsed_r / 60.0
		print("Radius %3.0fm (Active NPCs: %d): Total 60 frames: %.2f ms (Avg: %.2f ms/frame, est. FPS: %.1f, Speedup: %.1f%%)" % [
			r, active_count, elapsed_r, avg_frame_r, 1000.0 / avg_frame_r, ((avg_frame_all - avg_frame_r) / avg_frame_all) * 100.0
		])

	print("\n--- BENCHMARK FINISHED ---")
	quit(0)
