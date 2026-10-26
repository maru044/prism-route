extends SceneTree
## Real 1021 geometry, unchanged grass cache, cameras and water collision layers.
const OUT := "res://.current_map_build/water_1026/review/"
const PUBLISHED := "res://assets/water/review/"
var scene
var failures: Array[String] = []
var report: Dictionary = {}
var capture := false

func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
    if not ok:failures.append(message);push_error(message)
func draws(n: int) -> void:
    for i in n:await process_frame
func frames(n: int) -> void:
    for i in n:await physics_frame
func shot(label: String) -> void:
    await draws(12);await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(OUT+label+".png")==OK,"World capture failed")

func tree_reflection_check(view: int) -> void:
    Engine.time_scale = 0.0
    await draws(3);await RenderingServer.frame_post_draw
    var a := root.get_texture().get_image();a.convert(Image.FORMAT_RGBA8)
    scene.water_manager.set_process(false)
    var hidden: Array[Node3D] = []
    for row: Dictionary in scene.water_manager.proxy_records:
        if row.proxy is MultiMeshInstance3D and row.proxy.visible:
            hidden.append(row.proxy);row.proxy.hide()
    await draws(3);await RenderingServer.frame_post_draw
    var b := root.get_texture().get_image();b.convert(Image.FORMAT_RGBA8)
    var aa := a.get_data();var bb := b.get_data();var count := 0
    for i in range(aa.size()/2,aa.size(),4):
        if maxi(absi(int(aa[i])-int(bb[i])),maxi(absi(int(aa[i+1])-int(bb[i+1])),absi(int(aa[i+2])-int(bb[i+2]))))>4:count += 1
    check(count>100,"World trees are missing from the reflected view")
    report["tree_reflection_pixels_"+str(view)] = count
    for node in hidden:node.show()
    scene.water_manager.set_process(true);Engine.time_scale = 1.0
func ray(a: Vector3,b: Vector3,mask: int,excluded: Array[RID] = []) -> Dictionary:
    var query := PhysicsRayQueryParameters3D.create(a,b,mask)
    query.hit_back_faces = true;query.exclude = excluded
    return scene.get_world_3d().direct_space_state.intersect_ray(query)

func geometry() -> void:
    var manager = scene.water_manager
    check(manager.bodies.size()==7,"Not all seven water bodies are configured")
    var count := 0
    for row: Dictionary in manager.bodies:
        var box: AABB = row.mesh.global_transform * row.mesh.get_aabb()
        check(absf(box.position.y)<.001 and absf(box.end.y)<.001,"Nonzero water plane")
        check(row.mesh.get_children().any(func(n):return n is StaticBody3D and n.collision_layer == 4),"Water query layer changed")
        count += 1
    check(scene.character.collision_mask==32 and scene.camper.collision_mask==32,"Water became an actor collision floor")
    var probes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/current_map_validation/review/lagoon_1026_probes.json"))
    var depths: Dictionary = {};var overlap_count := 0
    var open_points: Dictionary = {}
    for name: String in probes:
        open_points[name] = []
        var minimum := INF;var maximum := 0.0;var samples := 0
        for p: Array in probes[name].samples:
            var center := Vector3(float(p[0])-1450,0,1150-float(p[1]))
            var h := ray(center+Vector3.UP*.1,center+Vector3.DOWN*.1,4)
            check(not h.is_empty(),"Missing water over lake bed: "+name)
            if h.is_empty():continue
            if ray(center+Vector3.UP*.1,center+Vector3.UP*200.0,32).is_empty():open_points[name].append([p[0],p[1]])
            minimum = minf(minimum,-float(p[2]));maximum = maxf(maximum,-float(p[2]));samples += 1
            var again := ray(center+Vector3.UP*.1,center+Vector3.DOWN*.1,4,[h.collider.get_rid()])
            if not again.is_empty():overlap_count += 1
        depths[name] = {"samples":samples,"min_m":minimum,"max_m":maximum}
    report.geometry = {"water_bodies":count,"depths":depths,"overlap_probe_hits":overlap_count,"objects":scene.metadata.objects,"mesh_sha256":scene.metadata.mesh_sha256}
    report.open_water_points = open_points
    check(overlap_count==0,"Coplanar water overlaps at bed samples")

func measure(label: String,style: int) -> Dictionary:
    scene.water_manager.apply_style(style)
    await frames(30)
    await draws(60)
    var main := PackedFloat64Array();var mirror := PackedFloat64Array();var wall := PackedFloat64Array()
    var previous := Time.get_ticks_usec()
    var vram_before := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
    for i in 120:
        await process_frame
        var now := Time.get_ticks_usec();wall.append((now-previous)/1000.0);previous = now
        main.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
        mirror.append(scene.water_manager.reflection_gpu_ms)
    var a := 0.0;var b := 0.0
    for v in main:a += v
    for v in mirror:b += v
    main.sort();mirror.sort();wall.sort()
    return {"case":label,"main_gpu_ms":a/main.size(),"main_p95_ms":main[113],"reflection_gpu_ms":b/mirror.size(),
        "reflection_p95_ms":mirror[113],"wall_p95_ms":wall[113],"render_memory_mib":vram_before/1048576.0,"metrics":scene.water_manager.metrics()}

func render_views() -> void:
    scene.set_review_ui_visible(false)
    scene.character.hide();scene.camper.hide()
    # Freeze wind across A/Bs: the accepted grass B deformation has a different
    # rendering cost from breeze, so an AUTO phase change invalidates the pair.
    scene.grass_wind.running = false
    scene.grass_wind.set_mode(0);scene.grass_wind.blend = 0.0;scene.grass_wind.advance(0.0)
    scene.water_manager.wind_override = 0.0
    RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
    report.adapter = RenderingServer.get_video_adapter_name()
    report.driver = RenderingServer.get_current_rendering_driver_name()
    report.performance = []
    for view in [1,2]:
        await scene._water_review_view(view)
        var stream = scene.vegetation.volume_streamer
        stream.refresh()
        var start := Time.get_ticks_msec()
        while stream.pending_visible_count()>0 and Time.get_ticks_msec()-start<45000:await process_frame
        report["stream_pending_"+str(view)] = stream.pending_visible_count()
        for style in [0,1,2]:
            var label: String = ("south" if view==1 else "north")+"_"+["original","sky","planar"][style]
            report.performance.append(await measure(label,style))
            await shot("world_"+label)
        await tree_reflection_check(view)
        scene.water_manager.wind_override = 1.0
        await draws(12);await shot("world_"+("south" if view==1 else "north")+"_wind")
        scene.water_manager.wind_override = -1.0
    var stream = scene.vegetation.volume_streamer
    check(stream.store.corrupt==0,"Water test corrupted grass cache")
    report.grass = {"signature":stream.store.manifest.get("signature",""),"complete":stream.store.manifest.get("complete",false),"corrupt":stream.store.corrupt}
    var old_target: Node3D = scene.vegetation.target
    var active: Camera3D = root.get_camera_3d()
    await draws(4)
    check(root.get_camera_3d()==active and scene.vegetation.target==old_target,"Reflection changes active streamer camera")
    scene.show_overview();await frames(30)
    check(not scene.water_manager.metrics().reflection_active,"Overview keeps an unnecessary mirror active")
    await scene.select_spawn(1)
    await scene.set_character_mode(false);await frames(3)
    check(not scene.character_mode and root.get_camera_3d()==scene.chase_camera,"Camper camera switch failed")
    check(scene.water_manager.active_camera()==scene.chase_camera,"Mirror does not track camper camera")
    await scene.set_character_mode(true);await frames(3)
    check(scene.character_mode and scene.water_manager.active_camera()==scene.character.camera,"Character camera switch failed")
    report.camera_switches = {"overview":true,"camper":true,"character":true}

func run() -> void:
    capture = "--capture" in OS.get_cmdline_user_args()
    Engine.max_fps = 0;root.size = Vector2i(1600,900)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
    check(ProjectSettings.get_setting("application/run/main_scene")=="res://scenes/map_1021.tscn","F5 no longer opens the formal map")
    scene = load("res://scenes/map_1021.tscn").instantiate()
    scene.automation_enabled = true
    root.add_child(scene)
    var start := Time.get_ticks_msec()
    while not scene.test_ready and Time.get_ticks_msec()-start<150000:await process_frame
    check(scene.test_ready,"World startup timeout")
    if scene.test_ready:
        check(scene.water_manager!=null and scene.water_manager.style==2,"Formal map does not default to planar water")
        check(scene.water_manager.name=="WaterManager","Formal map still uses the preview manager")
        for control in scene.find_children("*","Control",true,false):
            if control is Button or control is OptionButton:
                check(not "水面" in control.text and not "SSR" in control.text,"Formal HUD still exposes water comparison navigation")
        report.entry = {"scene":"res://scenes/map_1021.tscn","style":"planar","comparison_controls":false}
        await frames(5);geometry()
        if capture:await render_views()
    report.passed = failures.is_empty();report.failures = failures
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
    var report_file := FileAccess.open(OUT+("world_render.json" if capture else "world_geometry.json"),FileAccess.WRITE)
    report_file.store_string(JSON.stringify(report,"  "))
    report_file.close()
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PUBLISHED))
    var files := ["world_render.json","world_south_planar.png","world_north_planar.png"] if capture else ["world_geometry.json"]
    for name: String in files:
        check(DirAccess.copy_absolute(ProjectSettings.globalize_path(OUT+name),ProjectSettings.globalize_path(PUBLISHED+name))==OK,"Cannot publish world water evidence: "+name)
    print("WATER_WORLD_VERIFY ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
