extends SceneTree
## Same-world texture comparison with unchanged HDRI radiance and exposure.
const OUT="res://docs/acg_sky_1107/"
var world
var sky_material: ShaderMaterial
func _initialize() -> void:call_deferred("run")
func settle(seconds: float) -> void:
	var start:=Time.get_ticks_msec()
	while Time.get_ticks_msec()-start<seconds*1000.:await process_frame
func use_panorama(texture: Texture2D) -> void:
	sky_material.set_shader_parameter("display_panorama",texture)
	for row: Dictionary in world.water_manager.bodies:
		row.material.set_shader_parameter("sky_panorama",texture)
func capture(label: String) -> void:
	await settle(1.2);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")
	print("ACG_SKY_CAPTURE ",label)
func run() -> void:
	create_timer(150).timeout.connect(func():push_error("Sky review timeout");quit(1))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	AudioServer.set_bus_mute(0,true)
	world=load("res://scenes/main.tscn").instantiate();world.automation_enabled=true;root.add_child(world)
	while not world.test_ready:await process_frame
	world.set_free(true)
	for layer: CanvasLayer in world.review_ui_layers:layer.visible=false
	var environment_node: WorldEnvironment=world.find_children("*","WorldEnvironment",true,false)[0]
	sky_material=environment_node.environment.sky.sky_material
	var old: Texture2D=load("res://assets/environment/sky/fresh_cumulus_panorama_v2.png")
	var previous_acg: Texture2D=load("res://assets/environment/sky/acg_summer_panorama_v2.png")
	var current: Texture2D=sky_material.get_shader_parameter("display_panorama")
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/beach_slope_1107/manifest.json"))
	var a: Array=manifest.report.profiles[3].xyz[0];var b: Array=manifest.report.profiles[3].xyz[-1]
	var p:=Vector3(float(a[0])-1450.,0.,1150.-float(a[1]))
	var direction:=(Vector3(float(b[0])-1450.,0.,1150.-float(b[1]))-p).normalized()
	world.character.set_spawn(p-direction*6.+Vector3.UP*.08,atan2(-direction.x,-direction.z))
	world.camera.global_position=p-direction*9.+Vector3.UP*2.2
	world.camera.look_at(p+direction*36.+Vector3.UP*.15)
	use_panorama(old);await capture("before_shore")
	use_panorama(current);await capture("after_shore")
	world.camera.look_at(world.camera.global_position+direction*10.+Vector3.UP*4.5)
	await capture("after_sky_up")
	var yaw:=environment_node.environment.sky_rotation.y
	var display_yaw: float=sky_material.get_shader_parameter("display_yaw")
	# Godot SKY_COORDS places u=.5 at local north. Include the display-only
	# yaw when aiming at the main cloud and panorama seam.
	var main_azimuth:=TAU*(.32-.5)+yaw-display_yaw
	var main_direction:=Vector3(sin(main_azimuth),.28,-cos(main_azimuth)).normalized()
	world.camera.look_at(world.camera.global_position+main_direction*10.)
	use_panorama(previous_acg);await capture("v2_same_yaw_main_cloud")
	use_panorama(current)
	await capture("after_main_cloud")
	for offset in [-.015,.015]:
		var seam_azimuth: float=yaw-display_yaw-PI+float(offset)
		world.camera.look_at(world.camera.global_position+Vector3(sin(seam_azimuth),.4,-cos(seam_azimuth))*10.)
		await capture("seam_left" if offset<0 else "seam_right")
	world.camera.look_at(world.camera.global_position+Vector3.UP*10.,Vector3.FORWARD)
	await capture("zenith")
	var report: Dictionary={"entry":"scenes/main.tscn","native_resolution":[current.get_width(),current.get_height()],
		"display_yaw_degrees":rad_to_deg(display_yaw),"main_cloud_approx_azimuth_from_north_degrees":fposmod(rad_to_deg(main_azimuth),360.),
		"display_asset":current.resource_path,"lighting_asset":sky_material.get_shader_parameter("lighting_panorama").resource_path,
		"lighting_energy":sky_material.get_shader_parameter("lighting_energy"),"exposure":environment_node.environment.tonemap_exposure,
		"water_bodies":world.water_manager.bodies.size(),"note":"Texture A/B shares HDRI lighting, exposure, and narrow pole guard."}
	FileAccess.open(OUT+"review.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("ACG_SKY_REVIEW_DONE");quit()
