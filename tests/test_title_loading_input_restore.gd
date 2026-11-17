extends SceneTree

const LOADING_SCREEN := preload("res://scripts/ui/title_loading.gd")
const WORLD_CONTROL := preload("res://scripts/world/world_control_context.gd")

class MockWorld extends Node:
	var sync_called := false
	func _sync_actor_controls() -> void:
		sync_called = true

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("--- Running test_title_loading_input_restore ---")
	var world := MockWorld.new()
	root.add_child(world)
	
	var loading := LOADING_SCREEN.new()
	root.add_child(loading)
	loading._target_world = world
	
	# 1. Assert input is blocked while loading is active
	assert(WORLD_CONTROL.is_world_input_blocked(self), "Input should be blocked while loading screen is in tree")
	assert(not world.sync_called, "Sync should not be called yet")
	
	# 2. Queue free loading screen and wait for tree exit + deferred sync
	loading.queue_free()
	await process_frame
	await process_frame
	
	# 3. Assert input is unblocked and world sync was called
	assert(not WORLD_CONTROL.is_world_input_blocked(self), "Input should be unblocked after loading screen exits tree")
	assert(world.sync_called, "world._sync_actor_controls() should have been called deferred on tree exit")
	
	world.queue_free()
	await process_frame
	print("--- ALL TITLE LOADING TESTS PASSED ---")
	quit(0)
