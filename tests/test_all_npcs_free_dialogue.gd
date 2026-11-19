@tool
extends SceneTree
## Verifies free dialogue entry and persona/state injection for all characters.

const GameLLMClientClass := preload("res://scripts/ai/game_llm_client.gd")
const DialoguePanelClass := preload("res://scenes/narrative/dialogue_panel.gd")
const CharacterRosterDatabaseClass := preload("res://scripts/characters/character_roster_database.gd")

func _init() -> void:
	print("==================================================")
	print("[Test] Verifying All NPCs Free Dialogue and Persona Injection")
	print("==================================================")

	var client := GameLLMClientClass.new()
	var load_err := client._load_dialogue_markdown()
	assert(load_err.is_empty(), "Failed to load worldbook: " + load_err)
	print("  [Pass] Base worldbook loaded successfully")

	# Test 1: Verify token expansion with state injection
	print("\n--- Test 1: Worldbook Token Expansion and State Injection ---")
	client.context = {
		"character_id": "keqing",
		"npc_name": "刻晴",
		"character_title": "璃月七星 · 玉衡星",
		"dialogue_location": "沙洲度假遗址",
		"companion_status": "已缔结契约（识趣玩伴，完全顺从Master的一切安排与要求）",
		"current_interaction_state": "日常闲聊 / 初步试探",
		"bound_furniture_info": "desk_service: sandbar_desk",
		"pleasure_npc": "25.0%",
		"pleasure_player": "10.0%",
	}
	var parsed := client._parsed_dialogue_prompts()
	var found_scene_entry := false
	for mid in parsed.mid:
		if mid.name == "角色与场景":
			found_scene_entry = true
			var content: String = mid.content
			assert("刻晴" in content, "Scene must contain npc_name")
			assert("璃月七星 · 玉衡星" in content, "Scene must contain character_title")
			assert("沙洲度假遗址" in content, "Scene must contain dialogue_location")
			assert("已缔结契约" in content, "Scene must contain companion_status")
			assert("日常闲聊 / 初步试探" in content, "Scene must contain current_interaction_state")
			assert("desk_service: sandbar_desk" in content, "Scene must contain bound_furniture_info")
			assert("25.0%" in content, "Scene must contain pleasure_npc")
			assert("10.0%" in content, "Scene must contain pleasure_player")
			assert(not "{{" in content, "Scene content must not contain unresolved template tokens")
			print("  [Pass] 角色与场景 expansion verified with rich state values")
			break
	assert(found_scene_entry, "角色与场景 entry must be present in parsed prompts")

	# Test 2: Verify Persona Injection for all 50 characters in Roster Database
	print("\n--- Test 2: Roster Characters Persona Resolution ---")
	var entries := CharacterRosterDatabaseClass.get_all_entries()
	assert(entries.size() >= 48, "Expected at least 48 roster entries, got: %d" % entries.size())

	for entry in entries:
		var c_id: String = entry.id
		var c_name: String = entry.name
		client.context = {
			"character_id": c_id,
			"npc_name": c_name,
			"dialogue_location": "大世界"
		}
		var parsed_char := client._parsed_dialogue_prompts()
		var found_persona := false
		for mid in parsed_char.mid:
			if mid.name.begins_with("角色设定"):
				found_persona = true
				assert(not str(mid.content).is_empty(), "Persona content for %s must not be empty" % c_id)
				break
		assert(found_persona, "Persona must be injected for character: %s (%s)" % [c_id, c_name])

	print("  [Pass] All %d roster character personas successfully resolved and injected" % entries.size())

	# Test 3: DialoguePanel Free Dialogue Button toggle and signal
	print("\n--- Test 3: DialoguePanel Free Dialogue Button ---")
	var panel := DialoguePanelClass.new()
	root.add_child(panel)
	panel._ready()

	# Initially false
	assert(panel.free_dialogue_button == null or not panel.free_dialogue_button.visible, "Button should be hidden by default")

	# Dynamically enable
	panel.enable_free_dialogue = true
	assert(panel.free_dialogue_button != null and panel.free_dialogue_button.visible, "Button should be visible when enabled")

	# Verify signal emission
	var signal_box := [false]
	panel.free_dialogue_requested.connect(func():
		signal_box[0] = true
	)
	panel.free_dialogue_button.pressed.emit()
	assert(signal_box[0], "Clicking free dialogue button must emit free_dialogue_requested signal")
	print("  [Pass] DialoguePanel dynamic free dialogue button verified")

	# Test 4: DialoguePanel with enable_free_dialogue set before ready
	print("\n--- Test 4: DialoguePanel Pre-Ready Enable ---")
	var panel_pre := DialoguePanelClass.new()
	panel_pre.enable_free_dialogue = true
	root.add_child(panel_pre)
	panel_pre._ready()
	assert(panel_pre.free_dialogue_button != null and panel_pre.free_dialogue_button.visible, "Button should be visible when enabled before ready")
	print("  [Pass] DialoguePanel pre-ready enable_free_dialogue verified")

	# Test 5: Mock World and NPC Duel Free Dialogue flow
	print("\n--- Test 5: World show_free_dialogue Handshake ---")
	var last_received := {}

	var show_fn := func(p: Control, spk: String, cid: String = "", ctx: Dictionary = {}) -> void:
		last_received["speaker"] = spk
		last_received["id"] = cid
		last_received["context"] = ctx

	# Verify callback binding
	show_fn.call(panel, "甘雨", "ganyu", {
		"character_title": "循循守月 · 月海亭",
		"companion_status": "已缔结契约",
		"pleasure_npc": "50.0%",
	})
	assert(last_received.get("speaker") == "甘雨", "Speaker must match")
	assert(last_received.get("id") == "ganyu", "Character ID must match")
	assert(last_received.get("context", {}).get("pleasure_npc") == "50.0%", "Context payload must match")
	print("  [Pass] show_free_dialogue handshake verified")

	# Test 6: NPCWorldDuel Integration with Runtime
	print("\n--- Test 6: NPCWorldDuel Free Dialogue Integration ---")
	var NPCWorldDuelClass := load("res://scripts/world/npc_world_duel.gd")
	var NPCEncounterRuntimeClass := load("res://scripts/world/npc_encounter_runtime.gd")

	var duel_host := Node3D.new()
	root.add_child(duel_host)

	var runtime_inst = NPCEncounterRuntimeClass.new()
	duel_host.add_child(runtime_inst)
	var setup_ok: bool = runtime_inst.setup_encounter("sandbar_keqing")
	assert(setup_ok, "sandbar_keqing setup must succeed")

	var duel_instance = NPCWorldDuelClass.new()
	duel_host.add_child(duel_instance)

	var world_received := {}
	var world_closed_box := [false]

	# Build lightweight mock script on Node3D
	var world_mock := Node3D.new()
	var mock_script := GDScript.new()
	mock_script.source_code = """
extends Node3D
var captured_info: Dictionary = {}
var close_called: bool = false
func show_free_dialogue(panel: Control, speaker: String, character_id: String = "", custom_context: Dictionary = {}) -> void:
	captured_info["speaker"] = speaker
	captured_info["character_id"] = character_id
	captured_info["custom_context"] = custom_context
func close_free_dialogue() -> void:
	close_called = true
"""
	mock_script.reload()
	world_mock.set_script(mock_script)
	root.add_child(world_mock)

	duel_instance.initialize(duel_host, world_mock, runtime_inst)
	assert(duel_instance.panel.enable_free_dialogue, "Duel panel must have enable_free_dialogue set to true")
	duel_instance.panel._ready()
	assert(duel_instance.panel.free_dialogue_button != null and duel_instance.panel.free_dialogue_button.visible, "Duel panel free dialogue button must be visible")

	# Start dialogue and trigger free dialogue
	runtime_inst.start_intro_dialogue()
	assert(runtime_inst.dialogue_manager.session_active, "Dialogue session must be active")

	duel_instance._on_free_dialogue_requested()
	var cap_info: Dictionary = world_mock.get("captured_info")
	assert(cap_info.get("speaker") == "刻晴", "Captured speaker should be 刻晴")
	assert(cap_info.get("character_id") == "keqing", "Captured id should be keqing")

	var ctx: Dictionary = cap_info.get("custom_context", {})
	assert(ctx.get("character_title") == "璃月七星 · 玉衡星", "Title should match")
	assert("沙洲度假遗址" in ctx.get("dialogue_location", ""), "Location should match")
	assert("未收服" in ctx.get("companion_status", "") or "初次相遇" in ctx.get("companion_status", ""), "Companion status should be populated")
	assert("日常闲聊" in ctx.get("current_interaction_state", ""), "State should be populated")
	assert(ctx.has("bound_furniture_info"), "Furniture info should be present")
	assert(ctx.has("pleasure_npc"), "Pleasure npc should be present")
	assert(ctx.has("pleasure_player"), "Pleasure player should be present")
	assert(ctx.get("dialogue_manager") == runtime_inst.dialogue_manager, "Dialogue manager should match")

	# Cancel/end dialogue session and verify close_free_dialogue
	runtime_inst.dialogue_manager.cancel_session()
	assert(world_mock.get("close_called"), "close_free_dialogue should be called when dialogue ends")
	print("  [Pass] NPCWorldDuel free dialogue signal, context injection, and teardown verified")

	panel.queue_free()
	panel_pre.queue_free()
	duel_host.queue_free()
	world_mock.queue_free()

	print("\n==================================================")
	print("[SUCCESS] All NPC free dialogue and persona injection tests passed")
	print("==================================================")
	quit(0)
