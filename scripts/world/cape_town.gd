extends "res://scripts/world/sandbar_pavilion.gd"
## Native fixed town; markers are independent of merged render batches.
const TOWN_GEOMETRY := preload("res://assets/world/cape_town_1110/town.glb")
const TOWN_MANIFEST := "res://assets/world/cape_town_1110/manifest.json"
const GRASS_BAKE := "res://assets/world/cape_town_1110/grass_bake.json"
const STORE := preload("res://scripts/grass_baked_store.gd")
var world
var cut: Image
var cut_texture: ImageTexture
var ground_material: ShaderMaterial
var installed_cells := 0

func _init() -> void:
	manifest=JSON.parse_string(FileAccess.get_file_as_string(TOWN_MANIFEST))

func _ready() -> void:
	name="CapeTown"
	var config: Dictionary=manifest.ground_cut
	cut=Image.create_from_data(config.size[0],config.size[1],false,Image.FORMAT_RGBAH,FileAccess.get_file_as_bytes("res://assets/world/cape_town_1110/"+str(config.path)))
	cut_texture=ImageTexture.create_from_image(cut)
	ground_material=ShaderMaterial.new();ground_material.shader=preload("res://shaders/environment/cape_town_ground.gdshader")
	ground_material.set_shader_parameter("ground_field",cut_texture)
	ground_material.set_shader_parameter("ground_bounds",Vector4(config.origin[0],config.origin[1],config.extent[0],config.extent[1]))
	ground_material.set_shader_parameter("beach_width",config.beach_width_m)
	var beach: ShaderMaterial=preload("res://assets/environment/beach_sand/beach_sand.tres")
	for key: String in ["sand_detail","sand_macro","sand_roughness","dry_color","wet_color","dry_roughness","wet_roughness","detail_strength","macro_strength"]:
		ground_material.set_shader_parameter(key,beach.get_shader_parameter(key))
	var resources: Dictionary={"cool_white_wall":WALL,"honey_timber":TIMBER,"sea_green_roof":ROOF}
	for key: String in manifest.materials:
		var row: Dictionary=manifest.materials[key]
		if key=="sand":
			materials[key]=ground_material
			continue
		var material: StandardMaterial3D
		if resources.has(row.get("resource","")):
			material=resources[row.resource].duplicate()
			material.uv1_triplanar=false
		else:
			material=StandardMaterial3D.new()
			material.albedo_color=Color(row.color[0],row.color[1],row.color[2])
			material.roughness=float(row.get("roughness",.8))
			material.metallic=float(row.get("metallic",0.))
		if key=="sea_glass":
			material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
			material.albedo_color=Color(.13,.42,.49,.52)
			material.roughness=.22;material.metallic=0.
		materials[key]=material
	geometry=TOWN_GEOMETRY.instantiate();add_child(geometry)
	var by_id: Dictionary={}
	for row: Dictionary in manifest.objects:by_id[row.id]=row
	for mesh: MeshInstance3D in geometry.find_children("*","MeshInstance3D",true,false):
		var id:=str(mesh.name).get_slice("_",1)
		var row: Dictionary=by_id[id]
		mesh.material_override=materials[row.material_key]
		mesh.visible=bool(row.render);mesh.set_meta("source_id",id);meshes_by_source[id]=mesh
		if not row.collision:continue
		var body:=StaticBody3D.new();body.collision_layer=49 if row.category=="terrain" else 33;body.collision_mask=0
		body.set_meta("source_id",id);body.set_meta("surface_kind","Terrain" if row.category=="terrain" else "Structure")
		body.set_meta("cape_town",true);mesh.add_child(body)
		var shape:=CollisionShape3D.new();shape.shape=mesh.mesh.create_trimesh_shape();shape.shape.backface_collision=true;body.add_child(shape)
	_build_furniture("cape_town_")
	print("CAPE_TOWN_READY buildings=14 meshes=",meshes_by_source.size()," triangles=",manifest.triangle_count)

func ground_data(p: Vector3) -> Color:
	var config: Dictionary=manifest.ground_cut
	var pixel:=(Vector2(p.x,p.z)-Vector2(config.origin[0],config.origin[1]))/float(config.pixel_size)
	if pixel.x<0 or pixel.y<0 or pixel.x>=cut.get_width() or pixel.y>=cut.get_height():return Color(0,-10000,0,0)
	return cut.get_pixel(floori(pixel.x),floori(pixel.y))

func grass_band(p: Vector3,margin:=.55) -> int:
	if p.y<float(manifest.ground_cut.min_height) or p.y>float(manifest.ground_cut.max_height):return -1
	var data:=ground_data(p)
	if data.a<.5:return -1
	return 1 if data.r<margin or absf(p.y-data.g)>.20 else 0

func blocks_grass(p: Vector3,margin:=.55) -> bool:return grass_band(p,margin)==1

func sync_ground_palette() -> void:
	for key: String in preload("res://scripts/meadow_palette.gd").BIOME_PARAMETERS+["ground_dry","ground_green","far_ground_dry","far_ground_green","meadow_color_fade"]:
		ground_material.set_shader_parameter(key,world.terrain_material.get_shader_parameter(key))

func install_grass_cells(stream: Node) -> void:
	for values: Array in manifest.ground_cut.cells:
		var cell:=Vector3i(values[0],values[1],values[2])
		if not stream.columns.get(Vector2i(cell.x,cell.z),[]).has(cell):stream.register_cell(cell)
	if not FileAccess.file_exists(GRASS_BAKE):return
	var baked: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(GRASS_BAKE))
	if not baked.get("complete",false) or baked.signature!=STORE.signature(world):return
	if baked.source_sha!=FileAccess.get_sha256(TOWN_MANIFEST):return
	if baked.geometry_sha!=FileAccess.get_sha256("res://assets/world/cape_town_1110/town.glb"):return
	if baked.mask_sha!=FileAccess.get_sha256("res://assets/world/cape_town_1110/ground_field.rgba"):return
	if baked.get("sampler_sha","")!=FileAccess.get_sha256("res://scripts/tree_planting/world_vegetation.gd"):return
	if baked.get("runtime_sha","")!=FileAccess.get_sha256("res://scripts/world/cape_town.gd"):return
	for id: String in baked.cells:
		stream.store.manifest.cells[id]=baked.cells[id]
		var p:=id.split("_");stream.empty.erase(Vector3i(int(p[0]),int(p[1]),int(p[2])))
		installed_cells+=1
	print("CAPE_TOWN_GRASS_CELLS ",installed_cells)

func bind_vegetation(vegetation: Node) -> void:
	var bounds: Dictionary=manifest.ground_cut
	vegetation.grass_material.set_shader_parameter("use_cape_town_grass_cut",true)
	vegetation.grass_material.set_shader_parameter("cape_town_grass_cut",cut_texture)
	vegetation.grass_material.set_shader_parameter("cape_town_cut_bounds",Vector4(bounds.origin[0],bounds.origin[1],bounds.extent[0],bounds.extent[1]))
	# Match the CAD planar u axis; interaction roots separately use right-handed +Z.
	var f:=Vector3(manifest.forward[0],0,manifest.forward[2]);var r:=f.cross(Vector3.UP)
	var origin:=Vector3(manifest.site_cad[0]-1450.,0,1150.-manifest.site_cad[1])
	var transforms: Array[Transform3D]=[]
	# Existing project tree models/palettes/LOD. No planting-save mutation.
	for p: Vector2 in [Vector2(-6,-2),Vector2(6,3),Vector2(-30,18),Vector2(30,18),Vector2(-60,42),Vector2(60,42),Vector2(-60,-42),Vector2(60,-42),Vector2(-96,130),Vector2(-67,130)]:
		var point:=origin+r*p.x+f*p.y+Vector3.UP*1.38
		transforms.append(Transform3D(Basis(Vector3.UP,p.x*.1),point))
	for transform: Transform3D in transforms:
		# Keep LOD visibility centered on the individual crown. A town-wide
		# MultiMesh AABB can cull all crowns while their trunks remain visible.
		var tree:=Node3D.new();tree.name="TownShadeTree";tree.position=transform.origin;add_child(tree)
		var local_transforms: Array[Transform3D]=[Transform3D(transform.basis,Vector3.ZERO)]
		for level in 3:vegetation._add_tree_lod_level(tree,1,local_transforms,0,level,0.)
		var body:=StaticBody3D.new();body.position=transform.origin+Vector3.UP*2.;body.collision_layer=33;body.collision_mask=0;add_child(body)
		var shape:=CollisionShape3D.new();var cylinder:=CylinderShape3D.new();cylinder.radius=.28;cylinder.height=4.;shape.shape=cylinder;body.add_child(shape)
