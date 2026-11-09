extends SceneTree
## Verify the new model in the actual formal world. No separate test scene.
var world
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		push_error("SANDBAR_CHECK_FAILED " + message)
		quit(1)
		assert(ok,message)
	checks += 1

func ray(from: Vector3,to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from,to,32)
	return world.get_world_3d().direct_space_state.intersect_ray(q)

func vector(value: Array) -> Vector3:
	return Vector3(value[0],value[1],value[2])

func clear_capsule(point: Vector3) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius=.29;capsule.height=1.78
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=capsule;query.collision_mask=32
	query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*.91)
	query.exclude=[world.character.get_rid(),world.camper.get_rid()]
	var contacts: Array = world.get_world_3d().direct_space_state.intersect_shape(query,8)
	if not contacts.is_empty():
		print("SANDBAR_CLEARANCE_BLOCKER point=",point," source=",contacts[0].collider.get_meta("source_id","unknown"))
	return contacts.is_empty()

func run() -> void:
	create_timer(150.).timeout.connect(func():push_error("Sandbar world review timeout");quit(1))
	AudioServer.set_bus_mute(0,true)
	world = load("res://scenes/main.tscn").instantiate()
	world.automation_enabled = true
	root.add_child(world)
	while not world.test_ready: await process_frame
	var pavilion: Node3D = world.sandbar_pavilion
	if "--capture-only" in OS.get_cmdline_user_args():
		await capture(pavilion)
		quit(0)
		return
	check(pavilion.meshes_by_source.size()==121,"121 merged production meshes")
	check(pavilion.manifest.triangle_count<25000,"five-building triangle budget")
	check(pavilion.furniture_instances.size()==8,"four seats, two desks and two loungers")
	check(pavilion.manifest.building_count==5 and pavilion.manifest.buildings.size()==4,"central pavilion plus four outer buildings")
	check(pavilion.geometry.transform.is_equal_approx(Transform3D.IDENTITY),"single world-coordinate conversion")
	var idx := -1
	for i in world.resolved_spawns.size():
		if world.resolved_spawns[i].get("key","")=="sandbar_pavilion":idx=i
	check(idx>=0,"world spawn exists")
	await world.select_spawn(idx)
	world.character.set_control_enabled(false)
	for i in range(8): await physics_frame
	var shapes: Array = pavilion.geometry.find_children("*","CollisionShape3D",true,false)
	var collision_count := 0
	for row: Dictionary in pavilion.manifest.objects:
		if row.collision: collision_count += 1
	check(shapes.size()==collision_count,"one collision per physical solid; no visual board/seam duplicates")
	for shape: CollisionShape3D in shapes:
		check(shape.get_parent().collision_layer==33,"layer 32 actor + layer 1 legacy")
	for row: Dictionary in pavilion.manifest.objects:
		var mesh: MeshInstance3D = pavilion.meshes_by_source[row.id]
		check(mesh.material_override!=null,"assigned material")
		check(mesh.visible==bool(row.get("render",true)),"collision helper visibility")
		var mat := mesh.material_override as StandardMaterial3D
		check(mat!=null,"standard production material")
		if row.material_key=="sea_glass":
			check(mat.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS and not mat.refraction_enabled,"facade glass without refraction")
		else:
			check(mat.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED,"opaque structural material")
		var definition: Dictionary = pavilion.manifest.materials[row.material_key]
		if definition.has("resource"):
			check(mat.albedo_texture is Texture2D and not mat.uv1_triplanar,"V3 tile uses directional mesh UVs")
			var arrays: Array = mesh.mesh.surface_get_arrays(0)
			check(arrays[Mesh.ARRAY_TEX_UV].size()==arrays[Mesh.ARRAY_VERTEX].size(),"UVs on every vertex")
		if row.material_key=="wall_concrete":
			check(mat.normal_enabled and mat.normal_texture is Texture2D,"wall micro normal remains bound")
	var floor_point: Vector3 = pavilion._frame(pavilion.manifest.spawn,pavilion.manifest.forward).origin
	var floor_hit := ray(floor_point+Vector3.UP*.25,floor_point-Vector3.UP*.4)
	check(not floor_hit.is_empty() and absf(floor_hit.position.y-.10)<.001,"plinth top 0.10 m")
	# Furniture dimensions, exact contact, clockwise/right-handed axes, and entry clearance.
	for row: Dictionary in pavilion.manifest.interactions.furniture:
		var furniture: Node3D = pavilion.furniture_instances[row.id]
		check(absf(furniture.global_basis.determinant()-1.)<.001,"right-handed unit furniture frame")
		check(furniture.global_basis.z.is_equal_approx(Vector3(-.6,0,.8)),"semantic +Z front")
		var key: String = {"chair":"Anchor_Seat","desk":"Anchor_Desk_Surface","bed":"Anchor_Bed_Center"}[row.type]
		var local: Transform3D = furniture.get_motion_anchor(key)
		check(absf(local.origin.y-float(row.surface_height))<.001,"local surface height")
		var surface: Vector3 = furniture.to_global(local.origin)
		var hit := ray(surface+Vector3.UP*.08,surface-Vector3.UP*.08)
		check(not hit.is_empty() and absf(hit.position.y-surface.y)<.001,"surface collision matches marker")
		check(row.geometry_ids.has(str(hit.collider.get_meta("source_id",""))),"contact belongs to this furniture")
		# Check usable rectangle corners as well as the contact point.
		for sx in [-1.,1.]:
			for sz in [-1.,1.]:
				var corner: Vector3 = surface+furniture.global_basis.x*sx*row.usable_surface.width_m*.5+furniture.global_basis.z*sz*row.usable_surface.depth_m*.5
				var support := ray(corner+Vector3.UP*.03,corner-Vector3.UP*.03)
				check(not support.is_empty() and row.geometry_ids.has(str(support.collider.get_meta("source_id",""))),"usable surface corner support")
		var front: Transform3D = furniture.global_transform*furniture.get_motion_anchor("Anchor_Front")
		check(front.basis.z.dot(furniture.global_basis.z)<-.99,"entry faces furniture")
		var ground := ray(front.origin+Vector3.UP*.08,front.origin-Vector3.UP*.08)
		check(not ground.is_empty() and absf(ground.position.y-float(row.position[1]))<.001,"entry has local finished floor support")
		var capsule := CapsuleShape3D.new()
		capsule.radius=.29;capsule.height=1.78
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape=capsule;query.collision_mask=32
		query.transform=Transform3D(Basis.IDENTITY,front.origin+Vector3.UP*.91)
		query.exclude=[world.character.get_rid(),world.camper.get_rid()]
		check(world.get_world_3d().direct_space_state.intersect_shape(query,8).is_empty(),"entry capsule plus 5 cm clearance")
	# The center route is walkable across short stones, sand gaps and the 10 cm floor lip.
	var f := Vector3(-.6,0,.8)
	var site := Vector3(-830,0,-130)
	var player = world.character
	player.set_spawn(site+f*7.+Vector3.UP*.09,atan2(f.x,f.z))
	player.camera_pivot.global_rotation=Vector3.ZERO
	player.test_move=Vector2.ZERO
	player.set_physics_process(true)
	for i in range(24):await physics_frame
	var start: Vector3 = player.global_position
	player.test_move=Vector2(-f.x,-f.z)
	var route_start := Time.get_ticks_msec()
	while (start-player.global_position).dot(f)<5.1 and Time.get_ticks_msec()-route_start<12000:
		await physics_frame
	player.test_move=Vector2.ZERO
	for i in range(12): await physics_frame
	check((start-player.global_position).dot(f)>5.0,"actual walking controller crosses stones and floor lip")
	check(absf(player.global_position.y-.10)<.06,"character stands on plinth")
	for building: Dictionary in pavilion.manifest.buildings:
		check(building.facade_revision=="timber_all_sides","timber rear and side elevations")
		for window: Dictionary in building.rear_windows+building.side_windows:
			var center := vector(window.center)
			var outward := vector(window.outward)
			var window_hit := ray(center+outward*.8,center-outward*.3)
			check(not window_hit.is_empty(),"rear/side glazing has physical contact")
			var window_source := str(window_hit.collider.get_meta("source_id",""))
			var window_mesh: MeshInstance3D = pavilion.meshes_by_source.get(window_source)
			check(window_mesh!=null and window_mesh.material_override==pavilion.materials.sea_glass,"window opening reaches inset glass, not a flat timber wall")
		check(building.single_storey and building.roof_height_m<=7.,"single-storey folded shell")
		check(building.facade_depth_m>=2.,"recessed architectural portal")
		for key: String in ["entry","interior"]:
			var position := vector(building[key])
			var hit := ray(position+Vector3.UP*.12,position-Vector3.UP*.12)
			check(not hit.is_empty() and str(hit.collider.get_meta("source_id",""))==building.floor_source_id,"building floor supports "+key)
			check(clear_capsule(position),"building capsule headroom at "+key)
		# Sample the real sand corridor from central court to this entrance.
		var begin: Vector3 = vector(pavilion.manifest.court_hub)
		var waypoints: Array = building.get("approach_waypoints",[]).duplicate()
		waypoints.append(building.approach)
		for waypoint: Array in waypoints:
			var end: Vector3 = vector(waypoint)
			for i in range(1,19):
				var point: Vector3 = begin.lerp(end,float(i)/18.)
				var hit := ray(point+Vector3.UP*.35,point-Vector3.UP*.25)
				check(not hit.is_empty(),"sandy approach has support")
				check(clear_capsule(hit.position),"sandy approach has capsule clearance")
			begin=end
		# Actual controller walk through each entrance and its 10 cm floor lip.
		player.test_move=Vector2.ZERO
		player.set_spawn(vector(building.route_start),0.)
		player.camera_pivot.global_rotation=Vector3.ZERO
		player.set_physics_process(true)
		for i in range(16):await physics_frame
		var direction := vector(building.route_forward)
		var route_origin: Vector3 = player.global_position
		player.test_move=Vector2(direction.x,direction.z)
		var walk_start := Time.get_ticks_msec()
		while (player.global_position-route_origin).dot(direction)<5.3 and Time.get_ticks_msec()-walk_start<12000:
			await physics_frame
		player.test_move=Vector2.ZERO
		for i in range(12):await physics_frame
		check((player.global_position-route_origin).dot(direction)>5.2,"actual controller enters "+str(building.id))
		check(absf(player.global_position.y-.10)<.06,"character supported inside "+str(building.id))
		print("SANDBAR_BUILDING_WALK_PASS ",building.id)
	print("SANDBAR_VERIFY_PASS checks=",checks," meshes=121 triangles=",pavilion.manifest.triangle_count," furniture=8 buildings=5 art=v3_timber")
	if "--capture" in OS.get_cmdline_user_args():
		await capture(pavilion)
	quit(0)

func capture(pavilion: Node3D) -> void:
	world.set_free(true)
	world.set_process_unhandled_input(false)
	for layer: CanvasLayer in world.review_ui_layers:layer.visible=false
	world.character.visible=false
	if world.character.switch_wheel!=null:world.character.switch_wheel.visible=false
	var views: Array = [{"name":"review","view":pavilion.manifest.camera},
		{"name":"detail","view":pavilion.manifest.detail_camera},
		{"name":"clay","view":pavilion.manifest.detail_camera}]
	var old_materials: Dictionary = {}
	var clay := StandardMaterial3D.new()
	clay.albedo_color=Color(.65,.65,.65);clay.roughness=.9
	for row: Dictionary in views:
		if row.name=="clay":
			for mesh: MeshInstance3D in pavilion.meshes_by_source.values():
				old_materials[mesh]=mesh.material_override
				mesh.material_override=clay
		var view: Dictionary = row.view
		world.camera.fov=float(view.fov)
		var start_ms := Time.get_ticks_msec()
		while Time.get_ticks_msec()-start_ms<4000:
			world.camera.make_current()
			world.camera.global_position=vector(view.position)
			world.camera.look_at(vector(view.target))
			await process_frame
		await RenderingServer.frame_post_draw
		var target := "res://.current_map_build/sandbar_pavilion_1109/"+str(row.name)+".png"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target.get_base_dir()))
		assert(root.get_texture().get_image().save_png(target)==OK,"Cannot save sandbar review image")
		print("SANDBAR_CAPTURE ",target)
	for mesh: MeshInstance3D in old_materials:mesh.material_override=old_materials[mesh]
