extends "res://scripts/map_1021_vegetation.gd"
## Tree presentation only. Inherit all existing grass generation unchanged.
var birch_assets=preload("res://scripts/tree_planting/birch_assets.gd").new()

func _add_tree_lod_level(parent: Node3D,model_id: int,transforms: Array[Transform3D],palette_id: int,level: int,margin: float) -> void:
	if model_id==3:birch_assets.add_level(self,parent,transforms,palette_id,level,margin)
	else:super._add_tree_lod_level(parent,model_id,transforms,palette_id,level,margin)

func _build_tree_lod() -> void:
	var editor=world_scene.planting
	var buckets: Array[Dictionary]=[{},{},{}]
	var sizes: Array=[TREE_LOD0_CHUNK_SIZE,TREE_LOD1_CHUNK_SIZE,TREE_LOD2_CHUNK_SIZE]
	tree_instance_count=0;large_tree_instance_count=0
	for row: Dictionary in editor.store.all_records().values():
		if editor.ring_ids.has(row.id):continue
		var p:=Vector3(row.position[0],row.position[1],row.position[2])
		var model: int=editor.model_index(row.species);var palette: int=editor.palette_index(row.palette)
		var transform:=Transform3D(Basis(Vector3.UP,float(row.yaw)).scaled(Vector3.ONE*float(row.scale)),p)
		tree_instance_count+=1
		if model>0:large_tree_instance_count+=1
		if record_tree_layout_for_review:review_tree_records.append({"transform":transform,"model":model,"palette":palette,"id":row.id})
		for level in 3:
			var cell:=Vector2i(floori(p.x/sizes[level]),floori(p.z/sizes[level]))
			var key:="%d,%d,%d,%d"%[cell.x,cell.y,palette,model]
			if not buckets[level].has(key):buckets[level][key]={"cell":cell,"model":model,"palette":palette,"transforms":[],"ids":[]}
			buckets[level][key].transforms.append(transform);buckets[level][key].ids.append(row.id)
	for level in 3:
		for bucket: Dictionary in buckets[level].values():
			var origin:=Vector3(bucket.cell.x*sizes[level],0,bucket.cell.y*sizes[level])
			var transforms: Array[Transform3D]=[]
			for transform: Transform3D in bucket.transforms:
				transform.origin-=origin;transforms.append(transform)
			var chunk:=Node3D.new();chunk.name="TreeLOD%dChunk_%d"%[level,get_child_count()];chunk.position=origin;add_child(chunk)
			_add_tree_lod_level(chunk,bucket.model,transforms,bucket.palette,level,sizes[level]*1.45)
			editor.bind_bucket(bucket.ids,chunk)
	for node in tree_lod2_nodes:
		node.visibility_range_end=MAP_FAR_TREE_END+TREE_LOD2_CHUNK_SIZE*1.45;node.set_meta("lod_end",node.visibility_range_end)
