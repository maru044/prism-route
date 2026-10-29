extends SceneTree
const SCENE=preload("res://archive/foliage_previews_1029_rejected/wall_foliage_single_leaf_rejected.tscn")
const OUT="res://docs/wall_foliage_art_prototype_1029/"
var prototype
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await process_frame
func capture(name: String) -> void:
	await frames(6);await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUT+name+".png")==OK)
func run() -> void:
	Engine.max_fps=60;root.size=Vector2i(1920,1080)
	prototype=SCENE.instantiate();prototype.automation_enabled=true;root.add_child(prototype)
	while not prototype.ready_for_review:await process_frame
	assert(prototype.foliage.multimesh.instance_count==prototype.leaves.size())
	prototype.ui.hide();prototype.set_view(0);await capture("prototype_front")
	prototype.set_view(1);await capture("prototype_oblique")
	prototype.set_view(0);prototype.ui.show();await capture("prototype_ui")
	prototype.set_reference_visible(true);await frames(2);assert(prototype.reference.visible)
	prototype.set_reference_visible(false);assert(not prototype.reference.visible)
	FileAccess.open(OUT+"leaf_layout.json",FileAccess.WRITE).store_string(JSON.stringify(prototype.leaves,"  "))
	print("WALL_FOLIAGE_ART_PROTOTYPE_CAPTURED leaves=",prototype.leaves.size())
	quit()
