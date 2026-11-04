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
	print("TERRAIN_REPAIRS_READY meshes=",meshes_by_source.size())

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
	if not FileAccess.file_exists(GRASS_BAKE):return
	var baked: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(GRASS_BAKE))
	if not baked.get("complete",false) or baked.get("signature","")!=STORE.signature(world):return
	if baked.get("ground_config_sha256","")!=FileAccess.get_sha256(GRASS_CONFIG):return
	if baked.get("source_geometry_sha256","")!=FileAccess.get_sha256("res://assets/world/terrain_repairs_1103/terrain.glb"):return
	for id: String in baked.cells:
		stream.store.manifest.cells[id]=baked.cells[id]
		var parts:=id.split("_");stream.empty.erase(Vector3i(int(parts[0]),int(parts[1]),int(parts[2])))
		local_grass_cells+=1
	print("TERRAIN_REPAIRS_GRASS_BAKED_CELLS ",local_grass_cells)

func register_reflections(manager: Node) -> void:
	for mesh: MeshInstance3D in meshes_by_source.values():manager.register_reflector(mesh,Color("91a46b"))
