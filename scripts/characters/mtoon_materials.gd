extends RefCounted
## Accepted MToon NPR appearance and wetness shader pipeline.
## Provides production-grade MToon rendering with wetness extension for Ganyu, Stelle, Lumine, and roster characters.

const PREPASS = preload("res://shaders/characters/mtoon_prepass.gdshader")
const PREPASS_CULL_OFF = preload("res://shaders/characters/mtoon_prepass_cull_off.gdshader")

const OPAQUE = preload("res://addons/mtoon/mtoon.gdshader")
const OPAQUE_CULL_OFF = preload("res://addons/mtoon/mtoon_cull_off.gdshader")

const CUTOUT = preload("res://addons/mtoon/mtoon_cutout.gdshader")
const CUTOUT_CULL_OFF = preload("res://addons/mtoon/mtoon_cutout_cull_off.gdshader")

const BLEND = preload("res://addons/mtoon/mtoon_trans.gdshader")
const BLEND_CULL_OFF = preload("res://addons/mtoon/mtoon_trans_cull_off.gdshader")

const TRANS_ZWRITE = preload("res://addons/mtoon/mtoon_trans_zwrite.gdshader")
const TRANS_ZWRITE_CULL_OFF = preload("res://addons/mtoon/mtoon_trans_zwrite_cull_off.gdshader")

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
	var transparency: int = source.transparency if transparency_override < 0 else transparency_override
	var double_sided: bool = source.cull_mode == BaseMaterial3D.CULL_DISABLED
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
	material.set_shader_parameter("_IndirectLightIntensity", 0.35)
	material.set_shader_parameter("_OutlineWidthMode", 0.0)
	return material

static func create_formal(source: StandardMaterial3D, region: String, surface_name: String) -> ShaderMaterial:
	var alpha: int = FORMAL_GANYU_ALPHA.get(surface_name, -1)
	var material := create(source, region, alpha)
	if not surface_name in ["面1","面2","发","角","服","新規","腰饰","神之眼","肌","裙摆"]: return material
	var double_sided: bool = source.cull_mode == BaseMaterial3D.CULL_DISABLED
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

static func apply_to_vrm_shader_material(source_mat: ShaderMaterial, surface_name: String, _character_id: String) -> ShaderMaterial:
	var mat := source_mat.duplicate() as ShaderMaterial
	var orig_shader_path: String = ""
	if source_mat.shader != null:
		orig_shader_path = source_mat.shader.resource_path.get_file().to_lower()
	
	var is_cutout: bool = orig_shader_path.contains("cutout")
	var is_trans_zwrite: bool = orig_shader_path.contains("trans_zwrite")
	var is_trans: bool = orig_shader_path.contains("trans") and not is_trans_zwrite
	var cull_off: bool = orig_shader_path.contains("cull_off")
	
	# Select target shader variant
	# Wetness extension is applied to opaque and cutout body surfaces;
	# Transparent overlay layers (hair+, eyes) use official clean MToon transparent shaders.
	if is_trans_zwrite:
		mat.shader = TRANS_ZWRITE_CULL_OFF if cull_off else TRANS_ZWRITE
	elif is_trans:
		mat.shader = BLEND_CULL_OFF if cull_off else BLEND
	elif is_cutout:
		mat.shader = WET_CUTOUT_CULL_OFF if cull_off else WET_CUTOUT
	else:
		mat.shader = WET_OPAQUE_CULL_OFF if cull_off else WET_OPAQUE
	
	# Outlines strictly disabled per art direction
	mat.set_shader_parameter("_OutlineWidthMode", 0.0)
	mat.next_pass = null
	
	# Upward sky normal indirect light blend for clean anime luminous look
	mat.set_shader_parameter("_IndirectLightIntensity", 0.35)
	
	var is_face: bool = surface_name in ["面", "面1", "面2", "脸", "颜", "颜2", "眉", "眉毛", "睫", "口", "口舌", "齿", "牙齿", "舌头", "口腔"]
	var is_skin: bool = surface_name in ["肌", "皮肤", "新胖次"]
	var is_eye: bool = surface_name in ["目", "眼睛", "眼白", "星目", "目星"]
	var is_hair: bool = surface_name in ["发", "头发", "髪", "髪+"]
	var is_metal: bool = surface_name in ["衣饰铁", "外套衣饰铁", "怀表", "神之眼", "腰饰", "角", "胸饰", "背饰铃铛", "裙饰铁", "鞋子饰"]
	
	var shade_col_param = mat.get_shader_parameter("_ShadeColor")
	var existing_shade_col: Color = shade_col_param if shade_col_param is Color else Color.WHITE
	
	if is_face or is_skin:
		if existing_shade_col == Color.WHITE or existing_shade_col.v > 0.95:
			mat.set_shader_parameter("_ShadeColor", Color(0.89, 0.79, 0.81))
		mat.set_shader_parameter("_ReceiveShadowRate", 0.20 if is_face else 0.40)
		mat.set_shader_parameter("_ShadeToony", 0.70)
	elif is_eye:
		mat.set_shader_parameter("_ReceiveShadowRate", 0.0)
		mat.set_shader_parameter("_ShadeToony", 0.90)
		if surface_name == "眼睛":
			mat.set_shader_parameter("_EmissionColor", Color(0.30, 0.25, 0.12))
	elif is_hair:
		if existing_shade_col == Color.WHITE:
			mat.set_shader_parameter("_ShadeColor", Color(0.78, 0.73, 0.85))
		mat.set_shader_parameter("_ShadeToony", 0.78)
	elif is_metal:
		mat.set_shader_parameter("_ShadeToony", 0.85)
	elif surface_name == "外套内侧":
		mat.set_shader_parameter("_ShadeColor", Color(0.85, 0.72, 0.48))
		mat.set_shader_parameter("_ShadeToony", 0.76)
	else:
		if existing_shade_col == Color.WHITE:
			mat.set_shader_parameter("_ShadeColor", Color(0.78, 0.73, 0.85))
		if mat.get_shader_parameter("_ShadeToony") == null:
			mat.set_shader_parameter("_ShadeToony", 0.75)
			
	# Wetness setup for wet-capable surfaces
	var is_wet_capable: bool = (not is_trans) and (not is_trans_zwrite) and (not (surface_name in ["眼睛1", "目星"]))
	if is_wet_capable:
		var wet_resp := Vector3(0.14, 0.12, 64)
		if is_face: wet_resp = Vector3(0.04, 0.04, 96)
		elif is_skin: wet_resp = Vector3(0.08, 0.14, 80)
		elif is_hair: wet_resp = Vector3(0.10, 0.16, 80)
		elif is_metal: wet_resp = Vector3(0.02, 0.25, 128)
		elif is_eye: wet_resp = Vector3(0.0, 0.0, 64)
		
		mat.set_shader_parameter("wet_darkening", wet_resp.x)
		mat.set_shader_parameter("wet_gloss", wet_resp.y)
		mat.set_shader_parameter("wet_gloss_power", wet_resp.z)
		var dry := PackedFloat32Array()
		dry.resize(24)
		dry.fill(0.0)
		mat.set_shader_parameter("wet_levels", dry)
		
	return mat

static func apply(character: Node3D, character_id: String = "auto") -> Dictionary:
	var result := {
		"converted": 0,
		"skipped": [],
		"surfaces": []
	}
	var detected_id := character_id
	if detected_id == "auto":
		var node_str := (character.name + " " + character.get_scene_file_path()).to_lower()
		if node_str.contains("ganyu") or node_str.contains("甘雨"):
			detected_id = "ganyu"
		elif node_str.contains("stelle") or node_str.contains("女主"):
			detected_id = "stelle"
		elif node_str.contains("lumine") or node_str.contains("荧"):
			detected_id = "lumine"
		elif node_str.contains("firefly") or node_str.contains("流萤"):
			detected_id = "firefly"
		else:
			detected_id = "generic"
	
	for mesh: MeshInstance3D in character.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null: continue
		for index in mesh.mesh.get_surface_count():
			var source: Material = mesh.get_active_material(index)
			var name_value: String = mesh.mesh.surface_get_name(index) if mesh.mesh is ArrayMesh else ""
			if name_value.is_empty() and source != null:
				name_value = source.resource_name
			
			var target_mat: Material = null
			var alpha_mode := "opaque"
			var cull_mode_str := "cull_back"
			
			if source is StandardMaterial3D:
				var region: String = "face" if name_value in ["面1", "面2", "脸", "颜"] else ("skin" if name_value in ["肌", "皮肤"] else "body")
				if detected_id == "ganyu":
					target_mat = create_formal(source, region, name_value)
				else:
					target_mat = create(source, region)
				mesh.set_surface_override_material(index, target_mat)
				result.converted += 1
			elif source is ShaderMaterial:
				target_mat = apply_to_vrm_shader_material(source, name_value, detected_id)
				mesh.set_surface_override_material(index, target_mat)
				result.converted += 1
			else:
				result.skipped.append(str(character.get_path_to(mesh)) + ":" + str(index))
				continue
				
			var sh_name := ""
			if target_mat is ShaderMaterial and target_mat.shader != null:
				sh_name = target_mat.shader.resource_path.get_file()
				if sh_name.contains("trans_zwrite"): alpha_mode = "trans_zwrite"
				elif sh_name.contains("trans"): alpha_mode = "transparent"
				elif sh_name.contains("cutout"): alpha_mode = "cutout"
				if sh_name.contains("cull_off"): cull_mode_str = "cull_off"
				
			result.surfaces.append({
				"mesh": mesh.name,
				"surface_index": index,
				"surface_name": name_value,
				"source_class": source.get_class() if source else "NULL",
				"target_shader": sh_name,
				"alpha_mode": alpha_mode,
				"cull_mode": cull_mode_str,
			})
	return result
