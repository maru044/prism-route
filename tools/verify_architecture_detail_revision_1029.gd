extends SceneTree
const OUT="res://docs/architecture_detail_revision_1029/"
const SHADER_PATH="res://shaders/environment/architecture_details_1029.gdshader"
const OLD_PATH="res://.current_map_build/architecture_detail_revision_before/shaders/environment/architecture_details_1029.gdshader"
var viewport: SubViewport
var wall: MeshInstance3D
var material: ShaderMaterial
var current_shader: Shader
var previous_shader: Shader

func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await process_frame
func capture(name: String) -> void:
	await frames(5);await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png(OUT+name+".png")==OK)
func make_shader(path: String) -> Shader:
	var shader:=Shader.new()
	# Controlled unlit test of the production shader's actual fragment functions.
	shader.code=FileAccess.get_file_as_string(path).replace("render_mode diffuse_burley, cull_back;","render_mode unshaded, cull_back;")
	return shader
func set_material(shader: Shader) -> void:
	material=ShaderMaterial.new();material.shader=shader
	var source: ShaderMaterial=load("res://assets/world/cliff_b_test/architecture.tres")
	for parameter: String in ["base_texture","micro_normal","roughness_texture"]:material.set_shader_parameter(parameter,source.get_shader_parameter(parameter))
	material.set_shader_parameter("warm_white",Color(.8,.8,.8));material.set_shader_parameter("detail_strength",0.)
	material.set_shader_parameter("seam_mask",load("res://assets/world/architecture_details_1029/seam_wear_mask_v1.png"))
	material.set_shader_parameter("foliage_atlas",load("res://assets/world/architecture_details_1029/foliage_leaf_mask_v2.png"))
	material.set_shader_parameter("plant_color",Color("66bb6a"));material.set_shader_parameter("plant_seed",17.)
	material.set_shader_parameter("panel_meters",Vector2(32,18));material.set_shader_parameter("joint_width",.018)
	material.set_shader_parameter("plant_cluster_meters",Vector2(7,7));material.set_shader_parameter("plant_draw_distance",300.)
	material.set_shader_parameter("mapping_right",Vector3(cos(.037),sin(.037),0.));material.set_shader_parameter("mapping_up",Vector3(-sin(.037),cos(.037),0.))
	material.set_shader_parameter("procedural_plants",true);wall.material_override=material
func run() -> void:
	Engine.max_fps=60;DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	viewport=SubViewport.new();viewport.size=Vector2i(1536,864);viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color(.8,.8,.8)
	var env:=WorldEnvironment.new();env.environment=environment;viewport.add_child(env)
	wall=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(96,54);wall.mesh=quad;wall.position.y=27.;viewport.add_child(wall)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=54.;camera.position=Vector3(0,27,70);viewport.add_child(camera);camera.make_current()
	current_shader=make_shader(SHADER_PATH);previous_shader=make_shader(OLD_PATH)
	set_material(previous_shader);material.set_shader_parameter("plants_enabled",false);await capture("seams_old_bug")
	set_material(current_shader);material.set_shader_parameter("plants_enabled",false);await capture("seams_fixed")
	material.set_shader_parameter("panel_meters",Vector2(8,4.5));await capture("seams_fixed_small")
	set_material(previous_shader);material.set_shader_parameter("joints_enabled",false);material.set_shader_parameter("plant_tile_meters",Vector2(14,12));material.set_shader_parameter("plant_density",.55);await capture("plants_old")
	set_material(current_shader);material.set_shader_parameter("joints_enabled",false);material.set_shader_parameter("plant_tile_meters",Vector2(9,9));material.set_shader_parameter("plant_density",.9);await capture("plants_new")
	material.set_shader_parameter("plant_seed",18.);await capture("plants_seed_18")
	material.set_shader_parameter("plant_seed",17.);await capture("plants_seed_17_again")
	material.set_shader_parameter("plant_density",0.);await capture("plants_density_zero")
	material.set_shader_parameter("plant_density",.9)
	material.set_shader_parameter("plant_loose_leaves",0.);await capture("plants_without_loose_blades")
	material.set_shader_parameter("plant_loose_leaves",1.);material.set_shader_parameter("plant_overlap",0.);await capture("plants_without_overlap")
	material.set_shader_parameter("plant_overlap",.65);material.set_shader_parameter("plant_tile_meters",Vector2(8.5,9.5));material.set_shader_parameter("plant_cluster_meters",Vector2(7,3));await capture("plants_aspect_a")
	material.set_shader_parameter("plant_cluster_meters",Vector2(3,7));await capture("plants_aspect_b")
	print("ARCHITECTURE_DETAIL_REVISION_GPU_CAPTURE_COMPLETE")
	quit()
