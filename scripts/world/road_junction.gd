extends Node3D
## Single native bridge surface replacement; original coastal road stays intact.
const GEOMETRY=preload("res://assets/world/road_junction_1104/junction.glb")
const REPLACED_IDS=["0808d32c-6ebc-4105-9258-a0f755ac2752"]

func _ready() -> void:
	name="RoadJunction"
	var geometry: Node3D=GEOMETRY.instantiate();add_child(geometry)
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color(.13,.145,.15);material.roughness=.93
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	for mesh: MeshInstance3D in geometry.find_children("*","MeshInstance3D",true,false):
		mesh.material_override=material
		var id:=str(mesh.name).get_slice("_",1);mesh.set_meta("source_id",id)
		var body:=StaticBody3D.new();body.collision_layer=41;body.collision_mask=0
		body.set_meta("source_id",id);body.set_meta("surface_kind","Road");mesh.add_child(body)
		var shape:=CollisionShape3D.new();shape.shape=mesh.mesh.create_trimesh_shape()
		shape.shape.backface_collision=true;body.add_child(shape)
	print("ROAD_JUNCTION_READY")
