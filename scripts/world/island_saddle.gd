extends Node3D
## Additive CAD feature. Existing terrain, vegetation records and masks are untouched.
const GEOMETRY=preload("res://assets/world/island_saddle_1031/saddle.glb")
const MANIFEST="res://assets/world/island_saddle_1031/manifest.json"
const ACTOR_SOLID_LAYER=32
var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
var geometry: Node3D
var materials: Dictionary={}
var walking_body: StaticBody3D

func _ready() -> void:
	for key: String in manifest.materials:
		var row: Dictionary=manifest.materials[key]
		var mat:=StandardMaterial3D.new()
		mat.resource_name="IslandSaddle_"+key
		mat.albedo_color=Color(row.color[0],row.color[1],row.color[2],row.opacity)
		mat.roughness=float(row.roughness);mat.metallic=float(row.metallic)
		mat.cull_mode=BaseMaterial3D.CULL_DISABLED
		if key in ["glass","contact_glass"]:
			mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
			mat.rim_enabled=true;mat.rim=.35;mat.rim_tint=.25
		materials[key]=mat
	geometry=GEOMETRY.instantiate();geometry.name="SaddleShell";add_child(geometry)
	var by_id: Dictionary={}
	for row: Dictionary in manifest.objects:by_id[row.id]=row
	for mesh: MeshInstance3D in geometry.find_children("*","MeshInstance3D",true,false):
		var id:=str(mesh.name).get_slice("_",1)
		var row: Dictionary=by_id[id]
		mesh.material_override=materials[row.material_key]
		mesh.set_meta("saddle_material",row.material_key)
		mesh.set_meta("source_id",id)
		mesh.visible=bool(row.get("visible",true))
		if row.name.ends_with("FlushPanelSeams"):
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if row.material_key=="contact_glass":
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not row.collision:continue
		var body:=StaticBody3D.new();body.collision_layer=1|ACTOR_SOLID_LAYER;body.collision_mask=0
		body.set_meta("surface_kind","Structure");body.set_meta("source_id",id)
		body.set_meta("island_saddle",true);mesh.add_child(body)
		var shape:=CollisionShape3D.new();shape.shape=mesh.mesh.create_trimesh_shape()
		shape.shape.backface_collision=true;body.add_child(shape)
		if id==manifest.walking_surface_id:walking_body=body
	print("ISLAND_SADDLE_READY meshes=",by_id.size()," continuous_collision=",walking_body!=null)

func register_reflections(manager: Node) -> void:
	for mesh: MeshInstance3D in geometry.find_children("*","MeshInstance3D",true,false):
		if not mesh.visible or mesh.get_meta("saddle_material","") in ["glass","contact_glass"]:continue
		var material:=mesh.material_override as StandardMaterial3D
		manager.register_reflector(mesh,material.albedo_color)
