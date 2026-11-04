extends SceneTree
const STORE=preload("res://scripts/grass_baked_store.gd")
class Context:
 extends RefCounted
 var ASSETS="res://assets/world/current_map_validation/"
 var metadata:Dictionary
func _initialize():
 var context=Context.new();context.metadata=JSON.parse_string(FileAccess.get_file_as_string(context.ASSETS+"metadata.json"))
 var expected:String=JSON.parse_string(FileAccess.get_file_as_string(context.ASSETS+"grass_bake/manifest.json")).signature
 assert(STORE.signature(context)==expected)
 var original:String=context.metadata.static_features.initial_ruin_1029.mesh_sha256
 context.metadata.static_features.initial_ruin_1029.mesh_sha256="future_edit"
 assert(STORE.signature(context)!=expected)
 context.metadata.static_features.initial_ruin_1029.mesh_sha256=original
 context.metadata.static_features.upper_ring_1030.mesh_sha256="future_other_feature_edit"
 assert(STORE.signature(context)!=expected)
 print("RHINO_SYNC_SIGNATURE_GUARD passed; no world loaded")
 quit()
