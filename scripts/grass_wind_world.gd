extends Node
## Shared wind material and immutable indexed grass LODs for the 1021 world.
enum Mode { BREEZE, STRONG, AUTO }
const MESH := preload("res://assets/vegetation/models/grass_star_3card_gust_v7.glb")
const SHADER := preload("res://assets/vegetation/shaders/grass_world_wind.gdshader")
const SETTINGS := preload("res://scripts/grass_wind_settings.gd")
const TRANSITION_SECONDS := SETTINGS.TRANSITION_SECONDS
const CYCLE_SECONDS := SETTINGS.CYCLE_SECONDS
const CULL_MARGIN := 1.8
# Native LOD edge errors for approximately 18 m and 44 m at 1080p / 60°.
# Godot uses projected size, so narrower FOV and higher resolutions retain detail longer.
const MIDDLE_LOD_ERROR := 0.019245
const FAR_LOD_ERROR := 0.047044

var material: ShaderMaterial
var mode := Mode.AUTO
var elapsed := 0.0
var blend := 0.0
var auto_epoch := 0.0
var running := true

func initialize(vegetation) -> void:
	material = vegetation.grass_material
	apply_wind_material(material)
	var source: Mesh = vegetation._extract_first_mesh(MESH)
	# Keep the existing grass envelope used by the baked-store AABBs.
	assert(source.get_aabb().is_equal_approx(vegetation.grass_mesh.get_aabb()))
	vegetation.grass_mesh = make_presentation_mesh(source, material, 4, true)
	advance(0.0)

static func apply_wind_material(material: ShaderMaterial) -> void:
	# Preserve the exact world's biome, alpha, LOD and interaction settings.
	var settings: Dictionary = {}
	for uniform: Dictionary in material.shader.get_shader_uniform_list():
		var value: Variant = material.get_shader_parameter(uniform.name)
		if value != null:
			settings[uniform.name] = value
	material.shader = SHADER
	for parameter: String in settings:
		material.set_shader_parameter(parameter, settings[parameter])
	SETTINGS.apply(material, SETTINGS.DEFAULT_PARAMETERS)
	material.set_shader_parameter("gust_shared_curve", true)
	material.set_shader_parameter("gust_distance_lod", true)

static func make_presentation_mesh(source: Mesh, material: ShaderMaterial, segments: int, use_mesh_lods := false) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var width := source.get_aabb().size.x
	var height := source.get_aabb().size.y
	for card in 3:
		var angle := float(card) * PI / 3.0
		var right := Vector3(cos(angle), 0, -sin(angle)) * width * 0.5
		for row in segments + 1:
			var u := float(row) / segments
			for side: int in [-1,1]:
				vertices.append(right * side + Vector3.UP * height * u)
				normals.append(Vector3.UP)
				colors.append(Color(u, u, u, 1))
				# glTF flips Blender's V: roots sample the atlas bottom (V=1).
				uvs.append(Vector2(float(side + 1) * 0.5, 1.0 - u))
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = _card_indices(segments, 1)
	var lods := {}
	if use_mesh_lods:
		assert(segments == 4)
		lods[MIDDLE_LOD_ERROR] = _card_indices(segments, 2)
		lods[FAR_LOD_ERROR] = _card_indices(segments, 4)
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], lods)
	result.surface_set_material(0, material)
	return result

static func _card_indices(segments: int, step: int) -> PackedInt32Array:
	var indices := PackedInt32Array()
	for card in 3:
		var base := card * (segments + 1) * 2
		for row in range(0, segments, step):
			var bottom := base + row * 2
			var top := bottom + step * 2
			indices.append_array([bottom, bottom + 1, top + 1, bottom, top + 1, top])
	return indices

func set_mode(value: int) -> void:
	mode = clampi(value, Mode.BREEZE, Mode.AUTO)
	if mode == Mode.AUTO:
		auto_epoch = elapsed

func _process(delta: float) -> void:
	if running:
		advance(delta)

func advance(delta: float) -> void:
	elapsed += delta
	var phase := fposmod(elapsed - auto_epoch, CYCLE_SECONDS)
	var strong := mode == Mode.STRONG or (mode == Mode.AUTO and phase >= 8.0 and phase < 19.0)
	blend = move_toward(blend, 1.0 if strong else 0.0, delta / TRANSITION_SECONDS)
	material.set_shader_parameter("gust_mix", blend)
	material.set_shader_parameter("gust_time", elapsed)
	SETTINGS.update_shared_curve(material, elapsed)
