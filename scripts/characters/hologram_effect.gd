extends Node
## Per-instance projection overrides; imported materials/mesh/skeleton stay shared and untouched.
signal printing_started
signal printing_finished
const HOLOGRAM = preload("res://shaders/characters/hologram.gdshader")
const DOUBLE_SIDED = preload("res://shaders/characters/hologram_cull_off.gdshader")
const MTOON = preload("res://scripts/characters/mtoon_materials.gd")
const GANYU_SOLID := ["面1","面2","睫","二重","眉","目","目星","口舌","齿","白目","发","角","新規","腰饰","神之眼","裙摆"]
const FACE_SURFACES := ["面","面1","面2","脸","眉","眉毛","目","目星","白目","睫","二重","口舌","齿","牙齿","舌头","口腔","眼白","眼睛","眼睛1","表情"]
@export var projection_color := Color(0.18,0.82,1.0)
@export_range(0.0,1.0) var opacity := 0.42
@export_range(0.0,4.0) var emission_strength := 1.05
@export_range(0.0,1.0) var scan_strength := 0.23
@export_range(0.0,1.0) var glitch_strength := 0.12
@export_range(0.0,1.0) var signal_strength := 1.0
@export_range(0.5,10.0) var print_duration := 3.5
@export_range(0.0,1.0) var materialization_progress := 0.0
@export_range(0.005,0.1) var print_edge_width := 0.025
var projection_bounds := Vector2(0.0,1.8)
var printing := false
var target: Node3D
var materials: Array[ShaderMaterial]=[]
var base_materials: Array[ShaderMaterial]=[]
var records: Array[Dictionary]=[]
var binding_report: Dictionary={}
var enabled := true
var playing := true
var clock := 0.0

func source_parameters(source: Material,name_value: String,profile: String) -> Dictionary:
	if source is StandardMaterial3D:
		var alpha: int=source.transparency
		if profile=="ganyu":
			if name_value in GANYU_SOLID:alpha=BaseMaterial3D.TRANSPARENCY_DISABLED
			elif name_value in ["服","肌"]:alpha=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		return {"texture":source.albedo_texture,"color":source.albedo_color,
			"uv":Vector4(source.uv1_scale.x,source.uv1_scale.y,source.uv1_offset.x,source.uv1_offset.y),
			"alpha":alpha!=BaseMaterial3D.TRANSPARENCY_DISABLED,"alpha_mode":alpha,
			"cutoff":source.alpha_scissor_threshold if alpha==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR else 0.0,
			"double_sided":source.cull_mode==BaseMaterial3D.CULL_DISABLED}
	if source is ShaderMaterial and source.shader!=null and source.shader.resource_path.begins_with("res://addons/mtoon/"):
		var path: String=source.shader.resource_path
		return {"texture":source.get_shader_parameter("_MainTex"),"color":source.get_shader_parameter("_Color"),
			"uv":source.get_shader_parameter("_MainTex_ST"),"alpha":"cutout" in path or "trans" in path or "prepass" in path,
			"cutoff":float(source.get_shader_parameter("_Cutoff")) if "cutout" in path else 0.0,"double_sided":"cull_off" in path}
	return {}

func create_base(source: Material,name_value: String,parameters: Dictionary) -> ShaderMaterial:
	var material: ShaderMaterial
	if source is StandardMaterial3D:
		var region: String="face" if name_value in ["面1","面2"] else ("skin" if name_value=="肌" else "body")
		material=MTOON.create(source,region,parameters.alpha_mode)
	else:
		material=source.duplicate()
	material.resource_name="Projection base · "+name_value
	material.next_pass=null
	material.set_shader_parameter("_OutlineWidthMode",0.0)
	return material

func bind(model: Node3D,profile: String="") -> Dictionary:
	restore();target=model;clock=0.0;enabled=true
	printing=false;materialization_progress=0.0
	binding_report={"converted":0,"unsupported":[],"profile":profile}
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh==null:continue
		var r: Dictionary={"mesh":mesh,"override":mesh.material_override,"shadow":mesh.cast_shadow,"visible":mesh.visible,"surfaces":[]}
		for i in mesh.mesh.get_surface_count():
			var source: Material=mesh.get_active_material(i)
			var name_value: String=mesh.mesh.surface_get_name(i) if mesh.mesh is ArrayMesh else source.resource_name
			var parameters:=source_parameters(source,name_value,profile)
			var old: Material=mesh.get_surface_override_material(i)
			if parameters.is_empty():
				binding_report.unsupported.append(str(model.get_path_to(mesh))+":"+str(i));continue
			var material:=ShaderMaterial.new()
			material.shader=DOUBLE_SIDED if parameters.double_sided else HOLOGRAM
			material.resource_name="Hologram · "+name_value
			material.render_priority=source.render_priority
			material.set_shader_parameter("source_texture",parameters.texture)
			material.set_shader_parameter("source_tint",parameters.color)
			material.set_shader_parameter("source_uv",parameters.uv)
			material.set_shader_parameter("use_source_alpha",parameters.alpha)
			material.set_shader_parameter("source_cutoff",parameters.cutoff)
			material.set_shader_parameter("face_protection",1.0 if name_value in FACE_SURFACES else 0.0)
			# Soft decorative overlays should not become a luminous solid mask.
			material.set_shader_parameter("surface_opacity",0.18 if name_value in ["脸红","頬染め"] else 1.0)
			var base:=create_base(source,name_value,parameters)
			base.next_pass=material
			r.surfaces.append({"index":i,"previous":old,"material":base,"overlay":material})
			base_materials.append(base)
			materials.append(material);binding_report.converted+=1
		if not r.surfaces.is_empty():
			records.append(r);mesh.material_override=null
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for item: Dictionary in r.surfaces:mesh.set_surface_override_material(item.index,item.material)
	_measure_projection_bounds()
	apply_parameters()
	return binding_report

func _measure_projection_bounds() -> void:
	# Imported rest-pose bounds include hair/accessories; one range for the whole actor.
	var minimum := INF
	var maximum := -INF
	for record: Dictionary in records:
		var mesh: MeshInstance3D=record.mesh
		var bounds: AABB=mesh.get_aabb()
		for corner in 8:
			var height: float=(mesh.global_transform*bounds.get_endpoint(corner)).y-target.global_position.y
			minimum=minf(minimum,height);maximum=maxf(maximum,height)
	projection_bounds=Vector2(minimum,maximum) if maximum-minimum>.01 else Vector2(0.0,1.8)

func start_printing(seconds: float=-1.0) -> void:
	if not is_instance_valid(target):return
	if seconds>0.0:print_duration=maxf(seconds,.5)
	materialization_progress=0.0;printing=true
	set_enabled(true);apply_parameters();printing_started.emit()

func reset_projection() -> void:
	printing=false;materialization_progress=0.0;apply_parameters()

func set_print_progress(value: float) -> void:
	# Scrub without advancing the animation; useful for previews and deterministic captures.
	printing=false;materialization_progress=clampf(value,0.0,1.0);apply_parameters()

func advance_printing(delta: float) -> void:
	if not printing:return
	materialization_progress=minf(materialization_progress+maxf(delta,0.0)/maxf(print_duration,.5),1.0)
	if materialization_progress>=1.0:
		printing=false;apply_parameters();printing_finished.emit()

func apply_parameters() -> void:
	var height: float=target.global_position.y if is_instance_valid(target) and target.is_inside_tree() else 0.0
	if enabled:
		for record: Dictionary in records:
			if is_instance_valid(record.mesh):
				record.mesh.visible=record.visible and signal_strength>0.0001
				record.mesh.cast_shadow=record.shadow if materialization_progress>=1.0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				for item: Dictionary in record.surfaces:
					# Stop submitting the light pass once solid; preserve normal accessory sorting.
					var light_pass: Material=item.overlay if materialization_progress<1.0 else null
					if item.material.next_pass!=light_pass:item.material.next_pass=light_pass
	for material in materials:
		material.set_shader_parameter("projection_color",projection_color)
		material.set_shader_parameter("opacity",opacity)
		material.set_shader_parameter("emission_strength",emission_strength)
		material.set_shader_parameter("scan_strength",scan_strength)
		material.set_shader_parameter("glitch_strength",glitch_strength)
		material.set_shader_parameter("signal_strength",signal_strength)
		material.set_shader_parameter("effect_time",clock)
		material.set_shader_parameter("emitter_height",height)
		material.set_shader_parameter("materialization_progress",materialization_progress)
		material.set_shader_parameter("projection_bounds",projection_bounds)
		material.set_shader_parameter("print_edge_width",print_edge_width)

func set_enabled(value: bool) -> void:
	enabled=value
	for record: Dictionary in records:
		var mesh: MeshInstance3D=record.mesh
		if not is_instance_valid(mesh):continue
		mesh.material_override=null if value else record.override
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if value and materialization_progress<1.0 else record.shadow
		mesh.visible=record.visible and signal_strength>0.0001 if value else record.visible
		for item: Dictionary in record.surfaces:mesh.set_surface_override_material(item.index,item.material if value else item.previous)

func restore() -> void:
	printing=false;set_enabled(false);materials.clear();base_materials.clear();records.clear();target=null

func _process(delta: float) -> void:
	if not enabled or not is_instance_valid(target):return
	if playing:
		clock+=delta;advance_printing(delta)
	apply_parameters()

func _exit_tree() -> void:restore()
