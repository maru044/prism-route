extends SceneTree
const OUT="res://docs/oval_atrium_1031/game/"
var world
func _initialize() -> void:call_deferred("run")
func frames(count: int) -> void:
	for i in count:await physics_frame
func native(x: float,y: float,z: float) -> Vector3:return Vector3(x-1450.,z,1150.-y)
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	world=load("res://scenes/map_1021.tscn").instantiate();world.automation_enabled=true
	root.add_child(world);current_scene=world
	while not world.test_ready:await process_frame
	var feature=world.oval_atrium;var stream=world.vegetation.volume_streamer
	assert(feature.local_grass_cells==15,"Local baked grass cells not installed")
	var protected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.current_map_build/atrium_grass_1031/protected_hashes.json"))
	for path: String in protected:assert(FileAccess.get_sha256("res://"+path)==protected[path],"Protected input changed: "+path)
	assert(feature.materials.Vegetation_ground.get_shader_parameter("force_green_meadow")==true)
	assert(world.vegetation.grass_material.get_shader_parameter("atrium_cut_min_y").y>35.4)
	world.character.set_spawn(native(1086.01,302.52,35.04),0)
	world.set_free(true);world.set_review_ui_visible(false)
	world.camera.global_position=native(1130.,276.,38.3);world.camera.look_at(native(1085.,309.,35.8))
	stream.refresh()
	var baked: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(feature.GRASS_BAKE))
	var wanted: Array[Vector3i]=[]
	for id: String in baked.cells:
		if int(baked.cells[id].instances)==0:continue
		var p:=id.split("_");wanted.append(Vector3i(int(p[0]),int(p[1]),int(p[2])))
	var begin:=Time.get_ticks_msec()
	while Time.get_ticks_msec()-begin<20000:
		await process_frame
		if wanted.all(func(cell):return stream.active.has(cell)):break
	var active_local:=0;var blades:=0
	for cell: Vector3i in wanted:
		assert(stream.active.has(cell),"Baked courtyard grass did not load: "+str(cell))
		active_local+=1
		for node: MultiMeshInstance3D in stream.active[cell].find_children("*","MultiMeshInstance3D",true,false):
			assert(node.material_override==world.vegetation.grass_material,"Wrong grass material")
			blades+=node.multimesh.instance_count
	await frames(80)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"green_grass_near.png")
	var report: Dictionary={"passed":true,"installed_baked_cells":feature.local_grass_cells,"active_nonempty_local_cells":active_local,
		"active_grass_blades":blades,"same_world_grass_material":true,"ground_shader":feature.materials.Vegetation_ground.shader.resource_path,
		"ground_green":str(feature.materials.Vegetation_ground.get_shader_parameter("ground_green")),
		"user_tree_save_unchanged":true,"global_bake_unchanged":true,"mesh_unchanged":true,"actual_scene":world.scene_file_path}
	FileAccess.open(OUT+"green_grass_review.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ATRIUM_GREEN_GRASS_READY ",JSON.stringify(report));quit()
