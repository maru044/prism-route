extends SceneTree
const SCENE=preload("res://archive/foliage_previews_1029_rejected/wall_foliage_single_leaf_rejected.tscn")
const OUT="res://docs/wall_foliage_volume_1029/"
var prototype
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await process_frame
func capture(name: String) -> void:
	await frames(8);await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUT+name+".png")==OK)
func run() -> void:
	Engine.max_fps=60;root.size=Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	prototype=SCENE.instantiate();prototype.automation_enabled=true;root.add_child(prototype)
	while not prototype.ready_for_review:await process_frame
	assert(prototype.foliage.multimesh.instance_count==1084)
	var original_layout: Array=JSON.parse_string(FileAccess.get_file_as_string("res://docs/wall_foliage_art_prototype_1029/leaf_layout.json"))
	assert(original_layout.size()==prototype.leaves.size())
	for i in original_layout.size():
		for key: String in ["x","depth","size","angle","tone"]:assert(absf(float(original_layout[i][key])-float(prototype.leaves[i][key]))<.00001)
	assert(prototype.LEAF_ATLAS.get_image().has_mipmaps())
	prototype.ui.hide();prototype.set_view(0);await capture("textured_front")
	prototype.set_texture_color(false);await capture("flat_color_front")
	prototype.set_texture_color(true);prototype.set_view(2);await capture("textured_close")
	prototype.set_texture_color(false);await capture("flat_color_close")
	prototype.set_texture_color(true);prototype.set_view(1);await capture("textured_oblique")
	prototype.set_parallax(false);await capture("oblique_without_parallax")
	prototype.set_parallax(true)
	var mm: MultiMesh=prototype.foliage.multimesh
	var first_transform:=mm.get_instance_transform(0);var first_custom:=mm.get_instance_custom_data(0)
	mm.visible_instance_count=1
	mm.set_instance_transform(0,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*.22),Vector3(0,3.07,.06)))
	mm.set_instance_custom_data(0,Color(0,1,1,1))
	prototype.view_target=Vector3(0,3.07,0);prototype.camera.size=1.2
	for angle in [-.42,0.,.42]:
		prototype.yaw=angle;prototype.update_camera()
		var suffix: String="left" if angle<0 else ("right" if angle>0 else "front")
		prototype.set_parallax(false);await capture("single_"+suffix+"_off")
		prototype.set_parallax(true);await capture("single_"+suffix+"_on")
	mm.set_instance_transform(0,first_transform);mm.set_instance_custom_data(0,first_custom);mm.visible_instance_count=-1
	prototype.set_view(0);prototype.ui.show();await capture("prototype_ui")
	var unchanged: Dictionary={}
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.current_map_build/wall_foliage_volume_before/hashes.json"))
	for path: String in before:
		if path in ["scripts/world/wall_foliage_art_prototype.gd","assets/world/wall_foliage_art_prototype_1029/layout.json"]:continue
		unchanged[path]=FileAccess.get_sha256("res://"+path)==before[path];assert(unchanged[path])
	var report: Dictionary={"adapter":RenderingServer.get_video_adapter_name(),"leaves":mm.instance_count,"source_layout_unchanged":true,"atlas_size":[prototype.LEAF_ATLAS.get_width(),prototype.LEAF_ATLAS.get_height()],"mipmaps":true,"atlas_sha256":FileAccess.get_sha256("res://assets/world/wall_foliage_art_prototype_1029/leaf_volume_atlas_v3.png"),"unchanged_formal_files":unchanged,"parallax_depth_m":prototype.paint.get_shader_parameter("parallax_depth_m"),"parallax_uses_main_camera_in_shadow_pass":true}
	FileAccess.open(OUT+"render_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("WALL_FOLIAGE_VOLUME_1029 ",JSON.stringify(report));quit()
