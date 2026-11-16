extends RefCounted

const PATH := "user://graphics.cfg"
const AUDIO_DEFAULTS := "res://assets/audio/world_1030/settings.json"
const QUALITY_NAMES := ["高画质", "中画质", "最低画质"]
const AUDIO_KEYS := ["enabled", "master", "ambience", "actions"]

static func load_config() -> ConfigFile:
	var config := ConfigFile.new()
	config.load(PATH)
	return config

static func quality() -> int:
	var config := load_config()
	var legacy: Variant = config.get_value("graphics", "performance", false)
	var preset: Variant = config.get_value("graphics", "preset", 1 if legacy == true else 0)
	return preset if preset is int and preset >= 0 and preset < QUALITY_NAMES.size() else 0

static func audio() -> Dictionary:
	var defaults: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AUDIO_DEFAULTS))
	var config := load_config()
	for key: String in AUDIO_KEYS:
		var value: Variant = config.get_value("audio", key, defaults[key])
		if key == "enabled":
			if value is bool:
				defaults[key] = value
		elif value is float or value is int:
			defaults[key] = clampf(float(value), 0.0, 1.0)
	return defaults

static func store(section: String, key: String, value: Variant) -> Error:
	var config := load_config()
	config.set_value(section, key, value)
	return config.save(PATH)

static func apply_viewport(viewport: Viewport, quality_index: int) -> void:
	var high := quality_index == 0
	viewport.msaa_3d = Viewport.MSAA_4X if high else Viewport.MSAA_2X
	viewport.scaling_3d_scale = 1.0 if high else .90
