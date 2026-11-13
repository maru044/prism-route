extends Node3D
## Temporary visual review of authored placements in the live map.

const SITES := preload("res://scripts/world/npc_preview_sites.gd")
const ACTOR := preload("res://scenes/characters/shared_humanoid_actor.tscn")
const MTOON := preload("res://scripts/characters/mtoon_materials.gd")
const CATALOG := "res://assets/characters/roster/catalog.json"
const IDLE := "res://assets/characters/roster/motions/shared_world_A01.tres"
const ORIGINAL_MODELS := {
	"ganyu": "res://scenes/characters/ganyu.tscn",
	"keqing": "res://assets/characters/import_tests_local/keqing/keqing_fixed.vrm",
	"hutao": "res://assets/characters/import_tests_local/hutao/hutao_fixed.vrm",
	"sparkle": "res://assets/characters/import_tests_local/huahuo/huahuo_fixed.vrm",
}
const LOAD_DISTANCE := 96.0
const RELEASE_DISTANCE := 125.0

var world
var sites: Array[Marker3D] = []
var actors: Dictionary = {}
var models: Dictionary = {}
var pending: Dictionary = {}
var failed: Dictionary = {}
var review_menu: MenuButton
var _refresh_after := 0.0


func initialize(map: Node3D) -> void:
	world = map
	models = ORIGINAL_MODELS.duplicate()
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	for profile: Dictionary in catalog.profiles:
		models[profile.id] = profile.model

	var menu := review_menu.get_popup()
	for region: String in SITES.REGIONS:
		var popup := PopupMenu.new()
		popup.name = "Region%d" % menu.item_count
		menu.add_child(popup)
		menu.add_submenu_item(region, String(popup.name))
		popup.id_pressed.connect(_review_site)
		var secondary := region == "次要点位" or region == SITES.CAPE_VISITORS
		for row: Array in SITES.REGIONS[region]:
			var marker := _make_site(row, secondary)
			popup.add_item(row[1], sites.size())
			sites.append(marker)


func add_controls(container: VBoxContainer) -> void:
	review_menu = MenuButton.new()
	review_menu.name = "NPCPlacementReview"
	review_menu.text = "角色点位"
	container.add_child(review_menu)


func close_menu() -> void:
	var menu := review_menu.get_popup()
	for child: Node in menu.get_children():
		if child is PopupMenu:
			child.hide()
	menu.hide()


func _make_site(row: Array, secondary: bool) -> Marker3D:
	var id: String = row[0]
	var marker := Marker3D.new()
	marker.name = id + ("_secondary" if secondary else "")
	var reuse_sparkle := id == "sparkle" and not secondary
	if reuse_sparkle:
		marker.transform = world.initial_ruin.npc_anchor.global_transform
	elif row[2] is NodePath:
		var anchor: Marker3D = world.npc_waypoint_ruins.get_node(row[2])
		marker.transform = anchor.global_transform
	else:
		marker.position = row[2]
		marker.rotation.y = deg_to_rad(row[3])
	marker.set_meta("character_id", id)
	marker.set_meta("label", row[1])
	marker.set_meta("model", models[id])
	marker.set_meta("reuse_sparkle", reuse_sparkle)
	add_child(marker)
	return marker


func _process(delta: float) -> void:
	if not is_instance_valid(world) or not world.test_ready:
		return
	_refresh_after -= delta
	if _refresh_after > 0:
		return
	_refresh_after = 0.15
	var camera: Camera3D = world.active_camera()
	if world.free_mode:
		camera = world.camera
	if not is_instance_valid(camera):
		return
	var nearest: Marker3D
	var nearest_distance := LOAD_DISTANCE * LOAD_DISTANCE
	for site: Marker3D in sites:
		if site.get_meta("reuse_sparkle"):
			continue
		var id: String = site.get_meta("character_id")
		var distance := camera.global_position.distance_squared_to(site.global_position)
		var same_as_player: bool = world.character_mode and id == world.character.active_character_id
		if actors.has(site):
			if same_as_player or distance > RELEASE_DISTANCE * RELEASE_DISTANCE:
				var actor: Node3D = actors[site]
				actors.erase(site)
				actor.queue_free()
			continue
		if not same_as_player and not failed.has(site.get_meta("model")) and distance < nearest_distance:
			nearest_distance = distance
			nearest = site
	# At most one model is in flight. Don't retain completed distant models.
	if not pending.is_empty():
		var path: String = pending.path
		var result := ResourceLoader.load_threaded_get_status(path)
		if result == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
		var site: Marker3D = pending.site
		pending.clear()
		if result != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			var packed := ResourceLoader.load_threaded_get(path) as PackedScene
			var id: String = site.get_meta("character_id")
			if packed == null:
				failed[path] = true
				push_warning("Could not load NPC preview " + path)
			elif camera.global_position.distance_to(site.global_position) < LOAD_DISTANCE and not (world.character_mode and id == world.character.active_character_id):
				_instance_actor(site, packed)
		else:
			failed[path] = true
			push_warning("Could not load NPC preview " + path)
		return
	if nearest != null:
		var path: String = nearest.get_meta("model")
		var error := ResourceLoader.load_threaded_request(path, "PackedScene")
		if error == OK:
			pending = {"site": nearest, "path": path}
		else:
			failed[path] = true
			push_warning("Could not request NPC preview " + path)


func _instance_actor(site: Marker3D, packed: PackedScene) -> void:
	var actor = ACTOR.instantiate()
	actor.name = "StandingPreview"
	actor.preview_model = packed
	actor.model_resource = site.get_meta("model")
	actor.motion_resource = IDLE
	actor.preview_pose_only = true
	actor.initialized.connect(func():
		MTOON.apply(actor.character, site.get_meta("character_id"))
	)
	actors[site] = actor
	site.add_child(actor)


func _review_site(index: int) -> void:
	if not world.test_ready or not world.is_world_input_allowed():
		return
	var site := sites[index]
	var id: String = site.get_meta("character_id")
	# When reviewing the active avatar, use another existing player profile.
	if world.character_mode and world.character.active_character_id == id:
		world.character.switch_character("ganyu" if id == "lumine" else "lumine")
	if not world.character_mode:
		world.character_mode = true

	var point := site.global_position
	var front := site.global_basis.z
	var capsule := PhysicsShapeQueryParameters3D.new()
	var shape: CollisionShape3D = world.character.get_node("CollisionShape3D")
	capsule.shape = shape.shape
	capsule.collision_mask = 32 | 64
	capsule.exclude = [world.character.get_rid()]
	var space := get_world_3d().direct_space_state
	for angle: float in [0.0, 45.0, -45.0, 90.0, -90.0, 135.0, -135.0, 180.0]:
		var offset := front.rotated(Vector3.UP, deg_to_rad(angle)) * 2.25
		var hit: Dictionary = world._ray(point + offset)
		if hit.is_empty() or absf(hit.position.y - point.y) > 0.5 or hit.normal.y < 0.72:
			continue
		var floor_point: Vector3 = hit.position
		capsule.transform.origin = floor_point + shape.position + Vector3.UP * 0.025
		if not space.intersect_shape(capsule, 1).is_empty():
			continue
		var sight := PhysicsRayQueryParameters3D.create(floor_point + Vector3.UP * 1.25, point + Vector3.UP * 1.20, 32)
		if not space.intersect_ray(sight).is_empty():
			continue
		world.character.set_spawn(floor_point + Vector3.UP * 0.08, atan2(offset.x, offset.z) + PI)
		world.set_free(false)
		world.spawn_menu.select(-1)
		world.status.text = "%s · 角色点位" % site.get_meta("label")
		return
	world.set_free(true)
	world.spawn_menu.select(-1)
	world.camera.global_position = point + Vector3.UP * 1.5 + front * 1.65
	world.camera.look_at(point + Vector3.UP * 0.95)
	world.status.text = "%s · 自由镜头" % site.get_meta("label")
