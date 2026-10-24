extends SceneTree
func _initialize() -> void:
	var root_path:="res://assets/world/current_map_validation/"
	var metadata: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(root_path+"metadata.json"))
	var texture: Texture2D=load(root_path+"landscape_mask.res")
	var image:=texture.get_image()
	var bytes:=FileAccess.get_file_as_bytes("res://.current_map_build/landscape_mask.rg16f")
	var size: int=metadata.resolution
	assert(bytes.size()==size*size*4 and image.get_format()==Image.FORMAT_RGH)
	var actual:=image.get_data().slice(0,bytes.size())
	var changed:=0;var pixels:=0
	for i in range(0,bytes.size(),4):
		var differs:=false
		for c in 4:
			if actual[i+c]!=bytes[i+c]:changed+=1;differs=true
		if differs:pixels+=1
	var report:={"resolution":size,"image_format":image.get_format(),"mipmaps":image.get_mipmap_count(),"changed_base_bytes":changed,"changed_pixels":pixels,"pixel_fraction":float(pixels)/(size*size),"loaded_mask_matches_latest_raw":changed==0,"note":"This RG16F texture stores CAD distance and height, not meadow dry/green colour."}
	DirAccess.make_dir_recursive_absolute("res://.vegetation_art_build/color_1024")
	FileAccess.open("res://.vegetation_art_build/color_1024/mask_audit.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("MEADOW_MASK_AUDIT ",JSON.stringify(report));quit()
