extends SceneTree
## Capture matched phases, with a fixed front camera and a world-space center line.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var loop_seam:=OS.get_cmdline_user_args().has("--loop-seam")
	root.size=Vector2i(1440,1000)
	var scene=load("res://scenes/character_motion_test.tscn").instantiate()
	root.add_child(scene)
	for child in scene.get_children():
		if child is CanvasLayer: child.visible=false
	scene.yaw=0.6 if loop_seam else 0.0
	scene.pitch=0.0
	scene.distance=3.1
	scene.camera_target=Vector3(0,0.8,0)
	scene._update_camera()
	scene.camera.h_offset=0.0
	scene._box(scene,Vector3(0.006,2,0.006),Vector3(0,1,-0.5),Color("efb565"))
	var layer:=CanvasLayer.new()
	root.add_child(layer)
	var title:=Label.new()
	title.position=Vector2(550,24)
	title.add_theme_font_size_override("font_size",30)
	layer.add_child(title)
	for index in [4,38]:
		var versions: Array=[]
		for old in [true,false]:
			scene.compare_old_walk=old and not loop_seam
			scene.compare_old_loop=old and loop_seam
			scene._select(index)
			scene.player.pause()
			title.text="%s · %s" % [scene.catalog[index].id,"修正前" if old else "修正后"]
			var frames: Array[Image]=[]
			for frame in 32:
				scene.player.seek(scene.catalog[index].duration*frame/32.0,true)
				scene.skeleton.force_update_all_bone_transforms()
				scene._center_character()
				for settle in 2: await process_frame
				await RenderingServer.frame_post_draw
				var image=root.get_texture().get_image().get_region(Rect2i(400,0,640,1000))
				image.resize(384,600,Image.INTERPOLATE_LANCZOS)
				frames.append(image)
			versions.append(frames)
		var directory=("res://.godot/walk_loop_compare/" if loop_seam else "res://.godot/walk_compare/")+scene.catalog[index].id
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		var contact=Image.create(384*4,600*2,false,Image.FORMAT_RGB8)
		for frame in 32:
			var pair=Image.create(768,600,false,Image.FORMAT_RGB8)
			for mode in 2:
				pair.blit_rect(versions[mode][frame],Rect2i(0,0,384,600),Vector2i(mode*384,0))
				if frame%8==0:
					contact.blit_rect(versions[mode][frame],Rect2i(0,0,384,600),Vector2i((frame/8)*384,mode*600))
			pair.save_png(ProjectSettings.globalize_path(directory+"/frame_%02d.png" % frame))
		var suffix: String="loop_phases" if loop_seam else "phases"
		contact.save_png(ProjectSettings.globalize_path("res://screenshots/walk_%s_%s.png" % [scene.catalog[index].id.to_lower(),suffix]))
		print("WALK_CAPTURE ",scene.catalog[index].id)
	quit()
