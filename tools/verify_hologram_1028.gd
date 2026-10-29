extends SceneTree
const LAB=preload("res://scenes/character_hologram_test.tscn")
const EFFECT=preload("res://scripts/characters/hologram_effect.gd")
const OUT="res://docs/hologram_1028/"
var lab
var failures: Array[String]=[]
var report: Dictionary={}

func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func frames(n: int) -> void:
	for i in n:await process_frame

func material_state(m: Material) -> String:
	if m==null:return "null"
	var state: Array=[m.get_instance_id(),m.next_pass,m.render_priority]
	if m is StandardMaterial3D:state.append_array([m.albedo_texture,m.albedo_color,m.transparency,m.alpha_scissor_threshold,m.cull_mode,m.uv1_scale,m.uv1_offset])
	elif m is ShaderMaterial:
		state.append(m.shader)
		for uniform: Dictionary in m.shader.get_shader_uniform_list():state.append(m.get_shader_parameter(uniform.name))
	return str(state)

func baseline() -> Array:
	var rows: Array=[]
	for mesh: MeshInstance3D in lab.character.find_children("*","MeshInstance3D",true,false):
		for i in mesh.mesh.get_surface_count():rows.append({"mesh":mesh,"index":i,"source":mesh.mesh.surface_get_material(i),"state":material_state(mesh.mesh.surface_get_material(i)),"override":mesh.get_surface_override_material(i),"active":mesh.get_active_material(i),"shadow":mesh.cast_shadow,"visible":mesh.visible})
	return rows

func check_original(rows: Array) -> void:
	for r: Dictionary in rows:
		check(r.mesh.mesh.surface_get_material(r.index)==r.source and material_state(r.source)==r.state,"Imported source material changed")
		check(r.mesh.get_surface_override_material(r.index)==r.override and r.mesh.get_active_material(r.index)==r.active,"Source override was not restored exactly")
		check(r.mesh.cast_shadow==r.shadow,"Original shadow mode lost")
		check(r.mesh.visible==r.visible,"Original mesh visibility lost")

func logic_checks() -> void:
	var rows: Array=[]
	for i in 4:
		lab.select_model(i);await frames(2);lab.effect.set_enabled(false)
		var original:=baseline();var expected: int=[19,20,40,21][i]
		lab.effect.set_enabled(true)
		check(lab.effect.binding_report.converted==expected and lab.effect.binding_report.unsupported.is_empty(),"Surface conversion missing: "+lab.MODELS[i].id)
		var skeleton_id: int=lab.skeleton.get_instance_id()
		var mesh_ids: Array=[]
		for mesh: MeshInstance3D in lab.character.find_children("*","MeshInstance3D",true,false):mesh_ids.append(mesh.mesh.get_instance_id())
		for action: String in ["A01","A25"]:
			lab.set_animation(action)
			for frame in 16:lab.player.advance(.04)
			for bone in lab.skeleton.get_bone_count():check(lab.skeleton.get_bone_global_pose(bone).is_finite(),"Invalid animated bone: "+lab.MODELS[i].id)
		check(skeleton_id==lab.skeleton.get_instance_id(),"Skeleton replaced by shader")
		for r: Dictionary in original:check(material_state(r.source)==r.state,"Source changed during animation")
		for cycle in 3:
			lab.effect.set_enabled(false);check_original(original);lab.effect.set_enabled(true)
		var shadow_free:=true
		for r: Dictionary in original:shadow_free=shadow_free and r.mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		check(shadow_free,"Projection casts a solid character shadow")
		check(lab.effect.base_materials.size()==expected,"Missing MToon depth shell")
		for base: ShaderMaterial in lab.effect.base_materials:
			check(not "hologram" in base.shader.resource_path,"Light layer used as the visible depth shell")
			check(base.next_pass!=null,"Projection light layer missing")
		# Two live instances must never share the per-instance hologram material.
		var other: Node3D=load(lab.MODELS[i].path).instantiate();root.add_child(other)
		await frames(2)
		var other_effect=EFFECT.new();root.add_child(other_effect);other_effect.bind(other,lab.MODELS[i].id)
		check(lab.effect.materials[0]!=other_effect.materials[0],"Projection material shared across actors")
		lab.effect.opacity=.18;lab.effect.apply_parameters()
		check(is_equal_approx(float(other_effect.materials[0].get_shader_parameter("opacity")),.42),"Another actor's opacity changed")
		lab.effect.opacity=.42;lab.effect.apply_parameters()
		check(lab.effect.base_materials[0]!=other_effect.base_materials[0],"Base material shared across actors")
		lab.effect.signal_strength=0.;lab.effect.apply_parameters()
		for r: Dictionary in original:check(not r.mesh.visible,"Zero signal leaves a solid character visible")
		lab.effect.set_enabled(false);check_original(original)
		lab.effect.signal_strength=1.;lab.effect.set_enabled(true)
		other_effect.restore();other_effect.queue_free();other.queue_free();await frames(2)
		lab.effect.restore();check_original(original)
		rows.append({"id":lab.MODELS[i].id,"surfaces":expected,"bones":lab.skeleton.get_bone_count(),"animations":["A01","A25"],"source_restored":true,"instance_isolation":true})
	check(ProjectSettings.get_setting("application/run/main_scene")=="res://scenes/map_1021.tscn","Formal F5 entry changed")
	var config:=ConfigFile.new();config.load("res://export_presets.cfg")
	var exported: PackedStringArray=config.get_value("preset.0","export_files")
	for p in exported:check(not "hologram" in p,"Independent preview entered formal export")
	report.models=rows

func capture(name: String) -> Image:
	await frames(6);await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	check(image.save_png(OUT+name+".png")==OK,"Capture failed: "+name)
	return image

func pixel(image: Image,world: Vector3) -> Color:
	var p: Vector2=lab.camera.unproject_position(world)
	var logical: Vector2=lab.get_viewport().get_visible_rect().size
	p*=Vector2(image.get_width(),image.get_height())/logical
	return image.get_pixel(clampi(int(p.x),0,image.get_width()-1),clampi(int(p.y),0,image.get_height()-1))

func rgb_distance(a: Color,b: Color) -> float:return Vector3(a.r,a.g,a.b).distance_to(Vector3(b.r,b.g,b.b))

func render_checks() -> void:
	var captures: Array=[]
	lab.playing=false;lab.effect.playing=false;lab.set_ui_visible(false)
	for i in 4:
		lab.select_model(i);lab.playing=false;lab.effect.playing=false;lab.set_animation("A01")
		lab.effect.clock=.8;lab.effect.apply_parameters()
		for lighting in 2:
			lab.set_background(lighting)
			var name: String=lab.MODELS[i].id+("_interior" if lighting==0 else "_daylight")
			await capture(name);captures.append(name)
		if i==1:
			var saved_target: Vector3=lab.target;var saved_distance: float=lab.distance
			var head_bone: int=lab.skeleton.find_bone("Head")
			lab.target=lab.skeleton.global_transform*(lab.skeleton.get_bone_global_pose(head_bone).origin+Vector3(0,.07,0))
			lab.distance=1.25;lab._update_camera()
			await capture("keqing_face_daylight");captures.append("keqing_face_daylight")
			lab.target=saved_target;lab.distance=saved_distance;lab._update_camera()
	lab.select_model(0);lab.playing=false;lab.effect.playing=false;lab.set_animation("A01");lab.set_background(0)
	lab.set_animation("A25");lab.player.seek(.9,true)
	await capture("ganyu_greeting");captures.append("ganyu_greeting")
	lab.set_animation("A01")
	lab.environment.glow_enabled=false
	# Opaque geometry in front must occlude a transparent projection.
	lab.occluder.visible=true
	var blocked:=await capture("ganyu_occlusion")
	lab.character.hide();await frames(4);await RenderingServer.frame_post_draw
	var opaque_reference:=root.get_texture().get_image()
	var occlusion_delta:=rgb_distance(pixel(blocked,lab.occluder.global_position),pixel(opaque_reference,lab.occluder.global_position))
	check(occlusion_delta<.03,"Projection drew through an opaque object")
	lab.character.show();lab.occluder.visible=false
	# The MToon shell must now hide a changed background behind the torso.
	var box:=BoxMesh.new();box.size=Vector3(.32,.35,.02)
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var card:=MeshInstance3D.new();card.mesh=box;card.material_override=material;card.position=Vector3(0,1.15,-.75);lab.add_child(card)
	material.albedo_color=Color(1,0,0);await frames(6);await RenderingServer.frame_post_draw
	var red:=root.get_texture().get_image()
	material.albedo_color=Color(0,0,1);await frames(6);await RenderingServer.frame_post_draw
	var blue:=root.get_texture().get_image()
	var transparency_delta:=rgb_distance(pixel(red,card.global_position),pixel(blue,card.global_position))
	check(transparency_delta<.02,"Background leaked through the restored character surface")
	card.queue_free();lab.environment.glow_enabled=true
	var internal_results: Array=[]
	lab.environment.glow_enabled=false
	for model_index in 4:
		lab.select_model(model_index);lab.playing=false;lab.effect.playing=false;lab.set_animation("A01");lab.effect.clock=.8;lab.effect.apply_parameters()
		var head: int=lab.skeleton.find_bone("Head")
		var internal_position: Vector3=lab.skeleton.global_transform*(lab.skeleton.get_bone_global_pose(head).origin+Vector3(0,.09,0))
		var ball:=SphereMesh.new();ball.radius=.025;ball.height=.05
		var sentinel:=MeshInstance3D.new();sentinel.mesh=ball;sentinel.position=internal_position;sentinel.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var marker:=StandardMaterial3D.new();marker.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;sentinel.material_override=marker;lab.add_child(sentinel)
		var max_delta:=0.
		for angle: float in [-.65,.10,.65]:
			lab.yaw=angle;lab._update_camera()
			marker.albedo_color=Color.RED;await frames(5);await RenderingServer.frame_post_draw
			var marker_red:=root.get_texture().get_image()
			marker.albedo_color=Color.BLUE;await frames(5);await RenderingServer.frame_post_draw
			var marker_blue:=root.get_texture().get_image()
			max_delta=maxf(max_delta,rgb_distance(pixel(marker_red,internal_position),pixel(marker_blue,internal_position)))
		check(max_delta<.02,"Internal head geometry is visible in "+lab.MODELS[model_index].id)
		internal_results.append({"model":lab.MODELS[model_index].id,"camera_angles":3,"internal_marker_rgb_delta":max_delta})
		sentinel.queue_free();await frames(2)
	lab.select_model(0);lab.playing=false;lab.effect.playing=false;lab.set_animation("A01");lab.set_background(0)
	lab.yaw=.10;lab.environment.glow_enabled=true
	lab.set_ui_visible(true);lab.effect.clock=.8;lab.effect.apply_parameters()
	await capture("preview_controls")
	report.render={"captures":captures,"opaque_occlusion_rgb_delta":occlusion_delta,"background_leak_rgb_delta":transparency_delta,"internal_head_checks":internal_results,"adapter":RenderingServer.get_video_adapter_name()}

func run() -> void:
	Engine.max_fps=60;root.size=Vector2i(1600,1000)
	lab=LAB.instantiate();root.add_child(lab)
	while not lab.ready_for_review:await process_frame
	await frames(4)
	var gpu: bool="--capture" in OS.get_cmdline_user_args()
	if gpu:await render_checks()
	else:await logic_checks()
	report.passed=failures.is_empty();report.failures=failures
	FileAccess.open(OUT+("render_report.json" if gpu else "logic_report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("HOLOGRAM_1028_RESULT ",JSON.stringify(report))
	lab.queue_free();await frames(3)
	quit(0 if failures.is_empty() else 1)
