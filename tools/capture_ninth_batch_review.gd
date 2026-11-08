extends SceneTree

const SANDBOX_SCENE := "res://scenes/test/corpse_interaction_sandbox.tscn"
const SCREENSHOT_DIR := "res://screenshots"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Capturing Ninth Batch (Lumine & Stelle) Close-up Review ---")
	root.size = Vector2i(1920, 1080)
	var dir := DirAccess.open("res://")
	if not dir.dir_exists("screenshots"):
		dir.make_dir("screenshots")
		
	var packed: PackedScene = load(SANDBOX_SCENE)
	var sandbox = packed.instantiate()
	root.add_child(sandbox)
	
	# Add a dedicated close-up camera focused on the corpse
	var close_cam := Camera3D.new()
	close_cam.position = Vector3(-0.7, 0.75, 1.6)
	close_cam.look_at(Vector3(-0.7, 0.5, 0.0), Vector3.UP)
	close_cam.current = true
	sandbox.add_child(close_cam)
	
	for i in 25: await physics_frame
	
	var lumine_idx := -1
	var stelle_idx := -1
	for i in sandbox.roster_profiles.size():
		var id: String = sandbox.roster_profiles[i].id
		if id == "lumine":
			lumine_idx = i
		elif id == "stelle":
			stelle_idx = i
			
	# 1. Lumine close-up
	if lumine_idx >= 0:
		sandbox._select_character(lumine_idx)
		for i in 40: await physics_frame
		await _capture("batch09_lumine_closeup.png")
		
	# 2. Stelle close-up
	if stelle_idx >= 0:
		sandbox._select_character(stelle_idx)
		for i in 40: await physics_frame
		await _capture("batch09_stelle_closeup.png")
		
	print("Close-up screenshots captured successfully!")
	quit()

func _capture(filename: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	if img != null:
		var path := ProjectSettings.globalize_path(SCREENSHOT_DIR + "/" + filename)
		img.save_png(path)
		print("Saved screenshot: ", path)
