extends SceneTree
## Reload the real world with vegetation and verify installed local caches.
const STORE=preload("res://scripts/grass_baked_store.gd")
const OUT="res://docs/terrain_seams_1102/"
var world
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func frames(n: int) -> void:
	for i in n:await process_frame
func native(p: Vector3) -> Vector3:return Vector3(p.x-1450.,p.z,1150.-p.y)
func run() -> void:
	create_timer(240).timeout.connect(func():push_error("Terrain visual review timeout");quit(1))
	AudioServer.set_bus_mute(0,true)
	world=load("res://scenes/map_1021.tscn").instantiate();world.automation_enabled=true
	root.add_child(world);current_scene=world
	while not world.test_ready:await process_frame
	var feature=world.terrain_repairs;var stream=world.vegetation.volume_streamer
	var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(feature.GRASS_CONFIG))
	var baked: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(feature.GRASS_BAKE))
	check(world.planting.load_error.is_empty(),"Planting reload error")
	check(feature.local_grass_cells==config.cells.size(),"New bake not installed")
	check(baked.signature==STORE.signature(world),"Bake signature mismatch")
	var bytes_checked:=0;var root_samples:=0;var max_error:=0.
	var ids: Array=baked.cells.keys();ids.sort()
	for i in ids.size():
		var id: String=ids[i];var row: Dictionary=baked.cells[id]
		check(stream.store.manifest.cells[id].resource_path==row.resource_path,"Old cache selected: "+id)
		check(FileAccess.get_sha256(row.resource_path)==row.sha256,"Grass file corrupt: "+id)
		bytes_checked+=int(row.compressed_bytes)
		if i%30!=0 or int(row.root_count)==0:continue
		var raw:=FileAccess.get_file_as_bytes(row.resource_path).decompress(row.raw_bytes,FileAccess.COMPRESSION_ZSTD)
		var roots:=raw.slice(0,int(row.root_count)*48).to_float64_array()
		var parts:=id.split("_");var origin:=Vector3(float(parts[0]),float(parts[1]),float(parts[2]))*24.
		for j in range(0,int(row.root_count),maxi(1,int(row.root_count)/12)):
			var p:=origin+Vector3(roots[j*6],roots[j*6+2],roots[j*6+1])
			var q:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*.15,p-Vector3.UP*.15,16);q.hit_back_faces=true
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(q)
			check(not hit.is_empty(),"Grass root lacks ground: "+id)
			if not hit.is_empty():max_error=maxf(max_error,absf(hit.position.y-p.y))
			root_samples+=1
	check(max_error<.02,"Grass roots float")
	var captures: Array=[]
	if DisplayServer.get_name()!="headless":
		world.set_review_ui_visible(false);world.set_free(true)
		var views: Dictionary={
			"waterfront_game":[Vector3(1410,1850,30),Vector3(1320,1730,1.5)],
			"east_game":[Vector3(1755,1410,56),Vector3(1685,1260,14)],
			"west_game":[Vector3(445,1235,34),Vector3(326,1140,5)]}
		for label: String in views:
			world.camera.global_position=native(views[label][0]);world.camera.look_at(native(views[label][1]))
			stream.refresh();await frames(240);await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(OUT+label+".png")==OK,"Capture failed")
			captures.append(label)
	var report: Dictionary={"passed":failures.is_empty(),"failures":failures,"grass_cells":feature.local_grass_cells,
		"grass_bytes_checked":bytes_checked,"root_samples":root_samples,"max_grass_root_error_m":max_error,
		"effective_trees":world.planting.store.all_records().size(),"global_bake_valid":stream.store.manifest.signature==STORE.signature(world),
		"captures":captures,"scene":world.scene_file_path}
	FileAccess.open(OUT+"game_review.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TERRAIN_GAME_REVIEW ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
