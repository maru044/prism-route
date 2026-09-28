extends Node3D

const SKY_TEXTURE := preload("res://assets/environment/hdri/rosendal_park_sunset_puresky_4k.exr")

@onready var camera: Camera3D = $Camera3D
@onready var vegetation = $VegetationLodStreamer
@onready var status_label: Label = $HUD/Status

var capture_name := ""
var automatic_mesh_lod_enabled := true
var transition_sweep_active := false
var transition_sweep_elapsed := 0.0
const TRANSITION_SWEEP_DURATION := 6.0


func _ready() -> void:
	_build_environment()
	var biome_noise := _create_biome_noise_texture()
	vegetation.initialize(camera, biome_noise, 2, true)

	var arguments := OS.get_cmdline_user_args()
	if "--disable-auto-mesh-lod" in arguments:
		_set_automatic_mesh_lod(false)
	if "--run-tree-lod-sweep" in arguments:
		transition_sweep_active = true
		camera.fov = 30.0
		camera.set_process(false)
		_configure_camera(70.0, 8.0, 0.0)
	elif "--capture-tree-lod-lod0-detail" in arguments:
		camera.fov = 22.0
		_configure_camera(70.0, 7.0, 0.0)
		capture_name = "tree_lod_transition_lod0_detail.png"
	elif "--capture-tree-lod-near-detail" in arguments:
		camera.fov = 15.4
		_configure_camera(100.0, 7.0, 0.0)
		capture_name = "tree_lod_transition_overlap_detail.png"
	elif "--capture-tree-lod-lod1-detail" in arguments:
		camera.fov = 11.85
		_configure_camera(130.0, 8.0, 0.0)
		capture_name = "tree_lod_transition_lod1_detail.png"
	elif "--capture-tree-lod2-lod1-detail" in arguments:
		camera.fov = 10.0
		_configure_camera(260.0, 13.0, 0.0)
		capture_name = "tree_lod2_lod1_detail.png"
	elif "--capture-tree-lod2-overlap-detail" in arguments:
		camera.fov = 8.52
		_configure_camera(305.0, 15.0, 0.0)
		capture_name = "tree_lod2_overlap_detail.png"
	elif "--capture-tree-lod2-only-detail" in arguments:
		camera.fov = 7.02
		_configure_camera(370.0, 17.0, 0.0)
		capture_name = "tree_lod2_only_detail.png"
	elif "--capture-tree-lod2-before-frame-boundary" in arguments:
		camera.fov = 7.02
		_configure_camera(370.0, 17.0, deg_to_rad(21.5))
		capture_name = "tree_lod2_frame_boundary_21_5deg.png"
	elif "--capture-tree-lod2-after-frame-boundary" in arguments:
		camera.fov = 7.02
		_configure_camera(370.0, 17.0, deg_to_rad(23.5))
		capture_name = "tree_lod2_frame_boundary_23_5deg.png"
	elif "--capture-tree-lod-near" in arguments:
		_configure_camera(100.0, 7.0, 0.0)
		capture_name = (
			"tree_lod_transition_near_clumped_lod1.png"
			if automatic_mesh_lod_enabled
			else "tree_lod_transition_near_clumped_lod1_mesh_lod_off.png"
		)
	elif "--capture-tree-lod-near-orbit" in arguments:
		_configure_camera(100.0, 9.0, deg_to_rad(42.0))
		capture_name = "tree_lod_transition_near_clumped_lod1_orbit.png"
	elif "--capture-tree-lod-far" in arguments:
		_configure_camera(305.0, 18.0, 0.0)
		capture_name = (
			"tree_lod_transition_far_dither.png"
			if automatic_mesh_lod_enabled
			else "tree_lod_transition_far_dither_mesh_lod_off.png"
		)
	elif "--capture-tree-lod-orbit" in arguments:
		_configure_camera(305.0, 18.0, deg_to_rad(22.5))
		capture_name = "tree_lod_transition_orbit_dither.png"

	if not capture_name.is_empty():
		camera.set_process(false)
		await get_tree().create_timer(3.0).timeout
		_capture_frame(capture_name)


func _process(delta: float) -> void:
	if transition_sweep_active:
		transition_sweep_elapsed += delta
		var progress := clampf(
			transition_sweep_elapsed / TRANSITION_SWEEP_DURATION, 0.0, 1.0
		)
		_configure_camera(lerpf(70.0, 140.0, progress), 8.0, 0.0)
		if progress >= 1.0:
			print(
				"TREE_LOD_SWEEP_COMPLETE fps=%d draws=%d primitives=%d"
				% [
					Engine.get_frames_per_second(),
					int(Performance.get_monitor(
						Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME
					)),
					int(Performance.get_monitor(
						Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME
					)),
				]
			)
			get_tree().quit()
			return
	var distance := camera.global_position.distance_to(Vector3(0.0, 6.0, 0.0))
	var small_lod0 := 1.0 - smoothstep(90.0, 120.0, distance)
	var small_lod1 := smoothstep(90.0, 120.0, distance) * (
		1.0 - smoothstep(280.0, 330.0, distance)
	)
	var small_lod2 := smoothstep(280.0, 330.0, distance)
	var large_lod0 := 1.0 - smoothstep(80.0, 110.0, distance)
	var large_lod1 := smoothstep(80.0, 110.0, distance) * (
		1.0 - smoothstep(280.0, 330.0, distance)
	)
	var large_lod2 := smoothstep(280.0, 330.0, distance)
	status_label.text = (
		"Camera distance: %.1f m    Automatic Mesh LOD: %s\n"
		+ "Small coverage  LOD0 %.2f  LOD1 %.2f  LOD2 %.2f\n"
		+ "Large coverage  LOD0 %.2f  LOD1 %.2f  LOD2 %.2f"
	) % [
		distance,
		"ON" if automatic_mesh_lod_enabled else "OFF",
		small_lod0, small_lod1, small_lod2,
		large_lod0, large_lod1, large_lod2,
	]


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1:
			_configure_camera(70.0, 7.0, 0.0)
		KEY_2:
			_configure_camera(100.0, 7.0, 0.0)
		KEY_3:
			_configure_camera(305.0, 18.0, 0.0)
		KEY_4:
			_configure_camera(370.0, 20.0, 0.0)
		KEY_M:
			_set_automatic_mesh_lod(not automatic_mesh_lod_enabled)


func _configure_camera(distance: float, height: float, azimuth: float) -> void:
	var target := Vector3(0.0, 6.0, 0.0)
	var horizontal_offset := Vector3(sin(azimuth), 0.0, cos(azimuth)) * distance
	camera.global_position = target + horizontal_offset + Vector3.UP * (height - 6.0)
	camera.look_at(target, Vector3.UP)


func _set_automatic_mesh_lod(enabled: bool) -> void:
	automatic_mesh_lod_enabled = enabled
	# Zero forces the source mesh and is the runtime equivalent of the editor's
	# Debug Draw > Disable Mesh LOD diagnostic.  One restores Godot's default
	# screen-space threshold without touching import settings.
	get_viewport().mesh_lod_threshold = 1.0 if enabled else 0.0


func _build_environment() -> void:
	var panorama_material := PanoramaSkyMaterial.new()
	panorama_material.panorama = SKY_TEXTURE
	panorama_material.energy_multiplier = 0.48
	var sky := Sky.new()
	sky.sky_material = panorama_material
	sky.radiance_size = Sky.RADIANCE_SIZE_1024
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.sky_rotation = Vector3(0.0, deg_to_rad(70.0), 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.38
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.82
	environment.ssao_enabled = true
	environment.ssao_radius = 1.25
	environment.ssao_intensity = 1.20
	environment.ssao_power = 1.30
	$WorldEnvironment.environment = environment
	$Sun.rotation_degrees = Vector3(-43.0, -128.0, 0.0)
	$Sun.light_color = Color("ffe2b8")
	$Sun.light_energy = 0.72
	$Sun.shadow_enabled = true


func _create_biome_noise_texture() -> NoiseTexture2D:
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.normalize = true
	var noise := FastNoiseLite.new()
	noise.seed = 46129
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.48
	texture.noise = noise
	return texture


func _capture_frame(filename: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var output_path := "res://screenshots/%s" % filename
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Failed to save %s: %s" % [output_path, error_string(error)])
	else:
		print("Saved ", ProjectSettings.globalize_path(output_path))
	print(
		"TREE_LOD_TRANSITION_METRICS fps=%d draws=%d primitives=%d distance=%.1f"
		% [
			Engine.get_frames_per_second(),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
			camera.global_position.distance_to(Vector3(0.0, 6.0, 0.0)),
		]
	)
	get_tree().quit()
