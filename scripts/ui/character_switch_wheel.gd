extends CanvasLayer
## Genshin Impact style character switch HUD.
## Supports direct toggle via [Tab] and HUD clicking.

signal character_selected(character_id: String)
const DIALOGUE_INPUT := preload("res://scenes/narrative/dialogue_panel.gd")
const WORLD_CONTROL := preload("res://scripts/world/world_control_context.gd")

const TEAM_MEMBERS: Array[Dictionary] = [
	{
		"id": "lumine",
		"slot": 1,
		"name": "荧",
		"title": "旅行者 · 荧",
		"desc": "风 / 岩元素 · 单手剑 | 异界寻亲旅者",
		"color": Color(0.98, 0.88, 0.52),
		"accent": Color(1.0, 0.95, 0.70),
	}
]

var active_character_id: String = "lumine"
var tween_banner: Tween
var wheel_visible: bool = false

@onready var wheel_root: Control = $WheelRoot
@onready var hud_team_list: VBoxContainer = $TeamHud/TeamList
@onready var switch_banner: PanelContainer = $SwitchBanner
@onready var banner_label: Label = $SwitchBanner/BannerMargin/BannerText

func _ready() -> void:
	layer = 100
	if wheel_root != null:
		wheel_root.visible = false
		wheel_root.process_mode = Node.PROCESS_MODE_DISABLED
	if switch_banner != null:
		switch_banner.visible = false
		switch_banner.modulate.a = 0.0
	if has_node("TeamHud"):
		$TeamHud.visible = false
	_build_team_hud()
	_update_hud_selection()

func set_active_character(id: String) -> void:
	if active_character_id == id:
		return
	active_character_id = id
	_update_hud_selection()

func get_team_info(id: String) -> Dictionary:
	for member: Dictionary in TEAM_MEMBERS:
		if String(member.get("id", "")) == id:
			return member
	return TEAM_MEMBERS[0]

func _build_team_hud() -> void:
	if hud_team_list == null:
		return
	for child in hud_team_list.get_children():
		child.queue_free()

func _update_hud_selection() -> void:
	pass

func _show_banner_message(_id: String) -> void:
	pass

func _input(_event: InputEvent) -> void:
	pass

func _trigger_switch(target_id: String) -> void:
	if WORLD_CONTROL.is_world_input_blocked(get_tree()): return
	if target_id == active_character_id:
		return
	active_character_id = target_id
	character_selected.emit(target_id)

func _cycle_next_character() -> void:
	pass
