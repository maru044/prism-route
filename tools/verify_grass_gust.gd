extends SceneTree
## Actual GPU silhouette, continuous rapid sway, breeze equivalence and integration.
const OUT := "res://.vegetation_art_build/grass_gust/"
const GUST := preload("res://assets/vegetation/shaders/grass_gust.gdshader")
const BASE := preload("res://assets/vegetation/shaders/vegetation_wind.gdshader")
var failures: Array[String]=[]
var report: Dictionary={}

func _initialize() -> void:call_deferred("run")
func frames(count: int) -> void:
	for i in count:await process_frame
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func model(path: String) -> Mesh:
	var source: Node3D=load(path).instantiate()
	var mesh: Mesh=source.find_children("*","MeshInstance3D",true,false)[0].mesh.duplicate()
	source.free();return mesh
func capture(name: String) -> Image:
	await frames(6);await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image();image.save_png(OUT+name+".png");return image
func silhouette(image: Image) -> Rect2i:
	var low:=Vector2i(image.get_width(),image.get_height());var high:=Vector2i(-1,-1)
	for y in image.get_height():
		for x in image.get_width():
			var c:=image.get_pixel(x,y)
			if c.r+c.g+c.b>0.15:low=low.min(Vector2i(x,y));high=high.max(Vector2i(x,y))
	return Rect2i(low,high-low+Vector2i.ONE)
func pixels_changed(a: Image,b: Image) -> int:
	var aa:=a.get_data();var bb:=b.get_data();var count:=0
	for i in range(0,aa.size(),4):
		if maxi(abs(int(aa[i])-int(bb[i])),maxi(abs(int(aa[i+1])-int(bb[i+1])),abs(int(aa[i+2])-int(bb[i+2]))))>3:count+=1
	return count

func motion_window(material: ShaderMaterial, start: float) -> Dictionary:
	var centers: Array[float]=[]
	var heights: Array[int]=[]
	var root_lines: Array[int]=[]
	# Sample the rendered geometry at 24 Hz, covering over six full sways.
	for i in 73:
		material.set_shader_parameter("gust_time",start+float(i)/24.0)
		await frames(2);await RenderingServer.frame_post_draw
		var image:=root.get_texture().get_image()
		var bounds:=silhouette(image)
		centers.append(bounds.get_center().x);heights.append(bounds.size.y);root_lines.append(bounds.end.y)
		if start==0.0:image.save_png(OUT+"motion_%03d.png"%i)
	var low: float=centers.min();var high: float=centers.max()
	var midpoint: float=(low+high)*0.5
	var armed:=false;var cycles:=0
	for x in centers:
		if x<midpoint-5.0:armed=true
		if x>midpoint+5.0 and armed:cycles+=1;armed=false
	check(high-low>35.0,"Strong wind is only small flutter at time %.1f"%start)
	check(cycles>=5 and cycles<=8,"Expected repeated fast large bends, got %d in 3 seconds at %.1f"%[cycles,start])
	check(root_lines.max()-root_lines.min()<=3,"Roots move during continuous sway")
	return {"start_seconds":start,"duration_seconds":3,"samples_hz":24,"large_bend_cycles":cycles,
		"horizontal_span_pixels":high-low,"height_span_pixels":heights.max()-heights.min(),"centers_x":centers,"heights":heights}

func run() -> void:
	root.size=Vector2i(640,480);Engine.max_fps=60
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await fixture()
	await grove()
	report["passed"]=failures.is_empty();report["failures"]=failures
	FileAccess.open(OUT+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("GRASS_GUST_VERIFY ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

func fixture() -> void:
	var fixture_root:=Node3D.new();root.add_child(fixture_root)
	var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color.BLACK
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color.WHITE;environment.ambient_light_energy=1.0
	var env:=WorldEnvironment.new();env.environment=environment;fixture_root.add_child(env)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.1
	camera.position=Vector3(0.3,0.6,4);fixture_root.add_child(camera);camera.look_at(Vector3(0.3,0.6,0));camera.make_current()
	var original:=model("res://assets/vegetation/models/grass_star_3card_v6.glb")
	var segmented:=model("res://assets/vegetation/models/grass_star_3card_gust_v7.glb")
	var arrays:=segmented.surface_get_arrays(0);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR]
	var levels: Dictionary={}
	for i in vertices.size():
		levels[snappedf(vertices[i].y,0.001)]=true
		check(absf(colors[i].r-vertices[i].y/1.15)<0.005,"Root-to-tip weight was not preserved")
	check(levels.size()==5,"Grass has no intermediate bending vertices")
	check((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()==144,"Unexpected triangle count")
	var card:=MeshInstance3D.new();card.mesh=segmented;card.lod_bias=10000.0;fixture_root.add_child(card)
	var material:=ShaderMaterial.new();material.shader=GUST;card.material_override=material
	var white:=Image.create(4,4,false,Image.FORMAT_RGBA8);white.fill(Color.WHITE)
	material.set_shader_parameter("albedo_texture",ImageTexture.create_from_image(white))
	var noise:=NoiseTexture2D.new();noise.noise=FastNoiseLite.new();noise.width=64;noise.height=64
	material.set_shader_parameter("wind_noise_texture",noise)
	material.set_shader_parameter("use_noise_wind",true);material.set_shader_parameter("wind_speed",0.0)
	material.set_shader_parameter("wind_variation_speed",0.0);material.set_shader_parameter("wind_tone_strength",0.0)
	material.set_shader_parameter("wind_direction",Vector2.RIGHT);material.set_shader_parameter("wind_strength",0.085)
	await frames(25)
	material.set_shader_parameter("gust_mix",0.0)
	var calm:=await capture("fixture_breeze");var calm_bounds:=silhouette(calm)
	var old:=material.duplicate() as ShaderMaterial;old.shader=BASE;card.material_override=old;card.mesh=original
	var old_image:=await capture("fixture_original_breeze")
	var difference:=pixels_changed(calm,old_image)
	check(difference<250,"The new calm mode changed the original breeze appearance")
	card.material_override=material;card.mesh=segmented
	material.set_shader_parameter("gust_mix",1.0);material.set_shader_parameter("gust_angle_override",1.0)
	material.set_shader_parameter("gust_time",0.0)
	var bent:=await capture("fixture_arc");var bent_bounds:=silhouette(bent)
	check(bent_bounds.size.y<calm_bounds.size.y-8,"Grass tip did not lower while bending")
	check(bent_bounds.get_center().x>calm_bounds.get_center().x+20,"Grass did not bend in world wind direction")
	check(absi(bent_bounds.end.y-calm_bounds.end.y)<=3,"Grass roots moved off their ground line")
	card.rotation.y=PI
	var rotated:=silhouette(await capture("fixture_arc_rotated"))
	check(absi(rotated.get_center().x-bent_bounds.get_center().x)<=3,"Random yaw rotates the world wind direction")
	card.rotation.y=0
	material.set_shader_parameter("gust_angle_override",-100.0)
	var motion: Array=[]
	motion.append(await motion_window(material,0.0))
	motion.append(await motion_window(material,18.0))
	# Reframe the same tuft at distant world positions, freezing the global clock.
	# Spatial wind must not change the strong-wind shape or timing at all.
	var max_spatial_difference:=0
	for time: float in [0.0,0.125,0.25,0.375,18.25]:
		material.set_shader_parameter("gust_time",time)
		card.position=Vector3.ZERO;camera.position=Vector3(0.3,0.6,4)
		var reference:=await capture("sync_reference")
		for offset: Vector3 in [Vector3(3,0,7),Vector3(-13,0,11),Vector3(50,0,-23)]:
			card.position=offset;camera.position=Vector3(0.3,0.6,4)+offset
			var remote:=await capture("sync_remote")
			var spatial_difference:=pixels_changed(reference,remote)
			max_spatial_difference=maxi(max_spatial_difference,spatial_difference)
			check(spatial_difference<40,"Strong wind differs between world positions at time %.3f"%time)
	card.position=Vector3.ZERO;camera.position=Vector3(0.3,0.6,4)
	material.set_shader_parameter("gust_time",20.0000);var wrap_a:=await capture("continuity_before")
	material.set_shader_parameter("gust_time",20.0001);var wrap_b:=await capture("continuity_after")
	# A rapid sway can move antialiased edge pixels even across 0.1 ms. Check
	# subpixel-sized bounds motion and sparse image changes, rather than exact pixels.
	var nearby_difference:=pixels_changed(wrap_a,wrap_b)
	var nearby_a:=silhouette(wrap_a);var nearby_b:=silhouette(wrap_b)
	check(nearby_difference<300 and (nearby_a.position-nearby_b.position).abs().x<=1
		and (nearby_a.size-nearby_b.size).abs().length()<=1.5,"Continuous wind jumps between nearby times")
	report["geometry"]={"vertices":vertices.size(),"triangles":48,"height_rows":levels.size(),"breeze_pixel_difference":difference,
		"calm_bounds":str(calm_bounds),"bent_bounds":str(bent_bounds),"motion_windows":motion,
		"nearby_time_pixel_difference":nearby_difference,"world_direction_yaw_invariant":true,
		"spatial_synchrony_max_pixel_difference":max_spatial_difference,"spatial_synchrony_comparisons":15}
	fixture_root.free();await frames(3)

func measure(label: String) -> Dictionary:
	await frames(35)
	var gpu: Array[float]=[]
	for i in 90:
		await process_frame
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
	gpu.sort()
	return {"mode":label,"gpu_median_ms":gpu[gpu.size()/2],"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}

func grove() -> void:
	root.size=Vector2i(1600,900);RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var scene: Node3D=load("res://scenes/vegetation_grove_test.tscn").instantiate();root.add_child(scene);await frames(30)
	var demo=scene.grass_wind_demo;demo.running=false
	check(demo.mode==demo.Mode.AUTO,"Grove did not default to automatic wind")
	check(demo.menu.item_count==3 and demo.menu.is_visible_in_tree(),"Wind selector is unavailable")
	var count:=0
	for chunk: MultiMeshInstance3D in scene.get_node("GrassChunks").get_children():
		count+=chunk.multimesh.instance_count;check(chunk.extra_cull_margin>=1.5,"Gust culling margin too small")
	check(count==63000,"Grass distribution/density changed")
	var camera: Camera3D=scene.get_node("OrbitCamera");camera.set_process(false)
	camera.position=Vector3(2.8,1.7,8.0);camera.look_at(Vector3(3,0.65,1.0))
	var timings: Array=[]
	demo.set_mode(demo.Mode.BREEZE);demo.advance(4.0)
	check(is_zero_approx(demo.blend),"Breeze cannot be selected")
	await capture("grove_breeze");timings.append(await measure("segmented_breeze"))
	demo.set_mode(demo.Mode.STRONG);demo.advance(1.0)
	check(demo.blend>0.0 and demo.blend<1.0,"Wind transition is instantaneous")
	demo.advance(3.0);check(is_equal_approx(demo.blend,1.0),"Strong wind cannot be selected")
	# Resume animation for the full-scene capture/performance sample.
	demo.running=true;await capture("grove_strong");timings.append(await measure("strong_gust"));demo.running=false
	# Deterministic real GPU frames, so visual review can inspect cadence as well
	# as one attractive still. Playback at 24 fps represents the sampled time.
	var movie_start: float=demo.elapsed
	for i in 48:
		scene.grass_material.set_shader_parameter("gust_time",movie_start+float(i)/24.0)
		await frames(2);await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"grove_motion_%03d.png"%i)
	demo.set_mode(demo.Mode.AUTO);demo.advance(4.0);check(is_zero_approx(demo.blend),"Auto does not begin with a calm interval")
	demo.advance(5.0);demo.advance(3.0);check(is_equal_approx(demo.blend,1.0),"Auto never reaches strong wind")
	demo.advance(8.0);demo.advance(3.0);check(is_zero_approx(demo.blend),"Auto never returns to breeze")
	# Baseline geometry and shader at the same fixed camera, without mutating files.
	var base_mesh:=model("res://assets/vegetation/models/grass_star_3card_v6.glb")
	var base_material:=scene.grass_material.duplicate() as ShaderMaterial;base_material.shader=BASE;base_mesh.surface_set_material(0,base_material)
	for chunk: MultiMeshInstance3D in scene.get_node("GrassChunks").get_children():chunk.multimesh.mesh=base_mesh
	timings.append(await measure("original_v6_breeze"))
	report["grove"]={"instances":count,"auto_cycle_seconds":24,"transition_seconds":3,"timings_1600x900":timings,"manual_and_auto_passed":true}
	scene.free();await frames(3)
