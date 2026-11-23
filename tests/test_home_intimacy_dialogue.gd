@tool
extends SceneTree
## Verifies that Home Intimacy Free Dialogue and dynamic intimate action tags work seamlessly.

const GameLLMClientClass := preload("res://scripts/ai/game_llm_client.gd")
const HomeHUDClass := preload("res://scripts/construction/home_hud.gd")
const ConstructionWorldClass := preload("res://scripts/construction/construction_world.gd")
const HomeIntimacyCatalogClass := preload("res://scripts/construction/home_intimacy_catalog.gd")
const BasicKitClass := preload("res://scripts/construction/basic_kit.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	print("==================================================")
	print("[Test] Verifying Home Intimacy Free Dialogue & Dynamic Tags~")
	print("==================================================")

	# ----------------------------------------------------
	# Test 1: Verify Worldbook Dynamic Intimate Action Tags
	# ----------------------------------------------------
	print("\n--- Test 1: Worldbook Dynamic Intimate Action Tags ---")
	var client := GameLLMClientClass.new()
	var da_err := client._load_dialogue_markdown()
	assert(da_err.is_empty(), "Failed to load worldbook: " + da_err)
	print("  ✓ Base worldbook loaded successfully (%d entries)" % client._dialogue_entries.size())

	# Case A: Normal world context without intimacy tags
	client.context = {
		"character_id": "keqing",
		"npc_name": "刻晴",
		"dialogue_location": "沙洲度假遗址",
		"companion_status": "初次相遇",
		"current_interaction_state": "大世界对话",
		"bound_furniture_info": "地面"
	}
	var parsed_normal := client._parsed_dialogue_prompts()
	var normal_scene_content := ""
	for mid in parsed_normal.mid:
		if mid.name == "角色与场景":
			normal_scene_content = mid.content
			break
	assert(not normal_scene_content.is_empty(), "Worldbook entry '角色与场景' must be present")
	assert(not normal_scene_content.contains("当前亲密动作"), "Normal context must NOT contain '当前亲密动作' label")
	assert(not normal_scene_content.contains("亲密动作细节"), "Normal context must NOT contain '亲密动作细节' label")
	print("  ✓ Clean removal verified: Inactive intimate tags leave zero blank labels!")

	# Case B: Home intimacy context with active motion
	client.context = {
		"character_id": "keqing",
		"npc_name": "刻晴",
		"dialogue_location": "海岛别墅 · 晴空起居室",
		"companion_status": "海岛契约伴侣 / 亲密同居中",
		"current_interaction_state": "家园亲密互动 · 日常侍奉",
		"bound_furniture_info": "双人软垫大床（Anchor_BedEdge_Front）",
		"intimate_action": "床沿仰卧胸部侍奉",
		"intimate_action_desc": "床沿仰卧互动，前戏胸部轻柔抚慰",
		"intimate_mode": true
	}
	var parsed_intimate := client._parsed_dialogue_prompts()
	var intimate_scene_content := ""
	for mid in parsed_intimate.mid:
		if mid.name == "角色与场景":
			intimate_scene_content = mid.content
			break
	assert(intimate_scene_content.contains("当前亲密动作：床沿仰卧胸部侍奉"), "Intimate context must inject current intimate action")
	assert(intimate_scene_content.contains("亲密动作细节：床沿仰卧互动，前戏胸部轻柔抚慰"), "Intimate context must inject action description")
	print("  ✓ Dynamic tag injection verified: '当前亲密动作' and '亲密动作细节' injected perfectly!")

	# ----------------------------------------------------
	# Test 2: Verify Scene ID Resolution
	# ----------------------------------------------------
	print("\n--- Test 2: Scene ID Resolution ---")
	var scene_id: String = GameLLMClientClass.resolve_scene_id(client.context)
	assert(scene_id == "intimate", "resolve_scene_id must return 'intimate' for intimate_mode context, got: %s" % scene_id)
	print("  ✓ Scene ID resolved to 'intimate' successfully!")

	# ----------------------------------------------------
	# Test 3: Verify HomeHUD Whisper Button & Notice
	# ----------------------------------------------------
	print("\n--- Test 3: HomeHUD Whisper Button & Notice Duration ---")
	var kit := BasicKitClass.new()
	kit.initialize()
	var mock_home := Node.new()
	var home_script := GDScript.new()
	home_script.source_code = """
extends Node
var kit = null
var selected_definition: String = "floor"
var erase_mode: bool = false
func select_story(_story: int) -> void: pass
func select_piece(_id: String) -> void: pass
func set_erase(_erasing: bool) -> void: pass
func rotate_piece() -> void: pass
func toggle() -> void: pass
func change_history(_redo: bool) -> void: pass
func place_lowland_example() -> void: pass
"""
	home_script.reload()
	mock_home.set_script(home_script)
	mock_home.set("kit", kit)

	var hud := HomeHUDClass.new()
	hud.home = mock_home
	root.add_child(hud)

	assert(is_instance_valid(hud._intimacy_whisper_button), "HUD must have _intimacy_whisper_button instantiated")
	assert(not hud._intimacy_whisper_button.visible, "Whisper button must be hidden initially")

	var callback_called := [false]
	var test_callback := func():
		callback_called[0] = true

	hud.show_intimacy_button("💬 贴身耳语 [T]", test_callback)
	assert(hud._intimacy_whisper_button.visible, "Whisper button must be visible after show_intimacy_button")
	assert(hud._intimacy_whisper_button.text == "💬 贴身耳语 [T]", "Whisper button text must match")

	hud._intimacy_whisper_button.emit_signal("pressed")
	assert(callback_called[0], "Whisper button callback must be triggered on press")
	print("  ✓ HomeHUD whisper button show and click dispatch verified!")

	hud.hide_intimacy_button()
	assert(not hud._intimacy_whisper_button.visible, "Whisper button must be hidden after hide_intimacy_button")
	print("  ✓ HomeHUD whisper button hide verified!")

	# Test notice duration parameter
	hud.show_notice("测试持久提示", -1.0)
	assert(hud._notice_left == -1.0, "Notice duration -1.0 must be respected")
	hud._process(1.0)
	assert(hud._notice.text == "测试持久提示", "Notice must persist when duration is negative")
	hud.show_notice("已结束互动", 5.0)
	assert(hud._notice_left == 5.0, "Notice duration 5.0 must reset countdown")
	print("  ✓ HomeHUD notice duration and persistence verified!")

	hud.queue_free()
	mock_home.queue_free()

	# ----------------------------------------------------
	# Test 4: Verify ConstructionWorld Intimacy Staging Methods
	# ----------------------------------------------------
	print("\n--- Test 4: ConstructionWorld Intimacy Methods ---")
	var cw := ConstructionWorldClass.new()
	assert(cw.has_method("_open_intimacy_free_dialogue"), "ConstructionWorld must implement _open_intimacy_free_dialogue")
	assert(cw.has_method("finish_intimacy_staging"), "ConstructionWorld must implement finish_intimacy_staging")
	assert("current_intimacy_motion" in cw, "ConstructionWorld must track current_intimacy_motion")
	print("  ✓ ConstructionWorld intimacy dialogue methods verified!")

	cw.queue_free()

	# ----------------------------------------------------
	# Test 5: Verify ConstructionWorld Free Dialogue Integration
	# ----------------------------------------------------
	print("\n--- Test 5: ConstructionWorld Free Dialogue Integration ---")
	var cw2 := ConstructionWorldClass.new()
	var mock_world := Node.new()
	var world_script := GDScript.new()
	world_script.source_code = """
extends Node
var dialogue_called := false
var received_speaker := ""
var received_char_id := ""
var received_context := {}
func has_llm_panel_open() -> bool:
	return false
func show_free_dialogue(_panel, speaker: String, character_id: String, custom_ctx: Dictionary) -> void:
	dialogue_called = true
	received_speaker = speaker
	received_char_id = character_id
	received_context = custom_ctx
func close_free_dialogue() -> void:
	pass
"""
	world_script.reload()
	mock_world.set_script(world_script)
	cw2.world = mock_world

	var resident_actor := HomeResidentActor.new()
	resident_actor.character_id = "keqing"
	resident_actor.plot_id = "coastal"
	resident_actor.room_data = {"title": "晴空卧室"}

	cw2.is_intimacy_active = true
	cw2.current_intimacy_actor = resident_actor
	cw2.current_intimacy_motion = {
		"name": "床沿仰卧胸部侍奉",
		"desc": "床沿仰卧互动，前戏胸部轻柔抚慰",
		"tier": "service",
		"furniture": "bed",
		"anchor": "Anchor_BedEdge_Front"
	}

	cw2._open_intimacy_free_dialogue()

	assert(mock_world.get("dialogue_called") == true, "show_free_dialogue must be called on world")
	assert(mock_world.get("received_speaker") == "刻晴", "Speaker must be passed as 刻晴")
	assert(mock_world.get("received_char_id") == "keqing", "Character ID must be passed as keqing")
	var ctx: Dictionary = mock_world.get("received_context")
	assert(ctx.get("intimate_action") == "床沿仰卧胸部侍奉", "Context must contain accurate intimate_action")
	assert(ctx.get("intimate_action_desc") == "床沿仰卧互动，前戏胸部轻柔抚慰", "Context must contain accurate intimate_action_desc")
	assert(ctx.get("intimate_mode") == true, "Context must have intimate_mode = true")
	assert(str(ctx.get("current_interaction_state")).contains("日常侍奉"), "Current interaction state must reflect motion tier")
	assert(str(ctx.get("bound_furniture_info")).contains("Anchor_BedEdge_Front"), "Furniture info must include anchor")
	print("  ✓ Full intimacy free dialogue dispatch and context tags verified!")

	cw2.finish_intimacy_staging()
	assert(not cw2.is_intimacy_active, "Intimacy must be inactive after finish")
	assert(cw2.current_intimacy_motion.is_empty(), "Intimacy motion must be cleared after finish")
	print("  ✓ Staging cleanup verified!")

	resident_actor.queue_free()
	mock_world.queue_free()
	cw2.queue_free()

	print("\n==================================================")
	print("[SUCCESS] All Home Intimacy Free Dialogue tests passed with 0 errors!")
	print("==================================================")
	quit(0)
