extends RefCounted
## Offline screenshot review only; no scene, input handler, or on-screen controls.
const STYLE := preload("res://scripts/foliage_style.gd")
var candidate_enabled := true
var fill_strength := STYLE.FILL_STRENGTH
var shadow_relief := STYLE.SHADOW_RELIEF
var green_mode := 0
var records: Array[Dictionary] = []

func set_candidate(enabled: bool) -> void:
	candidate_enabled=enabled
	for row: Dictionary in records:
		var material: ShaderMaterial=row.material
		material.shader=row.candidate if enabled else row.baseline
		for name: String in row.parameters:material.set_shader_parameter(name,row.parameters[name])
		if row.green:
			if row.instance_palette:
				for node: GeometryInstance3D in row.nodes:
					for name: String in STYLE.GREEN_VALUES:
						node.set_instance_shader_parameter(name,row.node_parameters[node.get_instance_id()][name])
			if green_mode>0:
				for name: String in STYLE.GREEN_VALUES:
					if row.instance_palette:
						for node: GeometryInstance3D in row.nodes:node.set_instance_shader_parameter(name,STYLE.GREEN_VALUES[name])
					else:material.set_shader_parameter(name,STYLE.GREEN_VALUES[name])
				material.set_shader_parameter("use_biome_palette",false)
		if enabled:
			material.set_shader_parameter("foliage_backlight_fill",fill_strength)
			material.set_shader_parameter("foliage_shadow_relief",shadow_relief)

func set_green_mode(mode: int) -> void:
	green_mode=posmod(mode,2)
	set_candidate(candidate_enabled)
