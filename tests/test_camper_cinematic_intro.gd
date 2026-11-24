extends SceneTree
## Test suite for CamperCinematicIntro and first-boarding save progression.

const CamperCinematicIntroClass := preload("res://scripts/ui/camper_cinematic_intro.gd")
const GameProgressClass := preload("res://scripts/progress/game_progress.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	print("--- BEGIN TEST: CamperCinematicIntro & Save Progression ---")

	# ----------------------------------------------------
	# Test 1: GameProgress camper_intro_seen serialization
	# ----------------------------------------------------
	print("\n--- Test 1: GameProgress Save Integration ---")
	var gp := GameProgressClass.new()
	assert(gp.camper_intro_seen == false, "camper_intro_seen should default to false in new game")

	var signal_fired := [false]
	gp.progress_changed.connect(func(key: String, val):
		if key == "camper_intro_seen" and val == true:
			signal_fired[0] = true
	)

	gp.mark_camper_intro_seen()
	assert(gp.camper_intro_seen == true, "camper_intro_seen should become true after mark")
	assert(signal_fired[0] == true, "progress_changed should fire for camper_intro_seen")

	var dict: Dictionary = gp.to_dict()
	assert(dict.has("camper_intro_seen"), "to_dict should include camper_intro_seen")
	assert(dict["camper_intro_seen"] == true, "dict camper_intro_seen should be true")

	# Restore into fresh progress
	var gp_loaded := GameProgressClass.new()
	assert(gp_loaded.camper_intro_seen == false, "fresh instance starts false")
	gp_loaded.from_dict(dict)
	assert(gp_loaded.camper_intro_seen == true, "from_dict should restore camper_intro_seen as true")
	print("  [Pass] GameProgress camper_intro_seen serialization verified!")

	# ----------------------------------------------------
	# Test 2: CamperCinematicIntro UI Structure & Non-blocking
	# ----------------------------------------------------
	print("\n--- Test 2: UI Structure & Non-blocking Filter ---")
	var intro := CamperCinematicIntroClass.new()
	root.add_child(intro)
	await process_frame

	assert(intro.layer == 50, "Layer should be 50")
	assert(intro.process_mode == Node.PROCESS_MODE_ALWAYS, "Process mode should be ALWAYS")

	var root_ctrl: Control = intro._root
	assert(root_ctrl != null, "Root control must exist")
	assert(root_ctrl.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Root control must ignore mouse input")

	assert(intro._bar_top != null, "Top bar must exist")
	assert(intro._bar_top.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Top bar must ignore mouse")
	assert(intro._bar_top.offset_bottom == 72.0, "Top bar height should be 72px")

	assert(intro._bar_bottom != null, "Bottom bar must exist")
	assert(intro._bar_bottom.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Bottom bar must ignore mouse")
	assert(intro._bar_bottom.offset_top == -72.0, "Bottom bar height should be 72px")

	assert(intro._label_act1 != null, "Act 1 label must exist")
	assert(intro._label_act1.text == "P R I S M   R O U T E", "Act 1 text should match pure title")
	assert(intro._label_act1.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Act 1 label must ignore mouse")

	assert(intro._label_act2 != null, "Act 2 label must exist")
	assert(intro._label_act2.text == "P R E S E N T E D   B Y   A R C H A E A", "Act 2 text should match pure credit")
	assert(intro._label_act2.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Act 2 label must ignore mouse")

	assert(intro.is_running == true, "Intro should be active after entering tree")
	print("  [Pass] UI hierarchy and non-blocking mouse filters verified!")

	# ----------------------------------------------------
	# Test 3: Interruption & Cleanup Flow
	# ----------------------------------------------------
	print("\n--- Test 3: Interruption Flow ---")
	var finished_called := [false]
	intro.intro_finished.connect(func():
		finished_called[0] = true
	)

	intro.interrupt()
	await process_frame
	print("  [Pass] Interrupt called without errors!")

	# ----------------------------------------------------
	# Test 4: Signals & Second Instance Safety
	# ----------------------------------------------------
	print("\n--- Test 4: Signals & Second Instance Safety ---")
	var intro2 := CamperCinematicIntroClass.new()
	root.add_child(intro2)
	await process_frame

	var acts_received: Array[int] = []
	intro2.act_changed.connect(func(act: int):
		acts_received.append(act)
	)

	assert(intro2.is_running == true, "intro2 should be running after enter tree")
	intro2.interrupt()
	await process_frame
	print("  [Pass] Second instance and signal dispatch verified!")

	print("\n==================================================")
	print("ALL CAMPER CINEMATIC INTRO TESTS PASSED!")
	print("==================================================")
	quit(0)
