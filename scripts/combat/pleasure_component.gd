class_name PleasureComponent
extends Node
## Pleasure component for turn-based sensual combat without endurance (MP-like) mechanics.

signal pleasure_changed(current: float, max_val: float, percentage: float)
signal edging_entered()
signal climax_reached()

@export var character_name: String = "Actor"
@export var max_pleasure: float = 100.0
@export var current_pleasure: float = 0.0
@export var edging_threshold: float = 85.0 # Enters edging state when pleasure >= this

# Sensitivity zones
@export var sensitivity_mouth: float = 1.0
@export var sensitivity_nipples: float = 1.15
@export var sensitivity_anal: float = 1.1
@export var sensitivity_clitoris: float = 1.25

# Meta-cheat parameters provided by NPC
var pleasure_locked: bool = false
var pleasure_cap: float = 90.0
var damage_taken_multiplier: float = 1.0
var damage_dealt_multiplier: float = 1.0

var is_edging: bool = false
var has_reached_climax: bool = false

func reset() -> void:
	current_pleasure = 0.0
	is_edging = false
	has_reached_climax = false
	pleasure_changed.emit(current_pleasure, max_pleasure, 0.0)

func add_pleasure(amount: float, zone: String = "") -> float:
	if has_reached_climax:
		return 0.0
		
	var multiplier := 1.0
	match zone:
		"mouth": multiplier = sensitivity_mouth
		"nipples": multiplier = sensitivity_nipples
		"anal": multiplier = sensitivity_anal
		"clitoris": multiplier = sensitivity_clitoris
		_: multiplier = 1.0
		
	var actual_gain: float = amount * multiplier * damage_taken_multiplier
	current_pleasure += actual_gain
	
	if pleasure_locked and current_pleasure > pleasure_cap:
		current_pleasure = pleasure_cap
		
	if current_pleasure >= max_pleasure:
		current_pleasure = max_pleasure
		has_reached_climax = true
		climax_reached.emit()
	elif current_pleasure >= edging_threshold and not is_edging:
		is_edging = true
		edging_entered.emit()
		
	var pct: float = (current_pleasure / max_pleasure) * 100.0
	pleasure_changed.emit(current_pleasure, max_pleasure, pct)
	return actual_gain

func reduce_pleasure(amount: float) -> void:
	current_pleasure = maxf(0.0, current_pleasure - amount)
	if current_pleasure < edging_threshold:
		is_edging = false
	var pct: float = (current_pleasure / max_pleasure) * 100.0
	pleasure_changed.emit(current_pleasure, max_pleasure, pct)
