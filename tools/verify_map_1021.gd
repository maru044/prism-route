extends SceneTree
## Exercise actual per-storey physics spawning, walking, mask exclusions and rendering.
var scene
var failures: Array[String]=[]
var rows: Array[Dictionary]=[]
var vehicle_rows: Array[Dictionary]=[]
var gallery_directions: Array[Dictionary]=[]
const OUT := "res://assets/world/current_map_validation/review/"

func _initialize() -> void:
	call_deferred("run")

func frames(count:int) -> void:
	for i in count: await physics_frame

func check(ok:bool,message:String) -> void:
	if not ok:failures.append(message);push_error(message)

func shot(name:String) -> void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUT+name+".png")==OK)
	print("CURRENT_MAP_CAPTURE ",name)

func toggle_actor() -> void:
	var key:=InputEventKey.new();key.physical_keycode=KEY_C;key.pressed=true
	scene._unhandled_input(key)
	while scene.switching_actor:await physics_frame
	await frames(65)

func vegetation_checks() -> Dictionary:
	var veg=scene.vegetation
	var reference=load("res://scripts/map_1012_vegetation.gd").new()
	reference.biome_noise_texture=scene._noise();reference._load_meshes_and_materials()
	check(veg.grass_mesh.get_aabb().is_equal_approx(reference.grass_mesh.get_aabb()),"Grass geometry differs from 1012")
	for uniform in ["use_biome_palette","use_multimesh_color_data","canopy_base_color","canopy_color_uniformity","wind_strength","wind_speed","grass_near_fade_start","grass_near_fade_end","grass_far_fade_start","grass_far_fade_end"]:
		check(veg.grass_material.get_shader_parameter(uniform)==reference.grass_material.get_shader_parameter(uniform),"Grass setting differs from 1012: "+uniform)
	reference.free()
	var records: Array=JSON.parse_string(FileAccess.get_file_as_string(scene.ASSETS+"tree_layout.json"))
	var bins: Dictionary={};var large_bins: Dictionary={}
	var min_space:=INF;var min_large:=INF;var root_errors:=0;var max_height_error:=0.0;var large:=0
	var root_error_reasons: Dictionary={};var root_error_examples: Array=[]
	var root_source_counts: Dictionary={}
	for row: Array in records:
		var p:=Vector3(row[0],row[1],row[2])
		min_space=minf(min_space,nearest_previous(p,bins,9))
		if int(row[5])==1:large+=1;min_large=minf(min_large,nearest_previous(p,large_bins,22))
		var q:=PhysicsRayQueryParameters3D.create(Vector3(p.x,400,p.z),Vector3(p.x,-30,p.z),5);q.hit_back_faces=true
		var hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty() or hit.collider.get_meta("surface_kind", "")!="Terrain" or scene.architectural_band(p,3):
			root_errors+=1
			var reason: String="empty" if hit.is_empty() else ("mask" if scene.architectural_band(p,3) else str(hit.collider.get_meta("surface_kind", "")))
			root_error_reasons[reason]=root_error_reasons.get(reason,0)+1
			if root_error_examples.size()<6:root_error_examples.append({"position":[p.x,p.y,p.z],"reason":reason})
		else:
			max_height_error=maxf(max_height_error,absf(hit.position.y-p.y))
			var source_id: String=hit.collider.get_meta("source_id", "")
			root_source_counts[source_id]=root_source_counts.get(source_id,0)+1
	check(root_errors==0,"Invalid fixed tree roots: %d"%root_errors)
	check(max_height_error<.03,"Tree heights differ from imported collision")
	check(min_space>=8.999,"Trees closer than 1012's 9 m")
	check(min_large>=21.999,"Large trees closer than 1012's 22 m")
	check(veg.tree_instance_count==records.size() and veg.large_tree_instance_count==large,"Rendered tree population differs from baked layout")
	check(root_source_counts.get("a2a15e34-a9db-4e6a-a4ce-be472804bd15",0)>100,"Restored large land cap still has no planting")
	check(root_source_counts.get("9885b6ab-30cd-4214-b68d-b5d1faa7c1d1",0)==0,"Trees grew on architectural shell")
	return {"trees":records.size(),"large_trees":large,"minimum_tree_spacing_m":min_space,"minimum_large_spacing_m":min_large,"root_errors":root_errors,"root_error_reasons":root_error_reasons,"root_error_examples":root_error_examples,"root_source_counts":root_source_counts,"max_root_height_error_m":max_height_error,"grass_matches_1012":true,"grass_samples_per_24m_chunk":veg.GRASS_SAMPLES_PER_CHUNK,"blades_per_sample":veg.GRASS_BLADES_PER_SAMPLE,"grass_height_m":veg.grass_mesh.get_aabb().size.y}

func surface_role_checks() -> Dictionary:
	var policy: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(scene.ASSETS+"surface_roles.json"))
	var meshes: Dictionary={}
	for node in scene.model.find_children("*","MeshInstance3D",true,false):meshes[str(node.name).get_slice("_",1)]=node
	var counts: Dictionary={};var checked:=0
	for row: Dictionary in scene.metadata.object_records:
		var expected: String=row.kind
		if policy.objects.has(row.id):expected=policy.objects[row.id].kind
		elif row.layer=="建筑::崖壁B::种植承载面":expected="Terrain"
		elif row.layer=="建筑::崖壁B::建筑构件":expected="Structure"
		elif row.layer=="建筑::崖壁B" and not row.kind in ["Road","Water","Sand"]:expected="Structure"
		check(row.kind==expected,"Wrong metadata surface role: "+str(row.name))
		var mesh: MeshInstance3D=meshes[row.id]
		if expected=="Terrain":check(mesh.material_override==scene.terrain_material,"Terrain lost planting material")
		elif expected=="Structure":check(mesh.material_override==load("res://assets/world/cliff_b_test/architecture.tres"),"Structural part has planting material")
		if expected!="Water" and row.get("collision",true):
			var body: StaticBody3D=mesh.get_child(0)
			check(body.get_meta("surface_kind")==expected,"Vegetation collision classification differs")
		counts[expected]=counts.get(expected,0)+1;checked+=1
	return {"checked_objects":checked,"counts":counts,"explicit_policy":"surface_roles.json"}

func nearest_previous(p: Vector3,bins: Dictionary,size: float) -> float:
	var cell:=Vector2i(floori(p.x/size),floori(p.z/size));var result:=INF
	for dx in range(-1,2):
		for dz in range(-1,2):
			for other:Vector3 in bins.get(cell+Vector2i(dx,dz),[]):result=minf(result,Vector2(p.x-other.x,p.z-other.z).length())
	if not bins.has(cell):bins[cell]=[]
	(bins[cell] as Array).append(p)
	return result

func run() -> void:
	root.size=Vector2i(1600,1000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	scene=load("res://scenes/map_1021.tscn").instantiate();scene.automation_enabled=true
	root.add_child(scene)
	var started:=Time.get_ticks_msec()
	while not scene.test_ready:
		if Time.get_ticks_msec()-started>150000:
			push_error("Current map startup timed out");quit(1);return
		await process_frame
	print("CURRENT_MAP_TEST_BEGIN")
	var surfaces:=surface_role_checks()
	var population:=vegetation_checks()
	print("MAP_1021_VEGETATION ",JSON.stringify(population))
	var headless:=DisplayServer.get_name()=="headless"
	for i in scene.resolved_spawns.size():
		var row:Dictionary=scene.resolved_spawns[i]
		check(not row.is_empty(),"Missing spawn %d"%i)
		if row.is_empty():continue
		await scene.select_spawn(i);await frames(70)
		var actor=scene.character
		var start:Vector3=actor.global_position
		var expected:Vector3=row.floor_position
		check(actor.is_on_floor(),"Spawn not grounded: "+str(row.name))
		check(absf(start.y-expected.y)<0.5,"Wrong storey: "+str(row.name))
		actor.test_move=Vector2(0,-1)
		await frames(480 if i==2 else 100);actor.test_move=Vector2.ZERO;await frames(15)
		var moved:Vector3=actor.global_position
		var distance:=Vector2(moved.x-start.x,moved.z-start.z).length()
		check(distance>1.2,"Walking blocked: "+str(row.name))
		if i==2:check(distance>11,"Gallery forward route still blocked")
		check(actor.is_on_floor(),"Walking lost floor: "+str(row.name))
		check(absf(moved.y-expected.y)<3.0,"Walking changed storey unexpectedly: "+str(row.name))
		rows.append({"key":row.key,"name":row.name,"floor":[expected.x,expected.y,expected.z],"walk_distance_m":distance,
		"grounded":actor.is_on_floor(),"end_height_m":moved.y,"floor_source":row.floor_source})
		await scene.select_spawn(i);await frames(45)
		if not headless:await shot(str(row.key))
		if i==2:
			for direction in [Vector2(0,-1),Vector2(0,1),Vector2(-1,0),Vector2(1,0)]:
				await scene.select_spawn(i);await frames(20)
				var p:Vector3=actor.global_position;actor.test_move=direction
				await frames(150);actor.test_move=Vector2.ZERO;await frames(10)
				var step:=Vector2(actor.position.x-p.x,actor.position.z-p.z).length()
				check(step>3.7 and actor.is_on_floor(),"Gallery direction blocked: "+str(direction))
				gallery_directions.append({"direction":[direction.x,direction.y],"distance_m":step,"grounded":actor.is_on_floor()})
		await scene.select_spawn(i);await frames(20)
		if row.get("character_only",false):
			print("CURRENT_MAP_CHARACTER_SPAWN_OK ",row.key);continue
		await toggle_actor();check(not scene.character_mode,"C did not select camper at "+str(row.name))
		if not scene.character_mode:
			var p:Vector3=scene.camper.global_position
			check(scene.camper.is_on_floor(),"Camper did not settle at "+str(row.name))
			check(absf(p.y-expected.y)<.6,"C changed camper storey at "+str(row.name))
			scene.camper.test_throttle=1;await frames(100 if i==2 else 50)
			scene.camper.test_throttle=0;scene.camper.test_braking=true;await frames(30);scene.camper.test_braking=false
			var driven:=Vector2(scene.camper.position.x-p.x,scene.camper.position.z-p.z).length()
			check(driven>2 and scene.camper.is_on_floor(),"Camper driving blocked at "+str(row.name))
			var gaps:Array=scene.camper.wheel_ground_gaps()
			check(gaps.size()==4,"Missing camper wheel probes")
			for gap in gaps:check(absf(gap)<.05,"Camper wheel contact differs at "+str(row.name))
			vehicle_rows.append({"key":row.key,"drive_m":driven,"grounded":scene.camper.is_on_floor(),"wheel_gaps_m":gaps})
			if not headless and i in [1,2]:await shot(str(row.key)+"_camper")
			await toggle_actor();check(scene.character_mode,"C did not restore character at "+str(row.name))
		print("CURRENT_MAP_SPAWN_OK ",row.key," floor=",expected.y," walk=",distance)
	scene.show_overview();await frames(30)
	if not headless:await shot("overview")
	if not headless:
		scene.camera.position=Vector3(350,125,600);scene.camera.look_at(Vector3(-150,35,770));await frames(30)
		await shot("megastructure_architecture")
	var report:Dictionary={"date":Time.get_date_string_from_system(),"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_video_adapter_name(),
	"source":scene.metadata.source_document,"objects":scene.metadata.objects,"triangles":scene.metadata.triangles,
	"mask_resolution":scene.metadata.resolution,"spawns":rows,"vehicles":vehicle_rows,"gallery_directions":gallery_directions,"surface_role_checks":surfaces,"vegetation_checks":population,"procedural_vegetation":scene.tree_placement_report,
	"failures":failures,"passed":failures.is_empty(),"visual_captures":not headless}
	var file:=FileAccess.open(OUT+"validation.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("CURRENT_MAP_VALIDATION ",JSON.stringify(report))
	quit(0 if failures.is_empty()else 1)
