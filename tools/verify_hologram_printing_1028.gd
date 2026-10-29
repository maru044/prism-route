extends SceneTree
const LAB=preload("res://scenes/character_hologram_test.tscn")
const OUT="res://docs/hologram_1028/"
var lab
var failures: Array[String]=[]
var report: Dictionary={}

func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func frames(n: int) -> void:
	for i in n:await process_frame

func logic_checks() -> void:
	var models: Array=[]
	for index in 4:
		lab.select_model(index);await frames(2)
		lab.playing=false;lab.effect.playing=false;lab.effect.set_process(false)
		for modifier: SkeletonModifier3D in lab.character.find_children("*","SkeletonModifier3D",true,false):check(not modifier.active,"Deferred spring physics is still active in preview")
		var effect=lab.effect
		var events: Dictionary={"started":0,"finished":0,"solid_on_finish":false}
		var started: Callable=func():events.started+=1
		var finished: Callable=func():
			events.finished+=1
			events.solid_on_finish=effect.base_materials.all(func(m):return m.next_pass==null)
		effect.printing_started.connect(started);effect.printing_finished.connect(finished)
		var bounds: Vector2=effect.projection_bounds
		check(bounds.is_finite() and bounds.y-bounds.x>1.0 and bounds.y-bounds.x<3.0,"Invalid printing height: "+lab.MODELS[index].id)
		effect.start_printing(3.5)
		effect.advance_printing(.875);effect.apply_parameters()
		check(is_equal_approx(effect.materialization_progress,.25),"Printing does not advance at constant speed")
		effect._process(.5)
		check(is_equal_approx(effect.materialization_progress,.25),"Pause does not freeze printing")
		var previous_plane: float=INF
		for progress: float in [0.,.25,.5,.75,1.]:
			effect.set_print_progress(progress)
			var plane: float=lerpf(bounds.y+effect.print_edge_width*2.,bounds.x-effect.print_edge_width*2.,progress)
			check(plane<previous_plane,"Printing plane did not move from head to feet")
			previous_plane=plane
			for material: ShaderMaterial in effect.materials:
				check(is_equal_approx(material.get_shader_parameter("materialization_progress"),progress),"Surface progress differs")
				check(material.get_shader_parameter("projection_bounds")==bounds,"Surfaces use different height masks")
			for record: Dictionary in effect.records:
				check(record.mesh.cast_shadow==(record.shadow if progress==1. else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF),"Solid completion did not restore shadows")
		effect.start_printing();effect.advance_printing(20.);effect.apply_parameters();effect.advance_printing(20.)
		check(effect.materialization_progress==1. and not effect.printing,"Printing overshot or failed to finish")
		check(events.started==2 and events.finished==1,"Printing signals emitted an incorrect number of times")
		check(events.solid_on_finish,"Completion signal fired before the solid state was applied")
		effect.reset_projection()
		check(effect.materialization_progress==0. and not effect.printing,"Replay reset failed")
		effect.printing_started.disconnect(started);effect.printing_finished.disconnect(finished)
		models.append({"id":lab.MODELS[index].id,"height_bounds":bounds,"surfaces":effect.materials.size(),"progress_samples":5,"pause_replay_completion":true})
	check(ProjectSettings.get_setting("application/run/main_scene")=="res://scenes/map_1021.tscn","Formal F5 entry changed")
	report.models=models

func capture(name: String) -> Image:
	await frames(5);await RenderingServer.frame_post_draw
	var result: Image=root.get_texture().get_image()
	check(result.save_png(OUT+name+".png")==OK,"Capture failed: "+name)
	return result

func screen(world: Vector3,image: Image) -> Vector2:
	return lab.camera.unproject_position(world)*Vector2(image.get_width(),image.get_height())/lab.get_viewport().get_visible_rect().size

func distance_rgb(a: Color,b: Color) -> float:return Vector3(a.r,a.g,a.b).distance_to(Vector3(b.r,b.g,b.b))

func verify_regions(hologram: Image,mid: Image,solid: Image) -> Dictionary:
	var bounds: Vector2=lab.effect.projection_bounds
	var plane: float=lerpf(bounds.y+.05,bounds.x-.05,.5)+lab.character.global_position.y
	var top: float=INF
	var bottom: float=-INF
	for z: float in [-.6,.6]:
		top=minf(top,screen(Vector3(0,plane+.14,z),mid).y)
		bottom=maxf(bottom,screen(Vector3(0,plane-.14,z),mid).y)
	var upper_count:=0;var lower_count:=0
	var upper_error:=0.;var lower_error:=0.
	for y in range(0,mid.get_height(),2):
		for x in range(int(mid.get_width()*.25),int(mid.get_width()*.75),2):
			var initial: Color=hologram.get_pixel(x,y);var final: Color=solid.get_pixel(x,y)
			if distance_rgb(initial,final)<.025:continue
			if y<top:
				upper_count+=1;upper_error+=distance_rgb(mid.get_pixel(x,y),final)
			elif y>bottom:
				lower_count+=1;lower_error+=distance_rgb(mid.get_pixel(x,y),initial)
	upper_error/=maxi(upper_count,1);lower_error/=maxi(lower_count,1)
	check(upper_count>100 and lower_count>100,"Insufficient changed model pixels above/below scan plane")
	check(upper_error<.01,"Upper body did not become solid before lower body")
	check(lower_error<.01,"Lower body lost hologram before scan plane reached it")
	return {"upper_solid_pixels":upper_count,"lower_hologram_pixels":lower_count,"upper_rgb_error":upper_error,"lower_rgb_error":lower_error}

func render_checks() -> void:
	var models: Array=[]
	# Freeze scene/shader time for deterministic image comparisons.
	Engine.time_scale=0.0
	lab.set_ui_visible(false);lab.sun.shadow_enabled=false;lab.environment.glow_enabled=false
	for index in 4:
		lab.select_model(index);await frames(2)
		lab.playing=false;lab.effect.playing=false;lab.effect.set_process(false)
		lab.set_animation("A01");lab.set_background(0);lab.effect.clock=.8
		var id: String=lab.MODELS[index].id
		lab.effect.set_print_progress(0.);var initial:=await capture(id+"_print_000")
		lab.effect.set_print_progress(.5);var half:=await capture(id+"_print_050")
		lab.effect.set_print_progress(1.);var solid:=await capture(id+"_print_100")
		var result:=verify_regions(initial,half,solid);result.id=id
		# Fully printed must render identically to the same MToon base with no light pass.
		for base: ShaderMaterial in lab.effect.base_materials:
			check(base.next_pass==null,"Completion retained a hologram light pass")
		await frames(5);await RenderingServer.frame_post_draw
		var reference: Image=root.get_texture().get_image()
		reference.save_png(OUT+id+"_print_reference.png")
		var max_error:=0.
		for y in range(0,solid.get_height(),3):
			for x in range(0,solid.get_width(),3):max_error=maxf(max_error,distance_rgb(solid.get_pixel(x,y),reference.get_pixel(x,y)))
		check(max_error<.01,"Completed MToon image is unstable")
		result.completed_mtoon_max_rgb_error=max_error;models.append(result)
	report.render={"models":models,"adapter":RenderingServer.get_video_adapter_name()}
	# A short actual-render animation for review; frozen pose makes the mask easy to inspect.
	if "--animation" in OS.get_cmdline_user_args():
		lab.select_model(1);lab.playing=false;lab.effect.playing=false;lab.effect.set_process(false)
		lab.environment.glow_enabled=true;lab.sun.shadow_enabled=true
		var directory: String="res://.current_map_build/hologram_print_frames"
		DirAccess.make_dir_recursive_absolute(directory)
		for frame in 72:
			var progress: float=clampf((float(frame)/12.-.75)/3.5,0.,1.)
			lab.effect.clock=.8+frame/12.;lab.effect.set_print_progress(progress)
			await frames(2);await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(directory+"/%03d.png"%frame)
		lab.set_ui_visible(true);lab.effect.reset_projection()
		await capture("printing_controls")

func run() -> void:
	Engine.max_fps=60;root.size=Vector2i(1280,900)
	lab=LAB.instantiate();root.add_child(lab)
	while not lab.ready_for_review:await process_frame
	await frames(4)
	var gpu: bool="--capture" in OS.get_cmdline_user_args()
	if gpu:await render_checks()
	else:await logic_checks()
	check(report.has("render") if gpu else report.has("models"),"Verification did not finish")
	report.passed=failures.is_empty();report.failures=failures
	FileAccess.open(OUT+("printing_render_report.json" if gpu else "printing_logic_report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("HOLOGRAM_PRINTING_RESULT ",JSON.stringify(report))
	lab.queue_free();await frames(3);quit(0 if failures.is_empty() else 1)
