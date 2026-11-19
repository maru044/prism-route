@tool
extends SceneTree
## Verifies that secondary NPC placement models are cleanly hidden while preserving spatial records.

const NPCPlacementPreviewClass := preload("res://scripts/world/npc_placement_preview.gd")
const SITES := preload("res://scripts/world/npc_preview_sites.gd")

func _init() -> void:
	print("==================================================")
	print("[Test] Verifying Secondary NPC Model Hiding & Record Retention")
	print("==================================================")

	var preview := NPCPlacementPreviewClass.new()
	root.add_child(preview)

	# Build a mock map object
	var mock_map := Node3D.new()
	var mock_cam := Camera3D.new()
	mock_cam.position = Vector3(0, 5, 0)
	mock_cam.name = "Camera3D"
	mock_map.add_child(mock_cam)

	# Mock methods expected by preview
	var map_script := GDScript.new()
	map_script.source_code = """
extends Node3D
var test_ready: bool = true
var character_mode: bool = false
var free_mode: bool = false
var initial_ruin: Node = null
var npc_waypoint_ruins: Node = null
var cam_ref: Camera3D = null
func active_camera() -> Camera3D:
	return cam_ref
"""
	map_script.reload()
	mock_map.set_script(map_script)
	mock_map.set("cam_ref", mock_cam)

	const NPCWaypointRuinsClass := preload("res://scripts/world/npc_waypoint_ruins.gd")
	var waypoint_ruins = NPCWaypointRuinsClass.new()
	mock_map.add_child(waypoint_ruins)
	waypoint_ruins._ready()
	mock_map.set("npc_waypoint_ruins", waypoint_ruins)

	var initial_ruin_mock := Node3D.new()
	var npc_anchor := Marker3D.new()
	initial_ruin_mock.add_child(npc_anchor)
	initial_ruin_mock.set("npc_anchor", npc_anchor)
	mock_map.add_child(initial_ruin_mock)
	mock_map.set("initial_ruin", initial_ruin_mock)

	root.add_child(mock_map)

	# Initialize preview
	preview.initialize(mock_map)
	assert(preview.sites.size() > 0, "Preview sites should be initialized")
	print("  [Pass] Initialized preview with %d authored sites" % preview.sites.size())

	# Verify secondary site classification and hide_model flag
	var secondary_count := 0
	var secondary_sites_found: Array[String] = []
	for site in preview.sites:
		var is_sec: bool = site.get_meta("is_secondary", false)
		var hide_model: bool = site.get_meta("hide_model", false)

		if is_sec:
			assert(hide_model, "Secondary site must have hide_model = true")
			secondary_count += 1
			secondary_sites_found.append(str(site.name))

	assert(secondary_count >= 15, "Expected at least 15 secondary sites, found %d" % secondary_count)
	print("  [Pass] Verified %d secondary sites correctly marked with hide_model = true" % secondary_count)

	# Move camera right on top of a secondary site (e.g. secondary Barbara in sandbar)
	var barbara_site: Marker3D = null
	for site in preview.sites:
		if site.get_meta("character_id") == "barbara" and site.get_meta("is_secondary"):
			barbara_site = site
			break

	assert(barbara_site != null, "Secondary Barbara site must exist in records")
	mock_cam.position = barbara_site.position

	# Run process tick
	preview._process(0.2)

	# Verify no model actor was spawned for the secondary site
	assert(not preview.actors.has(barbara_site), "Secondary site must not spawn actor in actors dictionary")
	assert(barbara_site.get_child_count() == 0, "Secondary site Marker3D must have zero child meshes")
	print("  [Pass] Camera proximity verified: no 3D model spawned at secondary point")

	# Verify spatial records and review menu items remain intact
	assert(barbara_site.position != Vector3.ZERO, "Spatial position must be recorded")
	assert(barbara_site.has_meta("model"), "Model metadata must be preserved for rollback")
	print("  [Pass] Spatial coordinate records and rollback metadata intact: %s at %s" % [barbara_site.name, str(barbara_site.position)])

	preview.queue_free()
	mock_map.queue_free()

	print("\n==================================================")
	print("[SUCCESS] Secondary NPC model hiding and record retention verified")
	print("==================================================")
	quit(0)
