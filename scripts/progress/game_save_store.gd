extends RefCounted

const DIRECTORY := "user://saves"
const VERSION := 1
const AUTO := "auto"
const MANUAL := ["slot_1", "slot_2", "slot_3"]
const SLOTS := [AUTO, "slot_1", "slot_2", "slot_3"]
const REQUIRED_SECTIONS := ["world", "progress", "construction", "chat"]

static func read(slot: String) -> Dictionary:
	if slot not in SLOTS:
		return {}
	var path := _path(slot)
	var snapshot := _read_file(path)
	return _read_file(path + ".backup") if snapshot.is_empty() else snapshot

static func latest() -> String:
	var slot := ""
	var newest := -1.0
	for id: String in SLOTS:
		var snapshot := read(id)
		var time := float(snapshot.get("saved_at", -1.0))
		if time > newest:
			newest = time
			slot = id
	return slot

static func label(slot: String) -> String:
	return "自动存档" if slot == AUTO else "存档 " + slot.trim_prefix("slot_")

static func write(slot: String, sections: Dictionary) -> Error:
	if slot not in SLOTS:
		return ERR_INVALID_PARAMETER
	var error := DirAccess.make_dir_recursive_absolute(DIRECTORY)
	if error != OK:
		return error
	var path := _path(slot)
	var pending := path + ".pending"
	var file := FileAccess.open(pending, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({
		"version": VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"sections": sections,
	}))
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK:
		return error
	if _read_file(pending).is_empty():
		return ERR_FILE_CORRUPT
	if not _read_file(path).is_empty():
		error = DirAccess.rename_absolute(path, path + ".backup")
		if error != OK:
			return error
	return DirAccess.rename_absolute(pending, path)

static func _path(slot: String) -> String:
	return DIRECTORY.path_join(slot + ".json")

static func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary or value.get("version") != VERSION:
		return {}
	var time: Variant = value.get("saved_at")
	var sections: Variant = value.get("sections")
	if not (time is float or time is int) or not is_finite(time) or time <= 0 or not sections is Dictionary:
		return {}
	for key: String in REQUIRED_SECTIONS:
		if not sections.get(key) is Dictionary:
			return {}
	return value
