extends Node3D
## Reviewed CAD replacement; trees remain user-authored, grass uses the world bake.
const GEOMETRY=preload("res://assets/world/oval_atrium_1031/atrium.glb")
const MANIFEST="res://assets/world/oval_atrium_1031/manifest.json"
const REPLACED_IDS=["78d43939-e418-428e-aad5-d51b08c73985","ce36cdce-398b-44f5-b0b4-fe7f258106cf","de67bdb9-1d24-4d78-b864-a5f6bbd48ce6"]
const PALETTE=preload("res://scripts/meadow_palette.gd")
const GRASS_CONFIG="res://assets/world/oval_atrium_1031/ground_grass.json"
const GRASS_BAKE="res://assets/world/oval_atrium_1031/grass_bake/manifest.json"
const GRASS_STORE=preload("res://scripts/grass_baked_store.gd")
var world
var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
var geometry: Node3D
var materials: Dictionary={}
var meshes_by_source: Dictionary={}
var ground_config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(GRASS_CONFIG))
var ground_polygon:=PackedVector2Array()
var local_grass_cells:=0

func _ready() -> void:
	name="OvalAtrium"
	for p: Array in ground_config.polygon_xz:ground_polygon.append(Vector2(p[0],p[1]))
	for key: String in manifest.materials:
		if key=="Vegetation_ground":continue
		var row: Dictionary=manifest.materials[key]
		var material:=StandardMaterial3D.new();material.resource_name="OvalAtrium_"+key
		material.albedo_color=Color(row.color[0],row.color[1],row.color[2],row.opacity)
		material.roughness=float(row.roughness);material.metallic=float(row.metallic)
		material.cull_mode=BaseMaterial3D.CULL_DISABLED
		materials[key]=material
	materials.Vegetation_ground=world.terrain_material.duplicate() as ShaderMaterial
	sync_ground_palette()
	materials.source_terrain=world.terrain_material
	materials.source_architecture=load("res://assets/world/cliff_b_test/architecture.tres")
	geometry=GEOMETRY.instantiate();geometry.name="AtriumGeometry";add_child(geometry)
	var by_id: Dictionary={}
	for row: Dictionary in manifest.objects:by_id[row.id]=row
	for mesh: MeshInstance3D in geometry.find_children("*","MeshInstance3D",true,false):
		var id:=str(mesh.name).get_slice("_",1);var row: Dictionary=by_id[id]
		mesh.material_override=materials[row.material_key]
		mesh.set_meta("atrium_material",row.material_key);mesh.set_meta("source_id",id)
		meshes_by_source[id]=mesh
		if not row.collision:continue
		var body:=StaticBody3D.new();body.collision_mask=0
		body.collision_layer=33|(16 if row.kind=="Terrain" else 0)
		if id==ground_config.ground_source_id:
			body.collision_layer|=16
			body.set_meta("atrium_grass_ground",true)
		body.set_meta("source_id",id);body.set_meta("surface_kind",row.kind);body.set_meta("oval_atrium",true)
		mesh.add_child(body)
		var shape:=CollisionShape3D.new();shape.shape=mesh.mesh.create_trimesh_shape()
		shape.shape.backface_collision=true;body.add_child(shape)
	print("OVAL_ATRIUM_READY meshes=",by_id.size()," replaced_hosts=",REPLACED_IDS.size()," automatic_interior_trees=0")

func sync_ground_palette() -> void:
	var material: ShaderMaterial=materials.Vegetation_ground
	PALETTE.apply_ground(material)
	material.set_shader_parameter("use_shared_meadow_biome",true)
	material.set_shader_parameter("force_green_meadow",true)
	material.set_shader_parameter("force_grass_surface",true)
	material.set_shader_parameter("meadow_detail_strength",0.)

func ground_contains(p: Vector3,inset: float=0.) -> bool:
	if absf(p.y-float(ground_config.height_m))>.12:return false
	var point:=Vector2(p.x,p.z)
	if not Geometry2D.is_point_in_polygon(point,ground_polygon):return false
	if inset<=0.:return true
	for i in ground_polygon.size():
		var closest:=Geometry2D.get_closest_point_to_segment(point,ground_polygon[i],ground_polygon[(i+1)%ground_polygon.size()])
		if point.distance_squared_to(closest)<inset*inset:return false
	return true

func install_grass_cells(stream: Node) -> void:
	for values: Array in ground_config.cells:
		var cell:=Vector3i(values[0],values[1],values[2]);var column:=Vector2i(cell.x,cell.z)
		if not stream.columns.get(column,[]).has(cell):stream.register_cell(cell)
	if not FileAccess.file_exists(GRASS_BAKE):return
	var baked: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(GRASS_BAKE))
	if baked.get("signature","")!=GRASS_STORE.signature(world):return
	if baked.get("ground_config_sha256","")!=FileAccess.get_sha256(GRASS_CONFIG):return
	if baked.get("source_geometry_sha256","")!=FileAccess.get_sha256("res://assets/world/oval_atrium_1031/atrium.glb"):return
	for id: String in baked.cells:
		stream.store.manifest.cells[id]=baked.cells[id]
		var parts:=id.split("_");var cell:=Vector3i(int(parts[0]),int(parts[1]),int(parts[2]))
		stream.empty.erase(cell)
		local_grass_cells+=1
	print("ATRIUM_GRASS_BAKED_CELLS ",local_grass_cells)

func bind_grass(material: ShaderMaterial) -> void:
	var mask: Dictionary=manifest.tree_exclusion
	var center: Array=mask.center
	material.set_shader_parameter("use_atrium_grass_cut",true)
	material.set_shader_parameter("atrium_roof_cut_xz",Vector4(center[0]-1450.,1150.-center[1],92.6,64.4))
	material.set_shader_parameter("atrium_void_cut_xz",Vector4(center[0]-1450.,1150.-center[1],71.,49.))
	material.set_shader_parameter("atrium_cut_min_y",Vector2(60.,36.))
	var bounds: Array=ground_config.bounds_xz
	material.set_shader_parameter("atrium_green_bounds",Vector4(bounds[0][0],bounds[0][1],bounds[1][0],bounds[1][1]))
	material.set_shader_parameter("atrium_green_height",Vector2(34.8,35.4))

func register_reflections(manager: Node) -> void:
	for mesh: MeshInstance3D in geometry.find_children("*","MeshInstance3D",true,false):
		var key: String=mesh.get_meta("atrium_material","")
		var material:=mesh.material_override as StandardMaterial3D
		var color: Color=material.albedo_color if material!=null else (Color("91a46b") if key=="source_terrain" else Color("e8e4da"))
		if key=="Vegetation_ground":color=PALETTE.GROUND.ground_green
		manager.register_reflector(mesh,color)
