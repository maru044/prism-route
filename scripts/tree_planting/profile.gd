class_name TreePlantingProfile
extends Resource
## Test-only configuration. A new map/tree library can use another .tres.
@export_group("地形与树位")
@export var terrain: PackedScene
@export_file("*.json") var terrain_metadata := ""
@export_file("*.json") var baseline_layout := ""
@export_file("*.json") var test_edits_path := "res://assets/world/tree_planting_test/edits.json"
@export_group("树种与色板")
@export var species: Array[Resource] = []
@export var palettes: Array[Resource] = []
@export_group("局部编辑")
@export var initial_center := Vector3(-450, 63, 1050)
@export_range(20, 300, 5) var edit_radius := 80.0
@export_range(1, 80, 1) var height_band := 10.0
@export_range(5, 150, 1) var editable_limit := 40
@export_group("材质预览")
@export var architecture: Material
@export var terrain_material: Material
@export var sky: Material

func find_species(id: String) -> Resource:
	for item: Resource in species:
		if item != null and item.id == id:return item
	return null

func find_palette(id: String) -> Resource:
	for item: Resource in palettes:
		if item != null and item.id == id:return item
	return null
