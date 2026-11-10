extends SceneTree
## Formal main world only; also owns the local packed grass-bake operation.
const STREAM=preload("res://scripts/grass_volume_streamer.gd")
const STORE=preload("res://scripts/grass_baked_store.gd")
const BUFFER=preload("res://scripts/grass_instance_buffer.gd")
const DEST="res://assets/world/cape_town_1110/"
var world
var town
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func v(a: Array) -> Vector3:return Vector3(a[0],a[1],a[2])
func check(ok: bool,message: String) -> void:
	if not ok:
		failures+=1
		push_error("CAPE_TOWN_FAIL "+message);quit(1)
	checks+=1
func ray(a: Vector3,b: Vector3,mask:=32) -> Dictionary:
	var q:=PhysicsRayQueryParameters3D.create(a,b,mask)
	q.exclude=[world.character.get_rid(),world.camper.get_rid()]
	return world.get_world_3d().direct_space_state.intersect_ray(q)
func clear(p: Vector3,lift:=.91) -> bool:
	var capsule:=CapsuleShape3D.new();capsule.radius=.29;capsule.height=1.78
	var q:=PhysicsShapeQueryParameters3D.new();q.shape=capsule;q.collision_mask=32
	q.transform=Transform3D(Basis.IDENTITY,p+Vector3.UP*lift)
	q.exclude=[world.character.get_rid(),world.camper.get_rid()]
	var hits: Array=world.get_world_3d().direct_space_state.intersect_shape(q,8)
	if not hits.is_empty():print("TOWN_BLOCKER ",p," ",hits[0].collider.get_meta("source_id","?"))
	return hits.is_empty()
func run() -> void:
	create_timer(900.).timeout.connect(func():push_error("Town review timeout");quit(1))
	AudioServer.set_bus_mute(0,true)
	world=load("res://scenes/main.tscn").instantiate();world.automation_enabled=true
	world.vegetation_bake_only="--bake" in OS.get_cmdline_user_args()
	root.add_child(world)
	while not world.test_ready:await process_frame
	await physics_frame;await physics_frame
	town=world.cape_town
	if "--bake" in OS.get_cmdline_user_args():await bake();quit(1 if failures>0 else 0);return
	if "--capture-only" in OS.get_cmdline_user_args():await capture();quit();return
	check(town.manifest.buildings.size()==14,"14 native buildings")
	check(town.manifest.triangle_count<150000,"triangle budget")
	check(town.furniture_instances.size()==5,"five independent furniture slots")
	if "--check-geometry" not in OS.get_cmdline_user_args():
		check(town.installed_cells==town.manifest.ground_cut.cells.size(),"all affected grass cells installed")
		var bake_data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(town.GRASS_BAKE))
		for id: String in bake_data.cells:
			var bytes:=STORE.read_payload(bake_data.cells[id])
			check(bytes.size()==int(bake_data.cells[id].compressed_bytes) and sha(bytes)==bake_data.cells[id].sha256,"grass bundle chunk "+id)
	check(bool(world.vegetation.grass_material.get_shader_parameter("use_cape_town_grass_cut")),"GPU grass cut bound")
	if "--ground-mask" in OS.get_cmdline_user_args():
		verify_ground()
		if failures>0:quit(1);return
		if "--capture" in OS.get_cmdline_user_args():await capture()
		quit();return
	var idx:=-1
	for i in world.resolved_spawns.size():
		if world.resolved_spawns[i].get("key","")=="cape_town":idx=i
	check(idx>=0,"formal world town spawn")
	await world.select_spawn(idx)
	world.character.set_control_enabled(false)
	for row: Dictionary in town.manifest.objects:
		var mesh: MeshInstance3D=town.meshes_by_source[row.id]
		check(mesh.material_override!=null,"assigned material "+str(row.name))
		check(mesh.visible==bool(row.render),"helper visibility")
		if row.category=="stairs":check(not row.collision,"visual treads do not collide")
		if row.category=="ramp":check(row.collision and not row.render,"hidden smooth stair ramp")
		if row.material_key=="sea_glass":check((mesh.material_override as StandardMaterial3D).transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS,"glass depth prepass")
	for row: Dictionary in town.manifest.interactions.furniture:
		var f: Node3D=town.furniture_instances[row.id]
		check(absf(f.global_basis.determinant()-1)<.001,"right handed furniture frame")
		var anchor:="Anchor_Seat" if row.type=="chair" else "Anchor_Desk_Surface"
		var p: Vector3=(f.global_transform*f.get_motion_anchor(anchor)).origin
		check(absf(f.get_motion_anchor(anchor).origin.y-float(row.surface_height))<.001,"local furniture height")
		var hit:=ray(p+Vector3.UP*.04,p-Vector3.UP*.04)
		check(not hit.is_empty() and row.geometry_ids.has(str(hit.collider.get_meta("source_id",""))),"actual surface support")
		var front: Transform3D=f.global_transform*f.get_motion_anchor("Anchor_Front")
		check(front.basis.z.dot(f.global_basis.z)<-.99,"entry faces furniture")
		var support:=ray(front.origin+Vector3.UP*.08,front.origin-Vector3.UP*.08)
		check(not support.is_empty() and absf(support.position.y-front.origin.y)<.01,"entry finished floor support")
		check(clear(front.origin),"entry capsule clearance")
	var approach: Dictionary=town.manifest.routes[0]
	var road_a:=v(approach.points[0]);var road_b:=v(approach.points[1])
	for i in range(100):
		var p:=road_a.lerp(road_b,float(i)/99)
		var support:=ray(p+Vector3.UP*.15,p-Vector3.UP*.25)
		check(not support.is_empty(),"continuous vehicle approach support")
		check(clear(support.position),"approach capsule clearance")
	# Every ramp route: physical support & head clearance, then real controller climb.
	for route: Dictionary in town.manifest.routes:
		if route.id=="road_join":continue
		var a:=v(route.points[0]);var b:=v(route.points[1])
		for i in range(2,19):
			var p:=a.lerp(b,float(i)/20)
			var hit:=ray(p+Vector3.UP*.14,p-Vector3.UP*.3)
			check(not hit.is_empty(),"ramp physical support "+str(route.id))
			check(clear(hit.position,.97),"ramp head clearance "+str(route.id))
		await walk(a,b,route.id)
		await walk(b,v(route.points[2]),route.id+"_landing_entry")
	for building: Dictionary in town.manifest.buildings:
		var f:=v(building.forward);var p:=v(building.position)
		if building.type=="shrine":
			var a:=p+f*7.;a.y=1.36
			var b:=p+f*4.8;b.y=float(building.floor_height)+.04
			await walk(a,b,"shrine_entry")
		else:
			var width: float=building.width;var depth: float=building.depth
			var c:=3.5 if building.type=="shop" else .8
			var bays:=maxi(1,int((width-2*c)/3.5))
			var x:=width/2-c-(width-2*c)*(float(bays/2)+.5)/bays
			# Building offsets were authored in CAD u/v, not the Marker3D basis.
			var right:=f.cross(Vector3.UP)
			var a:=p+right*x+f*(depth/2+4.8);a.y=1.36
			var b:=p+right*x+f*(depth/2-1.2);b.y=float(building.floor_height)+.04
			await walk(a,b,str(building.id)+"_ground_entry")
	if failures>0:quit(1);return
	var report: Dictionary={"checks":checks,"passed":true,"buildings":14,"meshes":town.meshes_by_source.size(),"triangles":town.manifest.triangle_count,
		"furniture":5,"installed_grass_cells":town.installed_cells,"formal_scene":"scenes/main.tscn","npc_integration":"anchors_ready",
		"scope":"geometry_only" if "--check-geometry" in OS.get_cmdline_user_args() else "geometry_and_local_grass"}
	FileAccess.open("res://.current_map_build/cape_town_1110/verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("CAPE_TOWN_VERIFY_PASS ",JSON.stringify(report))
	if "--capture" in OS.get_cmdline_user_args():await capture()
	quit()
func walk(a: Vector3,b: Vector3,id: String) -> void:
	var player=world.character
	player.test_move=Vector2.ZERO;player.set_spawn(a,0);player.camera_pivot.global_rotation=Vector3.ZERO
	player.set_physics_process(true)
	for i in range(12):await physics_frame
	var start: Vector3=player.global_position
	var dir:=Vector3(b.x-a.x,0,b.z-a.z).normalized()
	player.test_move=Vector2(dir.x,dir.z)
	var time:=Time.get_ticks_msec()
	var distance:=Vector2(b.x-a.x,b.z-a.z).length()
	while (player.global_position-start).dot(dir)<distance-.15 and Time.get_ticks_msec()-time<10000:
		await physics_frame
	player.test_move=Vector2.ZERO
	for i in range(8):await physics_frame
	print("TOWN_WALK ",id," advance=",(player.global_position-start).dot(dir)," y=",player.global_position.y," expected=",b.y)
	check((player.global_position-start).dot(dir)>distance-.3,"controller climbs "+id)
	check(absf(player.global_position.y-(b.y-.04))<.10,"controller reaches correct storey "+id)
func sha(bytes: PackedByteArray) -> String:
	var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty():h.update(bytes)
	return h.finish().hex_encode()

func verify_ground() -> void:
	var config: Dictionary=town.manifest.ground_cut
	check(float(config.report.grass_m2)>float(config.report.land_m2)*.75,"grass is the dominant land cover")
	check(float(config.report.beach_m2)<float(config.report.land_m2)*.15,"beach is a narrow perimeter strip")
	var grass_pixels:=0;var beach_pixels:=0;var grass_roots:=0
	for z in range(1,town.cut.get_height(),9):
		for x in range(1,town.cut.get_width(),9):
			var data: Color=town.cut.get_pixel(x,z)
			if data.a<.5:continue
			var p:=Vector3(config.origin[0]+x,data.g,config.origin[1]+z)
			if data.r>2.:
				check(town.grass_band(p,.55)==0,"inland meadow CPU mask")
				var hit:=ray(p+Vector3.UP*.12,p-Vector3.UP*.12,16)
				check(not hit.is_empty() and absf(hit.position.y-p.y)<.1,"plantable ground layer matches finished surface")
				check(world.vegetation.grass_coverage_unmasked(p,Vector3.UP)>.4,"low elevation no longer forces sand density")
				grass_pixels+=1
			if data.b<16.:
				check(town.blocks_grass(p),"shoreline sand has no grass")
				beach_pixels+=1
	var bake_data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(town.GRASS_BAKE))
	for id: String in bake_data.cells:
		var row: Dictionary=bake_data.cells[id]
		if int(row.root_count)==0:continue
		var packed:=STORE.read_payload(row)
		var raw:=packed.decompress(int(row.raw_bytes),FileAccess.COMPRESSION_ZSTD)
		var roots:=raw.slice(0,int(row.root_count)*48).to_float64_array()
		var values:=id.split("_");var origin:=Vector3(int(values[0]),int(values[1]),int(values[2]))*24.
		for i in range(0,int(row.root_count),31):
			var p:=origin+Vector3(roots[i*6],roots[i*6+2],roots[i*6+1])
			check(not town.blocks_grass(p),"decoded roots avoid beach/paving and obsolete lower ground")
	# Bake report counts newly supported meadow roots separately from unaffected surroundings.
	grass_roots=int(bake_data.report.get("town_grass_roots",0))
	check(grass_roots>100000,"actual 3D meadow grass was baked, not only green ground")
	if failures>0:return
	var report: Dictionary={"passed":true,"scope":"corrected_land_cover","checks":checks,"grass_samples":grass_pixels,"beach_samples":beach_pixels,
		"town_grass_roots":grass_roots,"installed_cells":town.installed_cells,"land_cover":config.report,"beach_width_m":config.beach_width_m}
	FileAccess.open("res://.current_map_build/cape_town_1110/land_cover_verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("CAPE_TOWN_LAND_COVER_PASS ",JSON.stringify(report))
func bake() -> void:
	var source_sha:=FileAccess.get_sha256(town.TOWN_MANIFEST)
	var geometry_sha:=FileAccess.get_sha256(DEST+"town.glb")
	var mask_sha:=FileAccess.get_sha256(DEST+"ground_field.rgba")
	var sampler_sha:=FileAccess.get_sha256("res://scripts/tree_planting/world_vegetation.gd")
	var runtime_sha:=FileAccess.get_sha256("res://scripts/world/cape_town.gd")
	var tree_sha:=FileAccess.get_sha256("res://assets/world/tree_planting/world_edits.json")
	var global_sha:=FileAccess.get_sha256(world.ASSETS+"grass_bake/manifest.json")
	var vegetation=world.VEGETATION.new();vegetation.world_scene=world;world.add_child(vegetation)
	vegetation.target=world.camera;vegetation.biome_noise_texture=world._noise();vegetation._load_meshes_and_materials()
	var stream:=STREAM.new();vegetation.add_child(stream);stream.initialize(vegetation,world)
	stream.use_baked=false;stream.capture_roots=true
	var temp:="res://.current_map_build/cape_town_1110/roots.grass"
	var bundle:=FileAccess.open(temp,FileAccess.WRITE)
	var rows: Dictionary={};var count:=0;var blades:=0;var parity:=0;var town_roots:=0;var started:=Time.get_ticks_msec()
	Engine.max_fps=0
	for values: Array in town.manifest.ground_cut.cells:
		var cell:=Vector3i(values[0],values[1],values[2]);var id:=STORE.key(cell)
		stream._begin(cell)
		for i in vegetation.GRASS_SAMPLES_PER_CHUNK:stream._sample()
		var data: Dictionary=stream.payload();var roots:=PackedFloat64Array(stream.work.roots);var states:=PackedInt64Array(stream.work.root_states)
		var seed_value: int=stream.work.rng.seed
		for i in states.size():
			var p:=Vector3(cell)*24.+Vector3(roots[i*6],roots[i*6+2],roots[i*6+1])
			if town.blocks_grass(p):
				print("TOWN_BAD_ROOT cell=",cell," p=",p," field=",town.ground_data(p)," world_band=",world.architectural_band(p,.55)," roots=",roots.slice(i*6,i*6+6))
				check(false,"retained root diagnostic");return
			check(not town.blocks_grass(p),"no retained root under town/sand overlay")
			if town.grass_band(p,.55)==0:town_roots+=1
		if count%30==0 and not roots.is_empty():
			var reconstructed:=BUFFER.from_roots(roots,states,.2,vegetation.grass_mesh.get_aabb(),seed_value)
			check(reconstructed.near.to_byte_array()==data.near.to_byte_array() and reconstructed.far.to_byte_array()==data.far.to_byte_array(),"root buffer parity")
			parity+=1
		var raw:=roots.to_byte_array();raw.append_array(states.to_byte_array())
		var packed:=PackedByteArray() if raw.is_empty() else raw.compress(FileAccess.COMPRESSION_ZSTD)
		var offset:=bundle.get_position();bundle.store_buffer(packed)
		var instances: int=(data.near.size()+data.far.size())/16
		rows[id]={"instances":instances,"root_count":states.size(),"near_count":data.near.size()/16,"far_count":data.far.size()/16,
			"seed":seed_value,"raw_bytes":raw.size(),"compressed_bytes":packed.size(),"sha256":sha(packed),"bounds":data.bounds,
			"resource_path":DEST+"roots.grass","resource_offset":offset}
		blades+=instances;count+=1;stream.work={}
		if count%25==0:print("CAPE_TOWN_BAKE ",count,"/",town.manifest.ground_cut.cells.size()," seconds=",(Time.get_ticks_msec()-started)/1000.)
		await process_frame
	bundle.close()
	check(source_sha==FileAccess.get_sha256(town.TOWN_MANIFEST) and geometry_sha==FileAccess.get_sha256(DEST+"town.glb") and mask_sha==FileAccess.get_sha256(DEST+"ground_field.rgba"),"town source immutable during bake")
	check(sampler_sha==FileAccess.get_sha256("res://scripts/tree_planting/world_vegetation.gd") and runtime_sha==FileAccess.get_sha256("res://scripts/world/cape_town.gd"),"local sampling code immutable during bake")
	check(FileAccess.get_sha256("res://assets/world/tree_planting/world_edits.json")==tree_sha,"tree edits unchanged")
	check(FileAccess.get_sha256(world.ASSETS+"grass_bake/manifest.json")==global_sha,"global grass cache unchanged")
	if FileAccess.file_exists(DEST+"roots.grass"):check(DirAccess.remove_absolute(DEST+"roots.grass")==OK,"remove previous owned bundle")
	check(DirAccess.rename_absolute(temp,DEST+"roots.grass")==OK,"install verified bundle")
	var baked: Dictionary={"version":2,"complete":true,"signature":STORE.signature(world),"source_sha":source_sha,
		"geometry_sha":geometry_sha,"mask_sha":mask_sha,"sampler_sha":sampler_sha,"runtime_sha":runtime_sha,"cells":rows,
		"report":{"cells":count,"blades":blades,"town_grass_roots":town_roots,"parity_cells":parity,"checks":checks,"seconds":(Time.get_ticks_msec()-started)/1000.,"tree_edits_unchanged":true,"global_bake_unchanged":true}}
	FileAccess.open(DEST+"grass_bake.json",FileAccess.WRITE).store_string(JSON.stringify(baked))
	print("CAPE_TOWN_BAKED ",JSON.stringify(baked.report))
func capture() -> void:
	for i in world.resolved_spawns.size():
		if world.resolved_spawns[i].get("key","")=="cape_town":await world.select_spawn(i);break
	world.set_free(true);world.set_process_unhandled_input(false)
	for layer: CanvasLayer in world.review_ui_layers:layer.visible=false
	world.character.visible=false
	if world.character.switch_wheel!=null:world.character.switch_wheel.visible=false
	for row: Dictionary in [{"name":"overview","view":town.manifest.camera},{"name":"street","view":town.manifest.detail_camera},{"name":"shrine","view":town.manifest.shrine_camera}]:
		var view: Dictionary=row.view
		# Grass streaming follows the actor, even while the free camera is active.
		world.character.global_position=Vector3(view.target[0],1.4,view.target[2])
		world.camera.fov=float(view.fov)
		for i in range(160):
			world.camera.make_current();world.camera.global_position=v(view.position);world.camera.look_at(v(view.target));await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://.current_map_build/cape_town_1110/"+str(row.name)+".png")==OK,"save review")
		print("CAPE_TOWN_CAPTURE ",row.name)
