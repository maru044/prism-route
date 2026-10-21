extends "res://scripts/map_1012_vegetation.gd"
## The accepted 1012 grass appearance, with a stable 3D streaming cache.
const VOLUME_STREAMER := preload("res://scripts/grass_volume_streamer.gd")
var world_scene
var volume_streamer

func _init() -> void:
	layout_path = "res://assets/world/current_map_validation/tree_layout.json"

func _refresh_grass_cells() -> void:
	if volume_streamer == null:
		volume_streamer = VOLUME_STREAMER.new()
		add_child(volume_streamer)
		volume_streamer.initialize(self,world_scene)
	volume_streamer.refresh()

func _process(delta: float) -> void:
	if not initialized or not is_instance_valid(target): return
	volume_streamer.tick(delta)
	grass_interaction.enabled = grass_interaction_enabled
	grass_interaction.update(delta,grass_material)

func _raycast_terrain(x: float,z: float) -> Dictionary:
	if volume_streamer == null: return {}
	var nearest: Dictionary = {}
	var distance := INF
	for cell:Vector3i in volume_streamer.columns.get(Vector2i(floori(x/24),floori(z/24)),[]):
		for hit:Dictionary in volume_streamer.sample_surfaces(cell,x,z):
			var p:Vector3 = hit.position
			if p.distance_squared_to(target.global_position)>144*144: continue
			var dy := absf(p.y-target.global_position.y)
			if dy<distance: nearest=hit;distance=dy
	return nearest

func _grass_coverage(point: Vector3,normal: Vector3) -> float:
	if world_scene.architectural_band(point,0.55): return 0.0
	return super._grass_coverage(point,normal)

func get_active_grass_chunk_count() -> int:
	return 0 if volume_streamer == null else volume_streamer.active.size()

func get_pending_grass_chunk_count() -> int:
	return 0 if volume_streamer == null else volume_streamer.queue.size()+int(not volume_streamer.work.is_empty())

func get_pending_visible_grass_chunk_count() -> int:
	return 0 if volume_streamer == null else volume_streamer.pending_visible_count()
