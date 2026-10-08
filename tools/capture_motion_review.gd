extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size=Vector2i(1440,1000)
	var scene=load("res://scenes/character_motion_test.tscn").instantiate()
	root.add_child(scene)
	var tiles: Array[Image]=[]
	var labels:=CanvasLayer.new()
	root.add_child(labels)
	var caption:=Label.new()
	caption.position=Vector2(580,30)
	caption.add_theme_font_size_override("font_size",32)
	labels.add_child(caption)
	var samples=[0,4,5,15,21,29,32,36,38,40,41]
	for index in samples:
		caption.text="%s · %s" % [scene.catalog[index].id,scene.catalog[index].label_zh]
		scene.yaw=1.0 if index in [29,32] else 0.22
		scene.camera_target=Vector3(0,0.42 if index in [29,32] else 0.80,0)
		scene.distance=3.2
		scene._update_camera()
		scene._select(index)
		scene.player.pause()
		scene.player.seek(scene.catalog[index].duration*0.35,true)
		scene.skeleton.force_update_all_bone_transforms()
		scene._center_character()
		for frame in 8: await process_frame
		await RenderingServer.frame_post_draw
		var picture: Image=root.get_texture().get_image()
		if index==0: picture.save_png(ProjectSettings.globalize_path("res://screenshots/character_motion_test.png"))
		var tile=picture.get_region(Rect2i(400,0,1040,1000))
		tile.resize(520,500,Image.INTERPOLATE_LANCZOS)
		tiles.append(tile)
		print("CAPTURE ",scene.catalog[index].id)
	var matrix=Image.create(520*4,500*3,false,Image.FORMAT_RGB8)
	matrix.fill(Color("202b36"))
	for i in tiles.size(): matrix.blit_rect(tiles[i],Rect2i(Vector2i.ZERO,tiles[i].get_size()),Vector2i((i%4)*520,(i/4)*500))
	matrix.save_png(ProjectSettings.globalize_path("res://screenshots/character_motion_contact_sheet.png"))
	quit()
