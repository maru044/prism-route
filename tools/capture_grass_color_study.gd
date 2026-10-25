extends SceneTree
const OUT := "res://.vegetation_art_build/grass_color/"
func _initialize() -> void:call_deferred("run")
func frames(count: int) -> void:
	for i in count:await process_frame
func shot(name: String) -> void:
	await frames(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size=Vector2i(1600,900);Engine.max_fps=60
	var scene: Node3D=load("res://scenes/vegetation_grove_test.tscn").instantiate()
	root.add_child(scene);await frames(20)
	var camera: Camera3D=scene.get_node("OrbitCamera");camera.set_process(false)
	scene.trunk_comparison.isolate_toggle.button_pressed=false
	scene.trunk_comparison.panel.hide();scene.grass_wind_demo.panel.hide();scene.get_node("Instructions").hide()
	scene.grass_wind_demo.set_mode(0)
	scene.grass_wind_demo.running=false
	var study=scene.grass_color_study
	study.focus_meadow()
	study.menu.item_selected.emit(0);await shot("baseline")
	study.menu.item_selected.emit(1);await shot("fresh")
	# Closer ground view makes both mask zones readable beside one another.
	camera.global_position=Vector3(0,4.2,6.5);camera.look_at(Vector3(0,0,1.0))
	study.menu.item_selected.emit(0);await shot("baseline_ground")
	study.menu.item_selected.emit(1);await shot("fresh_ground")
	var report: Dictionary={"grass_instances":scene.GRASS_COUNT,"uses_same_alpha_texture":study.material.get_shader_parameter("albedo_texture")==scene.GRASS_TEXTURE,
		"preview_default":study.menu.selected,"fresh_dry":study.fresh.palette_dry.to_html(false),"fresh_green":study.fresh.palette_green.to_html(false),"world_changed":false}
	FileAccess.open(OUT+"capture.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("GRASS_COLOR_STUDY ",JSON.stringify(report));quit()
