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
	
	# Verify button labels do not contain shortcut bracket keys
	var btn_lumine: Button = wheel.hud_team_list.get_node_or_null("Slot_lumine")
	var btn_ganyu: Button = wheel.hud_team_list.get_node_or_null("Slot_ganyu")
	assert(btn_lumine != null and btn_ganyu != null, "HUD buttons missing")
	print("Slot_lumine text: '", btn_lumine.text, "'")
	print("Slot_ganyu text: '", btn_ganyu.text, "'")
	assert(not btn_lumine.text.contains("[1]"), "Lumine button should not show [1] shortcut")
	assert(not btn_ganyu.text.contains("[2]"), "Ganyu button should not show [2] shortcut")
	
	# Test KEY_2 press - should NOT switch character
	var ev_2 := InputEventKey.new()
	ev_2.keycode = KEY_2
	ev_2.physical_keycode = KEY_2
	ev_2.pressed = true
	wheel._input(ev_2)
	assert(wheel.active_character_id == "lumine", "KEY_2 must not change character")
	print("PASS: KEY_2 did not switch character")
	
	# Test KEY_1 press - should NOT switch character
	var ev_1 := InputEventKey.new()
	ev_1.keycode = KEY_1
	ev_1.physical_keycode = KEY_1
	ev_1.pressed = true
	wheel._input(ev_1)
	assert(wheel.active_character_id == "lumine", "KEY_1 must not change character")
	print("PASS: KEY_1 did not switch character")
	
	# Test KEY_TAB press - should cycle to next character (ganyu)
	var ev_tab := InputEventKey.new()
	ev_tab.keycode = KEY_TAB
	ev_tab.physical_keycode = KEY_TAB
	ev_tab.pressed = true
	wheel._input(ev_tab)
	assert(wheel.active_character_id == "ganyu", "KEY_TAB should switch character to ganyu")
	print("PASS: KEY_TAB switched character to ganyu")
	
	# Test HUD button press - clicking lumine button switches back
	btn_lumine.emit_signal("pressed")
	assert(wheel.active_character_id == "lumine", "HUD button click should switch character to lumine")
	print("PASS: HUD button click switched character to lumine")
	
	print("=== ALL CHARACTER SWITCH TESTS PASSED SUCCESSFULLY! ===")
	quit(0)
