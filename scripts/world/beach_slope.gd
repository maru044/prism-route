extends Node3D
## Sand-only native delta. The immutable base world and grass bake remain valid.
const GEOMETRY=preload("res://assets/world/beach_slope_1107/beach.glb")
const REPLACED_IDS=["a2b4d386-d01a-4559-a8f7-28e5c8b93563"]
var sand_material: Material

func _ready() -> void:
	name="BeachSlope"
	var geometry:=GEOMETRY.instantiate()
	add_child(geometry)
	for mesh: MeshInstance3D in geometry.find_children("*","MeshInstance3D",true,false):
		mesh.material_override=sand_material
		var id:=str(mesh.name).get_slice("_",1)
		mesh.set_meta("source_id",id)
		var body:=StaticBody3D.new()
		body.collision_layer=33;body.collision_mask=0
		body.set_meta("source_id",id);body.set_meta("surface_kind","Sand")
		mesh.add_child(body)
		var collider:=CollisionShape3D.new()
		collider.shape=mesh.mesh.create_trimesh_shape();collider.shape.backface_collision=true
		body.add_child(collider)
	print("BEACH_SLOPE_READY meshes=1")
