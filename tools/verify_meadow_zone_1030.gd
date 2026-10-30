extends SceneTree
const PALETTE=preload("res://scripts/meadow_palette.gd")
const STORE=preload("res://scripts/grass_baked_store.gd")
const OUT="res://docs/meadow_zone_1030/local/"
const OLD={"biome_noise_scale":.00135,"biome_warp_distance":210.,"biome_transition_half_width":135.,"biome_center_x":20.,"biome_lowland_enabled":false,"biome_lowland_fade":Vector2(18,64),"biome_lowland_green":.94}
var world
var failures: Array[String]=[]
var noise_image: Image
var mask_image: Image=PALETTE.LAKE_MASK.get_image()
var shore_image: Image=PALETTE.SHORE_MASK.get_image()
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func frames(n: int) -> void:
	for i in n:await physics_frame
func zone(settings: Dictionary,overlap: float) -> void:
	for parameter: String in settings:world.vegetation.grass_material.set_shader_parameter(parameter,settings[parameter])
	world.vegetation.grass_material.set_shader_parameter("biome_instance_overlap",overlap)
	for parameter: String in PALETTE.BIOME_PARAMETERS:
		world.terrain_material.set_shader_parameter(parameter,world.vegetation.grass_material.get_shader_parameter(parameter))
	for row: Dictionary in world.foliage_style.records:
		if row.green:world.foliage_style.configure_green_biome(row.material,world.vegetation.grass_material)
func capture(name: String,eye: Vector3,target: Vector3) -> void:
	world.set_free(true);world.camera.global_position=eye;world.camera.look_at(target)
	await frames(65);await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT+name+".png")==OK,"Failed screenshot: "+name)
func noise_at(p: Vector3,scale: float) -> float:
	var uv:=Vector2(p.x,p.z)*scale+Vector2(.137,.411)
	var pixel:=Vector2(fposmod(uv.x,1.)*noise_image.get_width()-.5,fposmod(uv.y,1.)*noise_image.get_height()-.5)
	var base:=Vector2i(floori(pixel.x),floori(pixel.y));var fraction:=pixel-Vector2(base)
	var values: Array[float]=[]
	for offset in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.ONE]:values.append(noise_image.get_pixel(posmod(base.x+offset.x,noise_image.get_width()),posmod(base.y+offset.y,noise_image.get_height())).r)
	return lerpf(lerpf(values[0],values[1],fraction.x),lerpf(values[2],values[3],fraction.x),fraction.y)
func green(p: Vector3,settings: Dictionary) -> float:
	var regional:=smoothstep(-float(settings.biome_transition_half_width),float(settings.biome_transition_half_width),p.x-float(settings.biome_center_x)+(noise_at(p,settings.biome_noise_scale)*2.-1.)*float(settings.biome_warp_distance))
	if settings.biome_lowland_enabled:
		var local:=local_weight(p)
		if settings.get("biome_shore_enabled",true):local=maxf(local,local_weight(p,true))
		var wet: float=(1.-smoothstep(settings.biome_lowland_fade.x,settings.biome_lowland_fade.y,p.y))*local
		regional=lerpf(regional,maxf(regional,settings.biome_lowland_green),wet)
	return regional
func local_weight(p: Vector3,shore:=false) -> float:
	var resource: Texture2D=PALETTE.SHORE_MASK if shore else PALETTE.LAKE_MASK
	var image: Image=shore_image if shore else mask_image
	var origin: Vector2=resource.get_meta("world_origin")
	var extent: Vector2=resource.get_meta("world_extent")
	var uv: Vector2=(Vector2(p.x,p.z)-origin)/extent
	if uv.x<0 or uv.y<0 or uv.x>1 or uv.y>1:return 0.
	var pixel:=uv*Vector2(image.get_size())-Vector2.ONE*.5
	var base:=Vector2i(floori(pixel.x),floori(pixel.y));var fraction:=pixel-Vector2(base)
	var values: Array[float]=[]
	for offset in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.ONE]:values.append(image.get_pixel(clampi(base.x+offset.x,0,image.get_width()-1),clampi(base.y+offset.y,0,image.get_height()-1)).r)
	var distance:=lerpf(lerpf(values[0],values[1],fraction.x),lerpf(values[2],values[3],fraction.x),fraction.y)
	return smoothstep(0.,80.,distance)
func run() -> void:
	create_timer(180).timeout.connect(func():push_error("Meadow zoning verification timed out");quit(1))
	AudioServer.set_bus_mute(0,true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	world=load("res://scenes/map_1021.tscn").instantiate();world.automation_enabled=true;root.add_child(world);current_scene=world
	while not world.test_ready:await process_frame
	world.set_review_ui_visible(false);await frames(8)
	var texture: Texture2D=world.vegetation.grass_material.get_shader_parameter("biome_noise_texture");noise_image=texture.get_image()
	var lakeside:=Vector3(-400,2,400);var distance:=INF
	var shore_weights: Array=[]
	var records: Dictionary=world.planting.store.all_records()
	var old_sum:=0.;var new_sum:=0.;var count:=0
	var initial_count:=0;var initial_delta:=0.;var outside_count:=0;var outside_delta:=0.;var upper_delta:=0.
	for row: Dictionary in records.values():
		var p:=Vector3(row.position[0],row.position[1],row.position[2]);old_sum+=green(p,OLD);new_sum+=green(p,PALETTE.ZONE);count+=1
		var delta:=absf(green(p,OLD)-green(p,PALETTE.ZONE))
		if p.z>=850.:initial_count+=1;initial_delta=maxf(initial_delta,delta)
		if maxf(local_weight(p),local_weight(p,true))==0.:outside_count+=1;outside_delta=maxf(outside_delta,delta)
		if p.y>=60.:upper_delta=maxf(upper_delta,delta)
		if p.y<40 and local_weight(p)>.999:
			shore_weights.append(green(p,PALETTE.ZONE))
			if p.distance_squared_to(Vector3(-400,2,400))<distance:distance=p.distance_squared_to(Vector3(-400,2,400));lakeside=p
	check(not shore_weights.is_empty(),"No actual western lake-shore samples")
	check(shore_weights.all(func(weight):return weight>=.939),"Low lake shores still have dry patches")
	check(initial_count>0 and initial_delta<.000001,"Initial region did not return to its original colours")
	check(outside_count>0 and outside_delta<.000001,"Colour override escaped the local selection")
	check(upper_delta<.000001,"Upper terraces were recoloured")
	check(green(Vector3(-1250,70,950),PALETTE.ZONE)<.15,"Dry highland contrast disappeared")
	var profile: Array=[]
	for height in [2.,18.,28.,38.,48.,58.,64.]:profile.append({"height":height,"green":green(Vector3(lakeside.x,height,lakeside.z),PALETTE.ZONE)})
	var bake: Dictionary=world.vegetation.volume_streamer.store.manifest
	check(bake.complete and bake.signature==STORE.signature(world),"Colour change invalidated grass roots")
	zone(OLD,35.)
	await capture("overview_before",Vector3(-160,1800,2100),Vector3(-250,15,400))
	await capture("lake_before",Vector3(-1050,500,680),Vector3(-620,5,-100))
	await capture("shore_before",lakeside+Vector3(45,18,55),lakeside+Vector3.UP*1)
	zone(PALETTE.ZONE,35.)
	await capture("overview_after",Vector3(-160,1800,2100),Vector3(-250,15,400))
	await capture("lake_after",Vector3(-1050,500,680),Vector3(-620,5,-100))
	await capture("shore_after",lakeside+Vector3(45,18,55),lakeside+Vector3.UP*1)
	for parameter: String in PALETTE.BIOME_PARAMETERS:
		check(world.terrain_material.get_shader_parameter(parameter)==world.vegetation.grass_material.get_shader_parameter(parameter),"Ground/grass zoning mismatch: "+parameter)
	for row: Dictionary in world.foliage_style.records:
		if row.green:
			for parameter: String in PALETTE.BIOME_PARAMETERS:check(row.material.get_shader_parameter(parameter)==world.vegetation.grass_material.get_shader_parameter(parameter),"Foliage zoning mismatch: "+parameter)
	var protected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.current_map_build/meadow_zone_1030_before/hashes.json"))
	for path: String in protected:check(FileAccess.get_sha256("res://"+path)==protected[path],"Protected layout or root mask changed: "+path)
	var report={"passed":failures.is_empty(),"failures":failures,"actual_scene":world.scene_file_path,"shore_samples":shore_weights.size(),"shore_minimum_green":shore_weights.min(),"initial_samples":initial_count,"initial_maximum_change":initial_delta,"outside_samples":outside_count,"outside_maximum_change":outside_delta,"upper_terrace_maximum_change":upper_delta,"tree_root_sample_mean_before":old_sum/count,"tree_root_sample_mean_after":new_sum/count,"height_feather":profile,"feather_inside_selection_m":80,"grass_signature":bake.signature,"tree_count":world.vegetation.tree_instance_count,"saved_edits":world.planting.store.edits.size(),"saved_removed":world.planting.store.removed.size(),"shore_capture_root":str(lakeside)}
	FileAccess.open(OUT+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("MEADOW_ZONE_VERIFIED ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
