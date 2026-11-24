class_name CamperCinematicIntro
extends CanvasLayer
## High-end cinematic opening credits for the first time boarding the camper van.
## Features floating semi-transparent titles with subtle upward drift and cinematic letterbox bars.
## Fully non-blocking (zero input capture) so driving controls and scenic viewing remain 100% fluid.

signal intro_finished()
signal act_changed(act_index: int)

const BAR_HEIGHT: float = 72.0
const TITLE_ACT1: String = "P R I S M   R O U T E"
const TITLE_ACT2: String = "P R E S E N T E D   B Y   A R C H A E A"

var is_running: bool = false
var _root: Control
var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _container: Control
var _label_act1: Label
var _label_act2: Label
var _active_tween: Tween

func _init() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func _ready() -> void:
	_build_ui()
	start_intro()

func _build_ui() -> void:
	if is_instance_valid(_root):
		return

	_root = Control.new()
	_root.name = "CinematicRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# Cinematic 2.39:1 letterbox bars
	var bar_color := Color(0.03, 0.04, 0.06, 0.85)

	_bar_top = ColorRect.new()
	_bar_top.name = "BarTop"
	_bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_top.color = bar_color
	_bar_top.anchor_left = 0.0
	_bar_top.anchor_right = 1.0
	_bar_top.anchor_top = 0.0
	_bar_top.anchor_bottom = 0.0
	_bar_top.offset_bottom = BAR_HEIGHT
	_bar_top.modulate.a = 0.0
	_root.add_child(_bar_top)

	_bar_bottom = ColorRect.new()
	_bar_bottom.name = "BarBottom"
	_bar_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_bottom.color = bar_color
	_bar_bottom.anchor_left = 0.0
	_bar_bottom.anchor_right = 1.0
	_bar_bottom.anchor_top = 1.0
	_bar_bottom.anchor_bottom = 1.0
	_bar_bottom.offset_top = -BAR_HEIGHT
	_bar_bottom.modulate.a = 0.0
	_root.add_child(_bar_bottom)

	# Centered text container
	_container = Control.new()
	_container.name = "TextContainer"
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_container)

	# Act 1: Game Title
	_label_act1 = Label.new()
	_label_act1.name = "LabelAct1"
	_label_act1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_act1.text = TITLE_ACT1
	_label_act1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_act1.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label_act1.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_label_act1.add_theme_font_size_override("font_size", 44)
	_label_act1.add_theme_color_override("font_color", Color(0.98, 0.99, 1.0, 0.96))
	_label_act1.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.72))
	_label_act1.add_theme_constant_override("shadow_offset_x", 0)
	_label_act1.add_theme_constant_override("shadow_offset_y", 2)
	_label_act1.modulate.a = 0.0
	_container.add_child(_label_act1)

	# Act 2: Studio / Creator Credit
	_label_act2 = Label.new()
	_label_act2.name = "LabelAct2"
	_label_act2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_act2.text = TITLE_ACT2
	_label_act2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_act2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label_act2.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_label_act2.add_theme_font_size_override("font_size", 26)
	_label_act2.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98, 0.92))
	_label_act2.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.72))
	_label_act2.add_theme_constant_override("shadow_offset_x", 0)
	_label_act2.add_theme_constant_override("shadow_offset_y", 2)
	_label_act2.modulate.a = 0.0
	_container.add_child(_label_act2)

## 启动两幕式渐进上浮开幕序列
func start_intro() -> void:
	_build_ui()
	is_running = true

	if not is_inside_tree():
		return

	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	_active_tween = create_tween()
	_active_tween.set_parallel(false)

	# 1. 前置等待 2.0s（车身启动、引擎轰鸣与电台音乐切入）
	_active_tween.tween_interval(2.0)

	# 2. 第一幕：黑条滑入、主标题浮现、向上微浮移动
	_active_tween.tween_callback(func():
		act_changed.emit(1)
		_label_act1.position.y = 16.0
	)
	var t1 := _active_tween.chain().set_parallel(true)
	# 黑条渐显
	t1.tween_property(_bar_top, "modulate:a", 1.0, 0.8)
	t1.tween_property(_bar_bottom, "modulate:a", 1.0, 0.8)
	# 标题淡入、缓慢上移
	t1.tween_property(_label_act1, "modulate:a", 1.0, 0.85)
	t1.tween_property(_label_act1, "position:y", -16.0, 3.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 停留片刻后主标题淡出
	_active_tween.chain().tween_interval(1.9)
	_active_tween.chain().tween_property(_label_act1, "modulate:a", 0.0, 0.75)

	# 第一幕到第二幕之间自然微间隔
	_active_tween.chain().tween_interval(0.2)

	# 3. 第二幕：厂牌字幕浮现、向上微浮移动
	_active_tween.chain().tween_callback(func():
		act_changed.emit(2)
		_label_act2.position.y = 14.0
	)
	var t2 := _active_tween.chain().set_parallel(true)
	t2.tween_property(_label_act2, "modulate:a", 1.0, 0.85)
	t2.tween_property(_label_act2, "position:y", -14.0, 3.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 停留片刻后副标题与黑边同步优雅收起
	_active_tween.chain().tween_interval(1.8)
	var t_exit := _active_tween.chain().set_parallel(true)
	t_exit.tween_property(_label_act2, "modulate:a", 0.0, 0.85)
	t_exit.tween_property(_bar_top, "modulate:a", 0.0, 0.85)
	t_exit.tween_property(_bar_bottom, "modulate:a", 0.0, 0.85)

	# 4. 全部收束完毕
	_active_tween.chain().tween_callback(_on_sequence_completed)

## 玩家提前下车或场景切换时的优雅即时中断
func interrupt() -> void:
	if not is_running:
		return
	is_running = false
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	var fast_exit := create_tween()
	fast_exit.set_parallel(true)
	if is_instance_valid(_root):
		fast_exit.tween_property(_root, "modulate:a", 0.0, 0.35)
	fast_exit.chain().tween_callback(_on_sequence_completed)

func _on_sequence_completed() -> void:
	is_running = false
	intro_finished.emit()
	queue_free()
