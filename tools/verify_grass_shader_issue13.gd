extends SceneTree
## Real grass shader, same instance data, fixed shader time and static lighting.
const VEG := preload("res://scripts/map_1021_vegetation.gd")
const BUFFER := preload("res://scripts/grass_instance_buffer.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,720);root.msaa_3d=Viewport.MSAA_4X
	var world:=Node3D.new();root.add_child(world)
	var camera:=Camera3D.new();camera.position=Vector3(0,12,35);world.add_child(camera);camera.look_at(Vector3(0,0,-35))
	var environment:=WorldEnvironment.new();var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color(.3,.45,.6)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=.65
	environment.environment=env;world.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);world.add_child(sun)
	var vegetation:=VEG.new();world.add_child(vegetation)
	var noise:=FastNoiseLite.new();noise.seed=46129
	var texture:=NoiseTexture2D.new();texture.width=256;texture.height=256;texture.noise=noise
	vegetation.biome_noise_texture=texture;vegetation._load_meshes_and_materials()
	while texture.get_image()==null:await process_frame
	var material: ShaderMaterial=vegetation.grass_material.duplicate()
	var shader:=Shader.new();shader.code=material.shader.code.replace("TIME","13.0");material.shader=shader
	material.set_shader_parameter("use_grass_lod_density",true)
	material.set_shader_parameter("skip_invisible_grass",false)
	var transforms: Array[Transform3D]=[];var custom: Array[Color]=[]
	var rng:=RandomNumberGenerator.new();rng.seed=1310442
	for i in 40000:
		transforms.append(Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU)),Vector3(rng.randf_range(-25,25),.025,rng.randf_range(-130,20))))
		custom.append(Color(rng.randf(),rng.randf(),rng.randf(),1.0 if i%5==0 else 0.0))
	var data:=BUFFER.pack(transforms,custom)
	var node:=BUFFER.make_node("Grass",vegetation.grass_mesh,material,data,0,BUFFER.bounds(data,vegetation.grass_mesh.get_aabb()))
	world.add_child(node)
	for i in 60:await process_frame
	await RenderingServer.frame_post_draw;var before:=root.get_texture().get_image()
	material.set_shader_parameter("skip_invisible_grass",true)
	for i in 10:await process_frame
	await RenderingServer.frame_post_draw;var after:=root.get_texture().get_image()
	node.visible=false
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw;var empty:=root.get_texture().get_image()
	var pixels_equal:=before.get_data()==after.get_data()
	var grass_visible:=before.get_data()!=empty.get_data()
	before.save_png("res://assets/world/current_map_validation/review/issue13_shader_before.png")
	after.save_png("res://assets/world/current_map_validation/review/issue13_shader_after.png")
	var report: Dictionary={"passed":pixels_equal and grass_visible,"pixels_equal":pixels_equal,"grass_visible":grass_visible,"instances":40000,"resolution":str(root.size),"shader_time":13.0,"note":"Real grass mesh/material with fixed TIME, static sun and no temporal SSAO. Only skip_invisible_grass differs."}
	var file:=FileAccess.open("res://assets/world/current_map_validation/review/issue13_shader_parity.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("GRASS_SHADER_PARITY ",JSON.stringify(report));quit(0 if report.passed else 1)
