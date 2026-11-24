extends SceneTree
## First-boarding progression, credits layout and animation phase regression checks.

const INTRO := preload("res://scripts/ui/camper_cinematic_intro.gd")
const PROGRESS := preload("res://scripts/progress/game_progress.gd")
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func run() -> void:
	_check_progress()
	await _check_intro(Vector2i(1920, 1080))
	await _check_intro(Vector2i(2560, 1080))
	await _check_interrupt()
	print("CAMPER_CINEMATIC_INTRO_RESULT ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _check_progress() -> void:
	var progress := PROGRESS.new()
	var events: Array[String] = []
	progress.progress_changed.connect(func(key: String, _value): events.append(key))
	check(not progress.camper_intro_seen, "New game starts with unseen credits")
	progress.mark_camper_intro_seen()
	progress.mark_camper_intro_seen()
	check(events == ["camper_intro_seen"], "Credits are marked seen once")
	var restored := PROGRESS.new()
	restored.from_dict(progress.to_dict())
	check(restored.camper_intro_seen, "Seen state survives a save and load")
	restored.from_dict({})
	check(not restored.camper_intro_seen, "Older saves start with unseen credits")

func _make_viewport(size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = size
	root.add_child(viewport)
	return viewport

func _check_intro(size: Vector2i) -> void:
	var viewport := _make_viewport(size)
	var intro := INTRO.new()
	var acts: Array[int] = []
	var finished: Array[bool] = []
	intro.act_changed.connect(func(act: int): acts.append(act))
	intro.intro_finished.connect(func(): finished.append(true))
	viewport.add_child(intro)
	intro._active_tween.pause()
	await process_frame
	await process_frame
	var center := Vector2(size) * 0.5
	check(intro.layer == 50 and intro.process_mode == Node.PROCESS_MODE_ALWAYS, "Credits keep their layer and processing")
	for control: Control in intro.find_children("*", "Control", true, false):
		check(control.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Credits must allow mouse input to pass through")
	check(intro._label_act1.text == "PRISM ROUTE" and intro._label_act2.text == "ARCHAEA", "Title and studio wording is preserved")
	check(intro._credit_caption.text == "PRESENTED BY", "Credit caption has its own line")
	check(intro._label_act1.get_theme_font_size("font_size") >= 110, "Main title uses a cinematic size")
	check(intro._label_act2.get_theme_font_size("font_size") >= 80, "Studio name uses a headline size")
	check(intro._label_act1.size.x >= 840, "The main title has enough screen presence at 1080p")
	check(intro._bar_top.size.y == 72.0 and intro._bar_bottom.position.y == size.y - 72.0, "Bars stay at opposite screen edges")

	_step(intro, INTRO.LEAD_IN - 0.1)
	check(acts.is_empty() and intro._act1.modulate.a == 0.0, "Opening delay leaves the view clear")
	_step(intro, 0.1 + INTRO.FADE_IN * 0.5)
	check(acts == [1] and intro._act1.modulate.a > 0.0 and intro._act1.modulate.a < 1.0, "The first act fades in")
	_check_center(intro._label_act1, center, "Main title during fade-in")
	_step(intro, INTRO.FADE_IN * 0.5 + INTRO.TITLE_HOLD * 0.5)
	check(is_equal_approx(intro._act1.modulate.a, 1.0), "Title stays fully visible during the hold")
	_check_center(intro._label_act1, center, "Main title during the hold")
	_step(intro, INTRO.TITLE_HOLD * 0.5 + INTRO.FADE_OUT * 0.5)
	check(intro._act1.modulate.a < 1.0 and intro._act1.modulate.a > 0.0, "Title fades during its upward exit")
	_check_center(intro._label_act1, center + Vector2(0,-25), "Main title halfway through its exit")
	check(is_equal_approx(intro._bar_top.modulate.a, 1.0), "Bars remain between acts")

	_step(intro, INTRO.FADE_OUT * 0.5 + INTRO.BETWEEN_ACTS + INTRO.FADE_IN * 0.5)
	check(acts == [1, 2] and intro._act1.modulate.a < 0.001 and intro._act2.modulate.a > 0.0, "Studio credit follows the title")
	_check_center(intro._credit_layout, center, "Studio credit during fade-in")
	_step(intro, INTRO.FADE_IN * 0.5 + INTRO.CREDIT_HOLD * 0.5)
	check(is_equal_approx(intro._act2.modulate.a, 1.0), "Studio credit holds fully visible")
	_check_center(intro._credit_layout, center, "Studio credit during the hold")
	_step(intro, INTRO.CREDIT_HOLD * 0.5 + INTRO.FADE_OUT * 0.5)
	_check_center(intro._credit_layout, center + Vector2(0,-25), "Studio credit halfway through its exit")
	check(intro._bar_top.modulate.a < 1.0 and intro._bar_top.modulate.a > 0.0, "Bars fade with the final card")

	_step(intro, INTRO.FADE_OUT * 0.5 + 0.01)
	await process_frame
	check(finished.size() == 1 and not is_instance_valid(intro), "Completed credits emit once and remove the overlay")
	viewport.free()

func _check_interrupt() -> void:
	var viewport := _make_viewport(Vector2i(1920, 1080))
	var intro := INTRO.new()
	var finished: Array[bool] = []
	intro.intro_finished.connect(func(): finished.append(true))
	viewport.add_child(intro)
	intro._active_tween.pause()
	await process_frame
	_step(intro, INTRO.LEAD_IN + INTRO.FADE_IN)
	intro.interrupt()
	intro._active_tween.pause()
	check(not intro.is_running, "Leaving the camper cancels the remaining credits")
	_step(intro, 0.17)
	check(intro._root.modulate.a > 0.0 and intro._root.modulate.a < 1.0, "Interrupt fades the overlay immediately")
	_step(intro, 0.2)
	await process_frame
	check(finished.size() == 1 and not is_instance_valid(intro), "Interruption emits once and cleans up")
	viewport.free()

func _step(intro: CamperCinematicIntro, seconds: float) -> void:
	intro._active_tween.custom_step(seconds)

func _check_center(control: Control, expected: Vector2, message: String) -> void:
	var center := control.get_global_rect().get_center()
	check(center.distance_to(expected) <= 1.0, "%s. Expected %s, got %s" % [message, expected, center])
