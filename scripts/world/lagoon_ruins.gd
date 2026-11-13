extends Node3D

const GEOMETRY := preload("res://assets/world/north_lagoon_ruins/ruins.glb")
const CONCRETE := preload("res://assets/world/cliff_b_test/architecture.tres")

var meshes: Array[MeshInstance3D] = []

func _ready() -> void:
	name = "NorthLagoonRuins"
	var geometry := GEOMETRY.instantiate()
	add_child(geometry)
	for mesh: MeshInstance3D in geometry.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = CONCRETE
		meshes.append(mesh)
		var body := StaticBody3D.new()
		body.collision_layer = 32
		body.collision_mask = 0
		body.set_meta("surface_kind", "Structure")
		body.set_meta("source_id", String(mesh.name))
		mesh.add_child(body)
		var shape := CollisionShape3D.new()
		shape.shape = mesh.mesh.create_trimesh_shape()
		body.add_child(shape)

func register_reflections(manager: Node) -> void:
	var tint: Color = CONCRETE.get_shader_parameter("warm_white")
	for mesh in meshes:
		manager.register_reflector(mesh, tint)
