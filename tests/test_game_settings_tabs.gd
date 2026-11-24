extends SceneTree

const GAME_SETTINGS := preload("res://scripts/ui/game_settings.gd")
const SAVE_PANEL := preload("res://scripts/ui/game_save_panel.gd")
const SAVE_SESSION := preload("res://scripts/progress/game_save_session.gd")

func _init() -> void:
	print("--- Running test_game_settings_tabs ---")
	test_game_settings_in_world()
	test_game_settings_title_screen()
	test_game_save_panel()
	print("--- ALL SETTINGS TESTS PASSED ---")
	quit(0)

func test_game_settings_in_world() -> void:
	var settings := GAME_SETTINGS.new()
	settings.in_world = true
	settings.show_save_menu = true
	settings.allow_developer_tools = true
	root.add_child(settings)
	settings._ready()

	assert(settings._tab_buttons.size() == 3, "Expected 3 tab buttons")
	assert(settings._tab_buttons[0].text == "游戏设置", "Tab 0 text mismatch")
	assert(settings._tab_buttons[1].text == "存档/读档", "Tab 1 text mismatch")
	assert(settings._tab_buttons[2].text == "帮助", "Tab 2 text mismatch")

	assert(settings._pages.size() == 3, "Expected 3 pages")

	# Test tab switching
	settings._select_tab(0)
	assert(settings._pages[0].visible, "Page 0 should be visible")
	assert(not settings._pages[1].visible, "Page 1 should be hidden")
	assert(not settings._pages[2].visible, "Page 2 should be hidden")

	settings._select_tab(1)
	assert(not settings._pages[0].visible, "Page 0 should be hidden")
	assert(settings._pages[1].visible, "Page 1 should be visible")
	assert(not settings._pages[2].visible, "Page 2 should be hidden")

	settings._select_tab(2)
	assert(not settings._pages[0].visible, "Page 0 should be hidden")
	assert(not settings._pages[1].visible, "Page 1 should be hidden")
	assert(settings._pages[2].visible, "Page 2 should be visible")

	# Test signals
	var flags := {"dialogue_emitted": false, "discard_emitted": false}
	settings.dialogue_requested.connect(func(): flags.dialogue_emitted = true)
	settings.open(2)
	assert(settings.visible, "Settings should be visible after open")

	# Test assistant and dialogue buttons in page 2
	var ai_row: HBoxContainer = settings._pages[2].get_child(1)
	var assistant_btn: Button = ai_row.get_child(0)
	var dialogue_btn: Button = ai_row.get_child(1)
	assert(assistant_btn.text == "游戏助手", "Assistant button mismatch")
	assert(dialogue_btn.text == "自由对话", "Dialogue button mismatch")

	dialogue_btn.pressed.emit()
	assert(flags.dialogue_emitted, "dialogue_requested signal should be emitted")
	assert(not settings.visible, "Settings should close when dialogue clicked")
	assert(not settings.visible, "Settings should close when dialogue clicked")

	# Test save/load menu in page 1
	settings.save_menu_requested.connect(func(kind: String): flags["save_menu_kind"] = kind)
	settings.open(1)
	var saves_list: VBoxContainer = settings._pages[1].get_child(2)
	var save_btn: Button = saves_list.get_child(0)
	var load_btn: Button = saves_list.get_child(1)
	var title_btn: Button = saves_list.get_child(2)
	assert(save_btn.text == "保存游戏", "Save button mismatch")
	assert(load_btn.text == "读取存档", "Load button mismatch")
	assert(title_btn.text == "返回标题页面", "Return to title button mismatch: " + title_btn.text)

	title_btn.pressed.emit()
	assert(flags.get("save_menu_kind") == "quit", "save_menu_requested('quit') should be emitted, got: " + str(flags.get("save_menu_kind")))
	assert(not settings.visible, "Settings should close when return to title clicked")

	# Verify audio sliders match consolidated 4-slider layout
	for key: String in ["master", "ambience", "voice", "music"]:
		assert(settings._sliders.has(key), "Missing audio slider: " + key)
	assert(not settings._sliders.has("actions"), "Legacy 'actions' slider should be removed")
	settings.open(0)
	var audio_prefs := settings.PREFS.audio()
	assert(audio_prefs.has("voice") and audio_prefs.has("music"), "PREFS.audio() must include voice and music")
	settings.close()

	# Verify backward compatibility for performance monitor capture
	assert(settings._show_monitor != null, "_show_monitor must exist")
	assert(settings._show_details != null, "_show_details must exist")

	settings.queue_free()

func test_game_settings_title_screen() -> void:
	var settings := GAME_SETTINGS.new()
	settings.in_world = false
	settings.show_save_menu = false
	root.add_child(settings)
	settings._ready()

	assert(settings._tab_buttons.size() == 3, "Expected 3 tab buttons")
	assert(not settings._tab_buttons[1].visible, "Tab 1 (Saves) should be hidden on title screen")
	assert(settings._tab_buttons[0].visible, "Tab 0 should be visible")
	assert(settings._tab_buttons[2].visible, "Tab 2 should be visible")

	settings.queue_free()

func test_game_save_panel() -> void:
	var panel := SAVE_PANEL.new()
	root.add_child(panel)
	panel._ready()

	panel.open("quit")
	var heading: Label = panel._content.get_child(0)
	assert(heading.text == "返回标题页面", "Heading should be '返回标题页面', got: " + heading.text)
	var prompt: Label = panel._content.get_child(1)
	assert(prompt.text == "返回标题前要保存当前进度和对话吗？", "Prompt mismatch: " + prompt.text)

	var choices: HBoxContainer = panel._content.get_child(2)
	var save_ret_btn: Button = choices.get_child(0)
	var discard_ret_btn: Button = choices.get_child(1)
	assert(save_ret_btn.text == "保存并返回", "Save and return button mismatch: " + save_ret_btn.text)
	assert(discard_ret_btn.text == "不保存返回", "Discard and return button mismatch: " + discard_ret_btn.text)

	var flags := {"discard_emitted": false}
	panel.discard_requested.connect(func(): flags.discard_emitted = true)
	discard_ret_btn.pressed.emit()
	assert(flags.discard_emitted, "discard_requested should be emitted")

	panel.queue_free()
