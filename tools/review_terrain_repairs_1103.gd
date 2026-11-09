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
func digest(bytes: PackedByteArray) -> String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty():hash.update(bytes)
	return hash.finish().hex_encode()
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
	check(feature.local_grass_cells==baked.cells.size(),"New bake not installed")
	check(baked.signature==STORE.signature(world),"Bake signature mismatch")
	if feature.manifest.has("road_shoulder"):
		check(feature.shoulder_installed_cells==feature.manifest.road_shoulder.cells.size(),"Road shoulder cache not installed")
		check(feature.shoulder_mesh!=null and feature.shoulder_mesh.material_override==feature.shoulder_material,"Road shoulder terrain material missing")
		check(feature.shoulder_material.get_shader_parameter("landscape_mask")!=world.mask_texture,"Road edge needs its own mask")
		for body: StaticBody3D in feature.shoulder_mesh.find_children("*","StaticBody3D",true,false):
			check(body.collision_layer==49,"Road shoulder actor and grass query layers")
	var bytes_checked:=0;var root_samples:=0;var max_error:=0.
	var ids: Array=baked.cells.keys();ids.sort()
	for i in ids.size():
		var id: String=ids[i];var row: Dictionary=baked.cells[id]
		if not stream.store.manifest.cells.has(id):
			check(false,"Missing installed grass cell: "+id)
			continue
		check(stream.store.manifest.cells[id].resource_path==row.resource_path,"Old cache selected: "+id)
		var payload:=STORE.read_payload(row)
		check(digest(payload)==row.sha256,"Grass file corrupt: "+id)
		bytes_checked+=int(row.compressed_bytes)
		if i%30!=0 or int(row.root_count)==0:continue
		var raw:=payload.decompress(row.raw_bytes,FileAccess.COMPRESSION_ZSTD)
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
			if "--road-shoulder" in OS.get_cmdline_user_args():break
			world.camera.global_position=native(views[label][0]);world.camera.look_at(native(views[label][1]))
			stream.refresh();await frames(240);await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(OUT+label+".png")==OK,"Capture failed")
			captures.append(label)
		if "--road-shoulder" in OS.get_cmdline_user_args():
			var shoulder: Dictionary=feature.manifest.road_shoulder
			var road_views: Array=[{"name":"road_shoulder_game","eye":Vector3(-650,30,-497),"target":Vector3(-650,1,-555)},
				{"name":"road_shoulder_detail","eye":Vector3(-495,3.7,-589),"target":Vector3(-477,1.1,-610)}]
			world.character.visible=false
			for view: Dictionary in road_views:
				var begin:=Time.get_ticks_msec()
				while Time.get_ticks_msec()-begin<5000:
					world.camera.global_position=view.eye;world.camera.look_at(view.target);world.camera.make_current()
					await process_frame
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png(OUT+str(view.name)+".png")==OK,"Road shoulder capture failed")
				captures.append(view.name)
	var report: Dictionary={"passed":failures.is_empty(),"failures":failures,"grass_cells":feature.local_grass_cells,
		"grass_bytes_checked":bytes_checked,"root_samples":root_samples,"max_grass_root_error_m":max_error,
		"effective_trees":world.planting.store.all_records().size(),"global_bake_valid":stream.store.manifest.signature==STORE.signature(world),
		"captures":captures,"scene":world.scene_file_path}
	if feature.manifest.has("road_shoulder"):
		report["road_shoulder"]=baked.get("road_shoulder_report",{})
		report["road_shoulder_installed_cells"]=feature.shoulder_installed_cells
	FileAccess.open(OUT+"game_review.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TERRAIN_GAME_REVIEW ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
