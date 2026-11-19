extends RefCounted
## Source geometry exists in the workspace. The export audit verifies its
## imported counterpart in the PCK using the generated geometry manifest.
const EXPORT_MANIFEST := "res://export_grass_geometry.json"

static var _export_geometry: Dictionary = {}

static func matches(path: String, source_sha256: String) -> bool:
	if FileAccess.file_exists(path):
		if not source_sha256.is_empty() and FileAccess.get_sha256(path) == source_sha256:
			return true
	else:
		if _export_geometry.is_empty() and FileAccess.file_exists(EXPORT_MANIFEST):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(EXPORT_MANIFEST))
			if parsed is Dictionary:
				_export_geometry = parsed
		var row: Dictionary = _export_geometry.get(path, {})
		if not source_sha256.is_empty() and row.get("source_sha256") == source_sha256:
			var imported: String = row.imported
			var remap := ConfigFile.new()
			if remap.load(path + ".import") == OK and remap.get_value("remap", "path", "") == imported \
					and FileAccess.file_exists(imported) and ResourceLoader.exists(path, "PackedScene"):
				return true
	push_warning("Grass source geometry check failed: " + path)
	return false
