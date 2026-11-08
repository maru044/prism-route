extends SceneTree

const SANDBOX_SCENE := "res://scenes/test/corpse_interaction_sandbox.tscn"
const SCREENSHOT_DIR := "res://screenshots"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Capturing Corpse Sandbox Pure Natural Physics Screenshots ---")
	root.size = Vector2i(1280, 720)
	var dir := DirAccess.open("res://")
	if not dir.dir_exists("screenshots"):
		dir.make_dir("screenshots")
		
	var packed: PackedScene = load(SANDBOX_SCENE)
	var sandbox = packed.instantiate()
	root.add_child(sandbox)
	
	# Settle physics
	for i in 35:
		await physics_frame
		
	# 1. Natural Ragdoll on Ground
	await _capture("corpse_01_natural_ragdoll.png")
	
	# 2. Start Dragging Foot (Pure physical joint drag)
	sandbox.current_drag_bone = "LeftFoot"
	sandbox._unhandled_input(_make_key_event(KEY_E))
	for i in 25:
		sandbox.player.global_position += Vector3(0, 0, 0.04)
		await physics_frame
	await _capture("corpse_02_dragging_foot.png")
	
	# Drop foot
	sandbox._unhandled_input(_make_key_event(KEY_E))
	for i in 20: await physics_frame
	
	# 3. Open Character Selection Panel via [C]
	sandbox._unhandled_input(_make_key_event(KEY_C))
	for i in 10: await process_frame
	await _capture("corpse_03_character_panel.png")
	sandbox._unhandled_input(_make_key_event(KEY_C))
	for i in 10: await process_frame
	
	# 4. Quick Cycle Next Character via [Q]
	sandbox._unhandled_input(_make_key_event(KEY_Q))
	for i in 35: await physics_frame
	await _capture("corpse_04_switched_character.png")
	
	print("All pure natural physics review screenshots captured successfully!")
	quit()

func _capture(filename: String) -> void:
	for frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img != null:
		var path := ProjectSettings.globalize_path(SCREENSHOT_DIR + "/" + filename)
		img.save_png(path)
		print("Saved screenshot: ", path)

func _make_key_event(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	return ev
