extends Node3D

@export var biome_demo := false
@export var grove_demo := false
@export_group("Biome color test")
@export var grass_dry_tint := Color.WHITE
@export var grass_green_tint := Color(0.77, 0.88, 0.78)
@export var tree_dry_tint := Color(1.03, 0.98, 0.82)
@export var tree_green_tint := Color(0.83, 0.97, 0.89)
@export var ground_dry_color := Color("968a55")
@export var ground_green_color := Color("667752")
@export_range(1.0, 12.0) var biome_transition_half_width := 5.0
@export_range(0.0, 10.0) var biome_warp_distance := 4.0
@export_range(0.0, 5.0) var grass_color_overlap := 2.3
@export_range(-12.0, 12.0) var biome_center_x := 0.0

const GROUND_RADIUS := 24.0
# Preserve the original density: 7,000 instances over an 8 m radius disk.
# Tripling the radius multiplies the area and instance count by nine.
const GRASS_COUNT := 63000
const CHUNK_SIZE := 4.0
const GRASS_MODEL := preload("res://assets/vegetation/models/grass_star_3card_v6.glb")
const TREE_MODEL := preload("res://assets/vegetation/models/tree_foliage_480card_v8.glb")
const TREE_MODEL_REFINED := preload("res://assets/vegetation/models/tree_small_broad_canopy.glb")
const TREE_MODEL_UPRIGHT := preload("res://assets/vegetation/models/tree_medium_upright_asymmetric_canopy.glb")
const TREE_MODEL_BROAD_CLUSTERED := preload("res://assets/vegetation/models/tree_medium_broad_clustered_canopy.glb")
const WIND_SHADER := preload("res://assets/vegetation/shaders/vegetation_wind.gdshader")
const BIOME_GROUND_SHADER := preload("res://assets/vegetation/shaders/biome_ground.gdshader")
const GRASS_TEXTURE := preload("res://assets/vegetation/textures/grass_tuft_straw_minimal_v5.png")
const LEAF_TEXTURE := preload("res://assets/vegetation/textures/leaf_clusters_witness_sparse_flat_v11.png")
const SKY_TEXTURE := preload("res://assets/environment/hdri/rosendal_park_sunset_puresky_4k.exr")

var grass_wind_texture: NoiseTexture2D
var biome_noise_texture: NoiseTexture2D


func _ready() -> void:
	var arguments := OS.get_cmdline_user_args()
	var refined_tree := not ("--baseline-tree" in arguments)
	if biome_demo:
		biome_noise_texture = _create_biome_noise_texture()
	_build_environment()
	_build_ground()
	if biome_demo:
		if grove_demo:
			_build_landscape_grove(refined_tree)
		else:
			_build_forest(refined_tree)
	else:
		_build_tree(refined_tree)
	_build_grass_chunks()
	if grove_demo and (
		"--capture-focal-front" in arguments
		or "--capture-focal-side" in arguments
		or "--capture-upright-front" in arguments
		or "--capture-upright-side" in arguments
	):
		var camera := get_node("OrbitCamera") as Camera3D
		camera.set_process(false)
		var capture_upright := (
			"--capture-upright-front" in arguments
			or "--capture-upright-side" in arguments
		)
		var tree_origin := (
			Vector3(5.2, 0.0, 3.0)
			if capture_upright
			else Vector3(-9.8, 0.0, 5.5)
		)
		var tree_target := tree_origin + Vector3(
			0.0,
			9.2 if capture_upright else 7.2,
			0.0
		)
		var from_side := (
			"--capture-focal-side" in arguments
			or "--capture-upright-side" in arguments
		)
		var camera_distance := 20.0 if capture_upright else 17.0
		camera.position = tree_target + (
			Vector3(
				camera_distance if capture_upright else -camera_distance,
				0.0,
				0.0
			)
			if from_side
			else Vector3(0.0, 0.0, camera_distance)
		)
		camera.look_at(tree_target, Vector3.UP)
		get_node("Instructions").hide()
		var capture_prefix := "vegetation_upright" if capture_upright else "vegetation_focal"
		_capture_test_frame("%s_%s.png" % [capture_prefix, "side" if from_side else "front"])
	elif grove_demo and "--capture-ground" in arguments:
		var camera := get_node("OrbitCamera") as Camera3D
		camera.set_process(false)
		camera.position = Vector3(-18.0, 2.6, 19.0)
		camera.look_at(Vector3(-2.0, 3.5, -5.0), Vector3.UP)
		get_node("Instructions").hide()
		_capture_test_frame("vegetation_grove_ground.png")
	elif "--capture-top" in arguments:
		var camera := get_node("OrbitCamera") as Camera3D
		camera.set_process(false)
		camera.position = Vector3(0.0, 68.0 if biome_demo else 52.0, 0.01)
		camera.look_at(Vector3(0.0, 0.0 if biome_demo else 3.6, 0.0), Vector3.FORWARD)
		var top_name := "vegetation_grove_top.png" if grove_demo else (
			"vegetation_biome_top.png" if biome_demo else (
			"vegetation_test_refined_top.png" if refined_tree else "vegetation_test_top.png"
		))
		_capture_test_frame(top_name)
	elif "--capture-left" in arguments or "--capture-right" in arguments:
		var camera := get_node("OrbitCamera") as Camera3D
		camera.set_process(false)
		var target := Vector3(0.0, 2.25, 0.0)
		var angle := -45.0 if "--capture-left" in arguments else 45.0
		camera.position = target + Basis(Vector3.UP, deg_to_rad(angle)) * (camera.position - target)
		camera.look_at(target, Vector3.UP)
		var side := "left" if angle < 0.0 else "right"
		var model := "refined" if refined_tree else "baseline"
		var prefix := "vegetation_grove" if grove_demo else (
			"vegetation_biome" if biome_demo else "vegetation_test_%s" % model
		)
		_capture_test_frame("%s_%s.png" % [prefix, side])
	elif "--capture" in arguments:
		var filename := "vegetation_grove.png" if grove_demo else (
			"vegetation_biome.png" if biome_demo else (
			"vegetation_test_refined.png" if refined_tree else "vegetation_test.png"
		))
		_capture_test_frame(filename)


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

	if biome_demo:
		var biome_material := ShaderMaterial.new()
		biome_material.shader = BIOME_GROUND_SHADER
		_set_biome_transition_parameters(biome_material)
		biome_material.set_shader_parameter("ground_dry", ground_dry_color)
		biome_material.set_shader_parameter("ground_green", ground_green_color)
		ground_mesh.material = biome_material
	else:
		var ground_material := StandardMaterial3D.new()
		# Ground gaps stay darker but in the same straw color family.
		ground_material.albedo_color = ground_dry_color
		ground_material.roughness = 0.98
		ground_material.metallic = 0.0
		ground_mesh.material = ground_material

	var ground := MeshInstance3D.new()
	ground.name = "CircularGround"
	ground.mesh = ground_mesh
	ground.position.y = -0.175
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(ground)


func _build_tree(refined_tree: bool = true) -> void:
	var tree: Node3D = (TREE_MODEL_REFINED if refined_tree else TREE_MODEL).instantiate()
	tree.name = "HeroTree"
	tree.scale = Vector3.ONE * 1.12
	add_child(tree)
	_configure_tree(tree, _create_tree_leaf_material(false), Color.WHITE)


func _build_forest(refined_tree: bool) -> void:
	var forest := Node3D.new()
	forest.name = "TreeGrove"
	add_child(forest)
	var leaf_material := _create_tree_leaf_material(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260920
	var tint_variants := [
		Color(0.96, 0.98, 0.96),
		Color(1.04, 1.00, 0.96),
		Color(0.93, 1.00, 0.93),
		Color(1.00, 1.03, 0.98),
		Color(1.06, 0.96, 0.93),
	]
	for row in range(6):
		for column in range(6):
			var point := Vector2(
				(float(column) - 2.5) * 6.0 + rng.randf_range(-0.9, 0.9),
				(float(row) - 2.5) * 6.0 + rng.randf_range(-0.9, 0.9)
			)
			if point.length() > GROUND_RADIUS - 3.4:
				continue
			var tree: Node3D = (TREE_MODEL_REFINED if refined_tree else TREE_MODEL).instantiate()
			tree.name = "Tree_%d_%d" % [row, column]
			tree.position = Vector3(point.x, 0.0, point.y)
			tree.rotation.y = rng.randf_range(-PI, PI)
			tree.scale = Vector3.ONE * rng.randf_range(0.85, 1.15)
			forest.add_child(tree)
			var tint: Color = tint_variants[rng.randi_range(0, tint_variants.size() - 1)]
			_configure_tree(tree, leaf_material, tint)


func _build_landscape_grove(refined_tree: bool) -> void:
	var forest := Node3D.new()
	forest.name = "LandscapeGrove"
	add_child(forest)
	var leaf_material := _create_tree_leaf_material(true)
	var tree_model: PackedScene = TREE_MODEL_REFINED if refined_tree else TREE_MODEL
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260921
	var tint_variants: Array[Color] = [
		Color(0.96, 0.98, 0.96),
		Color(1.04, 1.00, 0.96),
		Color(0.93, 1.00, 0.93),
		Color(1.00, 1.03, 0.98),
		Color(1.06, 0.96, 0.93),
	]
	# A continuous central/foreground grass bay is deliberately left empty.
	# The principal grove runs off the back/right edge instead of forming a round island.
	_add_grove_group(forest, tree_model, leaf_material, rng, tint_variants, "Main", PackedVector2Array([
		Vector2(-1.0, -16.0), Vector2(3.6, -17.8), Vector2(8.2, -16.1),
		Vector2(13.0, -14.0), Vector2(17.2, -10.5), Vector2(18.5, -5.6),
		Vector2(13.5, -7.5), Vector2(8.7, -10.2), Vector2(4.0, -11.2),
		Vector2(11.5, -3.8), Vector2(3.5, -3.5), Vector2(8.8, -1.0),
		Vector2(14.2, -0.5),
	]))
	_add_grove_group(forest, tree_model, leaf_material, rng, tint_variants, "BackLeft", PackedVector2Array([
		Vector2(-15.0, -12.0), Vector2(-11.0, -15.0), Vector2(-9.0, -10.0),
	]))
	_add_grove_group(forest, tree_model, leaf_material, rng, tint_variants, "RightFront", PackedVector2Array([
		Vector2(10.0, 7.5), Vector2(13.8, 8.8), Vector2(9.2, 12.2),
		Vector2(14.0, 13.2),
	]))
	# The large tree is assembled from thirty reduced copies of the accepted v10
	# crown. Each group keeps the old tree's density, normals and silhouette.
	var large_tree_material := _create_tree_leaf_material(true)
	large_tree_material.set_shader_parameter("use_view_angle_fade", true)
	# Remove only genuinely edge-on cards. The narrow band preserves canopy
	# density while preventing parallel sheets from reading as visible slivers.
	large_tree_material.set_shader_parameter("view_angle_fade_start", 0.020)
	large_tree_material.set_shader_parameter("view_angle_fade_end", 0.140)
	var focal_tree: Node3D = TREE_MODEL_BROAD_CLUSTERED.instantiate()
	focal_tree.name = "BroadClusteredComparisonTree"
	focal_tree.position = Vector3(-9.8, 0.0, 5.5)
	focal_tree.rotation.y = 0.58
	focal_tree.scale = Vector3.ONE
	forest.add_child(focal_tree)
	_configure_tree(focal_tree, large_tree_material, Color(1.04, 1.01, 0.97))
	_configure_large_tree_shading(
		focal_tree,
		Vector3(0.0, 7.875, 0.0),
		Vector3(6.65, 5.295, 6.655),
		0.34
	)

	# Keep the second accepted large-tree form visible in the same lighting test.
	# It is offset in depth so the two silhouettes remain independently readable.
	var upright_tree: Node3D = TREE_MODEL_UPRIGHT.instantiate()
	upright_tree.name = "UprightAsymmetricTree"
	upright_tree.position = Vector3(5.2, 0.0, 3.0)
	upright_tree.rotation.y = -0.42
	upright_tree.scale = Vector3.ONE
	forest.add_child(upright_tree)
	_configure_tree(upright_tree, large_tree_material, Color(1.04, 1.01, 0.97))
	_configure_large_tree_shading(
		upright_tree,
		Vector3(0.085, 8.912, -0.250),
		Vector3(7.145, 7.423, 7.135),
		0.34
	)


func _add_grove_group(
	forest: Node3D,
	tree_model: PackedScene,
	leaf_material: ShaderMaterial,
	rng: RandomNumberGenerator,
	tint_variants: Array[Color],
	group_name: String,
	points: PackedVector2Array
) -> void:
	for index in points.size():
		var tree: Node3D = tree_model.instantiate()
		tree.name = "%s_%02d" % [group_name, index]
		tree.position = Vector3(points[index].x, 0.0, points[index].y)
		tree.rotation.y = rng.randf_range(-PI, PI)
		tree.scale = Vector3.ONE * rng.randf_range(0.94, 1.13)
		forest.add_child(tree)
		_configure_tree(tree, leaf_material, tint_variants[rng.randi_range(0, tint_variants.size() - 1)])


func _create_tree_leaf_material(use_biome: bool) -> ShaderMaterial:
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
	if use_biome:
		leaf_material.set_shader_parameter("use_biome_palette", true)
		_set_biome_transition_parameters(leaf_material)
		leaf_material.set_shader_parameter("palette_dry", tree_dry_tint)
		leaf_material.set_shader_parameter("palette_green", tree_green_tint)
	return leaf_material


func _configure_tree(tree: Node3D, leaf_material: ShaderMaterial, tint: Color) -> void:
	_apply_material_to_named_meshes(tree, "foliage", leaf_material)
	_set_tint_for_named_meshes(tree, "foliage", tint)
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


func _configure_large_tree_shading(
	tree: Node3D,
	canopy_center_local: Vector3,
	canopy_radii: Vector3,
	local_normal_weight: float
) -> void:
	_set_large_tree_shading_parameters(
		tree,
		tree.global_position,
		tree.to_global(canopy_center_local),
		canopy_radii * tree.scale,
		local_normal_weight,
		true
	)


func _set_large_tree_shading_parameters(
	node: Node,
	palette_anchor_world: Vector3,
	canopy_center_world: Vector3,
	canopy_radii: Vector3,
	local_normal_weight: float,
	use_canopy_normal: bool
) -> void:
	if node is MeshInstance3D and "foliage" in node.name.to_lower():
		node.set_instance_shader_parameter("use_tree_palette_anchor", 1.0)
		node.set_instance_shader_parameter("tree_palette_anchor_world", palette_anchor_world)
		node.set_instance_shader_parameter(
			"use_tree_canopy_normal",
			1.0 if use_canopy_normal else 0.0
		)
		node.set_instance_shader_parameter("tree_canopy_center_world", canopy_center_world)
		node.set_instance_shader_parameter("tree_canopy_radii", canopy_radii)
		node.set_instance_shader_parameter("tree_local_normal_weight", local_normal_weight)
	for child in node.get_children():
		_set_large_tree_shading_parameters(
			child,
			palette_anchor_world,
			canopy_center_world,
			canopy_radii,
			local_normal_weight,
			use_canopy_normal
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
	if biome_demo:
		grass_material.set_shader_parameter("use_biome_palette", true)
		grass_material.set_shader_parameter("use_multimesh_color_data", true)
		_set_biome_transition_parameters(grass_material)
		grass_material.set_shader_parameter("palette_dry", grass_dry_tint)
		grass_material.set_shader_parameter("palette_green", grass_green_tint)
		grass_material.set_shader_parameter("biome_instance_overlap", grass_color_overlap)
	grass_mesh.surface_set_material(0, grass_material)

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260914
	var chunk_transforms := {}
	var chunk_color_data := {}
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
			if biome_demo:
				chunk_color_data[key] = []
		var yaw := rng.randf_range(0.0, TAU)
		var width_scale := rng.randf_range(0.70, 1.00)
		var height_scale := rng.randf_range(0.72, 0.96)
		var lean := rng.randf_range(-0.16, 0.16)
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, lean)
		basis = basis.scaled(Vector3(width_scale, height_scale, width_scale))
		var transform := Transform3D(basis, Vector3(point.x, 0.02, point.y))
		chunk_transforms[key].append(transform)
		if biome_demo:
			chunk_color_data[key].append(Color(rng.randf(), rng.randf(), 0.0, 1.0))

	var grass_root := Node3D.new()
	grass_root.name = "GrassChunks"
	add_child(grass_root)
	for key in chunk_transforms:
		var transforms: Array = chunk_transforms[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_custom_data = biome_demo
		multimesh.mesh = grass_mesh
		multimesh.instance_count = transforms.size()
		for index in transforms.size():
			multimesh.set_instance_transform(index, transforms[index])
			if biome_demo:
				multimesh.set_instance_custom_data(index, chunk_color_data[key][index])
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


func _set_biome_transition_parameters(material: ShaderMaterial) -> void:
	material.set_shader_parameter("biome_noise_texture", biome_noise_texture)
	material.set_shader_parameter("biome_transition_half_width", biome_transition_half_width)
	material.set_shader_parameter("biome_warp_distance", biome_warp_distance)
	material.set_shader_parameter("biome_center_x", biome_center_x)


func _create_biome_noise_texture() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = 20260920
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.018
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 2
	noise.fractal_gain = 0.48
	noise.domain_warp_enabled = true
	noise.domain_warp_type = FastNoiseLite.DOMAIN_WARP_SIMPLEX
	noise.domain_warp_amplitude = 9.0
	noise.domain_warp_frequency = 0.012

	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.noise = noise
	texture.normalize = true
	texture.seamless = true
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


func _set_tint_for_named_meshes(node: Node, token: String, tint: Color) -> void:
	if node is MeshInstance3D and token.to_lower() in node.name.to_lower():
		node.set_instance_shader_parameter("variant_tint", tint)
	for child in node.get_children():
		_set_tint_for_named_meshes(child, token, tint)


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
	elif filename == "vegetation_test_refined.png":
		await get_tree().create_timer(10.0).timeout
		await RenderingServer.frame_post_draw
		var later_image := get_viewport().get_texture().get_image()
		var later_error := later_image.save_png(
			"res://screenshots/vegetation_test_refined_wind_10s.png"
		)
		if later_error != OK:
			push_error("Could not save refined wind frame: %s" % error_string(later_error))
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
