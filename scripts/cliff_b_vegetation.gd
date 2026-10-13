extends "res://scripts/map_1012_vegetation.gd"
## Planting-only grass rays preserve the current storey below the broad roof.

const SHRUB := preload("res://assets/vegetation/models/shrub_medium_rounded_canopy.glb")
const SHRUB_TEXTURE := preload("res://assets/vegetation/textures/shrub_leaf_lobes_billboard_flat_v3.png")
var current_storey := -999
var shrubs: MultiMeshInstance3D

func _ready() -> void:
	layout_path = "res://assets/world/cliff_b_test/tree_layout.json"

func _palette_for_cell(_cell: Vector2i) -> int:
	return 0

func _load_meshes_and_materials() -> void:
	super._load_meshes_and_materials()
	# Short meadow uses a derived mesh, keeping the accepted source grass intact.
	var arrays := grass_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for index in vertices.size():
		vertices[index].y *= 0.44
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var short_grass := ArrayMesh.new()
	short_grass.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	grass_mesh = short_grass
	grass_material.set_shader_parameter("biome_center_x", -100000.0)
	grass_material.set_shader_parameter("use_biome_palette", false)
	grass_material.set_shader_parameter("canopy_color_uniformity", 0.85)
	grass_material.set_shader_parameter("canopy_base_color", Color(0.42, 0.51, 0.29))
	grass_material.set_shader_parameter("wind_strength", 0.08)

func _build_tree_lod() -> void:
	super._build_tree_lod()
	var material := leaf_material.duplicate(true) as ShaderMaterial
	material.set_shader_parameter("albedo_texture", SHRUB_TEXTURE)
	material.set_shader_parameter("use_y_billboard", true)
	material.set_shader_parameter("use_billboard_pivot_data", true)
	material.set_shader_parameter("use_tree_local_canopy_normal", false)
	material.set_shader_parameter("use_biome_palette", false)
	material.set_shader_parameter("card_edge_fade", 0.025)
	material.set_shader_parameter("wind_strength", 0.012)
	var transforms: Array[Transform3D] = []
	var records: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/cliff_b_test/shrub_layout.json"))
	for row: Array in records:
		transforms.append(Transform3D(Basis(Vector3.UP, float(row[3])).scaled(Vector3.ONE * float(row[4])), Vector3(row[0], row[1], row[2])))
	shrubs = _make_multimesh_node("PlantingShrubs", _extract_first_mesh(SHRUB), transforms, material, 0, 500)
	shrubs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shrubs)

func _refresh_grass_cells() -> void:
	var storey := floori(target.global_position.y / 8.0)
	if current_storey != storey:
		for chunk: Node3D in active_grass_chunks.values():
			chunk.queue_free()
		active_grass_chunks.clear()
		empty_grass_cells.clear()
		queued_grass_cells.clear()
		grass_build_queue.clear()
		grass_lod0_nodes.clear()
		grass_lod1_nodes.clear()
		current_storey = storey
	super._refresh_grass_cells()

func _raycast_terrain(world_x: float, world_z: float) -> Dictionary:
	var floor_y := target.global_position.y
	var query := PhysicsRayQueryParameters3D.create(Vector3(world_x, floor_y + 4.0, world_z), Vector3(world_x, floor_y - 12.0, world_z), 16)
	query.hit_back_faces = false
	return get_world_3d().direct_space_state.intersect_ray(query)

func _grass_coverage(_position: Vector3, normal: Vector3) -> float:
	return 1.0 if normal.y > 0.9 else 0.0

func set_vegetation_enabled(value: bool) -> void:
	super.set_vegetation_enabled(value)
	if shrubs != null:
		shrubs.visible = value
