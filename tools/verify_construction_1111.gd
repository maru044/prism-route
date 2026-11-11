extends SceneTree
const DATA:=preload("res://scripts/construction/building_data.gd")
const STORE:=preload("res://scripts/grass_baked_store.gd")
const OUT:="res://.current_map_build/construction_1111/"
var checks:=0
var failures: Array[String]=[]
var world
var protected: Dictionary={}
var walks: Array[Dictionary]=[]
var report: Dictionary={}
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);push_error(label)

func frames(count: int) -> void:
	for i in count:await process_frame

func room_containing(data,cell: String) -> Dictionary:
	for room: Dictionary in data.rooms:
		if cell in room.cells:return room
	return {}

func unique_room_ids(data,label: String) -> void:
	var ids: Dictionary={}
	for room: Dictionary in data.rooms:ids[room.id]=true
	check(ids.size()==data.rooms.size(),label)

func room_id_checks(catalog: Dictionary) -> void:
	var first_check:=checks
	var data=DATA.new();data.initialize("identity",catalog.definitions)
	for x in range(0,8,2):
		for z in range(0,6,2):data.place("floor",0,x,z,0,false);data.place("roof",0,x,z,0,false)
	for x in range(0,8,2):data.place("wall",0,x,0,0,false);data.place("wall",0,x,6,0,false)
	for z in range(0,6,2):data.place("wall",0,0,z,1,false);data.place("wall",0,8,z,1,false)
	data.analyze();var original: String=data.rooms[0].id
	var bed: Dictionary=data.place("bed",0,5,3);check(bed.ok,"Identity: bed placement");data.analyze()
	check(data.rooms.size()==1 and data.rooms[0].id==original and data.rooms[0].function=="bedroom","Adding bed changes function, preserves ID")
	data.pieces[bed.id].x=5.5;data.analyze();check(data.rooms[0].id==original,"Moving furniture preserves ID")
	data.remove(bed.id);data.analyze();check(data.rooms[0].id==original and data.rooms[0].function=="generic","Removing bed preserves ID")
	var roof_id:=""
	for row: Dictionary in data.pieces.values():
		if row.definition=="roof":roof_id=row.id;break
	data.remove(roof_id);data.analyze();check(data.rooms[0].id==original and not data.rooms[0].covered,"Roof removal preserves space identity")
	data.undo();data.analyze();check(data.rooms[0].id==original and data.rooms[0].covered,"Undo roof removal restores coverage and ID")
	var partition: Array[String]=[]
	for z in range(0,6,2):
		var result: Dictionary=data.place("door" if z==2 else "wall",0,2,z,1);check(result.ok,"Identity partition placement");partition.append(result.id)
	data.analyze();check(data.rooms.size()==2,"Adding partition splits room")
	var small:=room_containing(data,"0:0:0");var large:=room_containing(data,"0:3:0")
	check(large.id==original and small.id!=original,"Largest split child inherits original ID")
	var small_id: String=small.id;var large_id: String=large.id
	unique_room_ids(data,"Split does not duplicate IDs")
	for opened: bool in [true,false,true]:
		for row: Dictionary in data.pieces.values():
			if row.definition=="door":row.open=opened
		data.analyze();check(room_containing(data,"0:0:0").id==small_id and room_containing(data,"0:3:0").id==large_id,"Repeated door state changes preserve both room IDs")
	for id: String in partition:data.remove(id)
	data.analyze();check(data.rooms.size()==1 and data.rooms[0].id==large_id,"Merge inherits largest predecessor ID")
	for z in range(0,6,2):data.place("wall",0,2,z,1)
	data.analyze();small=room_containing(data,"0:0:0");large=room_containing(data,"0:3:0")
	check(large.id==large_id,"Second split keeps surviving main ID")
	check(small.id!=small_id and small.id!=large_id,"Second split allocates a fresh ID instead of recycling retired child")
	unique_room_ids(data,"Repeated split remains unique")
	var before: Dictionary={}
	for room: Dictionary in data.rooms:
		for cell: String in room.cells:before[cell]=room.id
	var added: Dictionary=data.place("floor",0,14,14);check(added.ok,"Separate new space placement");data.analyze()
	for cell: String in before:check(room_containing(data,cell).id==before[cell],"Unrelated room addition preserves existing cell-to-ID mapping")
	data.undo();data.analyze()
	for cell: String in before:check(room_containing(data,cell).id==before[cell],"Undo unrelated addition preserves existing IDs")
	var state: Dictionary=JSON.parse_string(JSON.stringify(data.snapshot()))
	var reloaded=DATA.new();reloaded.initialize("identity",catalog.definitions);reloaded.restore(state);reloaded.analyze()
	for cell: String in before:check(room_containing(reloaded,cell).id==before[cell],"JSON roundtrip and recomputation preserve IDs")
	var other=DATA.new();other.initialize("other_plot",catalog.definitions);other.place("floor",0,0,0);other.analyze()
	check(not other.rooms[0].id in data.rooms.map(func(r:Dictionary):return r.id),"Different plot namespaces cannot collide")
	report["room_id_followup"]={"passed":failures.is_empty(),"checks":checks-first_check,"original":original,"retired_split_child":small_id,"current":data.rooms.map(func(r:Dictionary):return r.id),"scope":"production BuildingData, isolated fixtures; original full-world checks retained"}
	print("CONSTRUCTION_ROOM_IDS ",JSON.stringify(report.room_id_followup))

func logic(catalog: Dictionary) -> void:
	var data=DATA.new();data.initialize("unit",catalog.definitions);data.example()
	check(data.pieces.size()==164,"Sample component count")
	check(data.rooms.size()==5,"Sample space count")
	check(not data.place("floor",0,20,20).ok,"Duplicate floor rejected")
	check(not data.place("floor",0,60,60).ok,"Outside plot rejected")
	check(not data.place("bed",0,26,24).ok,"Bed crossing partition rejected")
	check(not data.place("floor",1,30,24).ok,"Stairwell opening protected")
	check(not data.place("roof",0,20,20).ok,"Upper floor prevents coplanar roof")
	check(absf(DATA.local_position({"definition":"roof","story":1,"x":0,"z":0}).y-7.4)<.001,"Roof above upper room")
	var floor_id: String=data.floor_map(0)[Vector2i(11,11)]
	check(not data.remove(floor_id).ok,"Furniture prevents removing supporting floor")
	var first:=JSON.stringify(data.snapshot());var placement: Dictionary=data.place("floor",0,4,4)
	check(placement.ok and data.undo(),"Place and undo")
	check(JSON.stringify(data.snapshot())==first,"Undo restores exact data")
	check(data.redo() and data.pieces.has(placement.id),"Redo restores stable instance")
	data=DATA.new();data.initialize("topology",catalog.definitions)
	for x in range(0,8,2):
		for z in range(0,6,2):data.place("floor",0,x,z,0,false);data.place("roof",0,x,z,0,false)
	for x in range(0,8,2):
		data.place("window",0,x,0,0,false);data.place("wall",0,x,6,0,false)
	for z in range(0,6,2):
		data.place("wall",0,0,z,1,false);data.place("wall",0,8,z,1,false);data.place("door" if z==2 else "wall",0,4,z,1,false)
	data.analyze();check(data.rooms.size()==2,"Door partition creates two rooms")
	check(data.rooms.all(func(r:Dictionary):return r.kind=="indoor"),"Window walls enclose rooms")
	var ids: Array=data.rooms.map(func(r:Dictionary):return r.id)
	for row: Dictionary in data.pieces.values():
		if row.definition=="door":row.open=true
	data.analyze();check(data.rooms.map(func(r:Dictionary):return r.id)==ids,"Opening door preserves room IDs")
	var snapshot: Dictionary=data.snapshot()
	for row: Dictionary in data.pieces.values():
		if row.x==4 and catalog.definitions[row.definition].kind=="edge" and int(row.rotation)==1:data.pieces.erase(row.id)
	data.analyze();check(data.rooms.size()==1,"Removing partition merges rooms")
	check(data.rooms[0].id in ids,"Merge inherits existing identity")
	data.restore(snapshot)
	for row: Dictionary in data.pieces.values():
		if row.x==4 and catalog.definitions[row.definition].kind=="edge" and int(row.rotation)==1:row.definition="arch"
	for row: Dictionary in data.pieces.values():
		if row.x==8 and catalog.definitions[row.definition].kind=="edge":data.pieces.erase(row.id)
	data.analyze();check(data.rooms.all(func(r:Dictionary):return r.exterior_connected and r.kind!="indoor"),"Exterior exposure propagates through arches to floored terrace")
	data=DATA.new();data.initialize("load",catalog.definitions)
	for x in range(30):
		for z in range(30):data.pieces["f_%d_%d"%[x,z]]={"id":"f_%d_%d"%[x,z],"definition":"floor","story":0,"x":x*2.,"z":z*2.,"rotation":0}
	var begin:=Time.get_ticks_usec();data.analyze();report["900_cell_analysis_ms"]=(Time.get_ticks_usec()-begin)/1000.
	check(data.rooms.size()==1 and data.rooms[0].cells.size()==900,"900-cell flood fill")
	print("CONSTRUCTION_LOGIC_PASS checks=",checks)

func run() -> void:
	create_timer(300).timeout.connect(func():push_error("Construction verification timeout");quit(1))
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/construction/basic_kit/catalog.json"))
	if "--room-ids-only" in OS.get_cmdline_user_args():
		room_id_checks(catalog)
		var previous: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"verification.json")) if FileAccess.file_exists(OUT+"verification.json") else {}
		previous["room_id_followup"]=report.room_id_followup
		FileAccess.open(OUT+"verification.json",FileAccess.WRITE).store_string(JSON.stringify(previous,"  "))
		quit(0 if failures.is_empty() else 1);return
	logic(catalog)
	room_id_checks(catalog)
	if "--logic-only" in OS.get_cmdline_user_args():print("CONSTRUCTION_LOGIC_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1);return
	for path: String in ["assets/world/tree_planting/world_edits.json","assets/world/current_map_validation/tree_layout.json","assets/world/current_map_validation/grass_bake/manifest.json","assets/world/cape_town_1110/roots.grass","assets/world/cape_town_1110/grass_bake.json"]:protected[path]=FileAccess.get_sha256("res://"+path)
	world=load("res://scenes/main.tscn").instantiate();world.automation_enabled=true;root.add_child(world)
	while not world.test_ready:await process_frame
	await physics_frame;await physics_frame
	var home=world.construction;var plot: Dictionary=home.plots.coastal;var data=plot.data
	check(world.resolved_spawns.all(func(r:Dictionary):return not r.is_empty()),"All original and construction spawns still resolve")
	for proposal: Dictionary in world.metadata.spawns:
		if proposal.get("key","")!="oval_atrium":continue
		var hit: Dictionary=world._ray(world.vec(proposal.position))
		var diagnostic: Dictionary={"proposal":proposal,"hit":{} if hit.is_empty() else {"source":hit.collider.get_meta("source_id",""),"position":_array(hit.position)}}
		if not hit.is_empty():
			var q:=PhysicsShapeQueryParameters3D.new();q.shape=world.character.collision_shape.shape;q.transform=Transform3D(Basis.IDENTITY,hit.position+Vector3(0,.88,0));q.collision_mask=32;q.exclude=[world.character.get_rid()]
			var overlaps: Array=world.get_world_3d().direct_space_state.intersect_shape(q,16);diagnostic["overlaps"]=[]
			for entry: Dictionary in overlaps:diagnostic.overlaps.append({"path":str(entry.collider.get_path()),"construction":entry.collider.get_meta("construction_id","")})
		report["existing_oval_spawn_diagnostic"]=diagnostic;print("CONSTRUCTION_EXISTING_SPAWN ",JSON.stringify(diagnostic))
	check(home.plots.size()==2,"Both actual plots installed")
	check(plot.root.basis.determinant()>.999,"Plot transform is right handed")
	check(world.vegetation.volume_streamer.store.manifest.signature==STORE.signature(world),"Immutable root bake remains valid")
	check(world.vegetation.grass_material.get_shader_parameter("construction_grass_enabled")==true,"Dynamic grass mask bound to live grass")
	var removed_counts: Dictionary={}
	for id: String in home.plots:
		var p: Node3D=home.plots[id].root;var count:=0
		for row: Dictionary in world.planting.store.all_records().values():
			var position:=Vector3(row.position[0],row.position[1],row.position[2]);var local:=p.to_local(position)
			if absf(local.y)<1 and local.x>=0 and local.x<=60 and local.z>=0 and local.z<=60:
				check(world.planting.record_is_excluded(row),"Tree excluded within designated building plot");count+=1
		removed_counts[id]=count
	check(not home.grass_cut(plot.root.to_global(Vector3(9,0,9))),"Empty courtyard grass remains")
	check(home.grass_cut(plot.root.to_global(Vector3(21,0,21))),"Existing ground floor suppresses grass")
	check(not home.grass_cut(plot.root.to_global(Vector3(21,-35,21))),"Mask does not cut lower level")
	check(not home.grass_cut(plot.root.to_global(Vector3(21,25,21))),"Mask does not cut upper hill")
	var placement: Dictionary=data.place("floor",0,8,8);home.refresh("coastal")
	check(placement.ok and home.grass_cut(plot.root.to_global(Vector3(9,0,9))),"Placed floor updates mask immediately")
	data.remove(placement.id);home.refresh("coastal")
	check(not home.grass_cut(plot.root.to_global(Vector3(9,0,9))),"Removing floor restores grass")
	data.undo();home.refresh("coastal");check(home.grass_cut(plot.root.to_global(Vector3(9,0,9))),"Undo removal restores cut")
	data.undo();home.refresh("coastal")
	var before_ids: Array=data.rooms.map(func(r:Dictionary):return r.id)
	await closed_door(plot)
	var door_id:=""
	for row: Dictionary in data.pieces.values():
		if row.definition=="door":
			home.toggle_door("coastal",row.id)
			if row.x==26 and row.z==30:door_id=row.id
	data.analyze();check(data.rooms.map(func(r:Dictionary):return r.id)==before_ids,"Actual door opening preserves room identities")
	await physics_frame;await physics_frame
	check(home.save_file(OUT+"save.json")==OK,"Construction save writes")
	var before_save:=JSON.stringify(data.snapshot());data.place("floor",0,6,6);home.refresh("coastal")
	check(home.load_file(OUT+"save.json"),"Construction save loads")
	data=home.plots.coastal.data;check(JSON.parse_string(JSON.stringify(data.snapshot()))==JSON.parse_string(before_save),"Save/load retains exact IDs and transforms")
	check(home.save_file(OUT+"save.json")==OK,"Atomic replacement of existing save")
	FileAccess.open(OUT+"invalid_save.json",FileAccess.WRITE).store_string("{\"version\":999}")
	var preserved: Variant=JSON.parse_string(JSON.stringify(data.snapshot()))
	check(not home.load_file(OUT+"invalid_save.json"),"Invalid save rejected")
	check(JSON.parse_string(JSON.stringify(data.snapshot()))==preserved,"Invalid load preserves live construction")
	check(home.load_file(OUT+"save.json"),"Valid save recovers after rejected file")
	await physics_frame;await physics_frame
	for row: Dictionary in data.pieces.values():
		var node: Node3D=plot.nodes[row.id];check(node.scale.is_equal_approx(Vector3.ONE),"Applied component scale")
		if home.kit.catalog.definitions[row.definition].kind!="furniture":continue
		var definition: Dictionary=home.kit.catalog.definitions[row.definition]
		var anchor: Node3D=node.get_motion_anchor_node(definition.anchor)
		check(anchor!=null,"Exact existing furniture anchor: "+str(row.definition))
		if anchor!=null:check(absf(node.to_local(anchor.global_position).y-float(definition.surface))<.005,"Furniture support/anchor height: "+str(row.definition))
		var approach:=node.get_node("Anchor_Front") as Node3D
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=world.character.collision_shape.shape;query.collision_mask=32;query.exclude=[world.character.get_rid()]
		query.transform=Transform3D(Basis.IDENTITY,approach.global_position+Vector3(0,.80,0))
		check(world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),"Furniture approach capsule clearance: "+str(row.definition))
		check(not ray_floor(approach.global_position+Vector3.UP*.1).is_empty(),"Furniture approach has floor")
	for s in range(2):
		for x in [21.,25.,29.,33.]:
			var p: Vector3=plot.root.to_global(Vector3(x,.2+s*3.6,21))
			var hit:=ray_floor(p+Vector3.UP*.1)
			check(not hit.is_empty() and absf(hit.position.y-p.y)<.005,"Floor collision at expected storey")
	await walk(plot.root.to_global(Vector3(27,.04,34)),plot.root.to_global(Vector3(27,.24,29)),"entry_and_door")
	await walk(plot.root.to_global(Vector3(27,.24,29)),plot.root.to_global(Vector3(27,.24,21)),"corridor_open_doors")
	await walk(plot.root.to_global(Vector3(31,.24,29)),plot.root.to_global(Vector3(31,3.84,21)),"stairs_up")
	await walk(plot.root.to_global(Vector3(31,3.84,21)),plot.root.to_global(Vector3(31,.24,29)),"stairs_down")
	# Input routing through real engine events, including numeric hotkey isolation.
	var previous_spawn: int=world.spawn_index
	key(KEY_F7);await frames(2);check(home.active,"F7 enters construction mode")
	key(KEY_1);await frames(2);check(world.spawn_index==previous_spawn,"Numeric keys do not switch world spawn while building")
	key(KEY_ESCAPE);await frames(2);check(not home.active,"Escape exits construction mode")
	if DisplayServer.get_name()!="headless":await captures(home,plot)
	for path: String in protected:check(FileAccess.get_sha256("res://"+path)==protected[path],"Protected source unchanged: "+path)
	report.merge({"passed":failures.is_empty(),"checks":checks,"failures":failures,"sample_pieces":data.pieces.size(),"rooms":data.rooms,"tree_records_excluded":removed_counts,"walks":walks,"source":"scenes/main.tscn","root_bake_preserved":true,"furniture_status":"anchors_ready"})
	FileAccess.open(OUT+"verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("CONSTRUCTION_VERIFY ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

func key(code: Key) -> void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=true;Input.parse_input_event(event)
	var release:=InputEventKey.new();release.physical_keycode=code;release.pressed=false;Input.parse_input_event(release)

func ray_floor(p: Vector3) -> Dictionary:
	var query:=PhysicsRayQueryParameters3D.create(p,p-Vector3.UP*.4,32);query.exclude=[world.character.get_rid()];return world.get_world_3d().direct_space_state.intersect_ray(query)

func closed_door(plot: Dictionary) -> void:
	var player=world.character;world.set_free(false);player.set_spawn(plot.root.to_global(Vector3(27,.04,32.5)),0);player.camera_pivot.global_rotation=Vector3.ZERO;player.test_move=Vector2.ZERO
	for i in range(15):await physics_frame
	var begin: Vector3=player.global_position;var dir: Vector3=plot.root.basis*Vector3(0,0,-1);player.test_move=Vector2(dir.x,dir.z)
	for i in range(150):await physics_frame
	player.test_move=Vector2.ZERO
	check((player.global_position-begin).dot(dir)<2.45,"Closed actual door blocks controller")

func walk(a: Vector3,b: Vector3,label: String) -> void:
	world.set_free(false);var player=world.character;player.test_move=Vector2.ZERO;player.set_spawn(a,0);player.camera_pivot.global_rotation=Vector3.ZERO;player.set_physics_process(true)
	for i in range(15):await physics_frame
	var start: Vector3=player.global_position;var direction:=Vector3(b.x-a.x,0,b.z-a.z).normalized();var distance:=Vector2(b.x-a.x,b.z-a.z).length()
	player.test_move=Vector2(direction.x,direction.z);var begin:=Time.get_ticks_msec()
	while (player.global_position-start).dot(direction)<distance-.12 and Time.get_ticks_msec()-begin<11000:await physics_frame
	player.test_move=Vector2.ZERO
	for i in range(12):await physics_frame
	var advance: float=(player.global_position-start).dot(direction);var error: float=absf(player.global_position.y-(b.y-.04))
	walks.append({"name":label,"advance":advance,"target_distance":distance,"height_error":error,"final":_array(player.global_position)})
	check(advance>distance-.35,"Actual controller traverses "+label);check(error<.12,"Correct storey after "+label)
	print("CONSTRUCTION_WALK ",label," ",advance,"/",distance," height_error=",error)

func _array(p: Vector3) -> Array:return [p.x,p.y,p.z]

func captures(home,plot: Dictionary) -> void:
	world.set_free(true);world.set_review_ui_visible(false);world.character.visible=false;world.character.set_physics_process(false)
	if world.character.switch_wheel!=null:world.character.switch_wheel.visible=false
	var views: Array=[{"name":"overview","eye":Vector3(49,21,49),"target":Vector3(27,2,25)},
		{"name":"entry","eye":Vector3(37,4,39),"target":Vector3(27,2,26)},
		{"name":"interior","eye":Vector3(27,1.75,29),"target":Vector3(27,1.5,21)},
		{"name":"stairs","eye":Vector3(31,1.75,29),"target":Vector3(31,4,21)}]
	for view: Dictionary in views:
		for frame in range(150):world.camera.global_position=plot.root.to_global(view.eye);world.camera.look_at(plot.root.to_global(view.target));world.camera.make_current();await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(OUT+str(view.name)+".png")==OK,"Capture "+str(view.name))
		print("CONSTRUCTION_CAPTURE ",view.name)
	# Same live grass, camera and patch before placement / with floor / after removal.
	for state in range(3):
		var id:=""
		if state==1:
			var result: Dictionary=plot.data.place("floor",0,8,8);check(result.ok,"GPU patch floor placement");id=result.get("id","");home.refresh("coastal")
		for frame in range(90):world.camera.global_position=plot.root.to_global(Vector3(11,3,14));world.camera.look_at(plot.root.to_global(Vector3(9,.2,9)));world.camera.make_current();await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(OUT+["grass_before","grass_floor","grass_restored"][state]+".png")==OK,"GPU grass placement capture")
		if state==1:plot.data.remove(id);home.refresh("coastal")
