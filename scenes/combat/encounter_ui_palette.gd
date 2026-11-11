class_name EncounterUIPalette
extends Resource

@export_group("Command glass")
@export var glass_top := Color("#4f2b82")
@export var glass_bottom := Color("#388ac5")
@export var glass_sheen := Color("#a989f4")

@export_group("Battle backdrop")
@export var edge_upper := Color("#572e9c")
@export var edge_lower := Color("#128599")
@export var edge_motif := Color("#c7b2f2")
@export_range(0.0, 1.0, 0.01) var edge_strength := 0.78

@export_group("Status bars")
@export var rail := Color("#231832bc")
@export var player_low := Color("#ffa8d5")
@export var player_high := Color("#f34aab")
@export var opponent_low := Color("#f62e74")
@export var opponent_high := Color("#ffad42")

@export_group("Text and dialogue")
@export var text := Color("#fff8ff")
@export var secondary := Color("#e2d5fa")
@export var accent := Color("#a0e8ff")
@export var speaker := Color("#ffacd9")
@export var shade := Color("#110c23")
