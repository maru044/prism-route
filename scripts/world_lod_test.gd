extends Node3D

const TERRAIN_SHADER := preload("res://assets/world/terrain/shaders/terrain_draft.gdshader")
const SKY_TEXTURE := preload("res://assets/environment/hdri/rosendal_park_sunset_puresky_4k.exr")

@onready var terrain_source: Node3D = $TerrainSource
@onready var camper = $CamperVan
@onready var vegetation = $VegetationLodStreamer
@onready var info_label: Label = $HUD/Info
@onready var status_label: Label = $HUD/Status

var primary_terrain: MeshInstance3D
var lod_enabled := true
var vegetation_enabled := true
var capture_requested := false
var capture_stress_mode := false
var biome_noise_texture: NoiseTexture2D


func _ready() -> void:
	var arguments := OS.get_cmdline_user_args()
	capture_requested = "--capture-world-lod" in arguments or "--capture" in arguments
	capture_stress_mode = "--capture-world-lod-stress" in arguments
	capture_requested = capture_requested or capture_stress_mode
	_build_environment()
	biome_noise_texture = _create_biome_noise_texture()
	_prepare_terrain()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_place_camper_on_terrain()
	vegetation.initialize(camper, biome_noise_texture)
	if capture_stress_mode:
		lod_enabled = false
		vegetation.set_lod_enabled(false)
	if capture_requested:
		await get_tree().create_timer(8.0).timeout
		_capture_frame()


func _process(_delta: float) -> void:
	if Input.is_key_pressed(KEY_L) and not Input.is_key_pressed(KEY_SHIFT):
		if not has_meta("lod_key_down"):
			set_meta("lod_key_down", true)
			lod_enabled = not lod_enabled
			vegetation.set_lod_enabled(lod_enabled)
	else:
		remove_meta("lod_key_down")

	if Input.is_key_pressed(KEY_V):
		if not has_meta("vegetation_key_down"):
			set_meta("vegetation_key_down", true)
			vegetation_enabled = not vegetation_enabled
			vegetation.set_vegetation_enabled(vegetation_enabled)
	else:
		remove_meta("vegetation_key_down")

	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var primitives := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	status_label.text = (
		"FPS %d    %.1f km/h    Draws %d    Primitives %s\n"
		% [
			Engine.get_frames_per_second(),
			camper.get_speed_kph(),
			draws,
			_format_count(primitives),
		]
		+ "LOD %s    Vegetation %s    Grass chunks %d (+%d loading)    Trees %d (large %d)"
		% [
			"ON" if lod_enabled else "OFF / stress",
			"ON" if vegetation_enabled else "OFF",
			vegetation.get_active_grass_chunk_count(),
			vegetation.get_pending_grass_chunk_count(),
			vegetation.tree_instance_count,
			vegetation.large_tree_instance_count,
		]
	)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_TAB:
		get_tree().change_scene_to_file("res://scenes/vegetation_grove_test.tscn")


func _build_environment() -> void:
	var panorama_material := PanoramaSkyMaterial.new()
	panorama_material.panorama = SKY_TEXTURE
	panorama_material.energy_multiplier = 0.48
	var sky := Sky.new()
	sky.sky_material = panorama_material
	sky.radiance_size = Sky.RADIANCE_SIZE_1024

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
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
	environment.ssao_intensity = 1.20
	environment.ssao_power = 1.30
	$WorldEnvironment.environment = environment

	$Sun.rotation_degrees = Vector3(-43.0, -128.0, 0.0)
	$Sun.light_color = Color("ffe2b8")
	$Sun.light_energy = 0.72
	$Sun.shadow_enabled = true
	$Sun.directional_shadow_max_distance = 180.0


func _prepare_terrain() -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances(terrain_source, meshes)
	var greatest_height := -INF
	for mesh_instance in meshes:
		var height := mesh_instance.mesh.get_aabb().size.y
		if height > greatest_height:
			greatest_height = height
			primary_terrain = mesh_instance
	if primary_terrain == null:
		push_error("No terrain mesh was found in map.gltf")
		return
	for mesh_instance in meshes:
		mesh_instance.visible = mesh_instance == primary_terrain
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var terrain_material := ShaderMaterial.new()
		terrain_material.shader = TERRAIN_SHADER
		terrain_material.set_shader_parameter("biome_noise_texture", biome_noise_texture)
		mesh_instance.material_override = terrain_material
	_create_coast_cliff_skirt(primary_terrain)
	primary_terrain.create_trimesh_collision()
	for child in primary_terrain.get_children():
		if child is StaticBody3D:
			(child as StaticBody3D).collision_layer = 1
			(child as StaticBody3D).collision_mask = 0
			_enable_collision_backfaces(child)


func _create_coast_cliff_skirt(terrain: MeshInstance3D) -> void:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangle_count := 0
	for surface_index in terrain.mesh.get_surface_count():
		var arrays := terrain.mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			continue
		var edges: Dictionary = {}
		for index in range(0, indices.size(), 3):
			_register_edge(edges, indices[index], indices[index + 1])
			_register_edge(edges, indices[index + 1], indices[index + 2])
			_register_edge(edges, indices[index + 2], indices[index])
		var sea_local_y := terrain.to_local(Vector3(0.0, -0.42, 0.0)).y
		for key in edges:
			var edge: Dictionary = edges[key]
			if edge["count"] != 1:
				continue
			var top_a := vertices[edge["a"]] as Vector3
			var top_b := vertices[edge["b"]] as Vector3
			if maxf(top_a.y, top_b.y) <= sea_local_y + 0.55:
				continue
			var bottom_a := Vector3(top_a.x, sea_local_y, top_a.z)
			var bottom_b := Vector3(top_b.x, sea_local_y, top_b.z)
			_add_cliff_triangle(surface_tool, top_a, bottom_b, top_b)
			_add_cliff_triangle(surface_tool, top_a, bottom_a, bottom_b)
			triangle_count += 2
	if triangle_count == 0:
		return
	surface_tool.generate_normals()
	var cliff_node := MeshInstance3D.new()
	cliff_node.name = "GeneratedCoastCliffs"
	cliff_node.mesh = surface_tool.commit()
	cliff_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var cliff_material := ShaderMaterial.new()
	cliff_material.shader = TERRAIN_SHADER
	cliff_material.set_shader_parameter("biome_noise_texture", biome_noise_texture)
	cliff_material.set_shader_parameter("rock_bias", 0.44)
	cliff_node.material_override = cliff_material
	terrain.add_child(cliff_node)


func _register_edge(edges: Dictionary, first: int, second: int) -> void:
	var low := mini(first, second)
	var high := maxi(first, second)
	var key := "%d:%d" % [low, high]
	if edges.has(key):
		edges[key]["count"] += 1
	else:
		edges[key] = {"a": first, "b": second, "count": 1}


func _add_cliff_triangle(surface_tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface_tool.add_vertex(a)
	surface_tool.add_vertex(b)
	surface_tool.add_vertex(c)


func _create_biome_noise_texture() -> NoiseTexture2D:
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.normalize = true
	var noise := FastNoiseLite.new()
	noise.seed = 46129
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.48
	texture.noise = noise
	return texture


func _enable_collision_backfaces(node: Node) -> void:
	if node is CollisionShape3D:
		var collision_shape := node as CollisionShape3D
		if collision_shape.shape is ConcavePolygonShape3D:
			(collision_shape.shape as ConcavePolygonShape3D).backface_collision = true
	for child in node.get_children():
		_enable_collision_backfaces(child)


func _collect_mesh_instances(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_mesh_instances(child, result)


func _place_camper_on_terrain() -> void:
	var best_hit := {}
	var best_score := INF
	for grid_x in range(-5, 6):
		for grid_z in range(-5, 6):
			var x := float(grid_x) * 65.0
			var z := float(grid_z) * 65.0
			var hit := _raycast_terrain(x, z)
			if hit.is_empty():
				continue
			var normal := hit.normal as Vector3
			var position := hit.position as Vector3
			if normal.y < 0.91 or position.y < 2.0 or position.y > 95.0:
				continue
			var score := Vector2(x, z).length() * 0.01
			score += abs(position.y - 28.0) * 0.035
			score += (1.0 - normal.y) * 20.0
			if score < best_score:
				best_score = score
				best_hit = hit
	if best_hit.is_empty():
		best_hit = _raycast_terrain(0.0, 0.0)
	if best_hit.is_empty():
		push_error("Could not find a driveable spawn point on the terrain")
		return
	var spawn_position := best_hit.position as Vector3
	camper.global_position = spawn_position + Vector3.UP * 0.32
	camper.rotation = Vector3.ZERO
	camper.set_respawn_transform(camper.global_transform)
	info_label.text += "\nSpawn: %.0f, %.1f, %.0f m" % [
		spawn_position.x, spawn_position.y, spawn_position.z
	]


func _raycast_terrain(x: float, z: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.new()
	query.from = Vector3(x, 320.0, z)
	query.to = Vector3(x, -30.0, z)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_world_3d().direct_space_state.intersect_ray(query)


func _format_count(value: int) -> String:
	if value >= 1000000:
		return "%.2fM" % (value / 1000000.0)
	if value >= 1000:
		return "%.1fk" % (value / 1000.0)
	return str(value)


func _capture_frame() -> void:
	var image := get_viewport().get_texture().get_image()
	var output_path := (
		"res://screenshots/world_lod_drive_stress.png"
		if capture_stress_mode
		else "res://screenshots/world_lod_drive_test.png"
	)
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Failed to save %s: %s" % [output_path, error_string(error)])
	else:
		print("Saved ", ProjectSettings.globalize_path(output_path))
	print(
		"LOD_METRICS mode=%s fps=%d draws=%d primitives=%d grass_chunks=%d trees=%d large_trees=%d"
		% [
			"stress_lod0" if capture_stress_mode else "lod_enabled",
			Engine.get_frames_per_second(),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
			vegetation.get_active_grass_chunk_count(),
			vegetation.tree_instance_count,
			vegetation.large_tree_instance_count,
		]
	)
	get_tree().quit()
