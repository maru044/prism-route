extends "res://scripts/vegetation_lod_streamer.gd"
## The shared LOD renderer with a separately baked, spaced 1012 population.

const LAYOUT_PATH := "res://assets/world/map_1012_test/tree_layout.json"
const MAP_FAR_TREE_END := 6000.0
const GRASS_INTERACTION := preload("res://scripts/grass_interaction.gd")
@export var grass_interaction_enabled := true
var grass_interaction = GRASS_INTERACTION.new()

func set_grass_actor(actor: Node3D, is_vehicle: bool) -> void:
	grass_interaction.set_actor(actor, is_vehicle)

func _process(delta: float) -> void:
	super._process(delta)
	if initialized and grass_material != null:
		grass_interaction.enabled = grass_interaction_enabled
		grass_interaction.update(delta, grass_material)

func _build_grass_chunk(cell: Vector2i) -> void:
	super._build_grass_chunk(cell)
	if active_grass_chunks.has(cell):
		for node in active_grass_chunks[cell].get_children():
			if node is MultiMeshInstance3D:
				node.extra_cull_margin = 1.5

func _load_meshes_and_materials() -> void:
	super._load_meshes_and_materials()
	# Retain crowns in the full-island view; near and medium LODs are unchanged.
	for material in [tree_small_lod2_material, tree_broad_lod2_material, tree_upright_lod2_material]:
		material.set_shader_parameter("tree_lod_fade", Vector4(280, 330, 5700, MAP_FAR_TREE_END))

func _build_tree_lod() -> void:
	var records: Array = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	var bucket_sets: Array[Dictionary] = [{}, {}, {}]
	var sizes := [TREE_LOD0_CHUNK_SIZE, TREE_LOD1_CHUNK_SIZE, TREE_LOD2_CHUNK_SIZE]
	var rng := RandomNumberGenerator.new()
	rng.seed = 10122026
	tree_instance_count = records.size()
	large_tree_instance_count = 0
	for row: Array in records:
		var position := Vector3(row[0], row[1], row[2])
		var palette := _palette_for_cell(Vector2i(floori(position.x / TREE_PALETTE_CELL_SIZE), floori(position.z / TREE_PALETTE_CELL_SIZE)))
		var model_id := 0
		if int(row[5]) == 1:
			large_tree_instance_count += 1
			model_id = 1 if palette in [1, 2] else (2 if palette in [3, 4] else (1 if rng.randf() < 0.58 else 2))
		var transform := Transform3D(Basis(Vector3.UP, row[3]).scaled(Vector3.ONE * float(row[4])), position)
		if record_tree_layout_for_review:
			review_tree_records.append({"transform": transform, "model": model_id, "palette": palette})
		for level in 3:
			var size: float = sizes[level]
			var cell := Vector2i(floori(position.x / size), floori(position.z / size))
			var key := "%d,%d,%d,%d" % [cell.x, cell.y, palette, model_id]
			if not bucket_sets[level].has(key):
				bucket_sets[level][key] = {"cell": cell, "palette": palette, "model": model_id, "transforms": []}
			(bucket_sets[level][key].transforms as Array).append(transform)
	for level in 3:
		var size: float = sizes[level]
		for key in bucket_sets[level]:
			var bucket: Dictionary = bucket_sets[level][key]
			var cell: Vector2i = bucket.cell
			var origin := Vector3(cell.x * size, 0, cell.y * size)
			var transforms: Array[Transform3D] = []
			for transform: Transform3D in bucket.transforms:
				transform.origin -= origin
				transforms.append(transform)
			var chunk := Node3D.new()
			chunk.name = "TreeLOD%dChunk_%s" % [level, key.replace(",", "_")]
			chunk.position = origin
			add_child(chunk)
			_add_tree_lod_level(chunk, bucket.model, transforms, bucket.palette, level, size * 1.45)
	for node in tree_lod2_nodes:
		node.visibility_range_end = MAP_FAR_TREE_END + TREE_LOD2_CHUNK_SIZE * 1.45
		node.set_meta("lod_end", node.visibility_range_end)

func _raycast_terrain(world_x: float, world_z: float) -> Dictionary:
	# Match the tree layout's conservative road footprint exclusion, including
	# authored roads that pass above or slightly below another terrain surface.
	var road_query := PhysicsRayQueryParameters3D.create(Vector3(world_x, 400, world_z), Vector3(world_x, -30, world_z), 8)
	road_query.hit_back_faces = true
	if not get_world_3d().direct_space_state.intersect_ray(road_query).is_empty():
		return {}
	var query := PhysicsRayQueryParameters3D.create(Vector3(world_x, 400, world_z), Vector3(world_x, -30, world_z), 5)
	query.hit_back_faces = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider.get_meta("map_surface", "") != "Terrain":
		return {}
	return hit

func _grass_coverage(_position: Vector3, normal: Vector3) -> float:
	# Beaches are separate surfaces; negative-height authored land is still land.
	var slope := 1.0 - clampf(absf(normal.y), 0.0, 1.0)
	return 1.0 - smoothstep(0.24, 0.58, slope)
