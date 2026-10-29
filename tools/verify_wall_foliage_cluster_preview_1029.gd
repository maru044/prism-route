extends SceneTree
## Compatibility for --script checks: load the exact current main scene, then
## run the same in-scene verifier used by the normal launcher -Verify switch.
func _initialize() -> void:call_deferred("run")
func run() -> void:
    var entry: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/architecture_details_1029/preview_entry.json"))
    if change_scene_to_file(str(entry.scene))!=OK:quit(1);return
    await process_frame
    while current_scene==null:await process_frame
    while not current_scene.ready_for_review:await process_frame
    current_scene.start_verification()
