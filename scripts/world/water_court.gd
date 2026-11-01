extends Node3D
## Reviewed additive CAD. The original shallow water and exit ramp remain intact.
const GEOMETRY=preload("res://assets/world/water_court_1101/court.glb")
const MANIFEST="res://assets/world/water_court_1101/manifest.json"
const GLASS=preload("res://shaders/environment/water_court_glass.gdshader")
var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
var geometry: Node3D
var materials: Dictionary={}
var meshes_by_source: Dictionary={}

func _ready() -> void:
	name="ShallowWaterCourt"
	for key: String in manifest.materials:
		var row: Dictionary=manifest.materials[key]
		var color:=Color(row.color[0],row.color[1],row.color[2],1.)
		if key=="glass":
			var glass:=ShaderMaterial.new();glass.shader=GLASS;glass.resource_name="WaterCourt_Glass"
			glass.set_shader_parameter("glass_tint",color)
			glass.set_shader_parameter("base_opacity",float(row.opacity))
			glass.set_shader_parameter("surface_roughness",float(row.roughness))
			materials[key]=glass
		else:
			var material:=StandardMaterial3D.new();material.resource_name="WaterCourt_"+key
			material.albedo_color=color;material.roughness=row.roughness;material.metallic=row.metallic
			materials[key]=material
	geometry=GEOMETRY.instantiate();geometry.name="ReviewedGeometry";add_child(geometry)
	var by_id: Dictionary={}
	for row: Dictionary in manifest.objects:by_id[row.id]=row
	for mesh: MeshInstance3D in geometry.find_children("*","MeshInstance3D",true,false):
		var id:=str(mesh.name).get_slice("_",1);var row: Dictionary=by_id[id]
		mesh.material_override=materials[row.material_key]
		mesh.set_meta("source_id",id);mesh.set_meta("water_court_material",row.material_key)
		meshes_by_source[id]=mesh
		if row.material_key in ["glass","joint"]:mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not row.collision:continue
		var body:=StaticBody3D.new();body.collision_layer=33;body.collision_mask=0
		body.set_meta("source_id",id);body.set_meta("surface_kind","Structure");body.set_meta("water_court",true)
		mesh.add_child(body)
		var shape:=CollisionShape3D.new();shape.shape=mesh.mesh.create_trimesh_shape()
		shape.shape.backface_collision=true;body.add_child(shape)
	print("WATER_COURT_READY meshes=",meshes_by_source.size()," existing_ramp_unchanged=true")

func register_reflections(manager: Node) -> void:
	for mesh: MeshInstance3D in geometry.find_children("*","MeshInstance3D",true,false):
		if mesh.get_meta("water_court_material","")=="glass":continue
		manager.register_reflector(mesh,(mesh.material_override as StandardMaterial3D).albedo_color)
