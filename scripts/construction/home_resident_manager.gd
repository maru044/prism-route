class_name HomeResidentManager
extends RefCounted
## Manages resident assignments between unlocked companions and home plot rooms.
## Enforces 1-to-1 uniqueness: one resident per room, and one room per resident.

signal assignment_changed(room_id: String, character_id: String)

## Maps room_id -> character_id
var _assignments: Dictionary = {}

func assign_resident(room_id: String, character_id: String) -> bool:
	if room_id.is_empty():
		return false
	if character_id.is_empty():
		unassign_room(room_id)
		return true

	# If the character is already living in another room, vacate that room first
	var previous_room := get_room_for_character(character_id)
	if not previous_room.is_empty() and previous_room != room_id:
		_assignments.erase(previous_room)
		assignment_changed.emit(previous_room, "")

	_assignments[room_id] = character_id
	assignment_changed.emit(room_id, character_id)
	return true

func unassign_room(room_id: String) -> void:
	if _assignments.has(room_id):
		_assignments.erase(room_id)
		assignment_changed.emit(room_id, "")

func unassign_character(character_id: String) -> void:
	var room_id := get_room_for_character(character_id)
	if not room_id.is_empty():
		unassign_room(room_id)

func get_resident(room_id: String) -> String:
	return str(_assignments.get(room_id, ""))

func get_room_for_character(character_id: String) -> String:
	for r_id: String in _assignments:
		if str(_assignments[r_id]) == character_id:
			return r_id
	return ""

func is_room_occupied(room_id: String) -> bool:
	return _assignments.has(room_id) and not str(_assignments[room_id]).is_empty()

func is_character_housed(character_id: String) -> bool:
	return not get_room_for_character(character_id).is_empty()

func get_all_assignments() -> Dictionary:
	return _assignments.duplicate(true)

func clear_all() -> void:
	_assignments.clear()

func to_dict() -> Dictionary:
	return {
		"version": 1,
		"assignments": _assignments.duplicate(true)
	}

func from_dict(data: Dictionary) -> void:
	_assignments.clear()
	var raw: Variant = data.get("assignments")
	if raw is Dictionary:
		for r_id in raw:
			var char_id = str(raw[r_id])
			if not str(r_id).is_empty() and not char_id.is_empty():
				_assignments[str(r_id)] = char_id
