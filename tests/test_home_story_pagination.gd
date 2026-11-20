@tool
extends SceneTree
## Verifies 5-story building data support and page-turnable floor HUD controller.

const BuildingDataClass := preload("res://scripts/construction/building_data.gd")
const HomeHudClass := preload("res://scripts/construction/home_hud.gd")
const ConstructionWorldClass := preload("res://scripts/construction/construction_world.gd")
const BasicKitClass := preload("res://scripts/construction/basic_kit.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	print("==================================================")
	print("[Test] Verifying 5-Story Support and Floor Paginator HUD")
	print("==================================================")

	var kit := BasicKitClass.new()
	kit.initialize()
	var catalog: Dictionary = kit.catalog

	# -------------------------------------------------------------
	# Test 1: BuildingData 5-story validation and stacking logic
	# -------------------------------------------------------------
	print("\n--- Test 1: BuildingData 5-Story Stacking and Bounds ---")
	var data := BuildingDataClass.new()
	data.initialize("story_test", catalog.definitions)

	assert(BuildingDataClass.MAX_STORIES == 5, "MAX_STORIES must be 5")

	# Place floor on Story 0 (1F)
	var f0: Dictionary = data.place("floor", 0, 10, 10, 0, false)
	assert(f0.ok, "Floor on Story 0 should succeed")

	# Place floor on Story 1 (2F) on top of Story 0
	var f1: Dictionary = data.place("floor", 1, 10, 10, 0, false)
	assert(f1.ok, "Floor on Story 1 above Story 0 should succeed")

	# Place floor on Story 2 (3F) on top of Story 1
	var f2: Dictionary = data.place("floor", 2, 10, 10, 0, false)
	assert(f2.ok, "Floor on Story 2 above Story 1 should succeed")

	# Place floor on Story 3 (4F) on top of Story 2
	var f3: Dictionary = data.place("floor", 3, 10, 10, 0, false)
	assert(f3.ok, "Floor on Story 3 above Story 2 should succeed")

	# Place floor on Story 4 (5F) on top of Story 3
	var f4: Dictionary = data.place("floor", 4, 10, 10, 0, false)
	assert(f4.ok, "Floor on Story 4 above Story 3 should succeed")

	# Attempt to place floor on Story 5 (outside range 0..4) -> must be rejected
	var f5: Dictionary = data.place("floor", 5, 10, 10, 0, false)
	assert(not f5.ok, "Floor on Story 5 must be rejected")
	assert(f5.error.contains("五层"), "Error message should mention 五层")
	print("  [Pass] Floor placement across stories 0..4 succeeds, story 5 rejected: %s" % f5.error)

	# Place roof on Story 4 (5F)
	var roof4: Dictionary = data.place("roof", 4, 10, 10, 0, false)
	assert(roof4.ok, "Roof on top floor (Story 4) should succeed")
	print("  [Pass] Roof on top floor (Story 4) placed successfully")

	# Room topology analysis across 5 stories
	data.analyze()
	assert(data.rooms.size() >= 1, "analyze() should detect rooms across all 5 stories")
	print("  [Pass] Room analysis detected %d room definitions across stories" % data.rooms.size())

	# Test stairs across upper stories
	var data_stairs := BuildingDataClass.new()
	data_stairs.initialize("stairs_test", catalog.definitions)
	# Build floors for stairs from Story 0 to 1: footprint is 2x6 (3 cells along Z)
	data_stairs.place("floor", 0, 30, 20, 0, false)
	data_stairs.place("floor", 0, 30, 22, 0, false)
	data_stairs.place("floor", 0, 30, 24, 0, false)
	data_stairs.place("floor", 0, 30, 26, 0, false)
	data_stairs.place("floor", 1, 30, 20, 0, false)
	var st0: Dictionary = data_stairs.place("stairs", 0, 30, 22, 0, false)
	assert(st0.ok, "Stairs on Story 0 should succeed: %s" % str(st0.get("error", "")))

	# Test stairs on top floor (Story 4) must be rejected
	var st4: Dictionary = data_stairs.place("stairs", 4, 30, 22, 0, false)
	assert(not st4.ok, "Stairs on top story 4 must be rejected")
	assert(st4.error.contains("顶层"), "Error message should mention 顶层: %s" % st4.error)
	print("  [Pass] Stairs allowed on lower stories, rejected on top story: %s" % st4.error)

	# -------------------------------------------------------------
	# Test 2: HomeHud Page-turnable floor switcher controls
	# -------------------------------------------------------------
	print("\n--- Test 2: HomeHud Page-Turning Floor Paginator UI ---")
	var hud := HomeHudClass.new()
	var mock_home := Node.new()

	var recorded_stories: Array[int] = []
	var home_script := GDScript.new()
	home_script.source_code = """
extends Node
var kit = null
var selected_definition: String = "floor"
var erase_mode: bool = false
var recorded_stories: Array = []
func select_story(story: int) -> void:
	recorded_stories.append(story)
func select_piece(id: String) -> void:
	pass
func set_erase(erasing: bool) -> void:
	pass
func rotate_piece() -> void:
	pass
func toggle() -> void:
	pass
func change_history(redo: bool) -> void:
	pass
func place_lowland_example() -> void:
	pass
"""
	home_script.reload()
	mock_home.set_script(home_script)
	mock_home.set("kit", kit)

	hud.home = mock_home
	root.add_child(hud)

	assert(HomeHudClass.MAX_STORIES == 5, "HomeHud MAX_STORIES must be 5")
	assert(is_instance_valid(hud._prev_story_btn), "Previous story button must exist")
	assert(is_instance_valid(hud._next_story_btn), "Next story button must exist")
	assert(is_instance_valid(hud._story_label), "Story label must exist")
	assert(hud._story_buttons.get_buttons().size() == 5, "5 direct floor buttons must exist in story_buttons group")

	# Initial state: Story 0 (1F)
	hud.set_editing(true, "测试地块", 0)
	assert(hud._current_story == 0, "Current story should be 0")
	assert(hud._prev_story_btn.disabled, "At Story 0, Prev button should be disabled")
	assert(not hud._next_story_btn.disabled, "At Story 0, Next button should be enabled")
	assert(hud._story_label.text.contains("第 1 层"), "Story label should show 第 1 层: %s" % hud._story_label.text)
	assert(hud._story_label.text.contains("共 5 层"), "Story label should show 共 5 层: %s" % hud._story_label.text)
	print("  [Pass] Initial HUD state (Story 0 / 1F): %s" % hud._story_label.text)

	# Page Turn: Click Next Floor (1F -> 2F)
	hud._on_next_story_pressed()
	assert(hud._current_story == 1, "Story should now be 1")
	assert(not hud._prev_story_btn.disabled, "At Story 1, Prev button should be enabled")
	assert(not hud._next_story_btn.disabled, "At Story 1, Next button should be enabled")
	assert(hud._story_label.text.contains("第 2 层"), "Story label should show 第 2 层: %s" % hud._story_label.text)
	print("  [Pass] Page turn to next floor (Story 1 / 2F): %s" % hud._story_label.text)

	# Page Turn: Step all the way to top floor (Story 4 / 5F)
	hud._on_next_story_pressed() # 2
	hud._on_next_story_pressed() # 3
	hud._on_next_story_pressed() # 4
	assert(hud._current_story == 4, "Story should now be 4")
	assert(not hud._prev_story_btn.disabled, "At Story 4, Prev button should be enabled")
	assert(hud._next_story_btn.disabled, "At Story 4 (top), Next button should be disabled")
	assert(hud._story_label.text.contains("第 5 层"), "Story label should show 第 5 层: %s" % hud._story_label.text)
	assert(hud._story_label.text.contains("五层"), "Story label should show 五层: %s" % hud._story_label.text)
	print("  [Pass] Page turn to top floor (Story 4 / 5F): %s" % hud._story_label.text)

	# Next pressed when at top -> remains at 4
	hud._on_next_story_pressed()
	assert(hud._current_story == 4, "Story should stay at 4 when Next is pressed at top")

	# Direct jump via floor button: click 3F (index 2)
	hud._select_story(2)
	assert(hud._current_story == 2, "Story should now be 2")
	assert(hud._story_label.text.contains("第 3 层"), "Story label should show 第 3 层")
	assert(not hud._prev_story_btn.disabled and not hud._next_story_btn.disabled, "Prev and Next should both be enabled at Story 2")
	print("  [Pass] Direct page tab jump to 3F: %s" % hud._story_label.text)

	# Page Turn: Click Prev Floor (3F -> 2F)
	hud._on_prev_story_pressed()
	assert(hud._current_story == 1, "Story should now be 1 after clicking Prev")
	print("  [Pass] Page turn down (3F -> 2F): %s" % hud._story_label.text)

	hud.queue_free()
	mock_home.queue_free()

	# -------------------------------------------------------------
	# Test 3: ConstructionWorld Story Selection Clamping & HUD Link
	# -------------------------------------------------------------
	print("\n--- Test 3: ConstructionWorld Story Clamping & Keyboard Step ---")
	var cw := ConstructionWorldClass.new()
	cw.name = "TestConstructionWorld"

	# Mock minimal world
	var mock_w := Node3D.new()
	var w_script := GDScript.new()
	w_script.source_code = """
extends Node3D
var test_ready: bool = true
var character_mode: bool = true
var free_mode: bool = false
var review_ui_visible: bool = false
var encounter_ui_active: bool = false
var automation_enabled: bool = true
var metadata: Dictionary = {"spawns": []}
var character: Node3D = null
func is_world_input_allowed() -> bool:
	return true
"""
	w_script.reload()
	mock_w.set_script(w_script)
	var ch := Node3D.new()
	mock_w.add_child(ch)
	mock_w.set("character", ch)
	root.add_child(mock_w)

	cw.world = mock_w
	root.add_child(cw)
	cw.set_process(false)

	assert(cw.selected_story == 0, "Default story should be 0")

	cw.select_story(3)
	assert(cw.selected_story == 3, "Selecting story 3 should set selected_story to 3")

	cw.select_story(10)
	assert(cw.selected_story == 4, "Selecting story 10 should clamp to 4 (MAX_STORIES - 1)")

	cw.select_story(-5)
	assert(cw.selected_story == 0, "Selecting story -5 should clamp to 0")
	print("  [Pass] ConstructionWorld story selection properly clamped to 0..4")

	cw.queue_free()
	mock_w.queue_free()

	print("\n==================================================")
	print("ALL 5-STORY AND FLOOR PAGINATOR TESTS PASSED!")
	print("==================================================")
	quit(0)
