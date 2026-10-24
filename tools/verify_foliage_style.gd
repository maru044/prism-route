extends SceneTree
## Integration check for approved defaults, flower preservation, and retired keys.
const OUT := "res://.vegetation_art_build/approved_style_1024/"
const STYLE := preload("res://scripts/foliage_style.gd")
var scene

func _initialize() -> void:call_deferred("run")

func frames(count: int) -> void:
	for i in count:await process_frame

func tap(key: Key) -> void:
	for pressed: bool in [true,false]:
		var event:=InputEventKey.new()
		event.keycode=key;event.physical_keycode=key;event.pressed=pressed
		Input.parse_input_event(event);await frames(1)

func verify_materials() -> Dictionary:
	var green:=0;var flower:=0
	for row: Dictionary in scene.foliage_style.records:
		var material: ShaderMaterial=row.material
		assert(material.shader==row.candidate)
		assert(is_equal_approx(material.get_shader_parameter("foliage_backlight_fill"),0.06))
		assert(is_zero_approx(material.get_shader_parameter("foliage_shadow_relief")))
		if row.green:
			green+=1
			for name: String in STYLE.GREEN_VALUES:
				if row.instance_palette:
					for node: GeometryInstance3D in row.nodes:
						assert(node.get_instance_shader_parameter(name)==STYLE.GREEN_VALUES[name])
				else:assert(material.get_shader_parameter(name)==STYLE.GREEN_VALUES[name])
			assert(material.get_shader_parameter("use_biome_palette"))
			assert(material.get_shader_parameter("species_biome_tint"))
			assert(material.get_shader_parameter("palette_dry")==STYLE.TREE_DRY_TINT)
			assert(material.get_shader_parameter("palette_green")==STYLE.TREE_GREEN_TINT)
			if scene.foliage_style.biome_source!=null:
				for name: String in STYLE.BIOME_PARAMETERS:
					assert(material.get_shader_parameter(name)==scene.foliage_style.biome_source.get_shader_parameter(name))
		else:
			flower+=1
			assert(not material.get_shader_parameter("species_biome_tint"))
			for name: String in STYLE.GREEN_VALUES:
				if row.instance_palette:
					for node: GeometryInstance3D in row.nodes:
						assert(node.get_instance_shader_parameter(name)==row.node_parameters[node.get_instance_id()][name])
				elif row.parameters.has(name):
					assert(material.get_shader_parameter(name)==row.parameters[name])
	assert(green>0 and flower>0)
	return {"green_materials":green,"flower_materials_preserved":flower}

func run() -> void:
	root.size=Vector2i(1600,900);Engine.max_fps=60
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var grove:= "--grove" in OS.get_cmdline_user_args()
	if grove:
		scene=load("res://scenes/vegetation_grove_test.tscn").instantiate()
		root.add_child(scene);await frames(30)
		scene.get_node("OrbitCamera").set_process(false)
	else:
		scene=load("res://scenes/map_1021.tscn").instantiate()
		scene.automation_enabled=true;root.add_child(scene)
		while not scene.test_ready:await process_frame
		await scene.select_spawn(1);scene.set_free(true)
		scene.character.set_physics_process(false);scene.character.hide()
		scene.camper.set_physics_process(false)
		scene.camera.global_position=Vector3(-458.1884,68.96952,1061.078)
		scene.camera.look_at(Vector3(-436.6996,72.22557,1082.567))
		await frames(120)
	var report:=verify_materials()
	for key: Key in [KEY_N,KEY_M,KEY_BRACKETLEFT,KEY_BRACKETRIGHT]:
		await tap(key);assert(verify_materials()==report)
	assert(scene.find_children("*","CanvasLayer",true,false).all(func(ui):return not "foliage" in ui.name.to_lower()))
	report["retired_keys_inert"]=true
	report["default_green_follows_world_biome"]=true
	report["fill"]=STYLE.FILL_STRENGTH;report["shadow_relief"]=STYLE.SHADOW_RELIEF
	if not grove:
		scene.set_review_ui_visible(false)
		await tap(KEY_H);assert(scene.review_ui_visible)
		await tap(KEY_H);assert(not scene.review_ui_visible)
		report["hide_ui_key_preserved"]=true
		var grass: ShaderMaterial=scene.vegetation.grass_material
		assert(grass.shader.resource_path=="res://assets/vegetation/shaders/vegetation_wind.gdshader")
		# The style also supports the original online grass streamer.
		if "store" in scene.vegetation.volume_streamer:
			var signature: String=load("res://scripts/grass_baked_store.gd").signature(scene)
			assert(signature==scene.vegetation.volume_streamer.store.manifest.signature)
			report["grass_bake_signature"]=signature
		for name: String in ["biome_noise_texture","biome_noise_scale","biome_warp_distance","biome_transition_half_width","biome_center_x"]:
			assert(scene.terrain_material.get_shader_parameter(name)==grass.get_shader_parameter(name))
		report["shared_meadow_preserved"]=true
	await frames(12);await RenderingServer.frame_post_draw
	var tag:="grove" if grove else "world"
	assert(root.get_texture().get_image().save_png(OUT+tag+".png")==OK)
	FileAccess.open(OUT+tag+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("APPROVED_FOLIAGE_STYLE_PASS ",tag," ",JSON.stringify(report));quit()
