extends SceneTree
## Lit regression: ambient-only silhouettes cannot catch flipped back normals.
const OUT := "res://.vegetation_art_build/grass_gust/lighting/"
const WIND := preload("res://scripts/grass_wind_world.gd")
const SETTINGS := preload("res://scripts/grass_wind_settings.gd")
var failures: Array[String] = []
var results: Array = []

func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message);push_error(message)
func broken_shader() -> Shader:
	var shader := Shader.new()
	var common := FileAccess.get_file_as_string("res://assets/vegetation/shaders/vegetation_wind_common.gdshaderinc")
	common = common.replace("if (!FRONT_FACING) { NORMAL = -NORMAL; }", "// Reproduce the previous missing backface correction.")
	shader.code = "shader_type spatial;\n#define GRASS_GUST_DEMO\n#define GRASS_SINGLE_SIDED_GEOMETRY\n" + common
	return shader
func shot(name: String) -> Image:
	await frames(8);await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(OUT + name + ".png")
	return image
func difference(a: Image, b: Image) -> Dictionary:
	var aa := a.get_data();var bb := b.get_data()
	var changed := 0;var total := 0.0
	for i in range(0,aa.size(),4):
		var error := maxi(absi(int(aa[i])-int(bb[i])),maxi(absi(int(aa[i+1])-int(bb[i+1])),absi(int(aa[i+2])-int(bb[i+2]))))
		if error > 3: changed += 1
		total += error
	return {"changed_pixels":changed,"mean_max_channel_error":total/(aa.size()/4.0)}

func fixture() -> void:
	var group := Node3D.new();root.add_child(group)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR;environment.background_color = Color("554c2e")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("bdd0df");environment.ambient_light_energy = 0.38
	var env := WorldEnvironment.new();env.environment=environment;group.add_child(env)
	var sun := DirectionalLight3D.new();sun.rotation_degrees=Vector3(-48,45,0);sun.light_energy=0.72
	group.add_child(sun)
	var camera := Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.8
	group.add_child(camera);camera.make_current()
	var source: Node = WIND.MESH.instantiate()
	var original: Mesh=source.find_children("*","MeshInstance3D",true,false)[0].mesh
	var material := ShaderMaterial.new();material.shader=WIND.REFERENCE_SHADER
	material.set_shader_parameter("albedo_texture",load("res://assets/vegetation/textures/grass_tuft_straw_minimal_v5.png"))
	material.set_shader_parameter("light_wrap",0.46)
	material.set_shader_parameter("alpha_cutoff",0.34)
	material.set_shader_parameter("alpha_antialiasing_edge",0.20)
	material.set_shader_parameter("use_noise_wind",true)
	var noise := NoiseTexture2D.new();noise.noise=FastNoiseLite.new();noise.width=64;noise.height=64
	material.set_shader_parameter("wind_noise_texture",noise)
	material.set_shader_parameter("wind_strength",0.085)
	material.set_shader_parameter("wind_direction",Vector2(0.88,0.34).normalized())
	material.set_shader_parameter("gust_time",0.5)
	SETTINGS.apply(material,SETTINGS.DEFAULT_PARAMETERS)
	SETTINGS.update_shared_curve(material,0.5)
	material.set_shader_parameter("gust_shared_curve",true)
	var builder := WIND.new();builder.mesh=original;builder.material=material
	var single := builder._build_lod_mesh(4);builder.free()
	var card := MeshInstance3D.new();card.material_override=material;group.add_child(card)
	var broken := broken_shader()
	var largest_fixed := 0;var largest_broken := 0
	for mix_value: float in [0.0,1.0]:
		material.set_shader_parameter("gust_mix",mix_value)
		for view in 4:
			var angle := view*PI*0.5+0.2
			camera.position=Vector3(sin(angle)*4,1.2,cos(angle)*4);camera.look_at(Vector3(0,0.55,0))
			var label := "lit_%d_%d" % [int(mix_value),view]
			material.shader=WIND.REFERENCE_SHADER;card.mesh=original
			var reference := await shot(label+"_reference")
			material.shader=broken;card.mesh=single
			var before := await shot(label+"_broken")
			material.shader=WIND.SHADER
			var after := await shot(label+"_fixed")
			var old_diff := difference(reference,before);var new_diff := difference(reference,after)
			largest_fixed=maxi(largest_fixed,new_diff.changed_pixels);largest_broken=maxi(largest_broken,old_diff.changed_pixels)
			check(new_diff.changed_pixels < 350,"Lit grass diverges from original: "+label+" "+str(new_diff))
			results.append({"case":label,"before":old_diff,"fixed":new_diff})
	check(largest_broken>2000,"Lit fixture failed to reproduce the reported dark cards")
	print("GRASS_LIT_FIXTURE broken_max=",largest_broken," fixed_max=",largest_fixed)
	source.free();group.free();await frames(3)

func world() -> void:
	root.size=Vector2i(1600,900)
	var scene: Node3D=load("res://scenes/map_1021.tscn").instantiate();scene.automation_enabled=true;root.add_child(scene)
	var begin := Time.get_ticks_msec()
	while not scene.test_ready and Time.get_ticks_msec()-begin<150000: await process_frame
	if not scene.test_ready: check(false,"World startup timeout");return
	await scene.select_spawn(5)
	scene.character.set_physics_process(false)
	scene.set_free(true);scene.set_review_ui_visible(false)
	var stream=scene.vegetation.volume_streamer
	begin=Time.get_ticks_msec()
	while Time.get_ticks_msec()-begin<20000:
		await process_frame
		if stream.active.size()>0 and stream.visible_missing().values().all(func(value):return int(value)==0):break
	var wind=scene.grass_wind;wind.running=false;wind.set_mode(wind.Mode.STRONG);wind.advance(3.1);wind.elapsed=0.5;wind.advance(0.0)
	wind.refresh_lods();wind.set_process(false)
	var material: ShaderMaterial=scene.vegetation.grass_material
	var fixed_shader: Shader=material.shader
	scene.vegetation.set_process(false)
	for blend_value: float in [0.0,1.0]:
		material.set_shader_parameter("gust_mix",blend_value)
		material.shader=broken_shader();await shot("meadow_%d_before"%int(blend_value))
		material.shader=fixed_shader;await shot("meadow_%d_fixed"%int(blend_value))
		# Separate geometry LOD from lighting at the same clock and view.
		material.set_shader_parameter("gust_distance_lod",false)
		for node in wind.grass_nodes:
			if is_instance_valid(node): node.multimesh.mesh=wind.lod_meshes[4]
		await shot("meadow_%d_full_curve"%int(blend_value))
		material.set_shader_parameter("gust_distance_lod",true);wind.refresh_lods()
	check(load("res://scripts/grass_baked_store.gd").signature(scene)=="b3f8cc2f8957e6b70ae3f4e2691ecc1debfcfcd1d9a1da524811694b43da4d31","Rendering fix invalidated bake")
	print("GRASS_LIT_WORLD captured north meadow before/fixed/full curve")

func run() -> void:
	root.size=Vector2i(640,480);root.msaa_3d=Viewport.MSAA_4X;Engine.max_fps=60
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await fixture()
	if "--world" in OS.get_cmdline_user_args(): await world()
	var report := {"passed":failures.is_empty(),"failures":failures,"lit_comparisons":results}
	FileAccess.open(OUT+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("GRASS_BACKFACE_VERIFY ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
