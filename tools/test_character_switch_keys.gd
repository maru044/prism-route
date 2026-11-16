extends SceneTree

const WHEEL_SCENE := preload("res://scenes/ui/character_switch_wheel.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== RUNNING CHARACTER SWITCH KEY TEST ===")
	var root := Control.new()
	root.name = "TestRoot"
	get_root().add_child(root)
	
	var wheel = WHEEL_SCENE.instantiate()
	root.add_child(wheel)
	
	for frame in 2:
		await process_frame
	
	var initial_id: String = wheel.active_character_id
	print("Initial active character: ", initial_id)
	assert(initial_id == "lumine", "Expected initial character to be lumine")
	
	# Verify HUD buttons are removed and TeamHud is hidden
	var btn_lumine: Button = wheel.hud_team_list.get_node_or_null("Slot_lumine")
	var btn_ganyu: Button = wheel.hud_team_list.get_node_or_null("Slot_ganyu")
	assert(btn_lumine == null, "Lumine button should be removed")
	assert(btn_ganyu == null, "Ganyu button should be removed")
	assert(not wheel.get_node("TeamHud").visible, "TeamHud should be hidden")
	print("PASS: Right side switch buttons removed")
	
	# Test KEY_TAB press - should NOT switch character (remains lumine)
	var ev_tab := InputEventKey.new()
	ev_tab.keycode = KEY_TAB
	ev_tab.physical_keycode = KEY_TAB
	ev_tab.pressed = true
	wheel._input(ev_tab)
	assert(wheel.active_character_id == "lumine", "KEY_TAB should keep lumine active")
	print("PASS: KEY_TAB kept lumine active")
	
	print("=== ALL CHARACTER SWITCH TESTS PASSED SUCCESSFULLY! ===")
	quit(0)
