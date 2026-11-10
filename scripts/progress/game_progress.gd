class_name GameProgress
extends RefCounted
## Lightweight game progress and save boundary data structure.
## Manages tutorial completion, defeat counter, settlement outcome and unlocks.

var tutorial_completed: bool = false
var initial_temple_defeat_count: int = 0
var settlement_outcome: String = ""
var companion_unlocks: Array[String] = []
var world_unlocks: Array[String] = []

signal progress_changed(key: String, new_val)

func mark_tutorial_completed() -> void:
	if not tutorial_completed:
		tutorial_completed = true
		progress_changed.emit("tutorial_completed", true)

func record_defeat() -> void:
	initial_temple_defeat_count += 1
	progress_changed.emit("initial_temple_defeat_count", initial_temple_defeat_count)

func set_settlement_outcome(outcome: String) -> void:
	settlement_outcome = outcome
	progress_changed.emit("settlement_outcome", settlement_outcome)

func unlock_companion(companion_id: String) -> void:
	if not companion_unlocks.has(companion_id):
		companion_unlocks.append(companion_id)
		progress_changed.emit("companion_unlocks", companion_unlocks)

func is_companion_unlocked(companion_id: String) -> bool:
	return companion_unlocks.has(companion_id)

func unlock_world(area_id: String) -> void:
	if not world_unlocks.has(area_id):
		world_unlocks.append(area_id)
		progress_changed.emit("world_unlocks", world_unlocks)

func is_world_unlocked(area_id: String) -> bool:
	return world_unlocks.has(area_id)

func to_dict() -> Dictionary:
	return {
		"tutorial_completed": tutorial_completed,
		"initial_temple_defeat_count": initial_temple_defeat_count,
		"settlement_outcome": settlement_outcome,
		"companion_unlocks": companion_unlocks.duplicate(),
		"world_unlocks": world_unlocks.duplicate()
	}

func from_dict(data: Dictionary) -> void:
	tutorial_completed = data.get("tutorial_completed", false)
	initial_temple_defeat_count = int(data.get("initial_temple_defeat_count", 0))
	settlement_outcome = str(data.get("settlement_outcome", ""))
	companion_unlocks.clear()
	for c in data.get("companion_unlocks", []):
		companion_unlocks.append(str(c))
	world_unlocks.clear()
	for w in data.get("world_unlocks", []):
		world_unlocks.append(str(w))
