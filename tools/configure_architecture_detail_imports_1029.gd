extends SceneTree
func _initialize() -> void:
	for name: String in ["seam_wear_mask_v1.png","foliage_atlas_v1.png","foliage_leaf_mask_v2.png"]:
		var path:="res://assets/world/architecture_details_1029/"+name+".import"
		var config:=ConfigFile.new();assert(config.load(path)==OK)
		config.set_value("params","mipmaps/generate",true)
		config.set_value("params","compress/mode",0)
		config.set_value("params","process/fix_alpha_border",name.begins_with("foliage"))
		assert(config.save(path)==OK)
	print("ARCHITECTURE_DETAIL_IMPORTS_CONFIGURED");quit()
