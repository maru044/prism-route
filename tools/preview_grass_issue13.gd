extends SceneTree
## Interactive preview at the pilot corridor; the normal F5 entry is unchanged.
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene=load("res://scenes/map_1021.tscn").instantiate();root.add_child(scene)
	while not scene.test_ready:await process_frame
	await scene.select_spawn(7)
	await scene.set_character_mode(false)
	print("GRASS_ISSUE13_PREVIEW_READY spawn=8")
