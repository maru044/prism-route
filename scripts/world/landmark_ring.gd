extends Node3D
## Passive landmark: no interaction or HUD. Reuse the adjacent saddle's materials.
const GEOMETRY=preload("res://assets/world/landmark_ring_1101/ring.glb")
const MANIFEST="res://assets/world/landmark_ring_1101/manifest.json"
var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
var materials: Dictionary={}
var geometry: Node3D
var meshes_by_source: Dictionary={}

func _ready() -> void:
	name="LandmarkRing"
	geometry=GEOMETRY.instantiate();geometry.name="ReviewedCircularBands";add_child(geometry)
	var by_id: Dictionary={}
	for row: Dictionary in manifest.objects:by_id[row.id]=row
	for mesh: MeshInstance3D in geometry.find_children("*","MeshInstance3D",true,false):
		var id:=str(mesh.name).get_slice("_",1);var row: Dictionary=by_id[id]
		assert(materials.has(row.material_key),"Missing shared saddle material")
		mesh.material_override=materials[row.material_key];mesh.lod_bias=2.
		mesh.set_meta("source_id",id);mesh.set_meta("landmark_ring_material",row.material_key)
		meshes_by_source[id]=mesh
		if not row.collision:continue
		var body:=StaticBody3D.new();body.collision_layer=33;body.collision_mask=0
		body.set_meta("source_id",id);body.set_meta("surface_kind","Structure");body.set_meta("landmark_ring",true)
		mesh.add_child(body)
		var shape:=CollisionShape3D.new();shape.shape=mesh.mesh.create_trimesh_shape()
		shape.shape.backface_collision=true;body.add_child(shape)
	print("LANDMARK_RING_READY meshes=",meshes_by_source.size()," shared_saddle_materials=true")

func register_reflections(manager: Node) -> void:
	for mesh: MeshInstance3D in geometry.find_children("*","MeshInstance3D",true,false):
		manager.register_reflector(mesh,(mesh.material_override as StandardMaterial3D).albedo_color)
