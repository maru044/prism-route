extends RefCounted
## Accepted lab B appearance, shared by the formal character and review tools.
## No lab, C0/C1, SDF, profile or outline resources are loaded here.
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
# Audited against Ganyu's actual surface UVs and source texture alpha.
# Keep the historical lab B path in create(); only the formal actor opts in.
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
	# Unknown surfaces retain their source alpha behavior; this is not a generic
	# auto-converter for other characters or already-imported MToon materials.
	var alpha: int = FORMAL_GANYU_ALPHA.get(surface_name, -1)
	var material := create(source, region, alpha)
	# Preserve eye and blush overlays exactly. Only audited solid/cutout surfaces
	# opt into the project variant; historical create() stays upstream MToon.
	if not surface_name in ["面1","面2","发","角","服","新規","腰饰","神之眼","肌","裙摆"]: return material
	var double_sided := source.cull_mode == BaseMaterial3D.CULL_DISABLED
	if alpha == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		material.shader = WET_CUTOUT_CULL_OFF if double_sided else WET_CUTOUT
	else:
		material.shader = WET_OPAQUE_CULL_OFF if double_sided else WET_OPAQUE
	var response := Vector3(.14,.12,64)
	if surface_name in ["面1","面2"]: response = Vector3(.035,.035,96)
	elif surface_name == "肌": response = Vector3(.08,.14,80)
	elif surface_name == "发": response = Vector3(.10,.16,80)
	elif surface_name in ["角","腰饰","神之眼"]: response = Vector3(.02,.08,96)
	material.set_shader_parameter("wet_darkening",response.x)
	material.set_shader_parameter("wet_gloss",response.y)
	material.set_shader_parameter("wet_gloss_power",response.z)
	var dry := PackedFloat32Array(); dry.resize(24); dry.fill(0.0)
	material.set_shader_parameter("wet_levels",dry)
	return material

static func apply(character: Node3D) -> Dictionary:
	var result := {"converted": 0, "skipped": []}
	for mesh: MeshInstance3D in character.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null: continue
		for index in mesh.mesh.get_surface_count():
			var source: Material = mesh.get_active_material(index)
			if not source is StandardMaterial3D:
				result.skipped.append(str(character.get_path_to(mesh)) + ":" + str(index))
				continue
			var name_value: String = mesh.mesh.surface_get_name(index) if mesh.mesh is ArrayMesh else source.resource_name
			var region := "face" if name_value in ["面1", "面2"] else ("skin" if name_value == "肌" else "body")
			mesh.set_surface_override_material(index, create_formal(source, region, name_value))
			result.converted += 1
	return result
