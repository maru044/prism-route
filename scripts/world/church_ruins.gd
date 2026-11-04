extends Node3D
## Native Church Ruins atop West Twin Range; existing trees remain user-owned.
const GEOMETRY = preload("res://assets/world/church_ruins_1105/church.glb")
const MANIFEST = "res://assets/world/church_ruins_1105/manifest.json"
const GLASS = preload("res://shaders/environment/church_stained_glass.gdshader")
const ARCHITECTURE = preload("res://assets/world/cliff_b_test/architecture.tres")
const GRASS_CONFIG = "res://assets/world/church_ruins_1105/ground_grass.json"
const GRASS_BAKE = "res://assets/world/church_ruins_1105/grass_bake/manifest.json"
const STORE = preload("res://scripts/grass_baked_store.gd")

var world
var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
var geometry: Node3D
var materials: Dictionary = {}
var meshes_by_source: Dictionary = {}
var grass_config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GRASS_CONFIG))
var cut_image: Image
var cut_texture: ImageTexture
var local_grass_cells := 0
var colonly_ramps := 0

func _ready() -> void:
	name = "ChurchRuins"
	cut_image = Image.create_from_data(grass_config.size[0], grass_config.size[1], false, Image.FORMAT_RF, FileAccess.get_file_as_bytes("res://assets/world/church_ruins_1105/grass_cut.rf"))
	cut_texture = ImageTexture.create_from_image(cut_image)
	for key: String in manifest.materials:
		var row: Dictionary = manifest.materials[key]
		if key == "stained_glass_azure":
			var glass := ShaderMaterial.new()
			glass.resource_name = "ChurchRuins_" + key
			glass.shader = GLASS
			materials[key] = glass
			continue
		if key in ["path_flagstone", "pavement_marble_ivory", "weathered_limestone"]:
			var stone := ARCHITECTURE.duplicate() as ShaderMaterial
			stone.resource_name = "ChurchRuins_" + key
			if key == "path_flagstone":
				stone.set_shader_parameter("warm_white", Color(row.color[0], row.color[1], row.color[2]))
			materials[key] = stone
			continue
		var material := StandardMaterial3D.new()
		material.resource_name = "ChurchRuins_" + key
		material.albedo_color = Color(row.color[0], row.color[1], row.color[2], row.get("opacity", 1.0))
		material.roughness = row.roughness
		material.metallic = row.metallic
		materials[key] = material
	
	geometry = GEOMETRY.instantiate()
	geometry.name = "ChurchGeometry"
	add_child(geometry)
	
	var by_id: Dictionary = {}
	for row: Dictionary in manifest.objects:
		by_id[row.id] = row

	# 1. Handle auto-generated StaticBody3D from Godot's -colonly glTF import
	for body: StaticBody3D in geometry.find_children("*", "StaticBody3D", true, false):
		for row: Dictionary in manifest.objects:
			if row.category == "collision_helpers" and str(body.name) == str(row.name).trim_suffix("-colonly"):
				body.collision_layer = 32
				body.collision_mask = 0
				body.set_meta("source_id", row.id)
				body.set_meta("surface_kind", "Structure")
				body.set_meta("smooth_stair_ramp", true)
				colonly_ramps += 1
		
	# 2. Handle visible MeshInstance3D nodes
	for mesh: MeshInstance3D in geometry.find_children("*", "MeshInstance3D", true, false):
		var id := str(mesh.name).get_slice("_", 1)
		if not by_id.has(id):
			continue
		var row: Dictionary = by_id[id]
		mesh.material_override = materials[row.material_key]
		if row.kind == "Glazing":
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.set_meta("source_id", id)
		meshes_by_source[id] = mesh
		if not row.collision or row.category == "collision_helpers":
			continue
		var body := StaticBody3D.new()
		body.collision_layer = 33
		body.collision_mask = 0
		body.set_meta("source_id", id)
		body.set_meta("surface_kind", "Structure")
		body.set_meta("church_ruins", true)
		mesh.add_child(body)
		var shape := CollisionShape3D.new()
		shape.shape = mesh.mesh.create_trimesh_shape()
		shape.shape.backface_collision = true
		body.add_child(shape)
		
	print("CHURCH_RUINS_READY meshes=", meshes_by_source.size(), " colonly_ramps=", colonly_ramps, " trees_unchanged=true")

func cut_height(p: Vector3) -> float:
	var x := floori((p.x - float(grass_config.origin_xz[0])) / float(grass_config.pixel_size))
	var z := floori((p.z - float(grass_config.origin_xz[1])) / float(grass_config.pixel_size))
	if x < 0 or z < 0 or x >= cut_image.get_width() or z >= cut_image.get_height():
		return -10000.0
	return cut_image.get_pixel(x, z).r

func blocks_grass(p: Vector3) -> bool:
	if grass_config.source_geometry_sha256 != manifest.mesh_sha256:
		return false
	var height := cut_height(p)
	return height > -9999.0 and p.y >= height - float(grass_config.height_below_m) and p.y <= height + float(grass_config.height_above_m)

func bind_grass(material: ShaderMaterial) -> void:
	material.set_shader_parameter("use_church_grass_cut", grass_config.source_geometry_sha256 == manifest.mesh_sha256)
	material.set_shader_parameter("church_grass_cut", cut_texture)
	material.set_shader_parameter("church_cut_bounds", Vector4(grass_config.origin_xz[0], grass_config.origin_xz[1], grass_config.extent_xz[0], grass_config.extent_xz[1]))

func install_grass_cells(stream: Node) -> void:
	if not FileAccess.file_exists(GRASS_BAKE):
		return
	var baked: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GRASS_BAKE))
	if not baked.get("complete", false) or baked.get("signature", "") != STORE.signature(world):
		return
	if baked.get("cut_sha256", "") != FileAccess.get_sha256("res://assets/world/church_ruins_1105/grass_cut.rf"):
		return
	if baked.get("source_geometry_sha256", "") != grass_config.source_geometry_sha256:
		return
	if grass_config.source_geometry_sha256 != manifest.mesh_sha256:
		return
	for id: String in baked.cells:
		stream.store.manifest.cells[id] = baked.cells[id]
		var parts := id.split("_")
		stream.empty.erase(Vector3i(int(parts[0]), int(parts[1]), int(parts[2])))
		local_grass_cells += 1
	print("CHURCH_GRASS_BAKED_CELLS ", local_grass_cells)
