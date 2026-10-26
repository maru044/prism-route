extends SceneTree
## Contact, rendering and uncapped per-viewport timings for the isolated prototype.
const OUT := "res://.current_map_build/water_1026/review/"
const PUBLISHED := "res://assets/water/review/"
var scene
var failures: Array[String] = []
var report: Dictionary = {}
var capture := false

func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
    if not ok:failures.append(message);push_error(message)
func frames(count: int) -> void:
    for i in count:await physics_frame
func draws(count: int) -> void:
    for i in count:await process_frame
func shot(label: String) -> Image:
    await draws(8)
    await RenderingServer.frame_post_draw
    var image := root.get_texture().get_image()
    image.convert(Image.FORMAT_RGBA8)
    check(image.save_png(OUT+label+".png")==OK,"Capture failed: "+label)
    return image
func difference(a: Image,b: Image,rect: Rect2i) -> int:
    var aa := a.get_region(rect).get_data();var bb := b.get_region(rect).get_data()
    var changed := 0
    for i in range(0,aa.size(),4):
        if maxi(absi(int(aa[i])-int(bb[i])),maxi(absi(int(aa[i+1])-int(bb[i+1])),absi(int(aa[i+2])-int(bb[i+2]))))>5:changed += 1
    return changed

func contacts() -> void:
    scene.set_view(3)
    var actor: Variant = scene.character
    actor.automation_enabled = true
    actor.set_spawn(Vector3(0,scene.bed_height(4)+.04,4),PI)
    await frames(40)
    check(actor.is_on_floor(),"Actor has no lake bed support")
    check(actor.global_position.y > -.8,"Actor fell through lake bed")
    scene.water.interaction.reset()
    actor.test_move = Vector2(1,0)
    await frames(240)
    actor.test_move = Vector2.ZERO
    await frames(10)
    report.contact = {"events":scene.water.interaction.events.size(),"emitted":scene.water.interaction.emitted,"position":str(actor.global_position),"grounded":actor.is_on_floor()}
    check(scene.water.interaction.events.size() >= 2,"Walking did not emit a trail of ripples")
    var born: Vector2 = scene.water.interaction.events[0].xz if not scene.water.interaction.events.is_empty() else Vector2.ZERO
    await frames(12)
    if not scene.water.interaction.events.is_empty():check(scene.water.interaction.events[0].xz == born,"Old ripple follows the actor")
    # Teleport clears the history, rather than drawing an across-map streak.
    actor.set_spawn(Vector3(-16,.65,-28),0)
    await frames(40)
    check(scene.water.interaction.events.is_empty(),"Dry-land teleport retains water trail")
    actor.test_move = Vector2(1,0);await frames(90);actor.test_move = Vector2.ZERO
    check(scene.water.interaction.events.is_empty(),"Walking on dry ground emits ripples")
    # Same XZ as water, but a bridge floor several metres higher.
    actor.set_spawn(Vector3(0,3.6,-13),0);await frames(40)
    actor.test_move = Vector2(.5,0);await frames(90);actor.test_move = Vector2.ZERO
    check(scene.water.interaction.events.is_empty(),"Bridge walking emits water ripples")
    scene.water.interaction.add_event(Vector3.ZERO,"shallow_test",scene.water.clock)
    check(scene.water.interaction.packed_for("ocean_test").is_empty(),"Ripples leak into another water body")
    scene.water.interaction.expire(scene.water.clock+6.0)
    check(scene.water.interaction.events.is_empty(),"Stopped ripples never expire")
    scene.set_view(0)
    for row: Dictionary in scene.water.bodies:row.mesh.hide()
    scene.water._process(1.0)
    check(not scene.water.metrics().reflection_active,"Invisible water still renders the mirror")
    for row: Dictionary in scene.water.bodies:row.mesh.show()

func measure(label: String,style: int) -> Dictionary:
    scene.water.apply_style(style)
    await frames(30)
    await draws(90)
    var main := PackedFloat64Array();var mirror := PackedFloat64Array();var wall := PackedFloat64Array()
    var previous := Time.get_ticks_usec()
    for i in 180:
        await process_frame
        var now := Time.get_ticks_usec();wall.append((now-previous)/1000.0);previous = now
        main.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
        mirror.append(scene.water.reflection_gpu_ms)
    var main_total := 0.0;var mirror_total := 0.0
    for v in main:main_total += v
    for v in mirror:mirror_total += v
    wall.sort();main.sort();mirror.sort()
    return {"case":label,"samples":main.size(),"main_gpu_ms":main_total/main.size(),"main_p95_ms":main[170],
        "reflection_gpu_ms":mirror_total/mirror.size(),"reflection_p95_ms":mirror[170],"wall_p95_ms":wall[170],"metrics":scene.water.metrics()}

func render_tests() -> void:
    scene.hud.hide();scene.character.hide();scene.set_view(0)
    scene.water.surface_detail = 0.0
    scene.water.interactions_enabled = false
    report.gpu_adapter = RenderingServer.get_video_adapter_name()
    report.driver = RenderingServer.get_current_rendering_driver_name()
    report.resolution = [root.size.x,root.size.y]
    report.msaa = root.msaa_3d
    var cases: Array = []
    for value in 4:
        var label: String = ["original","sky","planar","ssr_opaque"][value]
        cases.append(await measure(label,value))
        await shot("small_"+label)
    report.performance = cases
    scene.water.apply_style(2);await draws(45)
    var a := await shot("small_mirror_reference")
    # Change reflection-only material: any changed pixels must come via water.
    var changed_materials: Array[ShaderMaterial] = []
    var original_colors: Array[Color] = []
    for row: Dictionary in scene.water.proxy_records:
        var m: ShaderMaterial = row.proxy.material_override
        changed_materials.append(m);original_colors.append(m.get_shader_parameter("base_color"))
        m.set_shader_parameter("base_color",Color("ff007f"))
    var b := await shot("small_mirror_diagnostic")
    var count := difference(a,b,Rect2i(0,root.size.y/2,root.size.x,root.size.y/2))
    check(count > 100,"Planar texture contains no scene reflection")
    report.reflection_changed_pixels = count
    for i in changed_materials.size():changed_materials[i].set_shader_parameter("base_color",original_colors[i])
    scene.set_view(1);await draws(20)
    var c := await shot("small_shallow")
    scene.water.bodies[0].material.set_shader_parameter("see_bottom",false)
    var d := await shot("small_no_bottom_diagnostic")
    var bottom_count := difference(c,d,Rect2i(root.size.x/4,root.size.y/3,root.size.x/2,root.size.y/2))
    check(bottom_count > 1000,"Shallow water does not transmit the actual bed")
    report.bottom_changed_pixels = bottom_count
    scene.water.bodies[0].material.set_shader_parameter("see_bottom",true)
    # Calibrate the cheap sky fallback against a real mirror containing sky only.
    scene.set_view(0);scene.water.apply_style(1);await draws(10)
    var sky_only := await shot("small_sky_calibration")
    scene.water.apply_style(2);await frames(30)
    for row: Dictionary in scene.water.proxy_records:row.proxy.hide()
    scene.water.set_process(false)
    var mirror_sky := await shot("small_planar_sky_calibration")
    var sky_difference := difference(sky_only,mirror_sky,Rect2i(100,root.size.y*2/3,root.size.x-200,root.size.y/3-10))
    report.sky_calibration_changed_pixels = sky_difference
    scene.water.set_process(true);scene.water.visibility_clock = 1.0
    scene.set_view(1)
    scene.water.surface_detail = 1.0
    scene.set_view(0)
    scene.wind_mode = 2
    await frames(200)
    report.strong_wind = scene.water.metrics()
    await shot("small_strong_wind")
    scene.set_view(1)
    scene.camera.position = Vector3(3,2.6,10)
    scene.camera.look_at(Vector3(1,-.2,7))
    scene.wind_mode = 0;scene.wind_blend = 0.0
    scene.water.wind_override = 0.0
    scene.water.interactions_enabled = true
    scene.water.interaction.reset()
    scene.water._process(0.0)
    scene.water.set_process(false)
    var no_ripples := await shot("small_ripple_reference")
    scene.water.interaction.add_event(Vector3(2,0,7),"shallow_test",scene.water.clock-.8,scene.water.INTERACTION.LANDING_AMPLITUDE)
    scene.water.interaction.add_event(Vector3(-2,0,7),"shallow_test",scene.water.clock-.4,scene.water.INTERACTION.STEP_AMPLITUDE)
    scene.water._process(0.0)
    var ripples := await shot("small_ripples")
    var ripple_pixels := difference(no_ripples,ripples,Rect2i(0,root.size.y/3,root.size.x,root.size.y*2/3))
    report.ripple_changed_pixels = ripple_pixels
    check(ripple_pixels > 100,"Interaction events do not alter the rendered water")
    scene.water.set_process(true)
    scene.set_view(2);await draws(20);await shot("small_ocean")
    scene.set_view(3);await frames(45)
    check(scene.water.active_camera() == scene.character.camera,"Mirror ignores active camera switch")
    scene.set_view(0)
    check(root.get_camera_3d() == scene.camera,"Reflection stole the main viewport camera")

func run() -> void:
    capture = "--capture" in OS.get_cmdline_user_args()
    root.size = Vector2i(1600,900)
    Engine.max_fps = 0
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
    scene = load("res://scenes/water_1026_test.tscn").instantiate()
    root.add_child(scene)
    while not scene.test_ready:await process_frame
    await contacts()
    if capture:await render_tests()
    report.failures = failures;report.passed = failures.is_empty()
    var file := FileAccess.open(OUT+("render.json" if capture else "contact.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  "));file.close()
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PUBLISHED))
    var files := ["render.json","small_planar.png","small_shallow.png","small_ripples.png","small_strong_wind.png","small_ocean.png"] if capture else ["contact.json"]
    for name: String in files:
        check(DirAccess.copy_absolute(ProjectSettings.globalize_path(OUT+name),ProjectSettings.globalize_path(PUBLISHED+name))==OK,"Cannot publish water evidence: "+name)
    print("WATER_VERIFY ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
