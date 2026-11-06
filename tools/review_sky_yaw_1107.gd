extends SceneTree
## Review panorama yaw at the unmodified default spawn and character camera.
const OUT="res://docs/acg_sky_1107/"
var world
func _initialize() -> void:call_deferred("run")
func settle(seconds: float) -> void:
	var start:=Time.get_ticks_msec()
	while Time.get_ticks_msec()-start<seconds*1000.:await process_frame
func run() -> void:
	create_timer(150).timeout.connect(func():push_error("Sky yaw review timeout");quit(1))
	AudioServer.set_bus_mute(0,true)
	world=load("res://scenes/main.tscn").instantiate();world.automation_enabled=true;root.add_child(world)
	while not world.test_ready:await process_frame
	for layer: CanvasLayer in world.review_ui_layers:layer.visible=false
	world.character.set_control_enabled(false)
	# The default camera is inside the cave. Review the same heading from its
	# outdoor platform so architecture and sky match the user's entrance view.
	world.set_free(true)
	var forward: Vector3=-world.camera.global_basis.z;forward.y=0.;forward=forward.normalized()
	world.camera.global_position+=forward*26.
	var node: WorldEnvironment=world.find_children("*","WorldEnvironment",true,false)[0]
	var environment:=node.environment
	var material:=environment.sky.sky_material as ShaderMaterial
	var accepted: float=material.get_shader_parameter("display_yaw")
	assert(is_equal_approx(world.water_manager.sky_yaw,environment.sky_rotation.y-accepted))
	for row: Dictionary in world.water_manager.bodies:
		assert(is_equal_approx(float(row.material.get_shader_parameter("sky_yaw")),world.water_manager.sky_yaw))
	var report: Dictionary={"entry":"scenes/main.tscn","spawn":world.resolved_spawns[world.spawn_index].key,
		"accepted_display_yaw_degrees":rad_to_deg(accepted),"initial_water_yaw_degrees":rad_to_deg(world.water_manager.sky_yaw),"water_yaw_matches_display":true,
		"camera_transform":str(world.camera.global_transform),"camera_exterior_offset_m":26.,"variants":[]}
	var angles: Array=[0.,45.,90.,120.]
	if "--selected-only" in OS.get_cmdline_user_args():angles=[rad_to_deg(accepted)]
	for degrees in angles:
		var yaw:=deg_to_rad(degrees)
		material.set_shader_parameter("display_yaw",yaw)
		world.water_manager.sky_yaw=environment.sky_rotation.y-yaw
		for row: Dictionary in world.water_manager.bodies:
			row.material.set_shader_parameter("sky_yaw",world.water_manager.sky_yaw)
		await settle(1.5);await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"initial_yaw_"+str(int(degrees))+".png")
		report.variants.append({"display_yaw_degrees":degrees,"water_yaw_degrees":rad_to_deg(world.water_manager.sky_yaw)})
	material.set_shader_parameter("display_yaw",accepted)
	FileAccess.open(OUT+"yaw_review.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("SKY_YAW_REVIEW_DONE ",JSON.stringify(report));quit()
