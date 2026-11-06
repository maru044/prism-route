extends SceneTree

const VALIDATION_SCENE := "res://scenes/character_mmd_vrm_validation.tscn"
const BED_GLB := "res://assets/furniture/prism/prism_geo_bed.glb"
const OUT_DIR := "C:/Users/PC/.gemini/antigravity/brain/51c58479-72e8-436c-a199-d13ab3cac199/bed_edge_loop05_test/"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1600, 900)
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	
	print("Testing Loop 05 at bed edge...")
	var scene_res := load(VALIDATION_SCENE)
	var scene: Node = scene_res.instantiate()
	root.add_child(scene)
	
	for i in 25:
		await process_frame
	await RenderingServer.frame_post_draw
	
	while scene.loading:
		await process_frame
		
	var bed_res = load(BED_GLB)
	var entries: Array = scene.catalog.get("entries", [])
	
	var target_entry_id := ""
	for e in entries:
		if e.get("pack", "") == "mmd_aec34d147925":
			target_entry_id = e.get("id", "")
			break
			
	scene.select_entry(target_entry_id)
	while scene.loading:
		await process_frame
	for f in 15:
		await process_frame
	await RenderingServer.frame_post_draw
	
	scene.playing = false
	scene.furniture_visible = true
	scene.auto_furn_match = false
	
	for c in scene.furniture_root.get_children():
		c.queue_free()
	var bed_inst: Node3D = bed_res.instantiate()
	scene.furniture_root.add_child(bed_inst)
	scene.furniture_instance = bed_inst
	bed_inst.visible = true
	
	# Bed position at bed edge:
	# Front foot rim of bed is at Z = +1.33m.
	# With offset Z = -1.28, the bed edge is at Z = +0.05m.
	scene._set_furniture_sliders(Vector3(0.0, 0.0, -1.28), 0.0)
	scene.seek_frame(45) # frame 45 is the active stroke posture
	
	# Shot 1: Oblique view
	scene.yaw = 0.65
	scene.pitch = 0.25
	scene.distance = 3.4
	scene.camera_target = Vector3(0.0, 0.45, 0.1)
	scene._update_camera()
	for f in 15:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT_DIR + "loop05_bed_edge_oblique.png")
	print("Saved loop05_bed_edge_oblique.png")
	
	# Shot 2: Side view showing Role B standing on floor and Role A on mattress
	scene.yaw = PI * 0.5
	scene.pitch = 0.12
	scene.distance = 3.2
	scene.camera_target = Vector3(0.0, 0.45, 0.0)
	scene._update_camera()
	for f in 15:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT_DIR + "loop05_bed_edge_side.png")
	print("Saved loop05_bed_edge_side.png")
	
	# Shot 3: Front view
	scene.yaw = 0.0
	scene.pitch = 0.20
	scene.distance = 3.2
	scene.camera_target = Vector3(0.0, 0.45, 0.1)
	scene._update_camera()
	for f in 15:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT_DIR + "loop05_bed_edge_front.png")
	print("Saved loop05_bed_edge_front.png")
	
	print("Loop 05 bed edge tests completed!")
	quit(0)
