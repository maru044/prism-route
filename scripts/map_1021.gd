extends Node3D
## Full current map review; explicit-height spawn selection never snaps to a roof above.
const ASSETS := "res://assets/world/current_map_validation/"
const VEGETATION := preload("res://scripts/tree_planting/world_vegetation.gd")
const PLANTING := preload("res://scripts/tree_planting/world_editor.gd")
var planting
var planting_edits_path := "res://assets/world/tree_planting/world_edits.json"
@export var start_planting_editor:=false
const PERFORMANCE_MONITOR := preload("res://scripts/performance_monitor_1021.gd")
const FOLIAGE_STYLE := preload("res://scripts/foliage_style.gd")
const GRASS_WIND := preload("res://scripts/grass_wind_world.gd")
const MEADOW_PALETTE := preload("res://scripts/meadow_palette.gd")
const SKY := preload("res://assets/environment/sky/fresh_cumulus_sky.tres")
const WATER_MANAGER := preload("res://scripts/water/water_manager.gd")
const WORLD_AUDIO := preload("res://scripts/audio/world_audio_1030.gd")
var world_audio
const INITIAL_RUIN := preload("res://scenes/world/initial_ruin.tscn")
const DIALOGUE_INPUT := preload("res://scenes/narrative/dialogue_panel.gd")
const WORLD_CONTROL := preload("res://scripts/world/world_control_context.gd")
const GAME_PROGRESS := preload("res://scripts/progress/game_progress.gd")
var game_progress := GAME_PROGRESS.new()
const UPPER_RING := preload("res://scenes/world/upper_ring.tscn")
const ISLAND_SADDLE := preload("res://scenes/world/island_saddle.tscn")
const OVAL_ATRIUM := preload("res://scripts/world/oval_atrium.gd")
const TERRACE_RUINS := preload("res://scripts/world/terrace_ruins.gd")
const LANDMARK_RING := preload("res://scripts/world/landmark_ring.gd")
const WATER_COURT := preload("res://scripts/world/water_court.gd")
const EARTH_PAVILION := preload("res://scripts/world/east_earth_pavilion.gd")
const TERRAIN_REPAIRS := preload("res://scripts/world/terrain_repairs.gd")
const SUNKEN_ARCHIVE := preload("res://scripts/world/sunken_archive.gd")
const ROAD_JUNCTION := preload("res://scripts/world/road_junction.gd")
const CHURCH_RUINS := preload("res://scripts/world/church_ruins.gd")
const BEACH_SLOPE := preload("res://scripts/world/beach_slope.gd")
const SANDBAR_PAVILION := preload("res://scripts/world/sandbar_pavilion.gd")
const LAGOON_RUINS := preload("res://scripts/world/lagoon_ruins.gd")
const NPC_WAYPOINT_RUINS := preload("res://scripts/world/npc_waypoint_ruins.gd")
const NPC_PLACEMENT_PREVIEW := preload("res://scripts/world/npc_placement_preview.gd")
const CAPE_TOWN := preload("res://scripts/world/cape_town.gd")
const CONSTRUCTION := preload("res://scripts/construction/construction_world.gd")
var construction
var cape_town
var sandbar_pavilion
var lagoon_ruins := LAGOON_RUINS.new()
var npc_waypoint_ruins := NPC_WAYPOINT_RUINS.new()
var npc_placement_preview
var church_ruins
var sunken_archive
var terrain_repairs
var earth_pavilion
var water_court
var landmark_ring
var terrace_ruins
var oval_atrium
var island_saddle
var upper_ring
const SURFACE_DETAIL_TRIAL := preload("res://scripts/world/architecture_detail_trial.gd")
const ACTOR_SOLID_LAYER := 32
const NPC_SOLID_LAYER := 64
const GRAPHICS_SETTINGS_PATH := "user://graphics.cfg"
enum GraphicsQuality { HIGH, MEDIUM, LOWEST }
var water_manager
var initial_ruin
var surface_detail_trial
# CAD north (+Y) exports to Godot -Z; azimuth runs clockwise from north.
const SUN_AZIMUTH_DEGREES := 135.0
# Measured bright horizon of rosendal_park_sunset_puresky_4k.exr (u ~= .6094).
const HDRI_BRIGHT_AZIMUTH_DEGREES := 219.4
@onready var character = $Character
@onready var camper = $CamperVan
@onready var chase_camera: Camera3D = $CamperVan/CameraPivot/SpringArm3D/Camera3D
var metadata: Dictionary
var model: Node3D
var mask_image: Image
var mask_texture: Texture2D
var terrain_material: ShaderMaterial
var vegetation
var foliage_style
var grass_wind
var test_ready := false
var automation_enabled := false
var free_mode := false
var overview_mode := false
var camera: Camera3D
var spawn_index := 0
var resolved_spawns: Array[Dictionary] = []
var status: Label
var spawn_menu: OptionButton
var graphics_menu: OptionButton
var graphics_environment: Environment
var graphics_quality: int = GraphicsQuality.HIGH
var dragging := false
var tree_placement_report: Dictionary = {}
var character_mode := true
var switching_actor := false
var vegetation_bake_only := false
var review_ui_visible := true
# Developer/review overlays only. Gameplay prompts must not register here.
var review_ui_layers: Array[CanvasLayer] = []
var encounter_ui_active := false

func vec(value: Array) -> Vector3:
	return Vector3(value[0],value[1],value[2])

func _ready() -> void:
	if "--verify-export" in OS.get_cmdline_user_args() or "--verify-world-clusters" in OS.get_cmdline_user_args() or "--verify-world-audio" in OS.get_cmdline_user_args():automation_enabled=true
	metadata=JSON.parse_string(FileAccess.get_file_as_string(ASSETS+"metadata.json"))
	# Preserve legacy query layers for planting, while actors ignore paint.
	character.collision_mask=ACTOR_SOLID_LAYER|NPC_SOLID_LAYER;camper.collision_mask=ACTOR_SOLID_LAYER|NPC_SOLID_LAYER
	character.surface_step_height=.18;character.safe_margin=.004
	camper.surface_step_height=.12;camper.safe_margin=.006;camper.ground_query_mask=ACTOR_SOLID_LAYER
	character.automation_enabled=automation_enabled; character.set_control_enabled(false)
	camper.automation_enabled=automation_enabled;camper.set_physics_process(false);camper.set_process_unhandled_input(false);camper.visible=false
	camper.calibrate_wheels()
	camper.respawn_resolver=_resolve_camper_respawn
	_load_mask();_environment();_build_model();add_child(ROAD_JUNCTION.new());_build_terrain_repairs();_build_oval_atrium();_build_initial_ruin();_build_island_saddle();_build_landmark_ring();_build_terrace_ruins();_build_water_court();_build_earth_pavilion();_build_sunken_archive();_build_church_ruins();_build_upper_ring();_build_surface_detail_trial();_build_sandbar_pavilion();_build_cape_town()
	add_child(lagoon_ruins)
	add_child(npc_waypoint_ruins)
	construction=CONSTRUCTION.new();construction.world=self;add_child(construction)
	if not vegetation_bake_only and FileAccess.file_exists(NPC_PLACEMENT_PREVIEW.CATALOG) and (OS.has_feature("editor") or "--npc-placement-preview" in OS.get_cmdline_user_args()):
		npc_placement_preview = NPC_PLACEMENT_PREVIEW.new()
		npc_placement_preview.name = "NPCPlacementPreview"
		add_child(npc_placement_preview)
	_hud()
	if npc_placement_preview != null:
		npc_placement_preview.initialize(self)
	camera=Camera3D.new();camera.near=0.15;camera.far=10000;camera.fov=58;add_child(camera)
	await get_tree().physics_frame;await get_tree().physics_frame
	for proposal: Dictionary in metadata.spawns:
		resolved_spawns.append(resolve_spawn(proposal))
	var initial_spawn:=0
	for i in resolved_spawns.size():
		if resolved_spawns[i].get("key","")==metadata.get("default_spawn_key",""):initial_spawn=i;break
	if "--ruin-preview" in OS.get_cmdline_user_args() or "--ruin-stairs-preview" in OS.get_cmdline_user_args():
		for i in resolved_spawns.size():
			if resolved_spawns[i].get("key","")=="initial_ruin":initial_spawn=i;break
	if "--upper-ring-preview" in OS.get_cmdline_user_args():initial_spawn=resolved_spawns.size()-1
	if "--island-saddle-preview" in OS.get_cmdline_user_args():
		for i in resolved_spawns.size():
			if resolved_spawns[i].get("key","")=="island_saddle":initial_spawn=i;break
	if "--oval-atrium-preview" in OS.get_cmdline_user_args():
		for i in resolved_spawns.size():
			if resolved_spawns[i].get("key","")=="oval_atrium":initial_spawn=i;break
	if "--terrace-ruins-preview" in OS.get_cmdline_user_args():
		for i in resolved_spawns.size():
			if resolved_spawns[i].get("key","")=="terrace_ruins_a":initial_spawn=i;break
	if "--landmark-ring-preview" in OS.get_cmdline_user_args():
		for i in resolved_spawns.size():
			if resolved_spawns[i].get("key","")=="spawn_cave":initial_spawn=i;break
	if "--water-court-preview" in OS.get_cmdline_user_args():
		for i in resolved_spawns.size():
			if resolved_spawns[i].get("key","")=="water_court":initial_spawn=i;break
	if start_planting_editor:initial_spawn=resolved_spawns.size()-1
	if "--earth-pavilion-preview" in OS.get_cmdline_user_args():
		for i in resolved_spawns.size():
			if resolved_spawns[i].get("key","")=="earth_pavilion":initial_spawn=i;break
	if "--church-preview" in OS.get_cmdline_user_args():
		for i in resolved_spawns.size():
			if resolved_spawns[i].get("key","")=="church_ruins":initial_spawn=i;break
	if "--sunken-archive-preview" in OS.get_cmdline_user_args():
		for i in resolved_spawns.size():
			if resolved_spawns[i].get("key","")=="sunken_archive":initial_spawn=i;break
	if "--sandbar-pavilion-preview" in OS.get_cmdline_user_args():
		for i in resolved_spawns.size():
			if resolved_spawns[i].get("key","")=="sandbar_pavilion":initial_spawn=i;break
	if "--cape-town-preview" in OS.get_cmdline_user_args():
		for i in resolved_spawns.size():
			if resolved_spawns[i].get("key","")=="cape_town":initial_spawn=i;break
	await select_spawn(initial_spawn)
	if "--ruin-preview" in OS.get_cmdline_user_args() or "--ruin-stairs-preview" in OS.get_cmdline_user_args():
		var forward:=vec(initial_ruin.planting_mask.manifest.forward)
		var near: Vector3=initial_ruin.avatar.global_position-forward*2.45
		near.y=float(initial_ruin.planting_mask.manifest.placement.main_floor)+.04
		if "--ruin-stairs-preview" in OS.get_cmdline_user_args():near=vec(initial_ruin.walk_manifest.routes.entry_1[0])+Vector3.UP*.04
		character.set_spawn(near,atan2(-forward.x,-forward.z))
		character.camera.h_offset=.55
	if vegetation_bake_only:
		test_ready=true
		return
	planting=PLANTING.new();planting.name="WorldPlantingEditor";add_child(planting);planting.initialize(self)
	vegetation=VEGETATION.new();vegetation.world_scene=self;add_child(vegetation)
	vegetation.initialize(character,_noise(),2)
	oval_atrium.bind_grass(vegetation.grass_material)
	terrace_ruins.bind_grass(vegetation.grass_material)
	earth_pavilion.bind_grass(vegetation.grass_material)
	sunken_archive.bind_grass(vegetation.grass_material)
	church_ruins.bind_grass(vegetation.grass_material)
	oval_atrium.install_grass_cells(vegetation.volume_streamer)
	earth_pavilion.install_grass_cells(vegetation.volume_streamer)
	terrain_repairs.install_grass_cells(vegetation.volume_streamer)
	church_ruins.install_grass_cells(vegetation.volume_streamer)
	cape_town.install_grass_cells(vegetation.volume_streamer)
	npc_waypoint_ruins.install_grass_cells(vegetation.volume_streamer, self)
	npc_waypoint_ruins.bind_grass(vegetation.grass_material)
	vegetation.volume_streamer.waypoint_grass_cell_filter = npc_waypoint_ruins.overlaps_grass_cell
	cape_town.bind_vegetation(vegetation)
	upper_ring.plant_courtyard(vegetation)
	grass_wind=GRASS_WIND.new();add_child(grass_wind)
	grass_wind.initialize(vegetation);grass_wind.set_mode(GRASS_WIND.Mode.AUTO)
	sunken_archive.install_courtyard_grass(vegetation)
	_apply_grass_quality()
	_sync_meadow_color()
	construction.bind_grass(vegetation.grass_material)
	foliage_style=FOLIAGE_STYLE.new()
	foliage_style.bind_streamer(vegetation)
	_initialize_water()
	world_audio.initialize(self)
	tree_placement_report=JSON.parse_string(FileAccess.get_file_as_string(ASSETS+"tree_layout_metadata.json"))
	_sync_actor_controls()
	test_ready=true
	planting.finish()
	if start_planting_editor or "--planting-editor" in OS.get_cmdline_user_args():planting.call_deferred("enter")
	print("CURRENT_MAP_READY objects=%d triangles=%d spawns=%d trees=%d" % [metadata.objects,metadata.triangles,resolved_spawns.size(),vegetation.tree_instance_count])
	if "--island-saddle-preview" in OS.get_cmdline_user_args():
		set_free(true)
		camera.global_position=vec(island_saddle.manifest.review_eye)
		camera.look_at(vec(island_saddle.manifest.review_target))
	if "--oval-atrium-preview" in OS.get_cmdline_user_args():
		set_free(true)
		camera.global_position=vec(oval_atrium.manifest.review_eye)
		camera.look_at(vec(oval_atrium.manifest.review_target))
	if "--terrace-ruins-preview" in OS.get_cmdline_user_args():
		set_free(true)
		camera.global_position=vec(terrace_ruins.manifest.detail_eye)
		camera.look_at(vec(terrace_ruins.manifest.detail_target))
	if "--landmark-ring-preview" in OS.get_cmdline_user_args():
		set_free(true)
		camera.global_position=vec(landmark_ring.manifest.spawn_eye)
		camera.look_at(vec(landmark_ring.manifest.spawn_target))
	if "--architecture-detail-preview" in OS.get_cmdline_user_args():surface_detail_trial.call_deferred("show_view",3)
	if "--water-court-preview" in OS.get_cmdline_user_args():
		set_free(true)
		camera.global_position=vec(water_court.manifest.review_eye)
		camera.look_at(vec(water_court.manifest.review_target))
	if "--sunken-archive-preview" in OS.get_cmdline_user_args():
		set_free(true)
		camera.global_position=vec(sunken_archive.manifest.views.overview.eye)
		camera.look_at(vec(sunken_archive.manifest.views.overview.target))
	if "--terrain-repairs-preview" in OS.get_cmdline_user_args():
		set_free(true)
		camera.global_position=Vector3(-40.,30.,-700.)
		camera.look_at(Vector3(-130.,1.5,-580.))
	if "--verify-world-clusters" in OS.get_cmdline_user_args():
		var verifier: Node=load("res://tools/check_world_clusters_1029.gd").new();verifier.world=self;add_child(verifier);verifier.call_deferred("run")
	if "--verify-world-audio" in OS.get_cmdline_user_args():
		var verifier: Node=load("res://tools/check_world_audio_1030.gd").new();verifier.world=self;add_child(verifier);verifier.call_deferred("run")
	if "--verify-export" in OS.get_cmdline_user_args():
		if ResourceLoader.exists("res://tools/verify_export_1021.gd"):
			get_tree().root.call_deferred("add_child",load("res://tools/verify_export_1021.gd").new())
		elif ResourceLoader.exists("res://tools/configure_export_1021.gd"):
			get_tree().root.call_deferred("add_child",load("res://tools/configure_export_1021.gd").new())
		else:
			push_warning("[Map1021] --verify-export verification script not found")

func _initialize_water() -> void:
	water_manager=WATER_MANAGER.new()
	water_manager.name="WaterManager";add_child(water_manager)
	var environment: Environment
	for node in get_children():
		if node is WorldEnvironment:environment=node.environment;break
	water_manager.initialize(environment,func():return active_actor(),func():return get_viewport().get_camera_3d())
	water_manager.wind_source=grass_wind
	var byid: Dictionary={}
	for row: Dictionary in metadata.object_records:byid[row.id]=row
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var id:=str(mesh.name).get_slice("_",1)
		var kind: String=byid.get(id,{}).get("kind","")
		if terrain_repairs!=null and terrain_repairs.shoulder_mesh==mesh:kind="Terrain"
		if kind=="Water":water_manager.register_water(mesh,id)
		elif kind!="Sand":
			var color:=Color("91a46b") if kind=="Terrain" else (Color("3b4248") if kind=="Road" else Color("e8e4da"))
			water_manager.register_reflector(mesh,color)
	water_manager.register_tree_streamer(vegetation)
	for mesh: MeshInstance3D in initial_ruin.geometry.find_children("*","MeshInstance3D",true,false):
		if mesh.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:water_manager.register_reflector(mesh,Color("d8d2bf"))
	surface_detail_trial.sync_reflections()
	upper_ring.register_reflections(water_manager)
	island_saddle.register_reflections(water_manager)
	oval_atrium.register_reflections(water_manager)
	terrace_ruins.register_reflections(water_manager)
	landmark_ring.register_reflections(water_manager)
	water_court.register_reflections(water_manager)
	earth_pavilion.register_reflections(water_manager)
	terrain_repairs.register_reflections(water_manager)
	sunken_archive.register_reflections(water_manager)
	sandbar_pavilion.register_reflections(water_manager)
	lagoon_ruins.register_reflections(water_manager)
	cape_town.register_reflections(water_manager)

func _build_cape_town() -> void:
	cape_town=CAPE_TOWN.new();cape_town.world=self;add_child(cape_town)
	var support:=""
	for row: Dictionary in cape_town.manifest.objects:
		if row.name=="street/approach":support=row.id;break
	metadata.spawns.append({"name":"海岬小镇 · 中央环岛","key":"cape_town","position":cape_town.manifest.spawn,
		"look_direction":cape_town.manifest.forward,"required_floor_kind":"Structure","required_source_id":support,"maximum_search_distance_m":1.,"character_only":true})

func _build_sandbar_pavilion() -> void:
	sandbar_pavilion=SANDBAR_PAVILION.new();add_child(sandbar_pavilion)
	metadata.spawns.append({"name":"沙洲度假遗址 · 中央双翼亭","key":"sandbar_pavilion","position":sandbar_pavilion.manifest.spawn,
		"look_direction":[.6,0,-.8],"required_floor_kind":"Structure",
		"required_source_id":sandbar_pavilion.manifest.objects[0].id,"maximum_search_distance_m":1.,"character_only":true})

func _build_terrain_repairs() -> void:
	terrain_repairs=TERRAIN_REPAIRS.new();terrain_repairs.world=self;add_child(terrain_repairs)

func _build_church_ruins() -> void:
	church_ruins=CHURCH_RUINS.new();church_ruins.world=self;add_child(church_ruins)
	metadata.spawns.append({"name":"西双子山 · 孤顶教堂遗址","key":"church_ruins","position":church_ruins.manifest.spawn_godot,
		"look_direction":church_ruins.manifest.spawn_look_direction_godot,"required_floor_kind":"Structure",
		"required_source_id":church_ruins.manifest.spawn_source_id,"maximum_search_distance_m":2.,"character_only":true})

func _build_sunken_archive() -> void:
	sunken_archive=SUNKEN_ARCHIVE.new();sunken_archive.world=self;add_child(sunken_archive)
	metadata.spawns.append({"name":"下沉环庭 · 地下展廊","key":"sunken_archive","position":sunken_archive.manifest.spawn,
		"look_direction":sunken_archive.manifest.look_direction,"required_floor_kind":"Structure",
		"required_source_id":sunken_archive.manifest.spawn_source_id,"maximum_search_distance_m":1.,"character_only":true})

func _build_earth_pavilion() -> void:
	earth_pavilion=EARTH_PAVILION.new();earth_pavilion.world=self;add_child(earth_pavilion)
	metadata.spawns.append({"name":"东侧覆土庭院 · 入口与中庭","key":"earth_pavilion","position":earth_pavilion.manifest.spawn,
		"look_direction":earth_pavilion.manifest.look_direction,"required_floor_kind":"Structure",
		"required_source_id":earth_pavilion.manifest.spawn_source_id,"maximum_search_distance_m":1.,"character_only":true})

func _build_water_court() -> void:
	water_court=WATER_COURT.new();add_child(water_court)
	metadata.spawns.append({"name":"浅水庭院 · 弧形展廊","key":"water_court","position":water_court.manifest.spawn,
		"look_direction":water_court.manifest.look_direction,"required_floor_kind":"Structure",
		"required_source_id":water_court.manifest.spawn_source_id,"maximum_search_distance_m":1.,"character_only":true})

func _build_landmark_ring() -> void:
	landmark_ring=LANDMARK_RING.new()
	landmark_ring.materials=island_saddle.materials
	add_child(landmark_ring)

func _build_terrace_ruins() -> void:
	terrace_ruins=TERRACE_RUINS.new();add_child(terrace_ruins)
	for row: Dictionary in terrace_ruins.manifest.spawns:
		metadata.spawns.append({"name":row.name,"key":row.key,"position":row.position,"look_direction":row.look_direction,
			"required_floor_kind":"Structure","required_source_id":row.source_id,"maximum_search_distance_m":1.,"character_only":true})

func _build_oval_atrium() -> void:
	oval_atrium=OVAL_ATRIUM.new();oval_atrium.world=self;add_child(oval_atrium)
	metadata.spawns.append({"name":"椭圆中庭 · 屋顶入口","key":"oval_atrium","position":oval_atrium.manifest.entry_spawn,
		"look_direction":oval_atrium.manifest.look_direction,"required_floor_kind":"Structure",
		"required_source_id":oval_atrium.manifest.entry_source_id,"maximum_search_distance_m":1.,"character_only":true})
	metadata.spawns.append({"name":"椭圆中庭 · 底层出口","key":"oval_atrium_floor","position":oval_atrium.manifest.floor_spawn,
		"look_direction":[-.7,0.,-.7],"required_floor_kind":"Structure","required_source_id":oval_atrium.manifest.floor_source_id,
		"maximum_search_distance_m":1.,"character_only":true})

func _build_island_saddle() -> void:
	island_saddle=ISLAND_SADDLE.instantiate();add_child(island_saddle)
	metadata.spawns.append({"name":"岛顶曲面遗址 · 曲面通路","key":"island_saddle","position":island_saddle.manifest.spawn,
		"look_direction":island_saddle.manifest.look_direction,"required_floor_kind":"Structure",
		"required_source_id":island_saddle.manifest.walking_surface_id,"maximum_search_distance_m":1.,"character_only":true})

func _build_upper_ring() -> void:
	upper_ring=UPPER_RING.instantiate();upper_ring.world=self;add_child(upper_ring)
	var front: Array=upper_ring.manifest.front
	metadata.spawns.append({"name":"上层环庭 · 中庭入口","key":"upper_ring","position":upper_ring.manifest.spawn,"look_direction":[-front[0],0,-front[2]],"required_floor_kind":"Terrain","maximum_search_distance_m":6.})

func _build_initial_ruin() -> void:
	initial_ruin=INITIAL_RUIN.instantiate();initial_ruin.world=self;add_child(initial_ruin)
	var row: Dictionary=initial_ruin.planting_mask.manifest
	metadata.spawns.append({"name":"初始神殿 · NPC庭廊","key":"initial_ruin","position":row.spawn,"look_direction":row.forward,"required_floor_kind":"Structure","maximum_search_distance_m":2.,"character_only":true})

func _build_surface_detail_trial() -> void:
	surface_detail_trial=SURFACE_DETAIL_TRIAL.new();surface_detail_trial.name="ArchitectureDetailTrial";add_child(surface_detail_trial);surface_detail_trial.initialize(self)

func _water_review_view(which: int) -> void:
	if which==0:return
	if which==3:
		if not character_mode:await set_character_mode(true)
		free_mode=false;overview_mode=false
		var p:=Vector3(1070-1450,-.30,1150-470)
		var q:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*.35,p+Vector3.DOWN,ACTOR_SOLID_LAYER)
		var hit:=get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():character.set_spawn(hit.position+Vector3.UP*.04,PI)
		_sync_actor_controls()
	else:
		set_free(true)
		camera.position=Vector3(1127.777-1450,2.4,1150-155.555) if which==1 else Vector3(844.444-1450,2.2,1150-1038.888)
		camera.look_at(Vector3(1350-1450,40,1150-250) if which==1 else Vector3(900-1450,24,1150-850))
	water_manager.interaction.reset()

func _sync_meadow_color() -> void:
	MEADOW_PALETTE.apply_grass(vegetation.grass_material)
	# Match the accepted grass zones, including their actual noise resource.
	# Per-blade overlap/value remains fine variation; the ground uses their mean.
	for parameter: String in MEADOW_PALETTE.BIOME_PARAMETERS:
		terrain_material.set_shader_parameter(parameter,vegetation.grass_material.get_shader_parameter(parameter))
	# Absolute colours replace the old atlas-multiplier ratio. The distant
	# surface is calibrated from rendered grass, not copied from its albedo.
	MEADOW_PALETTE.apply_ground(terrain_material)
	terrain_material.set_shader_parameter("use_shared_meadow_biome",true)
	oval_atrium.sync_ground_palette()
	terrain_repairs.sync_shoulder_palette()
	cape_town.sync_ground_palette()

func _load_mask() -> void:
	var path:=ASSETS+"landscape_mask.res"
	if ResourceLoader.exists(path) and not "--rebuild-mask" in OS.get_cmdline_user_args():
		mask_texture=load(path);mask_image=mask_texture.get_image()
	else:
		var raw:=FileAccess.get_file_as_bytes("res://.current_map_build/landscape_mask.rg16f")
		var size:=int(metadata.resolution);assert(raw.size()==size*size*4)
		mask_image=Image.create_from_data(size,size,false,Image.FORMAT_RGH,raw)
		var image:=mask_image.duplicate();image.generate_mipmaps()
		mask_texture=ImageTexture.create_from_image(image)
		assert(ResourceSaver.save(mask_texture,path,ResourceSaver.FLAG_COMPRESS)==OK)
	terrain_material=ShaderMaterial.new()
	terrain_material.shader=load(ASSETS+"landscape.gdshader")
	terrain_material.set_shader_parameter("landscape_mask",mask_texture)
	terrain_material.set_shader_parameter("mask_origin_xz",Vector2(metadata.origin_xz[0],metadata.origin_xz[1]))
	terrain_material.set_shader_parameter("mask_extent_xz",Vector2(metadata.extent_xz[0],metadata.extent_xz[1]))

func architectural_band(p: Vector3,margin:=0.0) -> bool:
	if npc_waypoint_ruins.blocks_grass(p):return true
	if cape_town!=null:
		var town_band: int=cape_town.grass_band(p,margin)
		if town_band>=0:return town_band==1
	if church_ruins!=null and church_ruins.blocks_grass(p):return true
	if sunken_archive!=null and sunken_archive.blocks_grass(p):return true
	if earth_pavilion!=null and earth_pavilion.blocks_grass(p):return true
	if terrace_ruins!=null and terrace_ruins.blocks_grass(p):return true
	if oval_atrium!=null and oval_atrium.ground_contains(p):
		return not oval_atrium.ground_contains(p,maxf(margin,float(oval_atrium.ground_config.edge_inset_m)))
	if upper_ring!=null and upper_ring.planting_mask.blocks(p,margin):return true
	if initial_ruin!=null and initial_ruin.planting_mask.blocks(p,margin):return true
	if terrain_repairs!=null:
		var shoulder_band: int=terrain_repairs.road_shoulder_band(p,margin)
		if shoulder_band>=0:return shoulder_band==1
	var uv: Vector2=(Vector2(p.x,p.z)-Vector2(metadata.origin_xz[0],metadata.origin_xz[1]))/Vector2(metadata.extent_xz[0],metadata.extent_xz[1])
	if uv.x<0 or uv.y<0 or uv.x>=1 or uv.y>=1: return false
	var data:=mask_image.get_pixel(clampi(int(uv.x*mask_image.get_width()),0,mask_image.get_width()-1),clampi(int(uv.y*mask_image.get_height()),0,mask_image.get_height()-1))
	return data.r<margin and absf(p.y-data.g)<3.2

func _build_model() -> void:
	# Use the imported scene: its ArrayMeshes contain generated LODs and
	# shadow meshes. Runtime GLTFDocument parsing bypasses those import steps.
	var packed: PackedScene=load(ASSETS+"current_region.glb")
	assert(packed!=null)
	model=packed.instantiate();add_child(model)
	var architecture: Material=load("res://assets/world/cliff_b_test/architecture.tres")
	var road:=StandardMaterial3D.new();road.albedo_color=Color(0.13,0.145,0.15);road.roughness=0.93
	road.cull_mode=BaseMaterial3D.CULL_DISABLED
	var sand: Material=load("res://assets/environment/beach_sand/beach_sand.tres")
	var water:=ShaderMaterial.new();water.shader=load("res://assets/world/map_1012_test/water.gdshader")
	var byid: Dictionary={}
	for row: Dictionary in metadata.object_records:byid[row.id]=row
	for node in model.find_children("*","MeshInstance3D",true,false):
		var mesh:=node as MeshInstance3D;var id:=str(mesh.name).get_slice("_",1)
		# Remove both the old render mesh and its prospective collision before building the reviewed hosts.
		if id in OVAL_ATRIUM.REPLACED_IDS or id in EARTH_PAVILION.REPLACED_IDS or id in TERRAIN_REPAIRS.REPLACED_IDS or id in SUNKEN_ARCHIVE.REPLACED_IDS or id in ROAD_JUNCTION.REPLACED_IDS or id in BEACH_SLOPE.REPLACED_IDS:
			mesh.free();continue
		# Object semantics can change without rebuilding or moving mesh geometry.
		var row: Dictionary=byid.get(id,{})
		var kind: String=row.get("kind",str(mesh.name).get_slice("_",0))
		mesh.material_override={"Terrain":terrain_material,"Structure":architecture,"Road":road,"Sand":sand,"Water":water}.get(kind,architecture)
		if kind=="Water":mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not row.get("collision",true) and kind!="Water":continue
		var body:=StaticBody3D.new();body.collision_layer=4 if kind=="Water" else (9 if kind=="Road" else (17 if kind=="Terrain" else 1));body.collision_mask=0
		var marking: bool="标线" in str(row.get("name",""))
		if kind!="Water" and not marking:body.collision_layer|=ACTOR_SOLID_LAYER
		body.set_meta("nonblocking_road_marking",marking)
		body.set_meta("surface_kind",kind);body.set_meta("source_id",id)
		mesh.add_child(body)
		var shape:=mesh.mesh.create_trimesh_shape();shape.backface_collision=true
		var collider:=CollisionShape3D.new();collider.shape=shape;body.add_child(collider)
	var beach:=BEACH_SLOPE.new();beach.sand_material=sand;model.add_child(beach)
	print("CURRENT_MAP_COLLISION_READY")

func _environment() -> void:
	var sky:=Sky.new();sky.sky_material=SKY
	var env:=Environment.new();env.background_mode=Environment.BG_SKY;env.sky=sky
	# Rotate both the painted background and HDR environment toward the sun.
	env.sky_rotation.y=deg_to_rad(HDRI_BRIGHT_AZIMUTH_DEGREES-SUN_AZIMUTH_DEGREES)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_SKY;env.ambient_light_energy=0.38
	env.reflected_light_source=Environment.REFLECTION_SOURCE_SKY;env.tonemap_mode=Environment.TONE_MAPPER_ACES
	env.tonemap_exposure=0.82;env.ssao_radius=1.1;env.ssao_intensity=0.85
	var world:=WorldEnvironment.new();world.environment=env;add_child(world)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-48,180.0-SUN_AZIMUTH_DEGREES,0);sun.light_energy=0.72
	sun.light_color=Color(1.0,0.95,0.86);sun.shadow_enabled=true;sun.directional_shadow_max_distance=180;add_child(sun)
	graphics_environment = env
	var config := ConfigFile.new()
	if config.load(GRAPHICS_SETTINGS_PATH) == OK:
		var previous: Variant = config.get_value("graphics", "performance", false)
		var fallback := GraphicsQuality.MEDIUM if previous is bool and previous else GraphicsQuality.HIGH
		var saved: Variant = config.get_value("graphics", "preset", fallback)
		if saved is int and saved >= GraphicsQuality.HIGH and saved <= GraphicsQuality.LOWEST:
			graphics_quality = saved
	_apply_graphics_quality()

func _apply_graphics_quality() -> void:
	var viewport := get_viewport()
	var high := graphics_quality == GraphicsQuality.HIGH
	viewport.msaa_3d = Viewport.MSAA_4X if high else Viewport.MSAA_2X
	viewport.scaling_3d_scale = 1.0 if high else 0.90
	graphics_environment.ssao_enabled = high
	_apply_grass_quality()

func _apply_grass_quality() -> void:
	if vegetation == null:
		return
	var show_grass := graphics_quality != GraphicsQuality.LOWEST
	vegetation.volume_streamer.set_rendering_enabled(show_grass)
	if is_instance_valid(sunken_archive.courtyard_grass):
		sunken_archive.courtyard_grass.visible = show_grass

func _on_graphics_quality_selected(index: int) -> void:
	graphics_quality = index
	_apply_graphics_quality()
	var config := ConfigFile.new()
	config.set_value("graphics", "preset", graphics_quality)
	var error := config.save(GRAPHICS_SETTINGS_PATH)
	if error != OK:
		push_warning("Could not save graphics quality: " + error_string(error))

func _noise() -> NoiseTexture2D:
	var result:=NoiseTexture2D.new();result.width=512;result.height=512;result.seamless=true
	result.generate_mipmaps=true
	var noise:=FastNoiseLite.new();noise.seed=46129;noise.frequency=0.012;noise.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH;noise.fractal_octaves=4
	result.noise=noise;return result

func _hud() -> void:
	var layer:=CanvasLayer.new();add_child(layer)
	review_ui_layers.append(layer)
	var panel:=PanelContainer.new();panel.name="MapControls";panel.position=Vector2(20,18);layer.add_child(panel)
	var style:=StyleBoxFlat.new();style.bg_color=Color(.055,.09,.11,.88)
	style.content_margin_left=12;style.content_margin_right=12;style.content_margin_top=12;style.content_margin_bottom=12
	for corner in ["top_left","top_right","bottom_left","bottom_right"]:style.set("corner_radius_"+corner,6)
	panel.add_theme_stylebox_override("panel",style)
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",8);panel.add_child(box)
	var title:=Label.new();title.text="Prism Route · 场景预览";title.add_theme_font_size_override("font_size",20);box.add_child(title)
	spawn_menu=OptionButton.new();spawn_menu.custom_minimum_size=Vector2(310,36)
	for i in metadata.spawns.size():spawn_menu.add_item("%d  %s" % [i+1,metadata.spawns[i].name])
	spawn_menu.item_selected.connect(select_spawn);box.add_child(spawn_menu)
	status=Label.new();status.add_theme_font_size_override("font_size",14);status.add_theme_color_override("font_color",Color("c2d0d9"));box.add_child(status)
	if npc_placement_preview != null:
		npc_placement_preview.add_controls(box)
	var edit_button:=Button.new();edit_button.text="植物编辑 · F4";box.add_child(edit_button)
	edit_button.pressed.connect(func():if planting!=null and test_ready:planting.toggle())
	var build_button:=Button.new();build_button.text="建筑构件 · F7";box.add_child(build_button);build_button.pressed.connect(construction.toggle)
	world_audio=WORLD_AUDIO.new();world_audio.name="WorldAudio";add_child(world_audio);world_audio.add_controls(box)
	graphics_menu = OptionButton.new()
	graphics_menu.name = "GraphicsQuality"
	graphics_menu.add_item("画质 · 高画质")
	graphics_menu.add_item("画质 · 中画质")
	graphics_menu.add_item("画质 · 最低画质")
	graphics_menu.select(graphics_quality)
	graphics_menu.item_selected.connect(_on_graphics_quality_selected)
	box.add_child(graphics_menu)
	for control in box.get_children():
		if control is BaseButton:control.custom_minimum_size.y=36;control.focus_mode=Control.FOCUS_NONE
	var performance_monitor:=PERFORMANCE_MONITOR.new()
	performance_monitor.world_scene=self;add_child(performance_monitor)
	review_ui_layers.append(performance_monitor)
	set_review_ui_visible(not "--no-ui" in OS.get_cmdline_user_args())

func set_review_ui_visible(enabled: bool) -> void:
	review_ui_visible=enabled
	for layer in review_ui_layers:layer.visible=enabled and not encounter_ui_active
	if not enabled or encounter_ui_active:
		get_viewport().gui_release_focus()
		if is_instance_valid(graphics_menu):graphics_menu.get_popup().hide()
		if npc_placement_preview != null:
			npc_placement_preview.close_menu()
		if world_audio!=null:world_audio.hide_settings()

func set_encounter_ui_active(active: bool) -> void:
	if encounter_ui_active==active:return
	encounter_ui_active=active
	set_review_ui_visible(review_ui_visible)
	if is_instance_valid(character.switch_wheel):character.switch_wheel.visible=not active

func _input(event: InputEvent) -> void:
	# Handle globally so H also works while the spawn menu has keyboard focus.
	if encounter_ui_active or (construction!=null and construction.active):return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if key==KEY_F4 and not event.alt_pressed and not event.ctrl_pressed and planting!=null and test_ready:
			planting.toggle();get_viewport().set_input_as_handled();return
		if planting!=null and planting.active and event.ctrl_pressed and key==KEY_S:
			planting.save_test();get_viewport().set_input_as_handled();return
		if planting!=null and planting.active:return
		if key==KEY_H:
			set_review_ui_visible(not review_ui_visible)
			get_viewport().set_input_as_handled()

func _ray(p: Vector3,highest:=false) -> Dictionary:
	var top:=400.0 if highest else p.y+2.2
	var bottom:=-20.0 if highest else p.y-4.0
	var q:=PhysicsRayQueryParameters3D.create(Vector3(p.x,top,p.z),Vector3(p.x,bottom,p.z),ACTOR_SOLID_LAYER)
	q.hit_back_faces=true
	return get_world_3d().direct_space_state.intersect_ray(q)

func resolve_spawn(proposal: Dictionary) -> Dictionary:
	var base:=vec(proposal.position);var offsets: Array[Vector2]=[]
	for x in range(-10,11):
		for z in range(-10,11):offsets.append(Vector2(x*4,z*4))
	offsets.sort_custom(func(a:Vector2,b:Vector2):return a.length_squared()<b.length_squared())
	for offset in offsets:
		if offset.length()>float(proposal.get("maximum_search_distance_m",INF)):continue
		var hit:=_ray(base+Vector3(offset.x,0,offset.y),proposal.get("highest",false))
		if hit.is_empty() or (hit.normal as Vector3).y<0.72:continue
		if proposal.has("required_floor_kind") and hit.collider.get_meta("surface_kind", "")!=proposal.required_floor_kind:continue
		# Coincident host/landing faces can exchange hit order when unrelated
		# bodies are added. Resolve the requested source only at the SAME height.
		if proposal.has("required_source_id") and hit.collider.get_meta("source_id", "")!=proposal.required_source_id:
			var probe:=PhysicsRayQueryParameters3D.create(hit.position+Vector3.UP*.02,hit.position-Vector3.UP*.02,ACTOR_SOLID_LAYER)
			probe.hit_back_faces=true
			var excluded: Array[RID]=[]
			for attempt in range(8):
				excluded.append(hit.collider.get_rid());probe.exclude=excluded
				var candidate:=get_world_3d().direct_space_state.intersect_ray(probe)
				if candidate.is_empty():break
				hit=candidate
				if hit.collider.get_meta("source_id", "")==proposal.required_source_id:break
		if proposal.has("required_source_id") and hit.collider.get_meta("source_id", "")!=proposal.required_source_id:continue
		if (hit.normal as Vector3).y<.72:continue
		var floor_point: Vector3=hit.position
		var clearance: float=proposal.get("minimum_edge_clearance_m",0.0)
		var supported:=true
		if clearance>0:
			for delta in [Vector3(clearance,0,0),Vector3(-clearance,0,0),Vector3(0,0,clearance),Vector3(0,0,-clearance)]:
				var edge:=_ray(floor_point+delta)
				if edge.is_empty() or absf(edge.position.y-floor_point.y)>.25 or edge.collider.get_meta("surface_kind", "")!=proposal.required_floor_kind:supported=false;break
		if not supported:continue
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=character.get_node("CollisionShape3D").shape
		query.transform=Transform3D(Basis.IDENTITY,floor_point+Vector3(0,0.88,0));query.collision_mask=ACTOR_SOLID_LAYER
		query.exclude=[character.get_rid()]
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():continue
		var result:=proposal.duplicate();result["floor_position"]=floor_point;result["floor_source"]=hit.collider.get_meta("source_id","")
		return result
	push_error("Cannot resolve spawn: "+str(proposal.name));return {}

func select_spawn(index: int) -> void:
	if resolved_spawns.size()<=index or resolved_spawns[index].is_empty():return
	spawn_index=index;free_mode=false;overview_mode=false
	var row: Dictionary=resolved_spawns[index];var direction:=vec(row.look_direction)
	var heading:=atan2(-direction.x,-direction.z)
	if character_mode:character.set_spawn((row.floor_position as Vector3)+Vector3.UP*0.10,heading)
	else:
		var floor_point:=_find_actor_floor(row.floor_position,heading,false)
		if floor_point.is_empty():character_mode=true;character.set_spawn((row.floor_position as Vector3)+Vector3.UP*.1,heading)
		else:_spawn_camper(floor_point.position,heading)
	_sync_actor_controls()
	spawn_menu.select(index);status.text="%s · %.1f m" % [row.name,(row.floor_position as Vector3).y]
	await get_tree().physics_frame

func set_free(enabled: bool) -> void:
	if enabled:camera.global_transform=active_camera().global_transform
	free_mode=enabled;overview_mode=false;_sync_actor_controls()

func active_actor() -> CharacterBody3D:
	return character if character_mode else camper

func active_camera() -> Camera3D:
	return character.camera if character_mode else chase_camera

func _sync_actor_controls() -> void:
	character.visible=character_mode
	character.process_mode=Node.PROCESS_MODE_INHERIT if character_mode and not (planting!=null and planting.active) else Node.PROCESS_MODE_DISABLED
	character.set_control_enabled(character_mode and not free_mode)
	camper.visible=not character_mode
	camper.set_physics_process(not character_mode and not free_mode)
	camper.set_process_unhandled_input(not character_mode and not free_mode)
	if free_mode:camera.make_current()
	else:active_camera().make_current()
	if vegetation!=null:
		vegetation.target=camera if free_mode else active_actor()
		vegetation.set_grass_actor(active_actor(),not character_mode)

func _spawn_camper(point: Vector3,heading: float) -> void:
	camper.restore_pose(Transform3D(Basis(Vector3.UP,heading),point+Vector3.UP*.12))
	camper.set_respawn_transform(camper.global_transform)
	camper.camera_pivot.rotation=Vector3(-.20,0,0)

func _resolve_camper_respawn(checkpoint: Transform3D) -> Variant:
	# Use the saved storey, not the height of a vehicle launched by penetration.
	var heading:=checkpoint.basis.get_euler().y
	var floor_point:=_find_actor_floor(checkpoint.origin,heading,false)
	if not floor_point.is_empty():
		return Transform3D(Basis(Vector3.UP,heading),floor_point.position+Vector3.UP*.12)
	# A stale/blocked checkpoint falls back to a validated spawn on this storey.
	var row: Dictionary=resolved_spawns[spawn_index]
	var direction:=vec(row.look_direction)
	heading=atan2(-direction.x,-direction.z)
	floor_point=_find_actor_floor(row.floor_position,heading,false)
	if not floor_point.is_empty():
		return Transform3D(Basis(Vector3.UP,heading),floor_point.position+Vector3.UP*.12)
	status.text="此处没有可安全放置房车的路面，请切换出生点"
	return null

func _find_actor_floor(base: Vector3,heading: float,use_character: bool) -> Dictionary:
	var offsets: Array[Vector2]=[]
	for x in range(-6,7):
		for z in range(-6,7):offsets.append(Vector2(x*2,z*2))
	offsets.sort_custom(func(a:Vector2,b:Vector2):return a.length_squared()<b.length_squared())
	var actor=character if use_character else camper
	var collider: CollisionShape3D=actor.get_node("CollisionShape3D")
	var basis:=Basis(Vector3.UP,heading)
	for offset in offsets:
		var hit:=_ray(base+Vector3(offset.x,0,offset.y))
		if hit.is_empty() or (hit.normal as Vector3).y<.72 or absf(hit.position.y-base.y)>1.3:continue
		var p: Vector3=hit.position
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=collider.shape
		query.transform=Transform3D(basis,p+Vector3.UP*.10)*collider.transform;query.collision_mask=ACTOR_SOLID_LAYER
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():continue
		var supported:=true
		if not use_character:
			for foot in [Vector3(-1.0,0,-2.6),Vector3(1.0,0,-2.6),Vector3(-1.0,0,2.6),Vector3(1.0,0,2.6)]:
				var ground:=_ray(p+basis*foot)
				if ground.is_empty() or absf(ground.position.y-p.y)>.65:supported=false;break
		if supported:return hit
	return {}

func set_character_mode(enabled: bool) -> void:
	if switching_actor or enabled==character_mode:return
	switching_actor=true
	var point:=active_actor().global_position
	var heading: float=camper.rotation.y if enabled else character.visual.rotation.y-PI
	character.set_control_enabled(false);camper.set_physics_process(false)
	camper.drive_speed=0;camper.velocity=Vector3.ZERO
	await get_tree().physics_frame
	var floor_point:=_find_actor_floor(point,heading,enabled)
	if floor_point.is_empty():
		status.text="附近空间不足，先移动到开阔路面再按 C";switching_actor=false;_sync_actor_controls();return
	character_mode=enabled;free_mode=false;overview_mode=false
	if enabled:character.set_spawn(floor_point.position+Vector3.UP*.1,heading)
	else:_spawn_camper(floor_point.position,heading)
	switching_actor=false;_sync_actor_controls()

func show_overview() -> void:
	free_mode=true;overview_mode=true;_sync_actor_controls()
	camera.position=Vector3(-160,1800,2100);camera.look_at(Vector3(-250,15,400));camera.make_current()

func is_world_input_allowed() -> bool:
	if construction!=null and construction.active:return false
	if WORLD_CONTROL.is_world_input_blocked(get_tree()):
		return false
	if planting != null and planting.active:
		return false
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not is_world_input_allowed():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if key>=KEY_1 and key<=KEY_9:select_spawn(key-KEY_1)
		elif key==KEY_F:set_free(not free_mode)
		elif key==KEY_V:show_overview()
		elif key==KEY_C:set_character_mode(not character_mode)
		elif key==KEY_B and vegetation!=null:vegetation.set_vegetation_enabled(not vegetation.vegetation_enabled)
		elif key==KEY_F6 and vegetation!=null:
			vegetation.volume_streamer.collect_detailed_timings=not vegetation.volume_streamer.collect_detailed_timings
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:dragging=event.pressed
	if event is InputEventMouseMotion and free_mode and dragging:
		camera.rotation.y-=event.relative.x*.003;camera.rotation.x=clampf(camera.rotation.x-event.relative.y*.003,-1.5,1.5)

func _process(delta: float) -> void:
	if construction!=null and construction.active:return
	if planting!=null and planting.active:return
	if not free_mode or automation_enabled:return
	var direction:=Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_E))-float(Input.is_physical_key_pressed(KEY_Q)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	camera.position+=camera.global_basis*direction*delta*(180 if Input.is_physical_key_pressed(KEY_SHIFT)else 50)
