extends Node3D

const GROUND_RADIUS := 24.0
# Preserve the original density: 7,000 instances over an 8 m radius disk.
# Tripling the radius multiplies the area and instance count by nine.
const GRASS_COUNT := 63000
const CHUNK_SIZE := 4.0
const GRASS_MODEL := preload("res://assets/vegetation/models/grass_star_3card_v6.glb")
const TREE_MODEL := preload("res://assets/vegetation/models/tree_foliage_480card_v8.glb")
const WIND_SHADER := preload("res://assets/vegetation/shaders/vegetation_wind.gdshader")
const GRASS_TEXTURE := preload("res://assets/vegetation/textures/grass_tuft_straw_minimal_v5.png")
const LEAF_TEXTURE := preload("res://assets/vegetation/textures/leaf_clusters_witness_sparse_flat_v11.png")
const SKY_TEXTURE := preload("res://assets/environment/hdri/rosendal_park_sunset_puresky_4k.exr")

var grass_wind_texture: NoiseTexture2D


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_tree()
	_build_grass_chunks()
	var arguments := OS.get_cmdline_user_args()
	if "--capture-top" in arguments:
		var camera := get_node("OrbitCamera") as Camera3D
		camera.set_process(false)
		camera.position = Vector3(0.0, 52.0, 0.01)
		camera.look_at(Vector3(0.0, 3.6, 0.0), Vector3.FORWARD)
		_capture_test_frame("vegetation_test_top.png")
	elif "--capture" in arguments:
		_capture_test_frame("vegetation_test.png")


func _build_environment() -> void:
	var panorama := PanoramaSkyMaterial.new()
	panorama.panorama = SKY_TEXTURE
	panorama.energy_multiplier = 0.48

	var sky := Sky.new()
	sky.sky_material = panorama
	sky.process_mode = Sky.PROCESS_MODE_QUALITY

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	# Turn the warmer sunset side of the panorama toward the default camera.
	environment.sky_rotation = Vector3(0.0, deg_to_rad(70.0), 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.38
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.82
	environment.glow_enabled = true
	environment.glow_intensity = 0.08
	environment.ssao_enabled = true
	environment.ssao_radius = 1.25
	environment.ssao_intensity = 1.35
	environment.ssao_power = 1.35

	var world_environment := WorldEnvironment.new()
	world_environment.name = "RosendalParkEnvironment"
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-43.0, -128.0, 0.0)
	sun.light_color = Color("ffe2b8")
	sun.light_energy = 0.72
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 100.0
	add_child(sun)


func _build_ground() -> void:
	var ground_mesh := CylinderMesh.new()
	ground_mesh.top_radius = GROUND_RADIUS
	ground_mesh.bottom_radius = GROUND_RADIUS
	ground_mesh.height = 0.35
	ground_mesh.radial_segments = 128

	var ground_material := StandardMaterial3D.new()
	# The under-grass ground stays darker and greyer than the straw blades, but
	# within the same hue family so alpha gaps read as depth rather than noise.
	ground_material.albedo_color = Color("968a55")
	ground_material.roughness = 0.98
	ground_material.metallic = 0.0
	ground_mesh.material = ground_material

	var ground := MeshInstance3D.new()
	ground.name = "CircularGround"
	ground.mesh = ground_mesh
	ground.position.y = -0.175
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(ground)


func _build_tree() -> void:
	var tree := TREE_MODEL.instantiate()
	tree.name = "HeroTree"
	tree.scale = Vector3.ONE * 1.12
	add_child(tree)

	var leaf_material := ShaderMaterial.new()
	leaf_material.shader = WIND_SHADER
	leaf_material.set_shader_parameter("albedo_texture", LEAF_TEXTURE)
	leaf_material.set_shader_parameter("alpha_cutoff", 0.50)
	leaf_material.set_shader_parameter("alpha_antialiasing_edge", 0.30)
	leaf_material.set_shader_parameter("atlas_grid", Vector2(2.0, 2.0))
	leaf_material.set_shader_parameter("card_edge_fade", 0.075)
	leaf_material.set_shader_parameter("light_wrap", 0.34)
	leaf_material.set_shader_parameter("wind_strength", 0.075)
	leaf_material.set_shader_parameter("wind_speed", 0.72)
	_apply_material_to_named_meshes(tree, "foliage", leaf_material)
	_set_shadow_casting_for_named_meshes(
		tree,
		"foliage",
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	_set_shadow_casting_for_named_meshes(
		tree,
		"trunk",
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	)


func _build_grass_chunks() -> void:
	var source := GRASS_MODEL.instantiate()
	var source_mesh_instance := _find_first_mesh_instance(source)
	if source_mesh_instance == null:
		push_error("Grass GLB contains no MeshInstance3D")
		return
	var grass_mesh := source_mesh_instance.mesh.duplicate()
	source.free()

	var grass_material := ShaderMaterial.new()
	grass_material.shader = WIND_SHADER
	grass_material.set_shader_parameter("albedo_texture", GRASS_TEXTURE)
	grass_material.set_shader_parameter("alpha_cutoff", 0.34)
	grass_material.set_shader_parameter("alpha_antialiasing_edge", 0.20)
	grass_material.set_shader_parameter("atlas_grid", Vector2.ONE)
	grass_material.set_shader_parameter("card_edge_fade", 0.0)
	grass_material.set_shader_parameter("light_wrap", 0.46)
	grass_wind_texture = _create_grass_wind_texture()
	grass_material.set_shader_parameter("use_noise_wind", true)
	grass_material.set_shader_parameter("wind_noise_texture", grass_wind_texture)
	grass_material.set_shader_parameter("wind_direction", Vector2(0.88, 0.34).normalized())
	grass_material.set_shader_parameter("wind_strength", 0.085)
	grass_material.set_shader_parameter("wind_speed", 1.08)
	grass_material.set_shader_parameter("wind_noise_world_scale", 0.018)
	grass_material.set_shader_parameter("wind_noise_scroll_speed", 0.035)
	grass_material.set_shader_parameter("wind_tone_curve_c1", 0.92)
	grass_material.set_shader_parameter("wind_tone_curve_c2", 1.0)
	grass_material.set_shader_parameter("wind_detail_scale", 2.65)
	grass_material.set_shader_parameter("wind_detail_amount", 0.20)
	grass_material.set_shader_parameter("wind_lateral_amount", 0.14)
	grass_material.set_shader_parameter("wind_gust_floor", 0.12)
	grass_material.set_shader_parameter("wind_tone_strength", 0.22)
	grass_material.set_shader_parameter("wind_variation_speed", 0.018)
	grass_material.set_shader_parameter("wind_variation_min", 0.45)
	grass_material.set_shader_parameter("wind_variation_max", 1.15)
	grass_material.set_shader_parameter("root_tone", 0.90)
	grass_material.set_shader_parameter("tip_tone", 1.045)
	grass_mesh.surface_set_material(0, grass_material)

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260914
	var chunk_transforms := {}
	for _index in GRASS_COUNT:
		var point := Vector2.ZERO
		while true:
			point = Vector2(
				rng.randf_range(-GROUND_RADIUS, GROUND_RADIUS),
				rng.randf_range(-GROUND_RADIUS, GROUND_RADIUS)
			)
			if point.length() <= GROUND_RADIUS - 0.18 and point.length() >= 0.48:
				break
		var key := Vector2i(
			floori((point.x + GROUND_RADIUS) / CHUNK_SIZE),
			floori((point.y + GROUND_RADIUS) / CHUNK_SIZE)
		)
		if not chunk_transforms.has(key):
			chunk_transforms[key] = []
		var yaw := rng.randf_range(0.0, TAU)
		var width_scale := rng.randf_range(0.70, 1.00)
		var height_scale := rng.randf_range(0.72, 0.96)
		var lean := rng.randf_range(-0.16, 0.16)
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, lean)
		basis = basis.scaled(Vector3(width_scale, height_scale, width_scale))
		var transform := Transform3D(basis, Vector3(point.x, 0.02, point.y))
		chunk_transforms[key].append(transform)

	var grass_root := Node3D.new()
	grass_root.name = "GrassChunks"
	add_child(grass_root)
	for key in chunk_transforms:
		var transforms: Array = chunk_transforms[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = grass_mesh
		multimesh.instance_count = transforms.size()
		for index in transforms.size():
			multimesh.set_instance_transform(index, transforms[index])
		var chunk := MultiMeshInstance3D.new()
		chunk.name = "GrassChunk_%d_%d" % [key.x, key.y]
		chunk.multimesh = multimesh
		chunk.visibility_range_end = 100.0
		# Hundreds of alpha-cut grass shadows become dark visual noise. Grounding
		# comes from SSAO; the trunk and a future canopy proxy handle tree shadows.
		chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		grass_root.add_child(chunk)


func _create_grass_wind_texture() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = 20260919
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.008
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.fractal_lacunarity = 1.93
	noise.fractal_gain = 0.42
	noise.domain_warp_enabled = true
	noise.domain_warp_type = FastNoiseLite.DOMAIN_WARP_SIMPLEX
	noise.domain_warp_amplitude = 14.0
	noise.domain_warp_frequency = 0.006
	noise.domain_warp_fractal_type = FastNoiseLite.DOMAIN_WARP_FRACTAL_NONE

	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.noise = noise
	texture.normalize = true
	texture.seamless = true
	texture.seamless_blend_skirt = 0.12
	texture.generate_mipmaps = true
	return texture


func _find_first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var result := _find_first_mesh_instance(child)
		if result != null:
			return result
	return null


func _apply_material_to_named_meshes(node: Node, token: String, material: Material) -> void:
	if node is MeshInstance3D and token.to_lower() in node.name.to_lower():
		node.material_override = material
	for child in node.get_children():
		_apply_material_to_named_meshes(child, token, material)


func _set_shadow_casting_for_named_meshes(
	node: Node,
	token: String,
	setting: GeometryInstance3D.ShadowCastingSetting
) -> void:
	if node is MeshInstance3D and token.to_lower() in node.name.to_lower():
		node.cast_shadow = setting
	for child in node.get_children():
		_set_shadow_casting_for_named_meshes(child, token, setting)


func _capture_test_frame(filename: String) -> void:
	for _frame in 24:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png("res://screenshots/" + filename)
	if error != OK:
		push_error("Could not save test screenshot: %s" % error_string(error))
	if filename == "vegetation_test.png":
		for _frame in 60:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var later_image := get_viewport().get_texture().get_image()
		var later_error := later_image.save_png(
			"res://screenshots/vegetation_test_wind_later.png"
		)
		if later_error != OK:
			push_error("Could not save later wind frame: %s" % error_string(later_error))
		_save_wind_debug_texture()
	get_tree().quit()


func _save_wind_debug_texture() -> void:
	if grass_wind_texture == null:
		return
	var noise_image := grass_wind_texture.get_image()
	if noise_image == null:
		push_warning("Grass wind texture was not ready for debug export")
		return
	var error := noise_image.save_png("res://screenshots/wind_field_open_simplex2s.png")
	if error != OK:
		push_error("Could not save wind field debug texture: %s" % error_string(error))
