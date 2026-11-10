extends Node3D
## Five-building sandbar group; fixed world geometry with manifest -> Marker3D.
const GEOMETRY := preload("res://assets/world/sandbar_pavilion_1109/pavilion.glb")
const MANIFEST := "res://assets/world/sandbar_pavilion_1109/manifest.json"
const WALL := preload("res://assets/world/sandbar_pavilion_1109/materials_v3/cool_white_wall.tres")
const TIMBER := preload("res://assets/world/sandbar_pavilion_1109/materials_v3/honey_timber.tres")
const ROOF := preload("res://assets/world/sandbar_pavilion_1109/materials_v3/sea_green_roof.tres")
const FURNITURE := preload("res://scripts/world/interactive_furniture.gd")
var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
var geometry: Node3D
var meshes_by_source: Dictionary = {}
var furniture_instances: Dictionary = {}
var materials: Dictionary = {}

func _ready() -> void:
	name = "SandbarPavilion"
	var resources: Dictionary = {"cool_white_wall":WALL,"honey_timber":TIMBER,"sea_green_roof":ROOF}
	for key: String in manifest.materials:
		var row: Dictionary = manifest.materials[key]
		var color := Color(row.color[0],row.color[1],row.color[2])
		var material: StandardMaterial3D
		if row.has("resource"):
			material = resources[row.resource].duplicate() as StandardMaterial3D
			# Exported UVs are meter-scale and follow each member's grain direction.
			material.uv1_triplanar = false
		else:
			material = StandardMaterial3D.new()
			material.albedo_color = color
			material.roughness = float(row.get("roughness",.75))
			material.metallic = float(row.get("metallic",0.))
			if key == "sea_glass":
				# Four facade batches only; no refraction or extra reflection camera.
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
				material.albedo_color = Color(.12,.48,.55,.28)
				material.metallic = 0.
				material.roughness = .18
			if row.has("emission"):
				material.emission_enabled = true
				material.emission = color
				material.emission_energy_multiplier = float(row.emission)
		materials[key] = material
	geometry = GEOMETRY.instantiate()
	geometry.name = "PavilionGeometry"
	add_child(geometry)
	var by_id: Dictionary = {}
	for row: Dictionary in manifest.objects: by_id[row.id] = row
	for mesh: MeshInstance3D in geometry.find_children("*","MeshInstance3D",true,false):
		var id := str(mesh.name).get_slice("_",1)
		assert(by_id.has(id),"Unmapped pavilion mesh")
		var row: Dictionary = by_id[id]
		mesh.material_override = materials[row.material_key]
		mesh.visible = bool(row.get("render",true))
		mesh.set_meta("source_id",id)
		meshes_by_source[id] = mesh
		if not row.collision: continue
		var body := StaticBody3D.new()
		body.collision_layer = 33
		body.collision_mask = 0
		body.set_meta("source_id",id)
		body.set_meta("surface_kind","Structure")
		body.set_meta("sandbar_pavilion",true)
		mesh.add_child(body)
		var shape := CollisionShape3D.new()
		shape.shape = mesh.mesh.create_trimesh_shape()
		shape.shape.backface_collision = true
		body.add_child(shape)
	_build_furniture()
	print("SANDBAR_PAVILION_READY meshes=",meshes_by_source.size()," furniture=",furniture_instances.size()," triangles=",manifest.triangle_count)

func _frame(position: Array,forward: Array) -> Transform3D:
	var f := Vector3(forward[0],forward[1],forward[2]).normalized()
	return Transform3D(Basis(Vector3.UP.cross(f).normalized(),Vector3.UP,f),Vector3(position[0],position[1],position[2]))

func _build_furniture(catalog_prefix:="sandbar_") -> void:
	var container := Node3D.new()
	container.name = "FurnitureInteractions"
	add_child(container)
	for row: Dictionary in manifest.interactions.furniture:
		var furniture := FURNITURE.new()
		furniture.name = row.id
		furniture.furniture_id = catalog_prefix + str(row.type)
		furniture.furniture_name_zh = row.name_zh
		furniture.seat_surface_height = float(row.surface_height)
		furniture.transform = _frame(row.position,row.forward)
		furniture.set_meta("instance_id",row.instance_id)
		furniture.set_meta("interaction_type",row.type)
		furniture.set_meta("interaction_status",row.interaction_status)
		for anchor: Dictionary in row.anchors:
			var marker := Marker3D.new()
			marker.name = anchor.name
			marker.transform = furniture.transform.affine_inverse() * _frame(anchor.position,anchor.forward)
			marker.set_meta("cad_source_id",anchor.source_id)
			furniture.add_child(marker)
		container.add_child(furniture)
		furniture_instances[row.id] = furniture

func register_reflections(manager: Node) -> void:
	# Reuse the existing water manager; do not introduce another viewport/camera.
	for row: Dictionary in manifest.objects:
		if not bool(row.get("render",true)): continue
		var rgb: Array = manifest.materials[row.material_key].color
		manager.register_reflector(meshes_by_source[row.id],Color(rgb[0],rgb[1],rgb[2]))
