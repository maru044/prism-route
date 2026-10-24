@tool
class_name TreePlantingSpecies
extends Resource
## A replaceable tree asset; IDs are saved independently of list order.
@export var id := "tree"
@export var display_name := "树木"
@export var model: PackedScene
@export var leaf_texture: Texture2D
@export var foliage_name_contains := "foliage"
@export var atlas_grid := Vector2(2, 2)
@export var model_scale := 1.0
@export var canopy_normal_weight := 0.34
