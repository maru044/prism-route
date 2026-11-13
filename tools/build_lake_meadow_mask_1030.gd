extends SceneTree
## Trace only the marked north-lake pocket, on the documented overview camera.
const OUT="res://assets/world/meadow_zone_1030/"
const SCREEN=[Vector2(1008,315),Vector2(1105,325),Vector2(1125,350),Vector2(1126,456),Vector2(1110,533),Vector2(1070,573),Vector2(978,592),Vector2(862,624),Vector2(767,658),Vector2(735,652),Vector2(713,623),Vector2(697,584),Vector2(716,552),Vector2(770,529),Vector2(842,505),Vector2(922,476),Vector2(975,442),Vector2(994,402),Vector2(999,358)]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	if "--verify-coast" in OS.get_cmdline_user_args():
		await review_coast();return
	if "--coast" in OS.get_cmdline_user_args():
		var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"coast_region.json"))
		var bytes:=FileAccess.get_file_as_bytes("res://.current_map_build/mid_platform_palette_1110/coast_field.rgh")
		assert(bytes.size()==int(config.size[0])*int(config.size[1])*4)
		var image:=Image.create_from_data(config.size[0],config.size[1],false,Image.FORMAT_RGH,bytes)
		var texture:=ImageTexture.create_from_image(image)
		texture.set_meta("world_origin",Vector2(config.origin[0],config.origin[1]));texture.set_meta("world_extent",Vector2(config.extent[0],config.extent[1]))
		texture.set_meta("surface_height",35.);texture.set_meta("field_sha256",config.field_sha256)
		assert(ResourceSaver.save(texture,OUT+"coast_field.res",ResourceSaver.FLAG_COMPRESS)==OK)
		print("COAST_COLOUR_MASK_BAKED area_m2=",config.area_m2," height=35 size=",config.size)
		quit();return
	root.size=Vector2i(1920,1080)
	var camera:=Camera3D.new();root.add_child(camera);camera.fov=58.;camera.position=Vector3(-160,1800,2100);camera.look_at(Vector3(-250,15,400));camera.make_current()
	var polygon:=PackedVector2Array();var points: Array=[]
	for screen: Vector2 in SCREEN:
		var p: Vector3=Plane(Vector3.UP,20.).intersects_ray(camera.project_ray_origin(screen),camera.project_ray_normal(screen))
		polygon.append(Vector2(p.x,p.z));points.append([p.x,p.z])
	var bounds:=Rect2(polygon[0],Vector2.ZERO)
	for p: Vector2 in polygon:bounds=bounds.expand(p)
	bounds=bounds.grow(12.)
	var image:=Image.create(384,384,false,Image.FORMAT_RF)
	for y in image.get_height():
		for x in image.get_width():
			var p:=bounds.position+(Vector2(x+.5,y+.5)/Vector2(image.get_size()))*bounds.size
			var distance:=INF
			for i in polygon.size():distance=minf(distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,polygon[i],polygon[(i+1)%polygon.size()])))
			if not Geometry2D.is_point_in_polygon(p,polygon):distance=-distance
			image.set_pixel(x,y,Color(distance,0,0,1))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var texture:=ImageTexture.create_from_image(image)
	texture.set_meta("world_origin",bounds.position);texture.set_meta("world_extent",bounds.size)
	assert(ResourceSaver.save(texture,OUT+"lake_green_sdf.res",ResourceSaver.FLAG_COMPRESS)==OK)
	var data={"origin":[bounds.position.x,bounds.position.y],"extent":[bounds.size.x,bounds.size.y],"feather_inside_m":80.,"height_fade_m":[40.,60.],"polygon":points,"screen_polygon":SCREEN.map(func(p):return [p.x,p.y]),"reference_camera":{"position":[-160,1800,2100],"target":[-250,15,400],"fov":58},"signed_distance":"positive inside; feather entirely inside selected boundary"}
	FileAccess.open(OUT+"lake_region.json",FileAccess.WRITE).store_string(JSON.stringify(data,"  "))
	print("LAKE_MEADOW_MASK ",JSON.stringify(data));quit()

func review_coast() -> void:
	var palette=load("res://scripts/meadow_palette.gd")
	var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"coast_region.json"))
	var image: Image=palette.COAST_MASK.get_image()
	var checks:=0;var interior:=0
	var polygon:=PackedVector2Array()
	for p: Array in config.polygon:polygon.append(Vector2(p[0],p[1]))
	for sample: Array in config.roadside_samples:
		assert(palette.coastal_weight(Vector3(sample[0],sample[1],sample[2]))>.99,"Roadside grass still falls outside coastal colour")
		checks+=1
	for z in range(1,image.get_height(),11):
		for x in range(1,image.get_width(),11):
			var p:=Vector3(config.origin[0]+(x+.5)*config.pixel_size,35.,config.origin[1]+(z+.5)*config.pixel_size)
			if image.get_pixel(x,z).r>3.:
				assert(Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),polygon));assert(palette.coastal_weight(p)>.99);interior+=1;checks+=2
			p.y=0.;assert(palette.coastal_weight(p)==0.);p.y=60.;assert(palette.coastal_weight(p)==0.);checks+=2
	var world=load("res://scenes/main.tscn").instantiate();world.automation_enabled=true
	root.add_child(world)
	while not world.test_ready:await process_frame
	await physics_frame;await physics_frame
	var road_meshes:=0
	for mesh: MeshInstance3D in world.model.find_children("*","MeshInstance3D",true,false):
		if not str(mesh.name).ends_with("47800a9c-ca72-4dc5-8203-d6d5d91d29a9"):continue
		assert(mesh.material_override is StandardMaterial3D,"Road asphalt material was replaced")
		assert((mesh.material_override as StandardMaterial3D).albedo_color.is_equal_approx(Color(.13,.145,.15)))
		road_meshes+=1;checks+=2
	assert(road_meshes>0)
	var counts: Dictionary={"broad":0,"upright":0};var all_trees:=0
	var chosen:=Vector3.ZERO;var nearest:=INF
	for row: Dictionary in world.planting.store.all_records().values():
		all_trees+=1
		if not row.species in counts:continue
		var p:=Vector3(row.position[0],row.position[1],row.position[2])
		if palette.coastal_weight(p)<.5:continue
		counts[row.species]+=1
		var d:=p.distance_squared_to(Vector3(550,35,1120))
		if d<nearest:nearest=d;chosen=p
	assert(counts.broad+counts.upright>0)
	var levels: Array[int]=[]
	for list: Array in [world.vegetation.tree_lod0_nodes,world.vegetation.tree_lod1_nodes,world.vegetation.tree_lod2_nodes]:
		var count:=0
		for node: MultiMeshInstance3D in list:
			var material:=node.material_override as ShaderMaterial
			if material!=null and material.get_shader_parameter("coastal_tree_enabled")==true:count+=1
		assert(count>0);levels.append(count);checks+=1
	assert(world.vegetation.grass_material.get_shader_parameter("coastal_field")==palette.COAST_MASK)
	assert(world.terrain_material.get_shader_parameter("coastal_field")==palette.COAST_MASK)
	assert(world.cape_town.installed_cells==1266);checks+=3
	var protected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.current_map_build/mid_platform_palette_1110/protected.json"))
	for path: String in protected:
		if path.ends_with("world_edits.json"):continue # User may still be editing in another process.
		assert(FileAccess.get_sha256("res://"+path)==protected[path]);checks+=1
	world.set_free(true);world.set_review_ui_visible(false)
	world.character.visible=false;world.character.set_physics_process(false)
	if world.character.switch_wheel!=null:world.character.switch_wheel.visible=false
	var nearby: Array[Dictionary]=[]
	for row: Dictionary in world.planting.store.all_records().values():
		var p:=Vector3(row.position[0],row.position[1],row.position[2])
		if absf(p.y-35.)<1. and p.distance_to(chosen)<80.:
			nearby.append({"p":p,"radius":(3.3 if row.species=="small" else 7.5)*float(row.scale)})
	var eye:=chosen+Vector3(22,3.2,25);var best:=-INF
	for dx in range(-36,37,3):
		for dz in range(-36,37,3):
			var candidate:=chosen+Vector3(dx,3.2,dz)
			if Vector2(dx,dz).length()<16. or Vector2(dx,dz).length()>36. or palette.coastal_weight(Vector3(candidate.x,35,candidate.z))<.99:continue
			var clearance:=INF
			for row: Dictionary in nearby:clearance=minf(clearance,Vector2(candidate.x-row.p.x,candidate.z-row.p.z).length()-float(row.radius))
			if clearance>best:best=clearance;eye=candidate
	var folder:="res://.current_map_build/mid_platform_palette_1110/"
	var views: Array=[{"name":"overview","eye":Vector3(900,350,1500),"target":Vector3(535,40,1070)},
		{"name":"ground","eye":eye,"target":chosen+Vector3(0,5,0)},
		{"name":"roadside","eye":Vector3(555,39.5,1252),"target":Vector3(620,35.8,1218)}]
	for view: Dictionary in views:
		world.character.global_position=view.target;world.camera.fov=58.
		for frame in range(200):
			world.camera.make_current();world.camera.global_position=view.eye;world.camera.look_at(view.target);await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(folder+str(view.name)+".png")==OK)
		print("COAST_WORLD_CAPTURE ",view.name)
	var report: Dictionary={"passed":true,"checks":checks,"interior_samples":interior,"roadside_colour_samples":config.roadside_samples.size(),"road_asphalt_material_preserved":road_meshes>0,"area_m2":config.area_m2,"platform_height":35.,"purple_existing_trees":counts,"total_tree_records":all_trees,"large_tree_batches_by_lod":levels,"grass_and_tree_layouts_unchanged":true,"grass_root_bakes_unchanged":true,"source":"scenes/main.tscn"}
	FileAccess.open(folder+"verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("COAST_WORLD_PALETTE_PASS ",JSON.stringify(report));quit()
