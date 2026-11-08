extends RefCounted
## Accepted MToon NPR appearance and wetness shader pipeline.
## Supports Ganyu, Stelle, Lumine, and general roster characters.
const PREPASS = preload("res://shaders/characters/mtoon_prepass.gdshader")
const PREPASS_CULL_OFF = preload("res://shaders/characters/mtoon_prepass_cull_off.gdshader")
const OPAQUE = preload("res://addons/mtoon/mtoon.gdshader")
const OPAQUE_CULL_OFF = preload("res://addons/mtoon/mtoon_cull_off.gdshader")
const BLEND = preload("res://addons/mtoon/mtoon_trans.gdshader")
const BLEND_CULL_OFF = preload("res://addons/mtoon/mtoon_trans_cull_off.gdshader")
const CUTOUT = preload("res://addons/mtoon/mtoon_cutout.gdshader")
const CUTOUT_CULL_OFF = preload("res://addons/mtoon/mtoon_cutout_cull_off.gdshader")
const WET_OPAQUE = preload("res://shaders/characters/wet_mtoon.gdshader")
const WET_OPAQUE_CULL_OFF = preload("res://shaders/characters/wet_mtoon_cull_off.gdshader")
const WET_CUTOUT = preload("res://shaders/characters/wet_mtoon_cutout.gdshader")
const WET_CUTOUT_CULL_OFF = preload("res://shaders/characters/wet_mtoon_cutout_cull_off.gdshader")

# Audited against Ganyu actual surface UVs and source texture alpha.
const FORMAL_GANYU_ALPHA := {
	"面1": BaseMaterial3D.TRANSPARENCY_DISABLED, "面2": BaseMaterial3D.TRANSPARENCY_DISABLED,
	"睫": BaseMaterial3D.TRANSPARENCY_DISABLED, "二重": BaseMaterial3D.TRANSPARENCY_DISABLED,
	"眉": BaseMaterial3D.TRANSPARENCY_DISABLED, "目": BaseMaterial3D.TRANSPARENCY_DISABLED,
	"目星": BaseMaterial3D.TRANSPARENCY_DISABLED, "口舌": BaseMaterial3D.TRANSPARENCY_DISABLED,
	"齿": BaseMaterial3D.TRANSPARENCY_DISABLED, "白目": BaseMaterial3D.TRANSPARENCY_DISABLED,
	"发": BaseMaterial3D.TRANSPARENCY_DISABLED, "角": BaseMaterial3D.TRANSPARENCY_DISABLED,
	"服": BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, "新規": BaseMaterial3D.TRANSPARENCY_DISABLED,
	"腰饰": BaseMaterial3D.TRANSPARENCY_DISABLED, "神之眼": BaseMaterial3D.TRANSPARENCY_DISABLED,
	"肌": BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, "裙摆": BaseMaterial3D.TRANSPARENCY_DISABLED,
	"脸红": BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS,
}

static func create(source: StandardMaterial3D, region: String, transparency_override: int = -1) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	var transparency := source.transparency if transparency_override < 0 else transparency_override
	var double_sided := source.cull_mode == BaseMaterial3D.CULL_DISABLED
	if transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:
		material.shader = PREPASS_CULL_OFF if double_sided else PREPASS
	elif transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
		material.shader = BLEND_CULL_OFF if double_sided else BLEND
	elif transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		material.shader = CUTOUT_CULL_OFF if double_sided else CUTOUT
	else:
		material.shader = OPAQUE_CULL_OFF if double_sided else OPAQUE
	material.resource_name = "MToon · " + source.resource_name
	material.set_shader_parameter("_Color", source.albedo_color)
	material.set_shader_parameter("_MainTex", source.albedo_texture)
	material.set_shader_parameter("_ShadeTexture", source.albedo_texture)
	material.set_shader_parameter("_ShadeColor", Color(0.78, 0.73, 0.85) if region not in ["face", "skin"] else Color(0.89, 0.79, 0.81))
	material.set_shader_parameter("_MainTex_ST", Vector4(source.uv1_scale.x, source.uv1_scale.y, source.uv1_offset.x, source.uv1_offset.y))
	material.set_shader_parameter("_ShadeToony", 0.75)
	material.set_shader_parameter("_ReceiveShadowRate", 1.0)
	material.set_shader_parameter("_AlphaCutoutEnable", 1.0 if transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR else 0.0)
	material.set_shader_parameter("_Cutoff", source.alpha_scissor_threshold)
	material.set_shader_parameter("_IndirectLightIntensity", 0.25)
	material.set_shader_parameter("_OutlineWidthMode", 0.0)
	return material

static func create_formal(source: StandardMaterial3D, region: String, surface_name: String) -> ShaderMaterial:
	var alpha: int = FORMAL_GANYU_ALPHA.get(surface_name, -1)
	var material := create(source, region, alpha)
	if not surface_name in ["面1","面2","发","角","服","新規","腰饰","神之眼","肌","裙摆"]: return material
	var double_sided := source.cull_mode == BaseMaterial3D.CULL_DISABLED
	if alpha == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		material.shader = WET_CUTOUT_CULL_OFF if double_sided else WET_CUTOUT
	else:
		material.shader = WET_OPAQUE_CULL_OFF if double_sided else WET_OPAQUE
	var response := Vector3(0.14, 0.12, 64)
	if surface_name in ["面1","面2"]: response = Vector3(0.035, 0.035, 96)
	elif surface_name == "肌": response = Vector3(0.08, 0.14, 80)
	elif surface_name == "发": response = Vector3(0.10, 0.16, 80)
	elif surface_name in ["角","腰饰","神之眼"]: response = Vector3(0.02, 0.08, 96)
	material.set_shader_parameter("wet_darkening", response.x)
	material.set_shader_parameter("wet_gloss", response.y)
	material.set_shader_parameter("wet_gloss_power", response.z)
	var dry := PackedFloat32Array()
	dry.resize(24)
	dry.fill(0.0)
	material.set_shader_parameter("wet_levels", dry)
	return material

static func apply_to_stelle_material(source_mat: ShaderMaterial, surface_name: String) -> ShaderMaterial:
	var mat := source_mat.duplicate() as ShaderMaterial
	var is_cutout := (surface_name in ["新建", "表情"])
	var is_trans := (surface_name == "眼睛1")
	var cull_off := not (surface_name in ["外套", "外套衣饰铁", "外套内侧"])
	
	if is_trans:
		mat.shader = BLEND_CULL_OFF
	elif is_cutout:
		mat.shader = WET_CUTOUT_CULL_OFF if cull_off else WET_CUTOUT
	else:
		mat.shader = WET_OPAQUE_CULL_OFF if cull_off else WET_OPAQUE
	
	var shade_col := Color(0.78, 0.73, 0.85)
	var receive_shadow := 1.0
	var shade_toony := 0.75
	var wet_resp := Vector3(0.14, 0.12, 64)
	
	if surface_name in ["外套", "衣服", "背带", "臂带", "鞋子", "手套"]:
		shade_col = Color(0.70, 0.68, 0.78)
		shade_toony = 0.80
		wet_resp = Vector3(0.15, 0.12, 64)
	elif surface_name == "外套内侧":
		shade_col = Color(0.88, 0.76, 0.55)
		shade_toony = 0.76
		wet_resp = Vector3(0.16, 0.10, 64)
	elif surface_name in ["衣饰铁", "外套衣饰铁", "怀表"]:
		shade_col = Color(0.72, 0.74, 0.82)
		shade_toony = 0.85
		wet_resp = Vector3(0.02, 0.25, 128)
	elif surface_name == "头发":
		shade_col = Color(0.75, 0.72, 0.84)
		shade_toony = 0.78
		wet_resp = Vector3(0.10, 0.16, 80)
	elif surface_name in ["脸", "皮肤", "眉毛", "口腔", "新胖次"]:
		shade_col = Color(0.95, 0.85, 0.85)
		shade_toony = 0.70
		receive_shadow = 0.20 if surface_name in ["脸", "眉毛", "口腔"] else 0.40
		wet_resp = Vector3(0.04, 0.04, 96) if surface_name in ["脸", "眉毛"] else Vector3(0.08, 0.14, 80)
	elif surface_name in ["眼睛", "眼白"]:
		shade_col = Color(0.90, 0.88, 0.92)
		receive_shadow = 0.0
		shade_toony = 0.90
		wet_resp = Vector3(0.0, 0.0, 64)
	
	mat.set_shader_parameter("_ShadeColor", shade_col)
	mat.set_shader_parameter("_ShadeToony", shade_toony)
	mat.set_shader_parameter("_ReceiveShadowRate", receive_shadow)
	mat.set_shader_parameter("_IndirectLightIntensity", 0.35)
	mat.set_shader_parameter("_OutlineWidthMode", 0.0)
	mat.next_pass = null
	
	if surface_name == "眼睛":
		mat.set_shader_parameter("_EmissionColor", Color(0.35, 0.28, 0.10))
	
	mat.set_shader_parameter("wet_darkening", wet_resp.x)
	mat.set_shader_parameter("wet_gloss", wet_resp.y)
	mat.set_shader_parameter("wet_gloss_power", wet_resp.z)
	var dry := PackedFloat32Array()
	dry.resize(24)
	dry.fill(0.0)
	mat.set_shader_parameter("wet_levels", dry)
	return mat

static func apply_to_generic_shader_material(source_mat: ShaderMaterial, surface_name: String) -> ShaderMaterial:
	var mat := source_mat.duplicate() as ShaderMaterial
	var orig_shader_path := source_mat.shader.resource_path if source_mat.shader else ""
	var is_cutout := orig_shader_path.contains("cutout") or surface_name.contains("cutout")
	var is_trans := orig_shader_path.contains("trans")
	var cull_off := orig_shader_path.contains("cull_off")
	
	if is_trans:
		mat.shader = BLEND_CULL_OFF if cull_off else BLEND
	elif is_cutout:
		mat.shader = WET_CUTOUT_CULL_OFF if cull_off else WET_CUTOUT
	else:
		mat.shader = WET_OPAQUE_CULL_OFF if cull_off else WET_OPAQUE
	
	var shade_col := Color(0.78, 0.73, 0.85)
	var receive_shadow := 1.0
	var shade_toony := 0.75
	var wet_resp := Vector3(0.14, 0.12, 64)
	
	if surface_name in ["面", "面1", "面2", "脸", "颜", "颜2", "眉", "睫", "口", "口舌", "齿"]:
		shade_col = Color(0.95, 0.85, 0.85)
		receive_shadow = 0.22
		shade_toony = 0.70
		wet_resp = Vector3(0.04, 0.04, 96)
	elif surface_name in ["肌", "皮肤"]:
		shade_col = Color(0.92, 0.82, 0.84)
		receive_shadow = 0.40
		shade_toony = 0.72
		wet_resp = Vector3(0.08, 0.14, 80)
	elif surface_name in ["目", "眼睛", "眼白", "星目", "目星"]:
		shade_col = Color(0.90, 0.88, 0.92)
		receive_shadow = 0.0
		shade_toony = 0.90
		wet_resp = Vector3(0.0, 0.0, 64)
	elif surface_name in ["发", "头发", "髪", "髪+"]:
		shade_col = Color(0.76, 0.73, 0.85)
		shade_toony = 0.78
		wet_resp = Vector3(0.10, 0.16, 80)
	
	mat.set_shader_parameter("_ShadeColor", shade_col)
	mat.set_shader_parameter("_ShadeToony", shade_toony)
	mat.set_shader_parameter("_ReceiveShadowRate", receive_shadow)
	mat.set_shader_parameter("_IndirectLightIntensity", 0.35)
	mat.set_shader_parameter("_OutlineWidthMode", 0.0)
	mat.next_pass = null
	
	mat.set_shader_parameter("wet_darkening", wet_resp.x)
	mat.set_shader_parameter("wet_gloss", wet_resp.y)
	mat.set_shader_parameter("wet_gloss_power", wet_resp.z)
	var dry := PackedFloat32Array()
	dry.resize(24)
	dry.fill(0.0)
	mat.set_shader_parameter("wet_levels", dry)
	return mat

static func apply(character: Node3D, character_id: String = "auto") -> Dictionary:
	var result := {"converted": 0, "skipped": []}
	var detected_id := character_id
	if detected_id == "auto":
		var node_str := (character.name + " " + character.get_scene_file_path()).to_lower()
		if node_str.contains("stelle") or node_str.contains("女主"):
			detected_id = "stelle"
		elif node_str.contains("lumine") or node_str.contains("荧"):
			detected_id = "lumine"
		elif node_str.contains("ganyu") or node_str.contains("甘雨"):
			detected_id = "ganyu"
		else:
			detected_id = "generic"
	
	for mesh: MeshInstance3D in character.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null: continue
		for index in mesh.mesh.get_surface_count():
			var source: Material = mesh.get_active_material(index)
			var name_value: String = mesh.mesh.surface_get_name(index) if mesh.mesh is ArrayMesh else ""
			if name_value.is_empty() and source != null:
				name_value = source.resource_name
			
			if source is StandardMaterial3D:
				var region := "face" if name_value in ["面1", "面2", "脸", "颜"] else ("skin" if name_value in ["肌", "皮肤"] else "body")
				mesh.set_surface_override_material(index, create_formal(source, region, name_value))
				result.converted += 1
			elif source is ShaderMaterial:
				if detected_id == "stelle":
					mesh.set_surface_override_material(index, apply_to_stelle_material(source, name_value))
				else:
					mesh.set_surface_override_material(index, apply_to_generic_shader_material(source, name_value))
				result.converted += 1
			else:
				result.skipped.append(str(character.get_path_to(mesh)) + ":" + str(index))
	return result
