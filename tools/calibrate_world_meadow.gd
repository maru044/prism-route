extends SceneTree
## Calibrate actual Forward+ screen colours under the unchanged 1021 lighting.
const OUT := "res://.vegetation_art_build/grass_color/world/"
const PALETTE := preload("res://scripts/meadow_palette.gd")
var failures: Array[String] = []
var scene
var results: Dictionary = {}

func _initialize() -> void:call_deferred("run")
func frames(count: int) -> void:
	for i in count:await process_frame
func check(ok: bool, message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func screenshot(name: String) -> void:
	await frames(4);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
func screen_median() -> Vector3:
	await frames(4);await RenderingServer.frame_post_draw
	var img:=root.get_texture().get_image()
	var hist: Array[PackedInt32Array]=[]
	for channel in 3:
		var bins:=PackedInt32Array();bins.resize(256);hist.append(bins)
	var count:=0
	for y in range(int(img.get_height()*.42),int(img.get_height()*.74),2):
		for x in range(int(img.get_width()*.30),int(img.get_width()*.70),2):
			var c:=img.get_pixel(x,y)
			for channel in 3:hist[channel][clampi(roundi(c[channel]*255),0,255)]+=1
			count+=1
	var result:=Vector3.ZERO
	for channel in 3:
		var total:=0
		for value in 256:
			total+=hist[channel][value]
			if total>=count/2:result[channel]=value;break
	return result
func array3(v: Vector3) -> Array:return [v.x,v.y,v.z]

func calibration() -> void:
	var saved: Dictionary={}
	for node: GeometryInstance3D in scene.find_children("*","GeometryInstance3D",true,false):
		saved[node]=node.visible;node.hide()
	scene.vegetation.set_process(false);scene.grass_wind.set_process(false)
	var fixture:=Node3D.new();scene.add_child(fixture);fixture.position=Vector3(0,500,0)
	var plane:=MeshInstance3D.new();fixture.add_child(plane)
	var mesh:=PlaneMesh.new();mesh.size=Vector2(40,40);plane.mesh=mesh
	var ground: ShaderMaterial=scene.terrain_material.duplicate()
	ground.set_shader_parameter("mask_origin_xz",Vector2(1000000,1000000))
	ground.set_shader_parameter("use_far_meadow_color",false);plane.material_override=ground
	var grass: ShaderMaterial=scene.vegetation.grass_material.duplicate()
	grass.set_shader_parameter("use_grass_lod_density",false)
	grass.set_shader_parameter("wind_strength",0.0);grass.set_shader_parameter("gust_mix",0.0)
	grass.set_shader_parameter("gust_time",0.0)
	var field:=MultiMeshInstance3D.new();fixture.add_child(field)
	field.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;field.material_override=grass
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true
	mm.mesh=scene.grass_wind.mesh;mm.instance_count=35840;field.multimesh=mm
	var rng:=RandomNumberGenerator.new();rng.seed=20261025
	for i in mm.instance_count:
		var scale_value:=rng.randf_range(.82,1.18)
		mm.set_instance_transform(i,Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale_value),Vector3(rng.randf_range(-16,16),.015,rng.randf_range(-16,16))))
		mm.set_instance_custom_data(i,Color(rng.randf(),rng.randf(),rng.randf(),0))
	var camera:=Camera3D.new();fixture.add_child(camera);camera.fov=42
	camera.position=Vector3(0,7,12);camera.look_at(fixture.position+Vector3(0,.5,0));camera.make_current()
	for zone: String in ["dry","green"]:
		var center: float=100000.0 if zone=="dry" else -100000.0
		grass.set_shader_parameter("biome_center_x",center);ground.set_shader_parameter("biome_center_x",center)
		ground.set_shader_parameter("ground_"+zone,PALETTE.GROUND["ground_"+zone])
		field.show();var target: Vector3=await screen_median();await screenshot(zone+"_reference_grass")
		field.hide();var before: Vector3=await screen_median();await screenshot(zone+"_root_ground")
		var fitted: Color=PALETTE.FAR_GROUND["far_ground_"+zone]
		if not "--verify-only" in OS.get_cmdline_user_args():
			var low:=Vector3.ZERO;var high:=Vector3.ONE
			for iteration in 10:
				var middle: Vector3=(low+high)*.5
				ground.set_shader_parameter("ground_"+zone,Color(middle.x,middle.y,middle.z))
				var sample: Vector3=await screen_median()
				for c in 3:
					if sample[c]<target[c]:low[c]=middle[c]
					else:high[c]=middle[c]
			var fit: Vector3=(low+high)*.5;fitted=Color(fit.x,fit.y,fit.z)
		ground.set_shader_parameter("ground_"+zone,fitted)
		var measured: Vector3=await screen_median();await screenshot(zone+"_calibrated_ground")
		var residual: Vector3=(measured-target).abs()
		check(maxf(residual.x,maxf(residual.y,residual.z))<=3,"Screen colour fit exceeds 3/255: "+zone)
		# Exercise the real terrain shader branch as well as the fitted swatch.
		ground.set_shader_parameter("ground_"+zone,PALETTE.GROUND["ground_"+zone])
		ground.set_shader_parameter("far_ground_"+zone,fitted)
		ground.set_shader_parameter("use_far_meadow_color",true)
		ground.set_shader_parameter("meadow_color_fade",Vector2(0,.1))
		var far_branch: Vector3=await screen_median()
		check(far_branch.distance_to(measured)<=2,"Far terrain shader branch did not use calibrated colour: "+zone)
		ground.set_shader_parameter("use_far_meadow_color",false)
		results[zone]={"grass_screen_rgb":array3(target),"root_ground_screen_rgb":array3(before),"far_ground_screen_rgb":array3(measured),"far_shader_screen_rgb":array3(far_branch),"fitted_source_color":fitted.to_html(false),"source_color_float":[fitted.r,fitted.g,fitted.b],"max_channel_error":maxf(residual.x,maxf(residual.y,residual.z))}
	fixture.free()
	for node: GeometryInstance3D in saved:
		if is_instance_valid(node):node.visible=saved[node]
	scene.vegetation.set_process(true);scene.grass_wind.set_process(true)
	scene.camera.make_current()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size=Vector2i(800,450);Engine.max_fps=60
	scene=load("res://scenes/map_1021.tscn").instantiate();scene.automation_enabled=true;root.add_child(scene)
	var begin:=Time.get_ticks_msec()
	while not scene.test_ready and Time.get_ticks_msec()-begin<150000:await process_frame
	if not scene.test_ready:check(false,"Map startup timeout");quit(1);return
	scene.set_free(true);scene.character.set_physics_process(false);scene.camper.set_physics_process(false)
	scene.set_review_ui_visible(false)
	var grass: ShaderMaterial=scene.vegetation.grass_material
	for key: String in PALETTE.GRASS:check(grass.get_shader_parameter(key)==PALETTE.GRASS[key],"World palette mismatch: "+key)
	for key: String in PALETTE.GROUND:check(scene.terrain_material.get_shader_parameter(key)==PALETTE.GROUND[key],"Root colour mismatch: "+key)
	for key: String in PALETTE.FAR_GROUND:check(scene.terrain_material.get_shader_parameter(key)==PALETTE.FAR_GROUND[key],"Distant colour mismatch: "+key)
	check(grass.get_shader_parameter("albedo_texture")==scene.vegetation.GRASS_TEXTURE,"Grass alpha texture changed")
	for key: String in ["biome_noise_texture","biome_noise_scale","biome_warp_distance","biome_transition_half_width","biome_center_x"]:
		check(grass.get_shader_parameter(key)==scene.terrain_material.get_shader_parameter(key),"Biome mask mismatch: "+key)
	var signature: String=load("res://scripts/grass_baked_store.gd").signature(scene)
	var manifest: Dictionary=scene.vegetation.volume_streamer.store.manifest
	check(signature==manifest.get("signature","") and manifest.get("complete",false),"Grass bake does not match the current map")
	await calibration()
	if "--verify-only" in OS.get_cmdline_user_args():
		root.size=Vector2i(1600,900)
		for spawn: int in [0,5,6]:
			await scene.select_spawn(spawn);scene.set_free(true)
			scene.character.set_physics_process(false);scene.character.hide();scene.camper.hide()
			var p: Vector3=scene.character.global_position
			scene.camera.position=p+Vector3(0,4.5,12);scene.camera.look_at(p+Vector3(0,1,-20))
			scene.vegetation.volume_streamer.refresh()
			var started:=Time.get_ticks_msec()
			while Time.get_ticks_msec()-started<18000:
				await process_frame
				var missing: Dictionary=scene.vegetation.volume_streamer.visible_missing()
				if scene.vegetation.volume_streamer.active.size()>0 and missing.values().all(func(v):return int(v)==0):break
			scene.grass_wind.set_mode(0);scene.grass_wind.advance(3.1);scene.grass_wind.running=false
			await screenshot("world_spawn_%d"%(spawn+1))
			scene.grass_wind.running=true
			check(scene.vegetation.volume_streamer.store.corrupt==0,"Corrupt grass bake")
			# A second angle above the canopy keeps the meadow/LOD transition visible.
			scene.camera.position=p+Vector3(0,24,32);scene.camera.look_at(p+Vector3(0,0,-35))
			await frames(40);await screenshot("world_raised_%d"%(spawn+1))
		scene.show_overview();await frames(35);await screenshot("world_overview")
		scene.overview_mode=false
		scene.camera.position=Vector3(-700,410,1700);scene.camera.look_at(Vector3(-150,35,650))
		await frames(35);await screenshot("world_landscape")
	var report: Dictionary={"passed":failures.is_empty(),"failures":failures,"calibration":results,"grass_bake_signature":signature,"bake_reused":true,"lighting_changed":false,"mode":"verify" if "--verify-only" in OS.get_cmdline_user_args() else "fit"}
	FileAccess.open(OUT+("validation.json" if report.mode=="verify" else "fit.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("MEADOW_SCREEN_CALIBRATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
