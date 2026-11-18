extends SceneTree
## Comprehensive verification for UnlockedCharactersPanel, CharacterRosterDatabase, and Settings Menu integration.

const GAME_SETTINGS := preload("res://scripts/ui/game_settings.gd")
const UNLOCKED_PANEL := preload("res://scripts/ui/unlocked_characters_panel.gd")
const ROSTER := preload("res://scripts/characters/character_roster_database.gd")
const GAME_PROGRESS := preload("res://scripts/progress/game_progress.gd")

func _init() -> void:
	print("--- Running test_unlocked_characters_panel ---")
	test_roster_database()
	test_unlocked_characters_panel_standalone()
	test_legacy_sparkle_save()
	test_settings_menu_integration()
	print("--- ALL UNLOCKED CHARACTERS TESTS PASSED ---")
	quit(0)

func test_roster_database() -> void:
	print("[Test] Verifying CharacterRosterDatabase...")
	var all_entries := ROSTER.get_all_entries()
	assert(all_entries.size() == 50, "Expected 50 character roster entries, got: %d" % all_entries.size())

	# Test specific key characters
	var keqing_entry := ROSTER.get_entry("keqing")
	assert(keqing_entry.name == "刻晴", "Keqing name mismatch")
	assert(keqing_entry.game == "原神", "Keqing game mismatch")

	var sparkle_entry := ROSTER.get_entry("sparkle")
	assert(sparkle_entry.name == "花火", "Sparkle name mismatch")
	assert(sparkle_entry.game == "崩坏：星穹铁道", "Sparkle game mismatch")

	var miku_entry := ROSTER.get_entry("miku")
	assert(miku_entry.name == "初音未来", "Miku name mismatch")

	var lumine_entry := ROSTER.get_entry("lumine")
	assert(lumine_entry.name == "荧", "Lumine name mismatch")

	# Test portrait path resolution
	var keqing_path := ROSTER.get_portrait_path("keqing")
	assert(not keqing_path.is_empty(), "Keqing portrait path must not be empty")
	assert(FileAccess.file_exists(keqing_path), "Keqing portrait file must exist on disk: " + keqing_path)

	var miku_path := ROSTER.get_portrait_path("miku")
	assert(not miku_path.is_empty(), "Miku portrait path must not be empty")
	assert(FileAccess.file_exists(miku_path), "Miku portrait file must exist on disk: " + miku_path)

	# Test persona loading
	var keqing_persona := ROSTER.load_persona_data("keqing")
	assert(keqing_persona.has_custom_persona, "Keqing should have custom persona file")
	assert("玉衡星" in keqing_persona.content, "Keqing persona content missing 玉衡星")

	var sparkle_persona := ROSTER.load_persona_data("sparkle")
	assert(sparkle_persona.has_custom_persona, "Sparkle should have custom persona file")
	assert("假面愚者" in sparkle_persona.content, "Sparkle persona content missing 假面愚者")

	var miku_persona := ROSTER.load_persona_data("miku")
	assert(miku_persona.has_custom_persona, "Miku should have custom persona file")
	assert("初音未来" in miku_persona.content, "Miku persona content missing 初音未来")

	# Test fallback persona for character without custom md
	var faruzan_persona := ROSTER.load_persona_data("faruzan")
	assert("珐露珊" in faruzan_persona.content, "Fallback persona should contain character name")
	print("  ✓ CharacterRosterDatabase verified successfully")

func test_unlocked_characters_panel_standalone() -> void:
	print("[Test] Verifying UnlockedCharactersPanel standalone...")
	var panel := UNLOCKED_PANEL.new()
	root.add_child(panel)
	panel._ready()

	# Scenario 1: Empty progress (no characters unlocked yet)
	var progress := GAME_PROGRESS.new()
	panel.open(progress)
	assert(panel.visible, "Panel should be visible after open()")
	assert(panel._char_buttons.is_empty(), "No character buttons expected when companion_unlocks is empty")
	assert(panel._portrait_rect.texture == null, "Portrait texture should be null when empty")

	# Scenario 2: Unlocking Keqing and Sparkle
	progress.unlock_companion("sparkle")
	progress.unlock_companion("keqing")
	panel.open(progress)

	assert(panel._char_buttons.size() == 2, "Expected 2 unlocked character buttons, got: %d" % panel._char_buttons.size())
	assert(panel._char_buttons.has("sparkle"), "Sparkle button missing")
	assert(panel._char_buttons.has("keqing"), "Keqing button missing")

	# Select Keqing
	panel._select_character("keqing")
	assert(panel.current_char_id == "keqing", "Current character should be keqing")
	assert(panel._name_label.text == "刻晴", "Name label should be 刻晴")
	assert("玉衡星" in panel._title_label.text, "Title label should mention 玉衡星")
	assert(panel._portrait_rect.texture != null, "Portrait texture must be loaded for Keqing")
	assert("玉衡星" in panel._persona_text.text, "Persona text should display Keqing persona")

	# Click portrait
	panel._on_portrait_clicked()
	assert(panel._feedback_label.text != "", "Feedback label should update on portrait click")

	# Select Sparkle
	panel._select_character("sparkle")
	assert(panel.current_char_id == "sparkle", "Current character should be sparkle")
	assert(panel._name_label.text == "花火", "Name label should be 花火")
	assert("假面愚者" in panel._title_label.text, "Title label should mention 假面愚者")
	assert(panel._portrait_rect.texture != null, "Portrait texture must be loaded for Sparkle")
	assert("假面愚者" in panel._persona_text.text, "Persona text should display Sparkle persona")

	# Test preview all toggle
	panel._toggle_preview_all()
	assert(panel.is_preview_all, "Preview all should be active")
	assert(panel._char_buttons.size() == 50, "Preview all should show all 50 characters, got: %d" % panel._char_buttons.size())

	# Select Miku in preview mode
	panel._select_character("miku")
	assert(panel.current_char_id == "miku", "Current character should be miku")
	assert(panel._name_label.text == "初音未来", "Name label should be 初音未来")
	assert(panel._portrait_rect.texture != null, "Portrait texture must be loaded for Miku")

	# Test close
	var flags := {"closed": false}
	panel.closed.connect(func(): flags.closed = true)
	panel.close()
	assert(not panel.visible, "Panel should be hidden after close()")
	assert(flags.closed, "Closed signal should be emitted")

	panel.queue_free()
	print("  ✓ UnlockedCharactersPanel standalone verified successfully")

func test_legacy_sparkle_save() -> void:
	var legacy := GAME_PROGRESS.new()
	legacy.from_dict({"initial_temple_defeat_count": 1, "companion_unlocks": ["keqing"]})
	assert(not legacy.is_companion_unlocked("sparkle"), "A tutorial defeat alone must not unlock Sparkle")
	legacy.from_dict({"tutorial_completed": true, "settlement_outcome": "kill", "companion_unlocks": ["keqing"]})
	assert(legacy.companion_unlocks == ["keqing", "sparkle"], "Legacy settlement must backfill Sparkle only")
	legacy.from_dict(legacy.to_dict())
	assert(legacy.companion_unlocks == ["keqing", "sparkle"], "Reload must not duplicate the backfilled ID")
	var panel := UNLOCKED_PANEL.new()
	root.add_child(panel)
	panel.open(legacy)
	var sparkle_button: Button = panel._char_buttons["sparkle"]
	sparkle_button.pressed.emit()
	assert(panel._name_label.text == "花火" and panel._portrait_rect.texture != null,
		"The unlocked-only list must show the migrated Sparkle entry and portrait")
	panel.queue_free()
	print("  ✓ Legacy Sparkle settlement restored in the showcase")

func test_settings_menu_integration() -> void:
	print("[Test] Verifying Settings Menu integration...")
	var settings := GAME_SETTINGS.new()
	settings.in_world = true
	settings.show_save_menu = true
	var progress := GAME_PROGRESS.new()
	progress.unlock_companion("keqing")
	settings.game_progress = progress
	root.add_child(settings)
	settings._ready()

	# Open Tab 1: 存档/读档
	settings.open(1)
	assert(settings._pages[1].visible, "Page 1 should be visible")

	var saves_list: VBoxContainer = settings._pages[1].get_child(2)
	assert(saves_list.get_child_count() >= 4, "Expected at least 4 buttons in saves_list")

	var save_btn: Button = saves_list.get_child(0)
	var load_btn: Button = saves_list.get_child(1)
	var title_btn: Button = saves_list.get_child(2)
	var unlocked_btn: Button = saves_list.get_child(3)

	assert(save_btn.text == "保存游戏", "Save button mismatch")
	assert(load_btn.text == "读取存档", "Load button mismatch")
	assert(title_btn.text == "返回标题页面", "Return to title button mismatch")
	assert(unlocked_btn.text == "【已解锁角色】", "Unlocked characters button mismatch: " + unlocked_btn.text)

	# Click 【已解锁角色】 button
	unlocked_btn.pressed.emit()
	assert(settings._unlocked_panel != null, "Unlocked panel should be created")
	assert(settings._unlocked_panel.visible, "Unlocked panel should be visible")
	assert(settings.is_world_input_locked(), "World input must be locked when unlocked panel is open")

	# Verify Keqing is listed in the opened panel
	assert(settings._unlocked_panel._char_buttons.has("keqing"), "Keqing must be in unlocked list")
	assert(settings._unlocked_panel._name_label.text == "刻晴", "Keqing should be selected")

	# Close settings menu should also close unlocked panel
	settings.close()
	assert(not settings.visible, "Settings menu should be hidden")
	assert(not settings._unlocked_panel.visible, "Unlocked panel should be hidden")
	assert(not settings.is_world_input_locked(), "World input should be unlocked when closed")

	settings.queue_free()
	print("  ✓ Settings Menu integration verified successfully")
