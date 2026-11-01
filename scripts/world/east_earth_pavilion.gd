extends Node3D
## Reviewed earth-enclosed pavilion; original planting and root caches stay reusable.
const GEOMETRY=preload("res://assets/world/east_earth_pavilion_1102/pavilion.glb")
const MANIFEST="res://assets/world/east_earth_pavilion_1102/manifest.json"
const REPLACED_IDS=["920c8a45-b23e-4260-9aab-86333f61b992"]
const GLASS=preload("res://shaders/environment/water_court_glass.gdshader")
const PALETTE=preload("res://scripts/meadow_palette.gd")
const GRASS_CONFIG="res://assets/world/east_earth_pavilion_1102/ground_grass.json"
const GRASS_BAKE="res://assets/world/east_earth_pavilion_1102/grass_bake/manifest.json"
const GRASS_STORE=preload("res://scripts/grass_baked_store.gd")
var world
var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
var geometry: Node3D
var materials: Dictionary={}
var meshes_by_source: Dictionary={}
var support_image: Image
var support_texture: ImageTexture
var local_grass_cells:=0

func _ready() -> void:
	name="EastEarthPavilion"
	var support: Dictionary=manifest.grass_support
	support_image=Image.create_from_data(support.size[0],support.size[1],false,Image.FORMAT_RGF,
		FileAccess.get_file_as_bytes("res://assets/world/east_earth_pavilion_1102/grass_support.rgf"))
	support_texture=ImageTexture.create_from_image(support_image)
	for key: String in manifest.materials:
		var row: Dictionary=manifest.materials[key]
		var color:=Color(row.color[0],row.color[1],row.color[2],1.)
		if key=="grass":
			var turf:=world.terrain_material.duplicate() as ShaderMaterial
			PALETTE.apply_ground(turf)
			turf.set_shader_parameter("use_shared_meadow_biome",true)
			turf.set_shader_parameter("force_green_meadow",true)
			turf.set_shader_parameter("force_grass_surface",true)
			turf.set_shader_parameter("meadow_detail_strength",0.)
			materials[key]=turf
		elif key=="glass":
			var glass:=ShaderMaterial.new();glass.shader=GLASS
			glass.set_shader_parameter("glass_tint",color)
			glass.set_shader_parameter("base_opacity",float(row.opacity))
			glass.set_shader_parameter("surface_roughness",float(row.roughness))
			materials[key]=glass
		else:
			var material:=StandardMaterial3D.new();material.albedo_color=color
			material.roughness=row.roughness;material.metallic=row.metallic
			materials[key]=material
	geometry=GEOMETRY.instantiate();geometry.name="ReviewedGeometry";add_child(geometry)
	var by_id: Dictionary={}
	for row: Dictionary in manifest.objects:by_id[row.id]=row
	for mesh: MeshInstance3D in geometry.find_children("*","MeshInstance3D",true,false):
		var id:=str(mesh.name).get_slice("_",1);var row: Dictionary=by_id[id]
		mesh.material_override=materials[row.material_key]
		mesh.set_meta("source_id",id);mesh.set_meta("earth_pavilion_material",row.material_key)
		meshes_by_source[id]=mesh
		if row.material_key=="glass":mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not row.collision:continue
		var body:=StaticBody3D.new();body.collision_layer=49 if row.kind=="Terrain" else 33;body.collision_mask=0
		body.set_meta("source_id",id);body.set_meta("surface_kind",row.kind);body.set_meta("earth_pavilion",true)
		mesh.add_child(body)
		var shape:=CollisionShape3D.new();shape.shape=mesh.mesh.create_trimesh_shape()
		shape.shape.backface_collision=true;body.add_child(shape)
	print("EARTH_PAVILION_READY meshes=",meshes_by_source.size()," replaced_hills=1")

func bind_grass(material: ShaderMaterial) -> void:
	var support: Dictionary=manifest.grass_support
	material.set_shader_parameter("use_earth_pavilion_grass_support",true)
	material.set_shader_parameter("earth_pavilion_grass_support",support_texture)
	material.set_shader_parameter("earth_pavilion_support_bounds",Vector4(support.origin_xz[0],support.origin_xz[1],support.extent_xz[0],support.extent_xz[1]))

func support_at(p: Vector3) -> Color:
	var support: Dictionary=manifest.grass_support
	var uv:=(Vector2(p.x,p.z)-Vector2(support.origin_xz[0],support.origin_xz[1]))/Vector2(support.extent_xz[0],support.extent_xz[1])
	if uv.x<0. or uv.y<0. or uv.x>=1. or uv.y>=1.:return Color(0.,2.,0.)
	return support_image.get_pixel(floori(uv.x*support_image.get_width()),floori(uv.y*support_image.get_height()))

func affected_xz(p: Vector3) -> bool:return support_at(p).g<1.5

func blocks_grass(p: Vector3) -> bool:
	if p.y<40. or p.y>95.:return false
	var data:=support_at(p)
	return data.g<1.5 and (data.g<.5 or absf(p.y-data.r)>.4)

func install_grass_cells(stream: Node) -> void:
	if not FileAccess.file_exists(GRASS_CONFIG):return
	var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(GRASS_CONFIG))
	for values: Array in config.cells:
		var cell:=Vector3i(values[0],values[1],values[2]);var column:=Vector2i(cell.x,cell.z)
		if not stream.columns.get(column,[]).has(cell):stream.register_cell(cell)
	if not FileAccess.file_exists(GRASS_BAKE):return
	var baked: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(GRASS_BAKE))
	if not baked.get("complete",false) or baked.get("signature","")!=GRASS_STORE.signature(world):return
	if baked.get("ground_config_sha256","")!=FileAccess.get_sha256(GRASS_CONFIG):return
	if baked.get("source_geometry_sha256","")!=FileAccess.get_sha256("res://assets/world/east_earth_pavilion_1102/pavilion.glb"):return
	if baked.get("support_sha256","")!=FileAccess.get_sha256("res://assets/world/east_earth_pavilion_1102/grass_support.rgf"):return
	for id: String in baked.cells:
		stream.store.manifest.cells[id]=baked.cells[id]
		var parts:=id.split("_");stream.empty.erase(Vector3i(int(parts[0]),int(parts[1]),int(parts[2])))
		local_grass_cells+=1
	print("EARTH_PAVILION_GRASS_BAKED_CELLS ",local_grass_cells)

func register_reflections(manager: Node) -> void:
	for mesh: MeshInstance3D in meshes_by_source.values():
		var key: String=mesh.get_meta("earth_pavilion_material")
		if key=="glass":continue
		var color: Color=PALETTE.GROUND.ground_green if key=="grass" else (materials[key] as StandardMaterial3D).albedo_color
		manager.register_reflector(mesh,color)
