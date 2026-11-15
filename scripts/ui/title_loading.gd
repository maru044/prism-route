extends CanvasLayer

signal load_failed

const UI := preload("res://scenes/combat/encounter_ui_style.gd")
const LOGO := preload("res://assets/title/archaea_studio.png")
const BUBBLE_FRAMES := preload("res://assets/title/archaea_bubbles.png")
const WORLD_MODEL := "res://assets/world/current_map_validation/current_region.glb"
const BUBBLE_RECT := Rect2(448, 112, 816, 336)
const FRAME_COUNT := 5
const FRAMES_PER_SECOND := 7.0

var _bubbles := AtlasTexture.new()
var _caption: Label
var _elapsed := 0.0


func _ready() -> void:
	layer = 100
	add_to_group("world_input_blockers")
	var backdrop := ColorRect.new()
	backdrop.color = Color("#020912")
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var logo_size := LOGO.get_size()
	var fit := AspectRatioContainer.new()
	fit.ratio = logo_size.x / logo_size.y
	fit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(fit)
	fit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var art := TextureRect.new()
	art.texture = LOGO
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fit.add_child(art)

	_bubbles.atlas = BUBBLE_FRAMES
	_bubbles.region = Rect2(Vector2.ZERO, BUBBLE_RECT.size)
	_bubbles.filter_clip = true
	var bubbles := TextureRect.new()
	bubbles.texture = _bubbles
	bubbles.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bubbles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(bubbles)
	bubbles.anchor_left = BUBBLE_RECT.position.x / logo_size.x
	bubbles.anchor_top = BUBBLE_RECT.position.y / logo_size.y
	bubbles.anchor_right = BUBBLE_RECT.end.x / logo_size.x
	bubbles.anchor_bottom = BUBBLE_RECT.end.y / logo_size.y

	_caption = Label.new()
	_caption.text = "加载中"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_theme_font_override("font", UI.command_font())
	_caption.add_theme_font_size_override("font_size", 31)
	_caption.add_theme_color_override("font_color", Color("#e5f1f5"))
	backdrop.add_child(_caption)
	_caption.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_caption.offset_left = -224
	_caption.offset_right = -52
	_caption.offset_top = 40
	_caption.offset_bottom = 86


func _process(delta: float) -> void:
	_elapsed += delta
	var frame := int(_elapsed * FRAMES_PER_SECOND) % FRAME_COUNT
	var offset := frame * BUBBLE_RECT.size.x
	if _bubbles.region.position.x != offset:
		_bubbles.region = Rect2(offset, 0, BUBBLE_RECT.size.x, BUBBLE_RECT.size.y)
	_caption.modulate.a = .61 + .34 * cos(_elapsed * TAU / 1.5)


func _input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()


func is_world_input_locked() -> bool:
	return true


func start(world_path: String) -> void:
	var tree := get_tree()
	# Give the overlay a frame to draw before starting background work.
	await tree.process_frame
	await tree.process_frame
	var scene := await _load_packed(world_path)
	if scene == null:
		_fail()
		return
	var model := await _load_packed(WORLD_MODEL)
	if model == null:
		_fail()
		return
	var world := scene.instantiate()
	if world == null:
		_fail()
		return
	world.set("startup_model", model)
	if tree.change_scene_to_node(world) != OK:
		world.free()
		_fail()
		return
	await tree.scene_changed
	while is_instance_valid(world) and tree.current_scene == world and not world.get("test_ready"):
		await tree.process_frame
	# Render a complete world frame under the overlay before revealing it.
	await tree.process_frame
	await tree.process_frame
	queue_free()


func _load_packed(path: String) -> PackedScene:
	if ResourceLoader.load_threaded_request(path, "PackedScene") != OK:
		return null
	var status := ResourceLoader.load_threaded_get_status(path)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		return null
	return ResourceLoader.load_threaded_get(path) as PackedScene


func _fail() -> void:
	load_failed.emit()
	queue_free()
