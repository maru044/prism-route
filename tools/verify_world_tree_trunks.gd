extends SceneTree
## Actual 1021 integration: source layout, all rendered tree transforms, wood,
## crown geometry, biome materials and existing offline grass data.
const WOOD := preload("res://scripts/tree_trunk_assets.gd")
const OUT := "res://.vegetation_art_build/trunk_comparison/world/"
var failures: Array[String] = []
var layout: Array = []
var layout_bins: Dictionary = {}
var source_models: Dictionary = {}

func _initialize() -> void:call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func frames(count: int) -> void:
	for i in count:await process_frame

func source_index(position: Vector3) -> int:
	var cell := Vector2i(roundi(position.x),roundi(position.z))
	for dx in range(-1,2):
		for dz in range(-1,2):
			var index: int = layout_bins.get(cell+Vector2i(dx,dz),-1)
			if index<0:continue
			var row: Array = layout[index]
			if position.distance_to(Vector3(row[0],row[1],row[2]))<.005:return index
	return -1

func check_transforms(nodes: Array, level: int) -> Dictionary:
	var groups: Dictionary = {}
	var checked := 0
	for node: MultiMeshInstance3D in nodes:
		var is_wood: bool = "Trunks" in str(node.name)
		var group := "lod%d_%s" % [level,"wood" if is_wood else "crown"]
		if not groups.has(group):groups[group]={}
		var model_id := str(node.name).get_slice("_",0).trim_prefix("Tree").to_int()
		if is_wood:
			check(node.multimesh.mesh==WOOD.mesh_for(["small","broad","upright"][model_id]),"Old wood remains in "+str(node.name))
		for instance in node.multimesh.instance_count:
			var transform: Transform3D = node.global_transform*node.multimesh.get_instance_transform(instance)
			var index := source_index(transform.origin)
			if index<0:
				check(false,"Rendered tree has no source root: "+str(transform.origin))
				continue
			var row: Array = layout[index]
			var expected := Basis(Vector3.UP,float(row[3]))
			check(transform.basis.x.normalized().dot(expected.x)>.999999,"Rendered tree yaw differs from stable layout")
			check(transform.basis.y.normalized().dot(Vector3.UP)>.999999,"Tree was tilted instead of rotated around vertical")
			check(absf(transform.basis.x.length()-float(row[4]))<.00001,"Tree scale changed")
			check(not groups[group].has(index),"Duplicated root in "+group)
			groups[group][index]=true
			source_models[index]=model_id
			checked+=1
	var result: Dictionary = {"checked_transforms":checked}
	for group: String in groups:
		check(groups[group].size()==layout.size(),"Tree population changed in "+group)
		result[group]=groups[group].size()
	return result

func check_crowns(renderer) -> void:
	for pair: Array in [[renderer.TREE_NEAR_SCENE,renderer.tree_near_leaf_mesh],
		[renderer.TREE_LARGE_BROAD_SCENE,renderer.tree_large_broad_leaf_mesh],
		[renderer.TREE_LARGE_UPRIGHT_SCENE,renderer.tree_large_upright_leaf_mesh],
		[renderer.TREE_NEAR_LOD1_SCENE,renderer.tree_near_lod1_leaf_mesh],
		[renderer.TREE_LARGE_BROAD_LOD1_SCENE,renderer.tree_large_broad_lod1_leaf_mesh],
		[renderer.TREE_LARGE_UPRIGHT_LOD1_SCENE,renderer.tree_large_upright_lod1_leaf_mesh]]:
		var original: Mesh = renderer._extract_tree_meshes(pair[0])[1]
		var current: Mesh = pair[1]
		check(original.get_surface_count()==current.get_surface_count(),"Crown surfaces changed")
		for surface in current.get_surface_count():
			var a := original.surface_get_arrays(surface)
			var b := current.surface_get_arrays(surface)
			for attribute in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_COLOR,Mesh.ARRAY_INDEX]:
				check(a[attribute]==b[attribute],"Crown geometry/UV/normal/color changed")

func check_visual_library() -> void:
	for path: String in WOOD.SOURCE_SPECIES:
		var root: Node3D = load(path).instantiate()
		var leaves: Dictionary = {}
		for node: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
			if not "trunk" in str(node.name).to_lower():leaves[node]=node.mesh
		WOOD.apply_visual(root)
		for node: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
			if "trunk" in str(node.name).to_lower():check(node.mesh==WOOD.mesh_for(WOOD.SOURCE_SPECIES[path]),"Authoring visual differs from production wood")
			else:check(node.mesh==leaves[node],"Authoring changes accepted canopy")
		root.free()

func screenshot(name: String) -> void:
	await frames(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size=Vector2i(1600,900);Engine.max_fps=60
	var layout_path := "res://assets/world/current_map_validation/tree_layout.json"
	var layout_sha := FileAccess.get_sha256(layout_path)
	layout=JSON.parse_string(FileAccess.get_file_as_string(layout_path))
	var yaw_bins: Array[int]=[0,0,0,0,0,0,0,0,0,0,0,0]
	for index in layout.size():
		var row: Array=layout[index]
		layout_bins[Vector2i(roundi(row[0]),roundi(row[2]))]=index
		yaw_bins[mini(11,int(fposmod(row[3],TAU)/TAU*12))]+=1
	for count in yaw_bins:check(count>layout.size()/16 and count<layout.size()/9,"Tree yaw distribution lacks natural variation")
	check_visual_library()
	var scene: Node3D=load("res://scenes/map_1021.tscn").instantiate()
	scene.automation_enabled=true
	root.add_child(scene)
	var begin:=Time.get_ticks_msec()
	while not scene.test_ready and Time.get_ticks_msec()-begin<150000:await process_frame
	if not scene.test_ready:
		check(false,"World startup timeout");quit(1);return
	var renderer=scene.vegetation
	scene.character.set_physics_process(false)
	check(renderer.tree_instance_count==layout.size(),"World tree count changed")
	check(renderer.tree_near_trunk_mesh==renderer.tree_near_lod1_trunk_mesh,"Small wood changes between LODs")
	check(renderer.tree_large_broad_trunk_mesh==renderer.tree_large_broad_lod1_trunk_mesh,"Broad wood changes between LODs")
	check(renderer.tree_large_upright_trunk_mesh==renderer.tree_large_upright_lod1_trunk_mesh,"Upright wood changes between LODs")
	check_crowns(renderer)
	var transform_results: Array[Dictionary]=[]
	for level in 3:
		transform_results.append(check_transforms(renderer.get(["tree_lod0_nodes","tree_lod1_nodes","tree_lod2_nodes"][level]),level))
	for row: Dictionary in scene.foliage_style.records:
		if not row.green:continue
		var material: ShaderMaterial=row.material
		check(material.get_shader_parameter("species_biome_tint")==true,"Green trees no longer follow world mask")
		for parameter: String in scene.foliage_style.BIOME_PARAMETERS:
			check(material.get_shader_parameter(parameter)==renderer.grass_material.get_shader_parameter(parameter),"Tree world-mask parameters changed")
	var signature: String=load("res://scripts/grass_baked_store.gd").signature(scene)
	check(signature==renderer.volume_streamer.store.manifest.get("signature",""),"Tree integration invalidates the existing grass bake")
	check(renderer.volume_streamer.store.manifest.get("complete",false),"Existing complete grass bake is not used")
	check(FileAccess.get_sha256(layout_path)==layout_sha,"Tree integration rewrote planting layout")
	await scene.select_spawn(0)
	scene.character.set_physics_process(false)
	scene.set_free(true)
	scene.set_review_ui_visible(false)
	var center: Vector3=scene.character.global_position
	for wanted in [0,1,2]:
		var nearest:=-1
		var distance:=INF
		for index in source_models:
			if source_models[index]!=wanted:continue
			var row: Array=layout[index]
			var p:=Vector3(row[0],row[1],row[2])
			if absf(p.y-center.y)>3.0:continue
			if p.distance_squared_to(center)<distance:nearest=index;distance=p.distance_squared_to(center)
		if nearest<0:continue
		var row: Array=layout[nearest]
		var p:=Vector3(row[0],row[1],row[2])
		scene.camera.global_position=p+Vector3(-9,2.5,5)
		scene.camera.look_at(p+Vector3.UP*2.7)
		scene.vegetation.volume_streamer.refresh()
		await frames(90)
		await screenshot(["small_in_world","broad_in_world","upright_in_world"][wanted])
	var triangles: Dictionary={}
	for species: String in WOOD.SCENES:triangles[species]=WOOD.mesh_for(species).get_faces().size()/3
	var result: Dictionary={"passed":failures.is_empty(),"failures":failures,"trees":layout.size(),
		"yaw_30degree_bins":yaw_bins,"layout_sha256":layout_sha,"grass_bake_signature":signature,
		"transforms":transform_results,"wood_triangles":triangles}
	FileAccess.open(OUT+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("WORLD_TREE_TRUNKS_VERIFY ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
