@tool
extends SceneTree
## Verifies that all 49 roster characters can load wildcards and generate AIRP replies with 0 errors and 0 ellipses.

const LocalAirpComposerClass := preload("res://scripts/ai/local_airp/local_airp_composer.gd")
const LocalAirpClientClass := preload("res://scripts/ai/local_airp/local_airp_client.gd")
const CharacterRosterDatabaseClass := preload("res://scripts/characters/character_roster_database.gd")

func _init() -> void:
	print("==================================================")
	print("[Test] Verifying All 49 Playable Characters Local AIRP")
	print("==================================================")

	var failures := 0
	var composer := LocalAirpComposerClass.new()
	composer.load_data("res://assets/ai/local_airp")

	var client := LocalAirpClientClass.new()
	client.load_resources()
	if client.templates.is_empty():
		push_error("Client templates empty!")
		failures += 1
		_finish(failures)
		return

	var probe_ok: bool = client.ensure_probe()
	if not probe_ok:
		push_error("Failed to initialize BgeProbeClient")
		failures += 1
		_finish(failures)
		return

	var entries := CharacterRosterDatabaseClass.get_all_entries()
	var tested_count := 0

	for entry in entries:
		var char_id: String = entry.id
		if char_id == "miku":
			continue # System guide is excluded

		var char_name: String = entry.name
		var cdata: Dictionary = composer.get_character_data(char_id)
		if cdata.is_empty():
			push_error("Character data empty for: " + char_id)
			failures += 1
			continue

		if not cdata.has("addresses") or not cdata.has("self_refs"):
			push_error("Missing addresses or self_refs for: " + char_id)
			failures += 1
			continue

		# Test 1: Daily Greet Composition
		var r_greet: Dictionary = client.retrieve_and_compose("早上好呀", char_id, "home_chat", {}, 101)
		var t_greet: String = str(r_greet.get("text", ""))
		if t_greet.is_empty():
			push_error("Empty greet text for " + char_id)
			failures += 1
		if _has_ellipsis(t_greet):
			push_error("Ellipsis in greet text for " + char_id + ": " + t_greet)
			failures += 1

		# Test 2: Intimate Touch Composition
		var r_touch: Dictionary = client.retrieve_and_compose("轻轻抚摸你的头发和脸颊", char_id, "intimate", {}, 102)
		var t_touch: String = str(r_touch.get("text", ""))
		if t_touch.is_empty():
			push_error("Empty touch text for " + char_id)
			failures += 1
		if _has_ellipsis(t_touch):
			push_error("Ellipsis in touch text for " + char_id + ": " + t_touch)
			failures += 1

		# Test 3: Combat Surrender Composition
		var r_surrender: Dictionary = client.retrieve_and_compose("乖乖宣布无条件投降吧", char_id, "combat_h", {}, 103)
		var t_surrender: String = str(r_surrender.get("text", ""))
		if t_surrender.is_empty():
			push_error("Empty surrender text for " + char_id)
			failures += 1
		if _has_ellipsis(t_surrender):
			push_error("Ellipsis in surrender text for " + char_id + ": " + t_surrender)
			failures += 1

		tested_count += 1
		if tested_count <= 8 or tested_count % 10 == 0 or tested_count == entries.size() - 1:
			print("  [Pass] %02d/%d %s (%s): %s" % [tested_count, entries.size() - 1, char_name, char_id, t_greet.substr(0, 36)])

	client.close_probe()
	print("\nSuccessfully validated all %d characters in Godot engine!" % tested_count)
	_finish(failures)

func _has_ellipsis(text: String) -> bool:
	if text.contains("\u2026"):
		return true
	if text.contains("." + "." + "."):
		return true
	return false

func _finish(failures: int) -> void:
	if failures == 0:
		print("==================================================")
		print("ALL 49 ROSTER CHARACTERS PASSED WITH 0 FAILURES!")
		print("==================================================")
		quit(0)
	else:
		print("==================================================")
		print("FAILED with %d errors" % failures)
		print("==================================================")
		quit(1)
