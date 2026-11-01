extends Node3D
## Additive reviewed CAD; existing trees and grass caches remain user-owned.
const GEOMETRY=preload("res://assets/world/terrace_ruins_1101/ruins.glb")
const MANIFEST="res://assets/world/terrace_ruins_1101/manifest.json"
const GRASS_CUT=preload("res://assets/world/terrace_ruins_1101/grass_cut.png")
var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
var geometry: Node3D
var materials: Dictionary={}
var meshes_by_source: Dictionary={}
var cut_image: Image

func _ready() -> void:
	name="TerraceCurvedRuins"
	cut_image=GRASS_CUT.get_image()
	if cut_image.is_compressed():cut_image.decompress()
	for key: String in manifest.materials:
		var row: Dictionary=manifest.materials[key]
		var material:=StandardMaterial3D.new();material.resource_name="TerraceRuins_"+key
		material.albedo_color=Color(row.color[0],row.color[1],row.color[2],1.)
		material.roughness=row.roughness;material.metallic=row.metallic
		materials[key]=material
	geometry=GEOMETRY.instantiate();geometry.name="ReviewedGeometry";add_child(geometry)
	var by_id: Dictionary={}
	for row: Dictionary in manifest.objects:by_id[row.id]=row
	for mesh: MeshInstance3D in geometry.find_children("*","MeshInstance3D",true,false):
		var id:=str(mesh.name).get_slice("_",1);var row: Dictionary=by_id[id]
		mesh.material_override=materials[row.material_key];mesh.set_meta("source_id",id)
		meshes_by_source[id]=mesh
		if not row.collision:continue
		var body:=StaticBody3D.new();body.collision_layer=33;body.collision_mask=0
		body.set_meta("source_id",id);body.set_meta("surface_kind","Structure");body.set_meta("terrace_ruins",true)
		mesh.add_child(body)
		var shape:=CollisionShape3D.new();shape.shape=mesh.mesh.create_trimesh_shape()
		shape.shape.backface_collision=true;body.add_child(shape)
	print("TERRACE_RUINS_READY meshes=",meshes_by_source.size()," trees_unchanged=true")

func bind_grass(material: ShaderMaterial) -> void:
	var cut: Dictionary=manifest.grass_cut
	material.set_shader_parameter("use_terrace_grass_cut",true)
	material.set_shader_parameter("terrace_grass_cut",GRASS_CUT)
	material.set_shader_parameter("terrace_cut_bounds",Vector4(cut.origin_xz[0],cut.origin_xz[1],cut.extent_xz[0],cut.extent_xz[1]))
	material.set_shader_parameter("terrace_cut_height",Vector2(cut.height_range[0],cut.height_range[1]))

func blocks_grass(p: Vector3) -> bool:
	var cut: Dictionary=manifest.grass_cut
	if p.y<cut.height_range[0] or p.y>cut.height_range[1]:return false
	var uv:=(Vector2(p.x,p.z)-Vector2(cut.origin_xz[0],cut.origin_xz[1]))/Vector2(cut.extent_xz[0],cut.extent_xz[1])
	if uv.x<0 or uv.y<0 or uv.x>1 or uv.y>1:return false
	return cut_image.get_pixel(roundi(uv.x*(cut_image.get_width()-1)),roundi(uv.y*(cut_image.get_height()-1))).r>.5

func register_reflections(manager: Node) -> void:
	for mesh: MeshInstance3D in geometry.find_children("*","MeshInstance3D",true,false):
		manager.register_reflector(mesh,(mesh.material_override as StandardMaterial3D).albedo_color)
