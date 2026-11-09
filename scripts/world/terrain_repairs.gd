extends Node3D
## Three reviewed native repairs; local root buffers override the immutable bake.
const GEOMETRY=preload("res://assets/world/terrain_repairs_1103/terrain.glb")
const MANIFEST="res://assets/world/terrain_repairs_1103/manifest.json"
const REPLACED_IDS=["e7a0e133-f284-4cd4-8796-349bb8638efc"]
const GRASS_CONFIG="res://assets/world/terrain_repairs_1103/ground_grass.json"
const GRASS_BAKE="res://assets/world/terrain_repairs_1103/grass_bake/manifest.json"
const STORE=preload("res://scripts/grass_baked_store.gd")
var world
var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
var geometry: Node3D
var meshes_by_source: Dictionary={}
var support_images: Array[Image]=[]
var local_grass_cells:=0
var shoulder_image: Image
var shoulder_material: ShaderMaterial
var shoulder_mesh: MeshInstance3D
var shoulder_installed_cells:=0

func _ready() -> void:
	name="TerrainRepairs"
	for row: Dictionary in manifest.support:
		support_images.append(Image.create_from_data(row.size[0],row.size[1],false,Image.FORMAT_RF,
			FileAccess.get_file_as_bytes("res://assets/world/terrain_repairs_1103/"+row.path)))
	geometry=GEOMETRY.instantiate();add_child(geometry)
	for mesh: MeshInstance3D in geometry.find_children("*","MeshInstance3D",true,false):
		var id:=str(mesh.name).get_slice("_",1)
		mesh.material_override=world.terrain_material;mesh.set_meta("source_id",id)
		meshes_by_source[id]=mesh
		var body:=StaticBody3D.new();body.collision_layer=49;body.collision_mask=0
		body.set_meta("source_id",id);body.set_meta("surface_kind","Terrain");mesh.add_child(body)
		var shape:=CollisionShape3D.new();shape.shape=mesh.mesh.create_trimesh_shape()
		shape.shape.backface_collision=true;body.add_child(shape)
	_configure_road_shoulder()
	print("TERRAIN_REPAIRS_READY meshes=",meshes_by_source.size())

func _configure_road_shoulder() -> void:
	if not manifest.has("road_shoulder"):return
	var config: Dictionary=manifest.road_shoulder
	var path: String="res://assets/world/terrain_repairs_1103/"+str(config.mask_path)
	if FileAccess.get_sha256(path)!=config.mask_sha256 or FileAccess.get_sha256(world.ASSETS+"current_region.glb")!=config.source_mesh_sha256:
		push_warning("Road shoulder mask is stale; regenerate it before baking")
		return
	shoulder_image=Image.create_from_data(config.size[0],config.size[1],false,Image.FORMAT_RGH,FileAccess.get_file_as_bytes(path))
	shoulder_material=world.terrain_material.duplicate() as ShaderMaterial
	var texture_image:=shoulder_image.duplicate() as Image
	texture_image.generate_mipmaps()
	shoulder_material.set_shader_parameter("landscape_mask",ImageTexture.create_from_image(texture_image))
	shoulder_material.set_shader_parameter("mask_origin_xz",Vector2(config.origin_xz[0],config.origin_xz[1]))
	shoulder_material.set_shader_parameter("mask_extent_xz",Vector2(config.size[0],config.size[1])*float(config.pixel_size))
	for mesh: MeshInstance3D in world.model.find_children("*","MeshInstance3D",true,false):
		if not str(mesh.name).ends_with(str(config.source_id)):continue
		shoulder_mesh=mesh
		mesh.material_override=shoulder_material
		for body: StaticBody3D in mesh.find_children("*","StaticBody3D",true,false):
			body.collision_layer=49
			body.set_meta("surface_kind","Terrain")
		break
	assert(shoulder_mesh!=null,"Selected road shoulder missing from base map")
	print("ROAD_SHOULDER_READY curb_m=",config.curb_width_m)

func sync_shoulder_palette() -> void:
	if shoulder_material==null:return
	for key: String in ["ground_dry","ground_green","far_ground_dry","far_ground_green","use_far_meadow_color","use_shared_meadow_biome","biome_noise_texture","biome_noise_scale","biome_warp_distance","biome_transition_half_width","biome_center_x","meadow_color_fade"]:
		shoulder_material.set_shader_parameter(key,world.terrain_material.get_shader_parameter(key))

func road_shoulder_band(p: Vector3,margin: float) -> int:
	if shoulder_image==null:return -1
	var config: Dictionary=manifest.road_shoulder
	var x:=floori((p.x-float(config.origin_xz[0]))/float(config.pixel_size))
	var z:=floori((p.z-float(config.origin_xz[1]))/float(config.pixel_size))
	if x<0 or z<0 or x>=shoulder_image.get_width() or z>=shoulder_image.get_height():return -1
	var data:=shoulder_image.get_pixel(x,z)
	if data.g< -9999. or absf(p.y-data.g)>.6:return -1
	return 1 if data.r<margin else 0

func height_at(p: Vector3) -> float:
	var height:=-INF
	for i in manifest.support.size():
		var row: Dictionary=manifest.support[i]
		var x:=floori((p.x-float(row.origin_xz[0]))/float(row.pixel_size))
		var z:=floori((p.z-float(row.origin_xz[1]))/float(row.pixel_size))
		if x<0 or z<0 or x>=support_images[i].get_width() or z>=support_images[i].get_height():continue
		var value:=support_images[i].get_pixel(x,z).r
		if value> -9999.:height=maxf(height,value)
	return height

func install_grass_cells(stream: Node) -> void:
	var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(GRASS_CONFIG))
	for values: Array in config.cells:
		var cell:=Vector3i(values[0],values[1],values[2]);var column:=Vector2i(cell.x,cell.z)
		if not stream.columns.get(column,[]).has(cell):stream.register_cell(cell)
	if shoulder_image!=null:
		for values: Array in manifest.road_shoulder.cells:
			var cell:=Vector3i(values[0],values[1],values[2])
			if not stream.columns.get(Vector2i(cell.x,cell.z),[]).has(cell):stream.register_cell(cell)
	if not FileAccess.file_exists(GRASS_BAKE):return
	var baked: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(GRASS_BAKE))
	if not baked.get("complete",false) or baked.get("signature","")!=STORE.signature(world):return
	if baked.get("ground_config_sha256","")!=FileAccess.get_sha256(GRASS_CONFIG):return
	if baked.get("source_geometry_sha256","")!=FileAccess.get_sha256("res://assets/world/terrain_repairs_1103/terrain.glb"):return
	var shoulder_keys: Dictionary={}
	var shoulder_valid: bool=shoulder_image!=null and baked.get("road_shoulder_manifest_sha256","")==FileAccess.get_sha256(MANIFEST)
	if manifest.has("road_shoulder"):
		for cell: Array in manifest.road_shoulder.cells:shoulder_keys[STORE.key(Vector3i(cell[0],cell[1],cell[2]))]=true
	for id: String in baked.cells:
		if shoulder_keys.has(id) and not shoulder_valid:
			stream.store.manifest.cells.erase(id)
			continue
		stream.store.manifest.cells[id]=baked.cells[id]
		var parts:=id.split("_");stream.empty.erase(Vector3i(int(parts[0]),int(parts[1]),int(parts[2])))
		local_grass_cells+=1
		if shoulder_keys.has(id):shoulder_installed_cells+=1
	print("TERRAIN_REPAIRS_GRASS_BAKED_CELLS ",local_grass_cells)
	if shoulder_installed_cells>0:print("ROAD_SHOULDER_GRASS_BAKED_CELLS ",shoulder_installed_cells)

func register_reflections(manager: Node) -> void:
	for mesh: MeshInstance3D in meshes_by_source.values():manager.register_reflector(mesh,Color("91a46b"))
