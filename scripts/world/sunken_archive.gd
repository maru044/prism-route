extends Node3D
## Native single-storey buried court; all seaward terrain remains enclosed.
const GEOMETRY=preload("res://assets/world/sunken_archive_1103/court.glb")
const GLASS=preload("res://shaders/environment/water_court_glass.gdshader")
const PALETTE=preload("res://scripts/meadow_palette.gd")
const REPLACED_IDS=["95094d17-bdb0-4407-bdca-d26ab1deaad7","d01b8d98-9f3d-46e7-8737-7b60ad7a5657","012ab31c-3bd7-4f32-8676-9592c584ca4c","de6391b1-e6fa-48bf-978c-b261e0d6d4b4"]
var world
var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/sunken_archive_1103/manifest.json"))
var geometry:Node3D
var meshes_by_source:={}
var materials:={}
var cut_image:Image
var cut_texture:ImageTexture
var colonly_ramps:=0
var courtyard_grass:MultiMeshInstance3D
func _ready() -> void:
	name="SunkenArchive"
	var cut:Dictionary=manifest.grass_cut
	cut_image=Image.create_from_data(cut.size[0],cut.size[1],false,Image.FORMAT_RF,FileAccess.get_file_as_bytes("res://assets/world/sunken_archive_1103/grass_cut.rf"))
	cut_texture=ImageTexture.create_from_image(cut_image)
	materials.host=world.terrain_material;materials.grass=world.terrain_material
	for key:String in manifest.materials:
		if key=="grass":continue
		var row:Dictionary=manifest.materials[key];var color:=Color(row.color[0],row.color[1],row.color[2])
		if key=="soil":
			var mat:=world.terrain_material.duplicate() as ShaderMaterial
			PALETTE.apply_ground(mat);mat.set_shader_parameter("use_shared_meadow_biome",true)
			mat.set_shader_parameter("force_green_meadow",true);mat.set_shader_parameter("force_grass_surface",true)
			mat.set_shader_parameter("meadow_detail_strength",0.);materials[key]=mat
		elif key=="glass":
			var mat:=ShaderMaterial.new();mat.shader=GLASS
			mat.set_shader_parameter("glass_tint",color);mat.set_shader_parameter("base_opacity",row.opacity);mat.set_shader_parameter("surface_roughness",row.roughness);materials[key]=mat
		else:
			var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=row.roughness;mat.metallic=row.metallic
			if key=="green":mat.cull_mode=BaseMaterial3D.CULL_DISABLED
			materials[key]=mat
	geometry=GEOMETRY.instantiate();add_child(geometry)
	var by_id:={}
	for row:Dictionary in manifest.objects:by_id[row.id]=row
	for body:StaticBody3D in geometry.find_children("*","StaticBody3D",true,false):
		for row:Dictionary in manifest.objects:
			if row.category=="collision_helpers" and str(body.name)==str(row.name).trim_suffix("-colonly"):
				body.collision_layer=32;body.collision_mask=0;body.set_meta("source_id",row.id);body.set_meta("surface_kind","Structure")
				body.set_meta("smooth_stair_ramp",true);colonly_ramps+=1
	for mesh:MeshInstance3D in geometry.find_children("*","MeshInstance3D",true,false):
		var id:=str(mesh.name).get_slice("_",1);var row:Dictionary=by_id[id]
		mesh.material_override=materials[row.material_key];mesh.set_meta("source_id",id);meshes_by_source[id]=mesh
		if row.material_key=="glass":mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not row.collision:continue
		var body:=StaticBody3D.new();body.collision_layer=49 if row.kind=="Terrain" else 33;body.collision_mask=0
		body.set_meta("source_id",id);body.set_meta("surface_kind",row.kind);body.set_meta("sunken_archive",true);mesh.add_child(body)
		var shape:=CollisionShape3D.new();shape.shape=mesh.mesh.create_trimesh_shape();shape.shape.backface_collision=true;body.add_child(shape)
	print("SUNKEN_ARCHIVE_READY meshes=",meshes_by_source.size())
func install_courtyard_grass(vegetation:Node) -> void:
	# Reuse the project's accepted mesh, shader, palette and wind settings.
	var material:ShaderMaterial=vegetation.grass_material
	var multimesh:=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D;multimesh.use_custom_data=true
	multimesh.mesh=vegetation.grass_mesh;multimesh.instance_count=1500
	var rng:=RandomNumberGenerator.new();rng.seed=1103
	for i in multimesh.instance_count:
		var angle:=rng.randf()*TAU;var radius:=sqrt(rng.randf())
		var p:=Vector3(94.-1450.+5.25*radius*cos(angle),11.765,1150.-1147.+3.*radius*sin(angle))
		var scale:=rng.randf_range(.82,1.08)
		multimesh.set_instance_transform(i,Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(scale,scale,scale)),p))
		# Alpha 2 preserves the existing survivor group and marks intentional courtyard roots.
		multimesh.set_instance_custom_data(i,Color(rng.randf(),rng.randf(),.01,2.))
	courtyard_grass=MultiMeshInstance3D.new();courtyard_grass.name="ProjectGrass_Courtyard";courtyard_grass.multimesh=multimesh
	courtyard_grass.material_override=material;courtyard_grass.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	courtyard_grass.extra_cull_margin=1.8;add_child(courtyard_grass)
func bind_grass(mat:ShaderMaterial) -> void:
	var cut:Dictionary=manifest.grass_cut
	mat.set_shader_parameter("use_sunken_archive_grass_cut",true);mat.set_shader_parameter("sunken_archive_grass_cut",cut_texture)
	mat.set_shader_parameter("sunken_archive_cut_bounds",Vector4(cut.origin_xz[0],cut.origin_xz[1],cut.extent_xz[0],cut.extent_xz[1]))
func blocks_grass(p:Vector3) -> bool:
	if p.y<10.8 or p.y>60:return false
	var cut:Dictionary=manifest.grass_cut
	var uv:=(Vector2(p.x,p.z)-Vector2(cut.origin_xz[0],cut.origin_xz[1]))/Vector2(cut.extent_xz[0],cut.extent_xz[1])
	if uv.x<0 or uv.y<0 or uv.x>=1 or uv.y>=1:return false
	var value:=cut_image.get_pixel(floori(uv.x*cut_image.get_width()),floori(uv.y*cut_image.get_height())).r
	return value>.5 and (value<1.5 or p.y<=18.5)
func register_reflections(manager:Node) -> void:
	for row:Dictionary in manifest.objects:
		if row.material_key=="glass" or not meshes_by_source.has(row.id):continue
		var material:Material=materials[row.material_key]
		manager.register_reflector(meshes_by_source[row.id],(material as StandardMaterial3D).albedo_color if material is StandardMaterial3D else Color("91a46b"))
