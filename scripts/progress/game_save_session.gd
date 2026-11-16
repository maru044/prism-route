extends Node

const STORE := preload("res://scripts/progress/game_save_store.gd")
const PANEL := preload("res://scripts/ui/game_save_panel.gd")
const LOADING := preload("res://scripts/ui/title_loading.gd")
const WORLD := "res://scenes/main.tscn"
const TITLE_SCREEN := "res://scenes/ui/title_screen.tscn"

var world: Node
var sections: Dictionary
var panel: PANEL
var _section_writers: Dictionary = {}
var _autosave: Timer
var _load_slot := ""
var _overwrite_slot := ""
var _paused_before := false
var _focus_before: Control
var _loading := false

func _ready() -> void:
	register_section("world", world.make_world_save)
	register_section("progress", world.game_progress.to_dict)
	register_section("construction", _construction_snapshot)
	register_section("chat", _chat_snapshot)
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	panel = PANEL.new()
	layer.add_child(panel)
	panel.selected.connect(_on_selected)
	panel.closed.connect(_unpause)
	panel.discard_requested.connect(_return_to_title)
	_autosave = Timer.new()
	_autosave.one_shot = true
	_autosave.wait_time = 1.0
	add_child(_autosave)
	_autosave.timeout.connect(_save_checkpoint)
	world.game_progress.progress_changed.connect(_queue_checkpoint)

func register_section(key: String, writer: Callable) -> void:
	_section_writers[key] = writer

func read_section(key: StringName) -> Dictionary:
	var data: Variant = sections.get(key, {})
	return data.duplicate(true) if data is Dictionary else {}

func open(kind: String) -> void:
	if _loading or not world.test_ready:
		return
	if panel.visible and kind != "quit":
		return
	if not panel.visible:
		_paused_before = get_tree().paused
		_focus_before = world.get_viewport().gui_get_focus_owner()
		get_tree().paused = true
		world.dragging = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	panel.open(kind)

func save_game(slot: String) -> Error:
	if not world.test_ready or _loading:
		return ERR_BUSY
	var snapshot := sections.duplicate()
	for key: String in _section_writers:
		var data: Variant = _section_writers[key].call()
		if not data is Dictionary:
			return ERR_INVALID_DATA
		snapshot[key] = data
	var error := STORE.write(slot, snapshot)
	if error == OK:
		sections = snapshot
		_autosave.stop()
	return error

func _construction_snapshot() -> Variant:
	if world.construction.load_error.is_empty():
		return world.construction.save_snapshot()
	# Keep previously saved construction data when the catalogue cannot load it.
	return sections.get("construction")

func _chat_snapshot() -> Dictionary:
	if is_instance_valid(world.llm_panel):
		return world.llm_panel.save_snapshot()
	return read_section("chat")

func _on_selected(slot: String) -> void:
	match panel.mode:
		"load":
			_load_slot = slot
			panel.open("confirm_load")
		"confirm_load":
			_load_game()
		"save":
			if STORE.read(slot).is_empty():
				_save_from_panel(slot)
			else:
				_overwrite_slot = slot
				panel.open("confirm_save")
		"confirm_save":
			_save_from_panel(_overwrite_slot)
		"quit", "title":
			var error := save_game(STORE.AUTO)
			if error == OK:
				_return_to_title()
			else:
				panel.report("保存失败 · " + error_string(error))

func _return_to_title() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(TITLE_SCREEN)

func _save_from_panel(slot: String) -> void:
	var error := save_game(slot)
	if error == OK:
		panel.close()
		world._show_world_notice("游戏已保存 · " + STORE.label(slot))
	else:
		panel.report("保存失败 · " + error_string(error))

func _load_game() -> void:
	var snapshot := STORE.read(_load_slot)
	if snapshot.is_empty():
		panel.report("无法读取所选存档。")
		return
	_loading = true
	var loading := LOADING.new()
	loading.name = "WorldLoadingScreen"
	loading.load_failed.connect(func():
		_loading = false
		panel.report("无法加载游戏。")
	, CONNECT_ONE_SHOT)
	get_tree().root.add_child(loading)
	loading.start(WORLD, snapshot)

func _unpause() -> void:
	get_tree().paused = _paused_before
	if is_instance_valid(_focus_before) and _focus_before.is_visible_in_tree():
		_focus_before.grab_focus()

func _queue_checkpoint(_key: String, _value: Variant) -> void:
	if world.test_ready:
		_autosave.start()

func _save_checkpoint() -> void:
	var error := save_game(STORE.AUTO)
	if error != OK:
		world._show_world_notice("自动保存失败 · " + error_string(error))
