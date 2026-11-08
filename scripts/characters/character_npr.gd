class_name CharacterNPR
extends RefCounted

## Full non-photorealistic rendering (NPR) pipeline for character roster.
## Provides smoothed-normal inverted hull outline shells, face normal softening,
## anisotropic hair highlights, metallic accents, and wetness compatibility.

const MTOON_MATERIALS = preload("res://scripts/characters/mtoon_materials.gd")

const OUTLINE_ENABLED := false
const OUTLINE_SHADER = preload("res://shaders/characters/npr_outline.gdshader")
const TOON_OPAQUE = preload("res://shaders/characters/toon_opaque.gdshader")
const TOON_OPAQUE_CULL_OFF = preload("res://shaders/characters/toon_opaque_cull_off.gdshader")
const TOON_CUTOUT = preload("res://shaders/characters/toon_cutout.gdshader")
const TOON_CUTOUT_CULL_OFF = preload("res://shaders/characters/toon_cutout_cull_off.gdshader")
const TOON_BLEND_CULL_OFF = preload("res://shaders/characters/toon_blend_cull_off.gdshader")

static var outline_mesh_cache: Dictionary = {}

static func is_face_surface(name_val: String) -> bool:
	return name_val in ["脸", "面", "面1", "面2", "颜", "颜2", "眉毛", "眉", "口腔", "口舌", "齿", "牙齿", "舌头"]

static func is_hair_surface(name_val: String) -> bool:
	return name_val in ["头发", "发", "髪", "髪+"]

static func is_skin_surface(name_val: String) -> bool:
	return name_val in ["皮肤", "肌", "新胖次"]

static func is_eye_surface(name_val: String) -> bool:
	return name_val in ["眼睛", "眼白", "眼睛1", "目", "白目", "星目", "目星"]

static func is_accessory_surface(name_val: String) -> bool:
	return name_val in ["衣饰铁", "外套衣饰铁", "怀表", "神之眼", "腰饰", "角", "胸饰", "背饰铃铛", "裙饰铁", "鞋子饰"]

static func get_region_code(name_val: String) -> int:
	if is_face_surface(name_val): return 0
	if is_skin_surface(name_val): return 1
	if is_hair_surface(name_val): return 2
	if is_eye_surface(name_val): return 4
	if is_accessory_surface(name_val): return 5
	return 3 # body

static func apply_npr(character: Node3D, character_id: String) -> Dictionary:
	var result := {"converted": 0, "outline_shell": null, "face_materials": []}
	var main_mesh: MeshInstance3D = null
	var max_surfaces := 0
	
	for mesh: MeshInstance3D in character.find_children("*", "MeshInstance3D", true, false):
		if mesh.has_meta("character_npr_outline"): continue
		if mesh.mesh != null and mesh.mesh.get_surface_count() > max_surfaces:
			max_surfaces = mesh.mesh.get_surface_count()
			main_mesh = mesh
			
	if main_mesh == null or main_mesh.mesh == null:
		return result
		
	var selected_outline: Array[Dictionary] = []
	for i in main_mesh.mesh.get_surface_count():
		var s_name: String = main_mesh.mesh.surface_get_name(i) if main_mesh.mesh is ArrayMesh else ""
		var orig_mat: Material = main_mesh.get_active_material(i)
		if s_name.is_empty() and orig_mat != null:
			s_name = orig_mat.resource_name
			
		var tex: Texture2D = null
		var base_col: Color = Color.WHITE
		var is_trans: bool = false
		var is_cutout: bool = false
		var cull_off: bool = true
		var cutoff: float = 0.5
		
		if orig_mat is ShaderMaterial and orig_mat.shader != null:
			tex = orig_mat.get_shader_parameter("_MainTex")
			if orig_mat.get_shader_parameter("_Color") != null:
				base_col = orig_mat.get_shader_parameter("_Color")
			var sh_name: String = orig_mat.shader.resource_path.get_file().to_lower()
			if sh_name.contains("trans"):
				is_trans = true
			elif sh_name.contains("cutout"):
				is_cutout = true
			cull_off = sh_name.contains("cull_off")
			var orig_cutoff = orig_mat.get_shader_parameter("_Cutoff")
			if orig_cutoff != null:
				cutoff = float(orig_cutoff)
		elif orig_mat is StandardMaterial3D:
			tex = orig_mat.albedo_texture
			base_col = orig_mat.albedo_color
			cull_off = (orig_mat.cull_mode == BaseMaterial3D.CULL_DISABLED)
			if character_id == "ganyu":
				var ganyu_alpha: int = MTOON_MATERIALS.FORMAL_GANYU_ALPHA.get(s_name, -1)
				if ganyu_alpha == BaseMaterial3D.TRANSPARENCY_ALPHA or ganyu_alpha == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:
					is_trans = true
				elif ganyu_alpha == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
					is_cutout = true
			else:
				if orig_mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA or orig_mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:
					is_trans = true
				elif orig_mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR or orig_mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_HASH:
					is_cutout = true
				cutoff = orig_mat.alpha_scissor_threshold
		else:
			# Fallback for unrecognized materials
			if s_name in ["脸红", "眼睛1"] or s_name.ends_with("+"):
				is_trans = true
			elif s_name in ["新建", "表情"]:
				is_cutout = true
				
		var mat := ShaderMaterial.new()
		if is_trans:
			mat.shader = TOON_BLEND_CULL_OFF
		elif is_cutout:
			mat.shader = TOON_CUTOUT_CULL_OFF if cull_off else TOON_CUTOUT
		else:
			mat.shader = TOON_OPAQUE_CULL_OFF if cull_off else TOON_OPAQUE
			
		mat.set_shader_parameter("base_texture", tex)
		mat.set_shader_parameter("base_color", base_col)
		mat.set_shader_parameter("alpha_cutoff", cutoff if is_cutout else 0.0)
		mat.set_shader_parameter("tone_bands", 2)
		mat.set_shader_parameter("edge_softness", 0.05)
		
		var region_code := get_region_code(s_name)
		mat.set_shader_parameter("region", region_code)
		mat.set_shader_parameter("face_softness", 0.85)
		mat.set_shader_parameter("diffuse_gain", 0.90 if region_code == 0 else 0.85)
		mat.set_shader_parameter("hair_highlight", 0.28 if region_code == 2 else 0.0)
		mat.set_shader_parameter("eye_highlight", 0.15 if region_code == 4 else 0.0)
		mat.set_shader_parameter("skin_shadow_multiplier", Vector3(0.92, 0.78, 0.80))
		mat.set_shader_parameter("shadow_multiplier", Vector3(0.68, 0.65, 0.78))
		if s_name == "外套内侧":
			mat.set_shader_parameter("shadow_multiplier", Vector3(0.85, 0.72, 0.48))
		elif region_code == 5:
			mat.set_shader_parameter("source_roughness", 0.35)
			
		var wet_resp := Vector3(0.14, 0.12, 64)
		if region_code == 0:
			wet_resp = Vector3(0.04, 0.04, 96)
			result.face_materials.append(mat)
		elif region_code == 1:
			wet_resp = Vector3(0.08, 0.14, 80)
		elif region_code == 2:
			wet_resp = Vector3(0.10, 0.16, 80)
		elif region_code == 5:
			wet_resp = Vector3(0.02, 0.25, 128)
		elif region_code == 4:
			wet_resp = Vector3(0.0, 0.0, 64)
			
		mat.set_shader_parameter("wet_darkening", wet_resp.x)
		mat.set_shader_parameter("wet_gloss", wet_resp.y)
		mat.set_shader_parameter("wet_gloss_power", wet_resp.z)
		var dry := PackedFloat32Array()
		dry.resize(24)
		dry.fill(0.0)
		mat.set_shader_parameter("wet_levels", dry)
		
		main_mesh.set_surface_override_material(i, mat)
		result.converted += 1
		
		# Outline disabled per modern NPR design
		if OUTLINE_ENABLED and region_code in [0, 2, 3, 5] and not is_trans and not is_cutout and s_name != "眉毛":
			var out_mat := ShaderMaterial.new()
			out_mat.shader = OUTLINE_SHADER
			out_mat.set_shader_parameter("base_texture", tex)
			out_mat.set_shader_parameter("base_color", base_col)
			var out_color := Color("383248")
			var out_pixels := 0.95
			if region_code == 0:
				out_color = Color("784c55")
				out_pixels = 0.55
			elif region_code == 2:
				out_color = Color("403850")
				out_pixels = 0.95
			out_mat.set_shader_parameter("outline_color", out_color)
			out_mat.set_shader_parameter("outline_pixels", out_pixels)
			selected_outline.append({"index": i, "material": out_mat})
			
	# Remove any existing outline shell
	for old_shell in character.find_children("*", "MeshInstance3D", true, false):
		if old_shell.has_meta("character_npr_outline") or old_shell.name == "CharacterNPROutline":
			old_shell.queue_free()
			
	if OUTLINE_ENABLED and not selected_outline.is_empty():
		var outline_shell := _build_outline_mesh(main_mesh, selected_outline)
		result.outline_shell = outline_shell
		
	return result

static func _build_outline_mesh(source: MeshInstance3D, selected: Array[Dictionary]) -> MeshInstance3D:
	var key := str(source.mesh.get_instance_id()) + ":" + str(selected.map(func(e): return e.index))
	var derived: ArrayMesh = outline_mesh_cache.get(key)
	
	if derived == null:
		derived = ArrayMesh.new()
		for shape in source.mesh.get_blend_shape_count():
			derived.add_blend_shape(source.mesh.get_blend_shape_name(shape))
		derived.blend_shape_mode = source.mesh.blend_shape_mode
		
		var groups := {}
		for entry in selected:
			var arrays := source.mesh.surface_get_arrays(entry.index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in vertices.size():
				var p := Vector3i(roundi(vertices[i].x * 100000.0), roundi(vertices[i].y * 100000.0), roundi(vertices[i].z * 100000.0))
				if not groups.has(p): groups[p] = []
				if not groups[p].has(normals[i]): groups[p].append(normals[i])
				
		for entry in selected:
			var arrays := source.mesh.surface_get_arrays(entry.index).duplicate(true)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL].duplicate()
			for i in vertices.size():
				var p := Vector3i(roundi(vertices[i].x * 100000.0), roundi(vertices[i].y * 100000.0), roundi(vertices[i].z * 100000.0))
				var average := Vector3.ZERO
				for candidate: Vector3 in groups[p]:
					if candidate.dot(normals[i]) > 0.0: average += candidate
				if average.length_squared() > 0.0001: normals[i] = average.normalized()
			arrays[Mesh.ARRAY_NORMAL] = normals
			var blend_arrays := source.mesh.surface_get_blend_shape_arrays(entry.index)
			derived.add_surface_from_arrays(source.mesh.surface_get_primitive_type(entry.index), arrays, blend_arrays)
		outline_mesh_cache[key] = derived
		
	# Remove any previous shell
	var existing: Node = source.get_parent().get_node_or_null("CharacterNPROutline")
	if existing != null:
		existing.queue_free()
		
	var outline_shell := MeshInstance3D.new()
	outline_shell.name = "CharacterNPROutline"
	outline_shell.set_meta("character_npr_outline", true)
	outline_shell.mesh = derived
	outline_shell.skin = source.skin
	outline_shell.skeleton = source.skeleton
	outline_shell.transform = source.transform
	outline_shell.layers = source.layers
	outline_shell.extra_cull_margin = 0.02
	outline_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in selected.size():
		outline_shell.set_surface_override_material(i, selected[i].material)
	source.get_parent().add_child(outline_shell)
	return outline_shell
