extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene: Node=load("res://assets/world/current_map_validation/current_region.glb").instantiate()
	var doc:=GLTFDocument.new();var state:=GLTFState.new();doc.append_from_file(ProjectSettings.globalize_path("res://assets/world/current_map_validation/current_region.glb"),state)
	var raw:=doc.generate_scene(state);var nodes: Array=scene.find_children("*","MeshInstance3D",true,false);var old: Array=raw.find_children("*","MeshInstance3D",true,false)
	var file:=FileAccess.open("res://.current_map_build/imported_faces.bin",FileAccess.WRITE);var source:=FileAccess.open("res://.current_map_build/direct_faces.bin",FileAccess.WRITE)
	var rows: Array=[]
	for i in nodes.size():
		var a: Mesh=nodes[i].mesh;var b: Mesh=old[i].mesh
		assert(nodes[i].name==old[i].name)
		var af:=a.get_faces().to_byte_array();var bf:=b.get_faces().to_byte_array()
		rows.append({"id":str(nodes[i].name).get_slice("_",1),"offset":file.get_position(),"source_offset":source.get_position(),"bytes":af.size(),"source_bytes":bf.size(),"imported_format":a.surface_get_format(0),"source_format":b.surface_get_format(0)})
		file.store_buffer(af);source.store_buffer(bf)
	file.close();source.close()
	file=FileAccess.open("res://.current_map_build/imported_faces.json",FileAccess.WRITE);file.store_string(JSON.stringify(rows));file.close();scene.free();raw.free();quit()
