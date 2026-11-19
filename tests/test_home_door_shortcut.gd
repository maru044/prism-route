@tool
extends SceneTree
## Verifies that Home Door shortcut is mapped to F (not E), avoiding conflicts with NPC dialogue.

const ConstructionWorldClass := preload("res://scripts/construction/construction_world.gd")
const GameSettingsClass := preload("res://scripts/ui/game_settings.gd")
const BasicKitClass := preload("res://scripts/construction/basic_kit.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	print("==================================================")
	print("[Test] Verifying Home Door Shortcut (F key) and Help Text")
	print("==================================================")

	# -----------------------------------------------------------------
	# Test 1: Verify Help Page in GameSettings contains F key guide
	# -----------------------------------------------------------------
	print("\n--- Test 1: GameSettings Help Page Keybinding Registration ---")
	var settings := GameSettingsClass.new()
	root.add_child(settings)
	settings.open(true)

	var found_f_row := false
	var found_e_row := false
	var page_help = settings._pages[2] # 帮助页

	var guide_labels: Array[String] = []
	for child in page_help.get_children():
		if child is VBoxContainer:
			for row in child.get_children():
				if row is HBoxContainer and row.get_child_count() >= 2:
					var key_lbl = row.get_child(0) as Label
					var desc_lbl = row.get_child(1) as Label
					if key_lbl and desc_lbl:
						guide_labels.append("%s -> %s" % [key_lbl.text, desc_lbl.text])
						if key_lbl.text == "F":
							found_f_row = true
							assert(desc_lbl.text.contains("开门"), "F key description must mention 开门")
						elif key_lbl.text == "E":
							found_e_row = true
							assert(desc_lbl.text.contains("交互") or desc_lbl.text.contains("对话"), "E key description must mention 交互/对话")

	print("  Keybindings found: ", guide_labels)
	assert(found_e_row, "E key must be documented in help")
	assert(found_f_row, "F key for door opening must be documented in help")
	print("  [Pass] GameSettings help page documents F for door opening and E for interaction/dialogue")
	settings.close()
	settings.queue_free()

	# -----------------------------------------------------------------
	# Test 2: Verify ConstructionWorld door trigger logic for F vs E
	# -----------------------------------------------------------------
	print("\n--- Test 2: ConstructionWorld Key Handling (F triggers door, E does not) ---")
	var home := ConstructionWorldClass.new()
	var mock_world := Node3D.new()

	# Create minimal mock world properties
	var world_script := GDScript.new()
	world_script.source_code = """
extends Node3D
var test_ready: bool = true
var character_mode: bool = true
var free_mode: bool = false
var review_ui_visible: bool = false
var encounter_ui_active: bool = false
var automation_enabled: bool = false
var metadata: Dictionary = {}
var character: Node3D = null
func is_world_input_allowed() -> bool:
	return true
"""
	world_script.reload()
	mock_world.set_script(world_script)

	var mock_char := Node3D.new()
	mock_char.position = Vector3(0, 0, 0)
	mock_world.add_child(mock_char)
	mock_world.set("character", mock_char)
	root.add_child(mock_world)

	home.world = mock_world
	home.kit = BasicKitClass.new()
	root.add_child(home)
	home.set_process(false)

	# Mock a plot with a door node containing a DoorHinge child
	var mock_door_node := Node3D.new()
	mock_door_node.position = Vector3(1.0, 0, 0)
	var hinge := Node3D.new()
	hinge.name = "DoorHinge"
	mock_door_node.add_child(hinge)
	home.add_child(mock_door_node)

	var door_piece := {
		"id": "door_1",
		"definition": "door",
		"open": false,
		"rotation": 0
	}
	var mock_data := RefCounted.new()
	var data_script := GDScript.new()
	data_script.source_code = """
extends RefCounted
var pieces := {}
"""
	data_script.reload()
	mock_data.set_script(data_script)
	mock_data.set("pieces", {"door_1": door_piece})

	home.plots["test_plot"] = {
		"data": mock_data,
		"nodes": {"door_1": mock_door_node},
		"root": home
	}
	home.initialized = true
	home.active = false # Exploring world as character

	# Simulate pressing E: door should NOT open (E is reserved for dialogue)
	var event_e := InputEventKey.new()
	event_e.physical_keycode = KEY_E
	event_e.pressed = true
	home._input(event_e)
	assert(door_piece.open == false, "Pressing E must NOT toggle the door")
	print("  [Pass] Pressing E does not toggle the door, preserving it for dialogue")

	# Simulate pressing F: door SHOULD open
	var event_f := InputEventKey.new()
	event_f.physical_keycode = KEY_F
	event_f.pressed = true
	home._input(event_f)
	assert(door_piece.open == true, "Pressing F MUST toggle the door to open")
	print("  [Pass] Pressing F successfully toggles the door to open")

	# Simulate pressing F again: door SHOULD close
	home._input(event_f)
	assert(door_piece.open == false, "Pressing F again MUST toggle the door to closed")
	print("  [Pass] Pressing F again successfully toggles the door to closed")

	home.queue_free()
	mock_world.queue_free()

	print("\n==================================================")
	print("[SUCCESS] Home door shortcut key change to F verified")
	print("==================================================")
	quit(0)
