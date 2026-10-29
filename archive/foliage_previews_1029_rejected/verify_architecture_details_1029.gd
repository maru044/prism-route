extends SceneTree
const LAB=preload("res://archive/foliage_previews_1029_rejected/architecture_detail_lab_historical.tscn")
const OUT="res://docs/architecture_details_1029/"
var lab
var failures: Array[String]=[]
var report: Dictionary={}
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func frames(n: int) -> void:
	for i in n:await physics_frame
func capture(name: String) -> void:
	await frames(5);await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT+name+".png")==OK,"Failed capture "+name)
func run() -> void:
	Engine.max_fps=120;root.size=Vector2i(1600,1000)
	lab=LAB.instantiate();lab.automation_enabled=true;root.add_child(lab)
	while not lab.ready_for_review:await process_frame
	await frames(5)
	for wall: MeshInstance3D in lab.walls:
		var arrays:=wall.mesh.surface_get_arrays(0)
		check(arrays[Mesh.ARRAY_TEX_UV]==null and arrays[Mesh.ARRAY_TEX_UV2]==null,"Test host unexpectedly has UVs")
	check(lab.baseline!=lab.decorated,"Controls would modify baseline material")
	for name: String in ["seam_mask","foliage_atlas"]:
		var texture: Texture2D=lab.decorated.get_shader_parameter(name)
		check(texture!=null,"Texture not loaded: "+name)
		if texture:check(texture.get_image().has_mipmaps(),"Texture lacks mipmaps: "+name)
	lab.ui.hide();lab.set_view(0);await capture("overview")
	lab.set_view(1);await capture("close_all")
	lab.set_plants(false);check(not lab.decorated.get_shader_parameter("plants_enabled"),"Plant toggle failed");await capture("close_joints")
	lab.set_joints(false);check(not lab.decorated.get_shader_parameter("joints_enabled"),"Seam toggle failed");await capture("close_clean")
	lab.set_plants(true);await capture("close_plants")
	var original_paint: Color=lab.decorated.get_shader_parameter("plant_color")
	lab.decorated.set_shader_parameter("plant_color",Color("6699dd"));await capture("leaf_recolor")
	lab.decorated.set_shader_parameter("plant_color",original_paint)
	lab.set_joints(true);lab.set_view(2);await capture("walltop")
	lab.set_view(3);await capture("alpha_edges")
	lab.set_view(0);lab.distance=29.;lab._update_camera();await capture("far")
	report={"passed":failures.is_empty(),"failures":failures,"adapter":RenderingServer.get_video_adapter_name(),"host_uv_channels":0,"host_walls":lab.walls.size(),"actual_game_scene_modified":false,"seam_texture_size":[lab.decorated.get_shader_parameter("seam_mask").get_width(),lab.decorated.get_shader_parameter("seam_mask").get_height()],"plant_texture_size":[lab.decorated.get_shader_parameter("foliage_atlas").get_width(),lab.decorated.get_shader_parameter("foliage_atlas").get_height()],"mipmaps":true,"plant_color_source":"foliage_style.GREEN_VALUES.species_mid_color","plant_rgb_from_texture":false}
	FileAccess.open(OUT+"render_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ARCHITECTURE_DETAILS_1029 ",JSON.stringify(report));lab.queue_free();await frames(3);quit(0 if failures.is_empty() else 1)
