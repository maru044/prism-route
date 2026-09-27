extends Node3D

const GRASS_CHUNK_SIZE := 24.0
const GRASS_KEEP_RADIUS := 120.0
const GRASS_NEAR_END := 52.0
const GRASS_FAR_END := 96.0
# Match the focused test: 63,000 instances over a 24 m radius disk is about
# 35 instances/m². Four nearby blades share one terrain sample to keep chunk
# streaming affordable while preserving that actual instance density.
const GRASS_SAMPLES_PER_CHUNK := 5200
const GRASS_BLADES_PER_SAMPLE := 4
const TREE_CHUNK_SIZE := 96.0
const TREE_CULL_END := 900.0
const TREE_TARGET_COUNT := 5000
const ISLAND_HALF_EXTENTS := Vector2(1285.0, 1494.0)

const GRASS_SCENE := preload("res://assets/vegetation/models/grass_star_3card_v6.glb")
const TREE_NEAR_SCENE := preload("res://assets/vegetation/models/tree_small_broad_canopy.glb")
const TREE_LARGE_BROAD_SCENE := preload("res://assets/vegetation/models/tree_medium_broad_clustered_canopy.glb")
const TREE_LARGE_UPRIGHT_SCENE := preload("res://assets/vegetation/models/tree_medium_upright_asymmetric_canopy.glb")
const VEGETATION_SHADER := preload("res://assets/vegetation/shaders/vegetation_wind.gdshader")
const GRASS_TEXTURE := preload("res://assets/vegetation/textures/grass_tuft_straw_minimal_v5.png")
const LEAF_TEXTURE := preload("res://assets/vegetation/textures/leaf_clusters_witness_sparse_flat_v11.png")

var target: Node3D
var initialized := false
var lod_enabled := true
var vegetation_enabled := true
var active_grass_chunks: Dictionary[Vector2i, Node3D] = {}
var queued_grass_cells: Dictionary[Vector2i, bool] = {}
var grass_build_queue: Array[Vector2i] = []
var grass_lod0_nodes: Array[MultiMeshInstance3D] = []
var grass_lod1_nodes: Array[MultiMeshInstance3D] = []
var tree_lod0_nodes: Array[MultiMeshInstance3D] = []
var tree_lod1_nodes: Array[MultiMeshInstance3D] = []
var large_tree_nodes: Array[MeshInstance3D] = []
var tree_instance_count := 0
var large_tree_instance_count := 0
var update_accumulator := 0.0

var grass_mesh: Mesh
var tree_near_trunk_mesh: Mesh
var tree_near_leaf_mesh: Mesh
var tree_large_broad_trunk_mesh: Mesh
var tree_large_broad_leaf_mesh: Mesh
var tree_large_upright_trunk_mesh: Mesh
var tree_large_upright_leaf_mesh: Mesh
var grass_material: ShaderMaterial
var leaf_material: ShaderMaterial
var trunk_material: StandardMaterial3D
var biome_noise_texture: NoiseTexture2D


func initialize(target_node: Node3D, shared_biome_noise: NoiseTexture2D) -> void:
	target = target_node
	biome_noise_texture = shared_biome_noise
	_load_meshes_and_materials()
	_build_tree_lod()
	initialized = true
	_refresh_grass_cells()


func _process(delta: float) -> void:
	if not initialized or target == null:
		return
	update_accumulator += delta
	if update_accumulator >= 0.35:
		update_accumulator = 0.0
		_refresh_grass_cells()
	if not grass_build_queue.is_empty():
		var cell: Vector2i = grass_build_queue.pop_front()
		queued_grass_cells.erase(cell)
		if not active_grass_chunks.has(cell):
			_build_grass_chunk(cell)


func _load_meshes_and_materials() -> void:
	grass_mesh = _extract_first_mesh(GRASS_SCENE)
	var near_meshes := _extract_tree_meshes(TREE_NEAR_SCENE)
	tree_near_trunk_mesh = near_meshes[0]
	tree_near_leaf_mesh = near_meshes[1]
	var large_broad_meshes := _extract_tree_meshes(TREE_LARGE_BROAD_SCENE)
	tree_large_broad_trunk_mesh = large_broad_meshes[0]
	tree_large_broad_leaf_mesh = large_broad_meshes[1]
	var large_upright_meshes := _extract_tree_meshes(TREE_LARGE_UPRIGHT_SCENE)
	tree_large_upright_trunk_mesh = large_upright_meshes[0]
	tree_large_upright_leaf_mesh = large_upright_meshes[1]

	var wind_noise := NoiseTexture2D.new()
	wind_noise.width = 512
	wind_noise.height = 512
	wind_noise.seamless = true
	wind_noise.normalize = true
	var fast_noise := FastNoiseLite.new()
	fast_noise.seed = 1947
	fast_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fast_noise.frequency = 0.018
	fast_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	fast_noise.fractal_octaves = 3
	wind_noise.noise = fast_noise

	grass_material = ShaderMaterial.new()
	grass_material.shader = VEGETATION_SHADER
	grass_material.set_shader_parameter("albedo_texture", GRASS_TEXTURE)
	grass_material.set_shader_parameter("alpha_cutoff", 0.34)
	grass_material.set_shader_parameter("alpha_antialiasing_edge", 0.20)
	grass_material.set_shader_parameter("light_wrap", 0.46)
	grass_material.set_shader_parameter("use_noise_wind", true)
	grass_material.set_shader_parameter("wind_noise_texture", wind_noise)
	grass_material.set_shader_parameter("wind_direction", Vector2(0.88, 0.34).normalized())
	grass_material.set_shader_parameter("wind_strength", 0.085)
	grass_material.set_shader_parameter("wind_speed", 1.08)
	grass_material.set_shader_parameter("wind_noise_world_scale", 0.018)
	grass_material.set_shader_parameter("wind_noise_scroll_speed", 0.035)
	grass_material.set_shader_parameter("wind_tone_strength", 0.18)
	grass_material.set_shader_parameter("root_tone", 0.93)
	grass_material.set_shader_parameter("tip_tone", 1.025)
	grass_material.set_shader_parameter("use_biome_palette", true)
	grass_material.set_shader_parameter("biome_noise_texture", biome_noise_texture)
	# These are restrained multipliers, not replacement albedo colours.
	grass_material.set_shader_parameter("palette_dry", Color.WHITE)
	grass_material.set_shader_parameter("palette_green", Color(0.77, 0.88, 0.78))
	grass_material.set_shader_parameter("biome_noise_scale", 0.00135)
	grass_material.set_shader_parameter("biome_warp_distance", 210.0)
	grass_material.set_shader_parameter("biome_transition_half_width", 135.0)
	grass_material.set_shader_parameter("biome_center_x", 20.0)
	grass_material.set_shader_parameter("biome_instance_overlap", 35.0)

	leaf_material = ShaderMaterial.new()
	leaf_material.shader = VEGETATION_SHADER
	leaf_material.set_shader_parameter("albedo_texture", LEAF_TEXTURE)
	leaf_material.set_shader_parameter("alpha_cutoff", 0.50)
	leaf_material.set_shader_parameter("alpha_antialiasing_edge", 0.30)
	leaf_material.set_shader_parameter("atlas_grid", Vector2(2.0, 2.0))
	leaf_material.set_shader_parameter("card_edge_fade", 0.075)
	leaf_material.set_shader_parameter("light_wrap", 0.34)
	leaf_material.set_shader_parameter("wind_strength", 0.075)
	leaf_material.set_shader_parameter("wind_speed", 0.72)
	leaf_material.set_shader_parameter("use_view_angle_fade", true)
	leaf_material.set_shader_parameter("view_angle_fade_start", 0.020)
	leaf_material.set_shader_parameter("view_angle_fade_end", 0.140)
	leaf_material.set_shader_parameter("species_noise_texture", biome_noise_texture)
	leaf_material.set_shader_parameter("species_noise_scale", 0.052)
	leaf_material.set_shader_parameter("species_texture_detail", 0.08)
	leaf_material.set_shader_parameter("species_light_ramp_start", -0.05)
	leaf_material.set_shader_parameter("species_light_ramp_end", 0.62)
	leaf_material.set_shader_parameter("species_shadow_band_start", -0.38)
	leaf_material.set_shader_parameter("species_shadow_band_end", -0.02)
	leaf_material.set_shader_parameter("species_mid_band_start", -0.10)
	leaf_material.set_shader_parameter("species_mid_band_end", 0.30)
	leaf_material.set_shader_parameter("species_sun_band_start", 0.16)
	leaf_material.set_shader_parameter("species_sun_band_end", 0.58)
	leaf_material.set_shader_parameter("species_direct_strength", 0.72)
	leaf_material.set_shader_parameter("species_art_direct_strength", 0.95)
	leaf_material.set_shader_parameter("species_light_warp_scale", 0.018)
	leaf_material.set_shader_parameter("species_light_warp_amount", 0.055)

	trunk_material = StandardMaterial3D.new()
	trunk_material.albedo_color = Color("594238")
	trunk_material.roughness = 0.92


func _extract_first_mesh(scene: PackedScene) -> Mesh:
	var instance := scene.instantiate()
	var meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances(instance, meshes)
	if meshes.is_empty():
		instance.free()
		return null
	var result := meshes[0].mesh.duplicate(true) as Mesh
	instance.free()
	return result


func _extract_tree_meshes(scene: PackedScene) -> Array[Mesh]:
	var instance := scene.instantiate()
	var meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances(instance, meshes)
	var trunk := _merge_tree_meshes(instance, meshes, true)
	var leaves := _merge_tree_meshes(instance, meshes, false)
	instance.free()
	return [trunk, leaves]


func _merge_tree_meshes(
	root: Node,
	meshes: Array[MeshInstance3D],
	want_trunk: bool
) -> Mesh:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var appended := false
	for mesh_instance in meshes:
		var name_lower := mesh_instance.name.to_lower()
		var is_trunk := "trunk" in name_lower
		var is_foliage := "foliage" in name_lower or "leaf" in name_lower
		if (want_trunk and not is_trunk) or (not want_trunk and not is_foliage):
			continue
		var relative_transform := _transform_relative_to_root(mesh_instance, root)
		for surface_index in mesh_instance.mesh.get_surface_count():
			surface_tool.append_from(
				mesh_instance.mesh, surface_index, relative_transform
			)
			appended = true
	if not appended:
		return null
	return surface_tool.commit()


func _transform_relative_to_root(node: Node3D, root: Node) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent != null and parent != root:
		if parent is Node3D:
			result = (parent as Node3D).transform * result
		parent = parent.get_parent()
	return result


func _collect_mesh_instances(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_mesh_instances(child, result)


func _refresh_grass_cells() -> void:
	var center := Vector2(target.global_position.x, target.global_position.z)
	var center_cell := Vector2i(
		floori(center.x / GRASS_CHUNK_SIZE),
		floori(center.y / GRASS_CHUNK_SIZE)
	)
	var cell_radius := ceili(GRASS_KEEP_RADIUS / GRASS_CHUNK_SIZE)
	for offset_x in range(-cell_radius, cell_radius + 1):
		for offset_y in range(-cell_radius, cell_radius + 1):
			var cell := center_cell + Vector2i(offset_x, offset_y)
			var cell_center := Vector2(
				(cell.x + 0.5) * GRASS_CHUNK_SIZE,
				(cell.y + 0.5) * GRASS_CHUNK_SIZE
			)
			if cell_center.distance_to(center) > GRASS_KEEP_RADIUS:
				continue
			if not active_grass_chunks.has(cell) and not queued_grass_cells.has(cell):
				grass_build_queue.append(cell)
				queued_grass_cells[cell] = true

	var remove_cells: Array[Vector2i] = []
	for cell in active_grass_chunks:
		var cell_center := Vector2(
			(cell.x + 0.5) * GRASS_CHUNK_SIZE,
			(cell.y + 0.5) * GRASS_CHUNK_SIZE
		)
		if cell_center.distance_to(center) > GRASS_KEEP_RADIUS + GRASS_CHUNK_SIZE * 1.5:
			remove_cells.append(cell)
	for cell in remove_cells:
		var chunk := active_grass_chunks[cell] as Node3D
		_remove_chunk_nodes_from_tracking(chunk)
		chunk.queue_free()
		active_grass_chunks.erase(cell)


func _build_grass_chunk(cell: Vector2i) -> void:
	var chunk_origin := Vector3(
		cell.x * GRASS_CHUNK_SIZE,
		0.0,
		cell.y * GRASS_CHUNK_SIZE
	)
	var near_transforms: Array[Transform3D] = []
	var far_transforms: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = _cell_seed(cell, 0x4A31)
	var blade_index := 0
	for _sample in GRASS_SAMPLES_PER_CHUNK:
		var local_x := rng.randf_range(0.0, GRASS_CHUNK_SIZE)
		var local_z := rng.randf_range(0.0, GRASS_CHUNK_SIZE)
		var world_x := chunk_origin.x + local_x
		var world_z := chunk_origin.z + local_z
		var hit := _raycast_terrain(world_x, world_z)
		if hit.is_empty() or (hit.normal as Vector3).y < 0.72:
			continue
		var hit_position := hit.position as Vector3
		var hit_normal := hit.normal as Vector3
		for blade in GRASS_BLADES_PER_SAMPLE:
			var offset := Vector2.ZERO
			if blade > 0:
				offset = Vector2(
					rng.randf_range(-0.34, 0.34),
					rng.randf_range(-0.34, 0.34)
				)
			var height_offset := 0.0
			if absf(hit_normal.y) > 0.01:
				height_offset = -(
					hit_normal.x * offset.x + hit_normal.z * offset.y
				) / hit_normal.y
			var yaw := rng.randf_range(0.0, TAU)
			var width_scale := rng.randf_range(0.88, 1.28)
			var height_scale := rng.randf_range(0.90, 1.16)
			var basis := Basis(Vector3.UP, yaw).scaled(
				Vector3(width_scale, height_scale, width_scale)
			)
			var transform := Transform3D(
				basis,
				Vector3(
					local_x + offset.x,
					hit_position.y + height_offset + 0.025,
					local_z + offset.y
				)
			)
			near_transforms.append(transform)
			if blade_index % 5 == 0:
				var far_transform := transform
				far_transform.basis = far_transform.basis.scaled(
					Vector3(1.32, 1.04, 1.32)
				)
				far_transforms.append(far_transform)
			blade_index += 1

	if near_transforms.is_empty():
		return
	var chunk := Node3D.new()
	chunk.name = "GrassChunk_%d_%d" % [cell.x, cell.y]
	chunk.position = chunk_origin
	add_child(chunk)
	var near_node := _make_multimesh_node(
		"Grass_LOD0", grass_mesh, near_transforms, grass_material, 0.0, GRASS_NEAR_END
	)
	near_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunk.add_child(near_node)
	grass_lod0_nodes.append(near_node)
	if not far_transforms.is_empty():
		var far_node := _make_multimesh_node(
			"Grass_LOD1", grass_mesh, far_transforms, grass_material,
			GRASS_NEAR_END, GRASS_FAR_END
		)
		far_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chunk.add_child(far_node)
		grass_lod1_nodes.append(far_node)
	active_grass_chunks[cell] = chunk
	_apply_lod_state_to_chunk(chunk)


func _build_tree_lod() -> void:
	large_tree_instance_count = 0
	var distribution_noise := FastNoiseLite.new()
	distribution_noise.seed = 7291
	distribution_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	distribution_noise.frequency = 0.0017
	distribution_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	distribution_noise.fractal_octaves = 3
	var rng := RandomNumberGenerator.new()
	rng.seed = 910247
	var buckets: Dictionary = {}
	var large_tree_records: Array[Dictionary] = []
	var accepted := 0
	var attempts := 0
	while accepted < TREE_TARGET_COUNT and attempts < TREE_TARGET_COUNT * 8:
		attempts += 1
		var world_x := rng.randf_range(-ISLAND_HALF_EXTENTS.x, ISLAND_HALF_EXTENTS.x)
		var world_z := rng.randf_range(-ISLAND_HALF_EXTENTS.y, ISLAND_HALF_EXTENTS.y)
		if Vector2(world_x, world_z).distance_to(
			Vector2(target.global_position.x, target.global_position.z)
		) < 24.0:
			continue
		if distribution_noise.get_noise_2d(world_x, world_z) < -0.08:
			continue
		var hit := _raycast_terrain(world_x, world_z)
		if hit.is_empty():
			continue
		var normal := hit.normal as Vector3
		var position := hit.position as Vector3
		if normal.y < 0.80 or position.y < 2.0:
			continue
		var cell := Vector2i(
			floori(world_x / TREE_CHUNK_SIZE),
			floori(world_z / TREE_CHUNK_SIZE)
		)
		var palette_id := _palette_for_cell(cell)
		var model_id := 0
		var accent_roll := _cell_seed(cell, 0x6D29) % 100
		# Match the two accepted seasonal large trees from the Ganyu test:
		# broad cherry and upright orange autumn. Each remains an individual
		# GeometryInstance so its canopy center/radii can drive the same normals.
		if palette_id == 1 and accent_roll < 35 and rng.randf() < 0.17:
			model_id = 1
		elif palette_id == 3 and accent_roll < 35 and rng.randf() < 0.17:
			model_id = 2
		var yaw := rng.randf_range(0.0, TAU)
		var scale_value := rng.randf_range(0.82, 1.30)
		var transform := Transform3D(
			Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale_value),
			position
		)
		if model_id > 0:
			large_tree_records.append({
				"transform": transform,
				"model": model_id,
				"palette": palette_id,
			})
			large_tree_instance_count += 1
		else:
			var bucket_key := "%d,%d,%d" % [cell.x, cell.y, palette_id]
			if not buckets.has(bucket_key):
				buckets[bucket_key] = {
					"cell": cell,
					"palette": palette_id,
					"transforms": [],
				}
			(buckets[bucket_key]["transforms"] as Array).append(transform)
		accepted += 1

	tree_instance_count = accepted
	for bucket_key in buckets:
		var bucket: Dictionary = buckets[bucket_key]
		var cell: Vector2i = bucket["cell"]
		var origin := Vector3(cell.x * TREE_CHUNK_SIZE, 0.0, cell.y * TREE_CHUNK_SIZE)
		var local_transforms: Array[Transform3D] = []
		for world_transform in bucket["transforms"]:
			var local_transform := world_transform as Transform3D
			local_transform.origin -= origin
			local_transforms.append(local_transform)
		var chunk := Node3D.new()
		chunk.name = "TreeChunk_%d_%d_P%d" % [
			cell.x, cell.y, bucket["palette"]
		]
		chunk.position = origin
		add_child(chunk)
		_add_tree_mesh_pair(chunk, "Tree_LOD0", tree_near_trunk_mesh, tree_near_leaf_mesh,
			local_transforms, 0.0, TREE_CULL_END, true, bucket["palette"])

	for index in large_tree_records.size():
		_add_large_tree_instance(large_tree_records[index], index)


func _palette_for_cell(cell: Vector2i) -> int:
	var value := _cell_seed(cell, 0x35B7) % 100
	if value < 7:
		return 1 # accepted A3 cherry
	if value < 14:
		return 2 # accepted A3 gold autumn
	if value < 20:
		return 3 # accepted A3 orange autumn
	if value < 25:
		return 4 # accepted A3 red autumn
	return 0


func _add_large_tree_instance(record: Dictionary, index: int) -> void:
	var model_id: int = record["model"]
	var tree_transform: Transform3D = record["transform"]
	var tree_root := Node3D.new()
	tree_root.name = "LargeTree_%03d_%s" % [
		index, "BroadCherry" if model_id == 1 else "UprightOrange"
	]
	tree_root.transform = tree_transform
	add_child(tree_root)

	var trunk_node := MeshInstance3D.new()
	trunk_node.name = "Trunk"
	trunk_node.mesh = (
		tree_large_broad_trunk_mesh if model_id == 1
		else tree_large_upright_trunk_mesh
	)
	trunk_node.material_override = trunk_material
	trunk_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	trunk_node.visibility_range_end = TREE_CULL_END
	trunk_node.set_meta("lod_end", TREE_CULL_END)
	tree_root.add_child(trunk_node)

	var leaf_node := MeshInstance3D.new()
	leaf_node.name = "Foliage"
	leaf_node.mesh = (
		tree_large_broad_leaf_mesh if model_id == 1
		else tree_large_upright_leaf_mesh
	)
	leaf_node.material_override = leaf_material
	leaf_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	leaf_node.visibility_range_end = TREE_CULL_END
	leaf_node.set_meta("lod_end", TREE_CULL_END)
	tree_root.add_child(leaf_node)

	_apply_tree_palette(leaf_node, record["palette"])
	leaf_node.set_instance_shader_parameter(
		"variant_tint", Color(1.04, 1.01, 0.97)
	)
	var canopy_center_local := (
		Vector3(0.0, 7.875, 0.0) if model_id == 1
		else Vector3(0.085, 8.912, -0.250)
	)
	var canopy_radii := (
		Vector3(6.65, 5.295, 6.655) if model_id == 1
		else Vector3(7.145, 7.423, 7.135)
	)
	leaf_node.set_instance_shader_parameter("use_tree_palette_anchor", 1.0)
	leaf_node.set_instance_shader_parameter(
		"tree_palette_anchor_world", tree_root.global_position
	)
	leaf_node.set_instance_shader_parameter("use_tree_canopy_normal", 1.0)
	leaf_node.set_instance_shader_parameter(
		"tree_canopy_center_world", tree_root.to_global(canopy_center_local)
	)
	leaf_node.set_instance_shader_parameter(
		"tree_canopy_radii", canopy_radii * tree_transform.basis.get_scale()
	)
	leaf_node.set_instance_shader_parameter("tree_local_normal_weight", 0.34)
	large_tree_nodes.append(trunk_node)
	large_tree_nodes.append(leaf_node)


func _add_tree_mesh_pair(
	parent: Node3D,
	prefix: String,
	trunk_mesh: Mesh,
	leaves_mesh: Mesh,
	transforms: Array[Transform3D],
	begin_distance: float,
	end_distance: float,
	is_near: bool,
	palette_id: int = 0
) -> void:
	var trunk_node := _make_multimesh_node(
		prefix + "_Trunks", trunk_mesh, transforms, trunk_material,
		begin_distance, end_distance
	)
	var leaf_node := _make_multimesh_node(
		prefix + "_Leaves", leaves_mesh, transforms, leaf_material,
		begin_distance, end_distance
	)
	# Match the accepted test scene: alpha-cut foliage shadows create dense dark
	# noise in groves, while the trunk alone provides grounding.
	leaf_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(trunk_node)
	parent.add_child(leaf_node)
	_apply_tree_palette(leaf_node, palette_id)
	if is_near:
		tree_lod0_nodes.append(trunk_node)
		tree_lod0_nodes.append(leaf_node)
	else:
		tree_lod1_nodes.append(trunk_node)
		tree_lod1_nodes.append(leaf_node)


func _apply_tree_palette(node: GeometryInstance3D, palette_id: int) -> void:
	if palette_id == 0:
		return
	var palettes := {
		1: [Color("b77f99"), Color("c18da5"), Color("e0b0c1"), Color("f1d2d9"), 0.17],
		2: [Color("a47d43"), Color("b58f4f"), Color("d1ad62"), Color("e6c982"), 0.39],
		3: [Color("a75448"), Color("b56550"), Color("d68162"), Color("e8a886"), 0.63],
		4: [Color("8c4359"), Color("9e5265"), Color("bf6874"), Color("d88b91"), 0.84],
	}
	var palette: Array = palettes[palette_id]
	node.set_instance_shader_parameter("use_species_palette", 1.0)
	node.set_instance_shader_parameter("species_palette_stage", 3.0)
	node.set_instance_shader_parameter("species_deep_color", palette[0])
	node.set_instance_shader_parameter("species_shadow_color", palette[1])
	node.set_instance_shader_parameter("species_mid_color", palette[2])
	node.set_instance_shader_parameter("species_light_color", palette[3])
	node.set_instance_shader_parameter("species_accent_color", palette[2])
	node.set_instance_shader_parameter("species_accent_amount", 0.0)
	node.set_instance_shader_parameter("species_seed", palette[4])


func _make_multimesh_node(
	node_name: String,
	mesh: Mesh,
	transforms: Array[Transform3D],
	material: Material,
	begin_distance: float,
	end_distance: float
) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = multimesh
	node.material_override = material
	node.visibility_range_begin = begin_distance
	node.visibility_range_end = end_distance
	node.set_meta("lod_begin", begin_distance)
	node.set_meta("lod_end", end_distance)
	return node


func _raycast_terrain(world_x: float, world_z: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.new()
	query.from = Vector3(world_x, 320.0, world_z)
	query.to = Vector3(world_x, -30.0, world_z)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_world_3d().direct_space_state.intersect_ray(query)


func _cell_seed(cell: Vector2i, salt: int) -> int:
	return abs(cell.x * 73856093 ^ cell.y * 19349663 ^ salt)


func _remove_chunk_nodes_from_tracking(chunk: Node3D) -> void:
	for child in chunk.get_children():
		if child is MultiMeshInstance3D:
			grass_lod0_nodes.erase(child)
			grass_lod1_nodes.erase(child)


func _apply_lod_state_to_chunk(chunk: Node3D) -> void:
	for child in chunk.get_children():
		if child is MultiMeshInstance3D:
			var node := child as MultiMeshInstance3D
			if not lod_enabled and "LOD1" in node.name:
				node.visible = false
			elif not lod_enabled:
				node.visible = vegetation_enabled
				node.visibility_range_begin = 0.0
				node.visibility_range_end = 0.0
			else:
				node.visible = vegetation_enabled
				node.visibility_range_begin = float(node.get_meta("lod_begin"))
				node.visibility_range_end = float(node.get_meta("lod_end"))


func set_lod_enabled(value: bool) -> void:
	lod_enabled = value
	for node in grass_lod0_nodes + tree_lod0_nodes:
		node.visible = vegetation_enabled
		node.visibility_range_begin = 0.0
		node.visibility_range_end = (
			float(node.get_meta("lod_end")) if lod_enabled else 0.0
		)
	for node in grass_lod1_nodes + tree_lod1_nodes:
		node.visible = vegetation_enabled and lod_enabled
		if lod_enabled:
			node.visibility_range_begin = float(node.get_meta("lod_begin"))
			node.visibility_range_end = float(node.get_meta("lod_end"))
	for node in large_tree_nodes:
		node.visible = vegetation_enabled
		node.visibility_range_begin = 0.0
		node.visibility_range_end = (
			float(node.get_meta("lod_end")) if lod_enabled else 0.0
		)


func set_vegetation_enabled(value: bool) -> void:
	vegetation_enabled = value
	visible = value


func get_active_grass_chunk_count() -> int:
	return active_grass_chunks.size()


func get_pending_grass_chunk_count() -> int:
	return grass_build_queue.size()
