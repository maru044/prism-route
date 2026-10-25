extends SceneTree
## Actual GPU, fixed-camera 8 s comparisons. Encodes each clip before removing
## its exact temporary frame files; no baked vegetation or project assets change.
const OUT := "res://.vegetation_art_build/grass_gust/issue15/body_tip_slow/"
const NAMES := {0: "current", 2: "body_tip"}
var failed := false

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count:
		await process_frame

func encode(input: String, output: String, filter: String = "") -> int:
	var args := PackedStringArray(["-hide_banner", "-loglevel", "error", "-y"])
	if input.ends_with(".jpg"):
		args.append_array(["-framerate", "60"])
	args.append_array(["-i", ProjectSettings.globalize_path(input)])
	if not filter.is_empty():
		args.append_array(["-vf", filter])
	args.append_array(["-c:v", "libx264", "-crf", "20", "-pix_fmt", "yuv420p", "-movflags", "+faststart", ProjectSettings.globalize_path(output)])
	var result: Array = []
	var code := OS.execute("ffmpeg", args, result, true)
	if code != 0:
		push_error("Video encoding failed: " + str(result))
		failed = true
	return code

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1280, 720)
	Engine.max_fps = 0
	var scene: Node3D = load("res://scenes/vegetation_grove_test.tscn").instantiate()
	root.add_child(scene)
	await frames(35)
	var demo = scene.grass_wind_demo
	demo.running = false
	demo.set_mode(demo.Mode.STRONG)
	demo.blend = 1.0
	demo.panel.hide()
	scene.get_node("Instructions").hide()
	var camera: Camera3D = scene.get_node("OrbitCamera")
	camera.set_process(false)
	var label := Label.new()
	label.position = Vector2(18, 15)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	demo.panel.get_parent().add_child(label)
	var views := {
		"low": [Vector3(2.8, 1.7, 8.0), Vector3(3, 0.65, 1)],
		"close": [Vector3(-0.5, 1.15, 3.5), Vector3(3.5, 0.65, 1.0)],
		"overhead": [Vector3(4, 10, 13), Vector3(4, 0, 2)],
	}
	# Match every candidate's time, camera, density, lighting and texture. Do not
	# infer visual success from a motion count; these are for human review.
	for view: String in views:
		camera.position = views[view][0]
		camera.look_at(views[view][1])
		for candidate: int in NAMES:
			demo.set_motion(candidate)
			var stem: String = view + "_" + NAMES[candidate]
			print("GRASS_CAPTURE_START ", stem)
			for i in 480:
				demo.elapsed = float(i) / 60.0
				demo.advance(0.0)
				label.text = "%s / %s  |  t=%.2fs\n%s" % [view, NAMES[candidate], demo.elapsed,
					"held bent 85 deg / slower rebound 0.85 Hz / tip 2.4 Hz" if candidate == 2 else "original 2.1 Hz / original angle range"]
				await frames(2)
				await RenderingServer.frame_post_draw
				var shot := root.get_texture().get_image()
				shot.save_jpg(OUT + "frame_%04d.jpg" % i, 0.96)
				if i == 90:
					shot.save_png(OUT + stem + ".png")
			var video: String = OUT + stem + "_60.mp4"
			if encode(OUT + "frame_%04d.jpg", video) == 0:
				encode(video, OUT + stem + "_30.mp4", "fps=30")
				# These exact files were written above in this ignored output folder.
				for i in 480:
					DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT + "frame_%04d.jpg" % i))
			print("GRASS_CAPTURE_DONE ", stem)
			if failed:
				quit(1)
				return
	FileAccess.open(OUT + "capture_manifest.json", FileAccess.WRITE).store_string(JSON.stringify({
		"seconds_per_clip": 8, "source_fps": 60, "additional_fps": 30,
		"resolution": [1280,720], "views": views.keys(), "candidates": NAMES,
		"grass_clock": "explicit identical sample times; unrelated scene animations use render time",
		"tip_variation": false, "density": 63000, "mesh": "v7 unchanged",
	}, "  "))
	print("GRASS_CAPTURE_ALL_DONE")
	quit()
