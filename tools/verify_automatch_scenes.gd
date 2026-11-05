@tool
extends SceneTree

const VALIDATION_SCENE := "res://scenes/character_mmd_vrm_validation.tscn"

func _init() -> void:
	print("Starting end-to-end UI verification with auto-matched furniture...")
	var scene = load(VALIDATION_SCENE).instantiate()
	get_root().add_child(scene)
	await process_frame
	while not scene.initialized:
		await process_frame
		
	var out_dir := "C:/Users/PC/.gemini/antigravity/brain/51c58479-72e8-436c-a199-d13ab3cac199/verified"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var vp: Viewport = get_root().get_viewport()
	
	var test_packs := [
		{"pack_id": "mmd_781d8c87fd79", "name": "welcome_bjv2_automatch", "frame": 281},
		{"pack_id": "mmd_6e891982bb51", "name": "loop02_automatch", "frame": 80},
		{"pack_id": "mmd_beee0d2eb57b", "name": "chikan03_automatch", "frame": 212},
		{"pack_id": "mmd_0a3f6ba5f5de", "name": "armchair_paizuri_automatch", "frame": 325},
		{"pack_id": "mmd_160b1e7a411c", "name": "lap_sitting_automatch", "frame": 224},
		{"pack_id": "mmd_71dec5bd8390", "name": "loop03_automatch", "frame": 132},
		{"pack_id": "mmd_43916ffe3d35", "name": "bed_riding_automatch", "frame": 162}
	]
	
	for t in test_packs:
		print("\n--- Verifying pack: %s ---" % t.name)
		var entry_id := ""
		for candidate in scene.catalog.entries:
			if candidate.pack == t.pack_id:
				entry_id = candidate.id
				break
		assert(entry_id != "", "Entry not found")
		
		# User flow: select entry (auto match triggers naturally!)
		await scene.select_entry(entry_id)
		scene.seek_frame(t.frame)
		
		# Capture Front / Default view
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		var p_front = "%s/%s_front.png" % [out_dir, t.name]
		vp.get_texture().get_image().save_png(p_front)
		print("Saved: %s" % p_front)
		
		# Capture 3/4 Oblique view
		var orig_yaw = scene.yaw
		scene.yaw = orig_yaw + 0.45
		scene.pitch = -0.18
		scene._update_camera()
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		var p_obl = "%s/%s_oblique.png" % [out_dir, t.name]
		vp.get_texture().get_image().save_png(p_obl)
		print("Saved: %s" % p_obl)
		
	print("\nAll end-to-end verifications completed successfully!")
	quit(0)
