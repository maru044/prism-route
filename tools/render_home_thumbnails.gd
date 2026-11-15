extends SceneTree

const KIT := preload("res://scripts/construction/basic_kit.gd")
const HUD := preload("res://scripts/construction/home_hud.gd")


func _initialize() -> void:
	render.call_deferred()


func render() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Run the thumbnail studio with a renderer.")
		quit(1)
		return
	var kit := KIT.new()
	kit.initialize()
	var studio := SubViewport.new()
	studio.size = HUD.PHOTO_SIZE * 2
	studio.own_world_3d = true
	studio.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	studio.msaa_3d = Viewport.MSAA_4X
	root.add_child(studio)

	var backdrop := WorldEnvironment.new()
	var lightbox := Environment.new()
	lightbox.background_mode = Environment.BG_COLOR
	lightbox.background_color = Color("#e4edf0")
	lightbox.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	lightbox.ambient_light_color = Color("#e4f2ff")
	lightbox.ambient_light_energy = .85
	backdrop.environment = lightbox
	studio.add_child(backdrop)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, 35, 0)
	light.light_energy = 1.15
	studio.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	studio.add_child(camera)
	camera.make_current()

	var ids := HUD.photo_ids()
	var rows := ceili(float(ids.size()) / HUD.PHOTO_COLUMNS)
	var sheet := Image.create(HUD.PHOTO_COLUMNS * HUD.PHOTO_SIZE.x, rows * HUD.PHOTO_SIZE.y, false, Image.FORMAT_RGB8)
	for index in range(ids.size()):
		var id := ids[index]
		var model := kit.make(id)
		studio.add_child(model)
		var bounds: AABB
		var first := true
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var world_aabb := mesh.global_transform * mesh.get_aabb()
			bounds = world_aabb if first else bounds.merge(world_aabb)
			first = false
		if first:
			printerr("No renderable model for ", id)
			quit(1)
			return
		var center := bounds.get_center()
		camera.position = center + Vector3(1, .67, 1.30).normalized() * 15.0
		camera.look_at(center)
		var half_width := 0.0
		var half_height := 0.0
		for corner in range(8):
			var offset := bounds.get_endpoint(corner) - center
			half_width = maxf(half_width, absf(offset.dot(camera.basis.x)))
			half_height = maxf(half_height, absf(offset.dot(camera.basis.y)))
		camera.size = 2.48 * maxf(half_height, half_width * float(studio.size.y) / studio.size.x)
		await process_frame
		await RenderingServer.frame_post_draw
		var image := studio.get_texture().get_image()
		image.convert(Image.FORMAT_RGB8)
		image.resize(HUD.PHOTO_SIZE.x, HUD.PHOTO_SIZE.y, Image.INTERPOLATE_LANCZOS)
		var position := Vector2i(index % HUD.PHOTO_COLUMNS, floori(float(index) / HUD.PHOTO_COLUMNS)) * HUD.PHOTO_SIZE
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, HUD.PHOTO_SIZE), position)
		model.free()
	var result := sheet.save_png(HUD.THUMBNAILS)
	print("HOME_STUDIO photos=", ids.size(), " save=", error_string(result))
	quit(result)
