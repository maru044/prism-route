class_name TurnActionResource
extends Resource
## Data structure defining an action in the turn-based sensual combat system.

@export var action_id: String = ""
@export var action_name: String = ""
@export_enum("tease", "toy", "endure", "meta", "servant") var action_category: String = "tease"
@export var target_zone: String = ""
@export var base_pleasure: float = 15.0
@export var self_pleasure_defense: float = 0.0 # Percentage damage reduction for the round (0.0 to 1.0)
@export_multiline var description: String = ""
@export_multiline var log_template: String = "{user}使用了{action}！"
