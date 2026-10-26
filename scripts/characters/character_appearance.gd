extends Node
## Per-character material instances; imported resources and mesh overrides stay intact.
const DEFAULT_PROFILE = preload("res://materials/characters/ganyu_appearance.tres")
const MTOON_MATERIALS = preload("res://scripts/characters/mtoon_materials.gd")
const FAMILIES := {"face": 0, "skin": 1, "hair": 2, "body": 3, "eye": 4, "accessory": 5, "overlay": 6}
static var outline_mesh_cache: Dictionary = {}
var profile: Resource
var character: Node3D
var entries: Array[Dictionary] = []
var warnings: Array[String] = []
var mode := "standard"
var skeleton: Skeleton3D
var head_index := -1
var head_rest_inverse := Basis.IDENTITY
var outline_shell: MeshInstance3D
var outlined_source: MeshInstance3D

func bind(target: Node3D, source_profile: Resource = DEFAULT_PROFILE) -> void:
	restore()
	if is_instance_valid(outline_shell): outline_shell.free()
	outline_shell = null
	entries.clear()
	warnings.clear()
	character = target
	profile = source_profile.duplicate(true)
	skeleton = target.find_child("GeneralSkeleton", true, false)
	if skeleton:
		head_index = skeleton.find_bone("Head")
		if head_index >= 0: head_rest_inverse = skeleton.get_bone_global_rest(head_index).basis.inverse()
	var mesh: MeshInstance3D = target.get_node_or_null(profile.mesh_path)
	if mesh == null:
		warnings.append("部位映射网格不存在；保留原材质。")
		return
	var seen := {}
	for i in mesh.mesh.get_surface_count():
		var original: Material = mesh.get_active_material(i)
		var name_key: String = mesh.mesh.surface_get_name(i) if mesh.mesh is ArrayMesh else ""
		if name_key.is_empty() and original: name_key = original.resource_name
		seen[name_key] = int(seen.get(name_key, 0)) + 1
	# A duplicate name is ambiguous; never silently assign a different region after import.
	for i in mesh.mesh.get_surface_count():
		var original: Material = mesh.get_active_material(i)
		var name_key: String = mesh.mesh.surface_get_name(i) if mesh.mesh is ArrayMesh else ""
		if name_key.is_empty() and original: name_key = original.resource_name
		if not original is StandardMaterial3D or not profile.regions.has(name_key) or seen[name_key] != 1 or mesh.material_override != null:
			warnings.append("未转换 surface：%s；保留原材质。" % name_key)
			continue
		# Unsupported source features must stay visible through the original material.
		if original.normal_enabled or original.vertex_color_use_as_albedo or original.next_pass != null or original.cull_mode == BaseMaterial3D.CULL_FRONT or original.emission_enabled or original.metallic > 0.0 or original.transparency not in [BaseMaterial3D.TRANSPARENCY_DISABLED, BaseMaterial3D.TRANSPARENCY_ALPHA, BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS]:
			warnings.append("%s 含未映射的法线/顶点色/多 pass；保留原材质。" % name_key)
			continue
		var entry := {"mesh": mesh, "index": i, "name": name_key, "source": original,
			"original_override": mesh.get_surface_override_material(i), "region": profile.regions[name_key], "cache": {}}
		entry.cache.mtoon = _mtoon(original, entry.region)
		entry.cache.custom = _custom(original, entry.region)
		entry.cache.genshin = _c1(original, entry.region)
		if entry.region in ["hair", "body", "accessory"] or name_key == "面1":
			entry.outline = _outline(original, entry.region)
		entries.append(entry)
	for expected in profile.regions:
		if not seen.has(expected): warnings.append("重导入缺少预期部位：" + expected)
	_build_outline_shell(mesh)
	set_mode("standard")

func set_mode(value: String) -> bool:
	if value not in ["standard", "mtoon", "custom", "genshin"]: return false
	mode = value
	for entry in entries:
		entry.mesh.set_surface_override_material(entry.index, entry.original_override if mode == "standard" else entry.cache[mode])
	update_parameters()
	return true

func restore() -> void:
	for entry in entries:
		if is_instance_valid(entry.mesh): entry.mesh.set_surface_override_material(entry.index, entry.original_override)
	mode = "standard"
	if is_instance_valid(outline_shell): outline_shell.hide()

func _exit_tree() -> void:
	restore()
	if is_instance_valid(outline_shell): outline_shell.queue_free()

func _mtoon(source: StandardMaterial3D, region: String) -> ShaderMaterial:
	return MTOON_MATERIALS.create(source, region)

func _custom(source: StandardMaterial3D, region: String) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	var suffix := "_cull_off" if source.cull_mode == BaseMaterial3D.CULL_DISABLED else ""
	var blend := source.transparency in [BaseMaterial3D.TRANSPARENCY_ALPHA, BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS]
	material.shader = load("res://shaders/characters/toon_%s%s.gdshader" % ["blend" if blend else "opaque", suffix])
	material.resource_name = "C · " + source.resource_name
	material.set_shader_parameter("base_color", source.albedo_color)
	material.set_shader_parameter("base_texture", source.albedo_texture)
	material.set_shader_parameter("uv_transform", Vector4(source.uv1_scale.x, source.uv1_scale.y, source.uv1_offset.x, source.uv1_offset.y))
	material.set_shader_parameter("region", FAMILIES.get(region, 3))
	material.set_shader_parameter("alpha_cutoff", source.alpha_scissor_threshold if source.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR else 0.0)
	material.set_shader_parameter("source_roughness", source.roughness)
	return material

func _c1(source: StandardMaterial3D, region: String) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	var suffix := "_cull_off" if source.cull_mode == BaseMaterial3D.CULL_DISABLED else ""
	var blend := source.transparency in [BaseMaterial3D.TRANSPARENCY_ALPHA, BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS]
	material.shader = load("res://shaders/characters/npr_c1_%s%s.gdshader" % ["blend" if blend else "opaque", suffix])
	material.resource_name = "C1 · " + source.resource_name
	material.set_shader_parameter("base_color", source.albedo_color)
	material.set_shader_parameter("base_texture", source.albedo_texture)
	material.set_shader_parameter("uv_transform", Vector4(source.uv1_scale.x, source.uv1_scale.y, source.uv1_offset.x, source.uv1_offset.y))
	material.set_shader_parameter("region", FAMILIES.get(region, 3))
	material.set_shader_parameter("alpha_cutoff", source.alpha_scissor_threshold if source.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR else 0.0)
	material.set_shader_parameter("face_sdf", profile.face_sdf)
	material.set_shader_parameter("body_material_mask", profile.body_material_mask)
	material.set_shader_parameter("has_body_mask", source.albedo_texture != null and source.albedo_texture.resource_name == "服" and profile.body_material_mask != null)
	return material

func _outline(source: StandardMaterial3D, region: String) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/characters/npr_outline.gdshader")
	material.resource_name = "C1 轮廓 · " + source.resource_name
	material.set_shader_parameter("base_texture", source.albedo_texture)
	material.set_shader_parameter("base_color", source.albedo_color)
	material.set_shader_parameter("uv_transform", Vector4(source.uv1_scale.x, source.uv1_scale.y, source.uv1_offset.x, source.uv1_offset.y))
	material.set_shader_parameter("outline_color", Color("414c7a") if region == "hair" else (Color("80535d") if region == "face" else Color("44304d")))
	return material

func _build_outline_shell(source: MeshInstance3D) -> void:
	# An outline-only mesh puts smoothed normals in NORMAL, so GPU skinning
	# transforms them correctly. CUSTOM0 would remain unskinned without extra work.
	var selected: Array[Dictionary] = []
	for entry in entries:
		if entry.has("outline"): selected.append(entry)
	if selected.is_empty(): return
	var key := str(source.mesh.get_instance_id()) + ":" + str(selected.map(func(e): return e.index))
	var derived: ArrayMesh = outline_mesh_cache.get(key)
	if derived == null:
		derived = ArrayMesh.new()
		for shape in source.mesh.get_blend_shape_count(): derived.add_blend_shape(source.mesh.get_blend_shape_name(shape))
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
					# Preserve opposite-facing sides of thin ribbons; no cancellation.
					if candidate.dot(normals[i]) > 0.0: average += candidate
				if average.length_squared() > 0.0001: normals[i] = average.normalized()
			arrays[Mesh.ARRAY_NORMAL] = normals
			var blend_arrays := source.mesh.surface_get_blend_shape_arrays(entry.index)
			derived.add_surface_from_arrays(source.mesh.surface_get_primitive_type(entry.index), arrays, blend_arrays)
			derived.surface_set_name(derived.get_surface_count() - 1, entry.name)
			# Keep a valid fallback while the renderer attaches instance overrides.
			derived.surface_set_material(derived.get_surface_count() - 1, entry.source)
		outline_mesh_cache[key] = derived
	outline_shell = MeshInstance3D.new()
	outline_shell.name = "CharacterNPROutline"
	outline_shell.set_meta("character_npr_outline", true)
	outline_shell.mesh = derived
	outline_shell.skin = source.skin
	outline_shell.skeleton = source.skeleton
	outline_shell.transform = source.transform
	outline_shell.layers = source.layers
	outline_shell.extra_cull_margin = 0.02
	outline_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in selected.size(): outline_shell.set_surface_override_material(i, selected[i].outline)
	source.get_parent().add_child(outline_shell)
	outlined_source = source
	outline_shell.hide()

func update_parameters() -> void:
	if profile == null: return
	for entry in entries:
		var material: ShaderMaterial = entry.cache.custom
		for parameter in ["tone_bands", "edge_softness", "face_softness", "diffuse_gain", "hair_highlight", "eye_highlight", "shadow_multiplier", "skin_shadow_multiplier"]:
			material.set_shader_parameter(parameter, profile.get(parameter))
		for parameter in ["tone_bands", "sdf_softness", "ambient_weight", "c1_diffuse_gain", "c1_shadow_multiplier", "c1_skin_shadow_multiplier", "c1_hair_highlight", "eye_highlight"]:
			entry.cache.genshin.set_shader_parameter(parameter, profile.get(parameter))
		entry.cache.genshin.set_shader_parameter("sdf_enabled", profile.sdf_enabled and profile.face_sdf != null)
		if entry.has("outline"):
			entry.outline.set_shader_parameter("outline_pixels", profile.outline_pixels * (0.60 if entry.region == "face" else 1.0))
	if is_instance_valid(outline_shell): outline_shell.visible = mode == "genshin" and profile.outline_enabled
	update_head()

func update_head() -> void:
	if skeleton == null or head_index < 0: return
	var head_basis := skeleton.global_basis * skeleton.get_bone_global_pose(head_index).basis * head_rest_inverse
	var forward := (head_basis * Vector3.BACK).normalized()
	var right := (head_basis * Vector3.RIGHT).normalized()
	var up := right.cross(forward).normalized() * -1.0
	for entry in entries:
		if entry.region == "face":
			entry.cache.custom.set_shader_parameter("head_forward", forward)
			entry.cache.genshin.set_shader_parameter("head_forward", forward)
			entry.cache.genshin.set_shader_parameter("head_right", right)
			entry.cache.genshin.set_shader_parameter("head_up", up)

func _process(_delta: float) -> void:
	if mode in ["custom", "genshin"]: update_head()
	if is_instance_valid(outline_shell) and outline_shell.visible:
		outline_shell.transform = outlined_source.transform
		for i in outlined_source.get_blend_shape_count():
			var value := outlined_source.get_blend_shape_value(i)
			if not is_equal_approx(value, outline_shell.get_blend_shape_value(i)): outline_shell.set_blend_shape_value(i, value)
