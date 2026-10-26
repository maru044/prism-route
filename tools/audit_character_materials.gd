extends SceneTree
## Runtime imported-resource audit; never changes the imported scene/materials.
const ATTRIBUTES := {"normal": Mesh.ARRAY_NORMAL, "tangent": Mesh.ARRAY_TANGENT, "color": Mesh.ARRAY_COLOR,
	"uv": Mesh.ARRAY_TEX_UV, "uv2": Mesh.ARRAY_TEX_UV2, "custom0": Mesh.ARRAY_CUSTOM0,
	"custom1": Mesh.ARRAY_CUSTOM1, "custom2": Mesh.ARRAY_CUSTOM2, "custom3": Mesh.ARRAY_CUSTOM3,
	"bones": Mesh.ARRAY_BONES, "weights": Mesh.ARRAY_WEIGHTS}

static func inspect(character: Node) -> Dictionary:
	var rows: Array = []
	var classes := {}
	for node in character.find_children("*", "MeshInstance3D", true, false):
		if node.has_meta("character_npr_outline"): continue
		var mesh: Mesh = node.mesh
		if mesh == null: continue
		for index in mesh.get_surface_count():
			var material: Material = node.get_active_material(index)
			var arrays := mesh.surface_get_arrays(index)
			var texture: Texture2D
			var row := {"mesh": str(character.get_path_to(node)), "surface": index,
				"surface_name": mesh.surface_get_name(index) if mesh is ArrayMesh else "",
				"material_name": material.resource_name if material else "", "class": material.get_class() if material else "null",
				"vertices": arrays[Mesh.ARRAY_VERTEX].size(), "format": mesh.surface_get_format(index),
				"blend_shapes": mesh.get_blend_shape_count() if mesh is ArrayMesh else 0,
				"attributes": {}}
			for slot in ATTRIBUTES: row.attributes[slot] = arrays[ATTRIBUTES[slot]] != null
			if material is StandardMaterial3D:
				texture = material.albedo_texture
				row.merge({"transparency": material.transparency, "alpha_scissor": material.alpha_scissor_threshold,
					"cull_mode": material.cull_mode, "roughness": material.roughness, "metallic": material.metallic,
					"albedo": material.albedo_color.to_html(), "vertex_color_albedo": material.vertex_color_use_as_albedo,
					"normal_enabled": material.normal_enabled, "emission_enabled": material.emission_enabled,
					"texture_filter": material.texture_filter, "texture_repeat": material.texture_repeat,
					"uv_scale": str(material.uv1_scale), "uv_offset": str(material.uv1_offset)})
			elif material is ShaderMaterial:
				row.shader = material.shader.resource_path
				texture = material.get_shader_parameter("_MainTex")
			row.texture = {"path": texture.resource_path, "name": texture.resource_name,
				"width": texture.get_width(), "height": texture.get_height()} if texture else {}
			row.next_pass = material.next_pass != null if material else false
			classes[row["class"]] = classes.get(row["class"], 0) + 1
			rows.append(row)
	return {"surfaces": rows, "material_classes_by_surface": classes,
		"note": "Counts are per drawn surface; source GLB texture semantics require separate inspection."}

static func inspect_source() -> Dictionary:
	var file := FileAccess.open("res://assets/characters/ganyu/ganyu.vrm", FileAccess.READ)
	if file == null: return {"error": "Source not readable"}
	if file.get_32() != 0x46546c67 or file.get_32() != 2: return {"error": "Not GLB2"}
	file.get_32()
	var length := file.get_32()
	if file.get_32() != 0x4e4f534a: return {"error": "Missing JSON chunk"}
	var data: Dictionary = JSON.parse_string(file.get_buffer(length).get_string_from_utf8())
	var images: Array = []
	for image: Dictionary in data.get("images", []):
		images.append({"name": image.get("name", ""), "mime_type": image.get("mimeType", ""), "embedded": image.has("bufferView")})
	var materials: Array = []
	for material: Dictionary in data.get("materials", []):
		materials.append({"name": material.get("name", ""), "alpha": material.get("alphaMode", "OPAQUE"),
			"pbr": material.get("pbrMetallicRoughness", {}), "extensions": material.get("extensions", {}).keys()})
	return {"images": images, "materials": materials, "extensions_used": data.get("extensionsUsed", []),
		"mask_conclusion": "No named SDF/ILM/mask image or declared MToon extension. No custom packed-channel semantics supplied; C0 does not assume any."}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var character: Node3D = load("res://scenes/characters/ganyu.tscn").instantiate()
	root.add_child(character)
	await process_frame
	var report := inspect(character)
	report.source_glb = inspect_source()
	report.engine = Engine.get_version_info()
	report.msaa_enum = root.msaa_3d
	report.source = "res://scenes/characters/ganyu.tscn"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/character_shader_lab"))
	var file := FileAccess.open("res://docs/character_shader_lab/material_audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	for row in report.surfaces:
		print(JSON.stringify(row))
	character.queue_free()
	await process_frame
	quit()
