extends "res://scripts/map_1021.gd"
## Optional F6 diagnostics. The formal map has no comparison controls or jumps.

func _ready() -> void:
	await super._ready()
	if water_manager==null:return
	var panel:=CanvasLayer.new();panel.layer=39;add_child(panel);review_ui_layers.append(panel)
	var box:=VBoxContainer.new();box.position=Vector2(350,18);panel.add_child(box)
	var styles:=OptionButton.new()
	for text: String in ["水面 · 原版对照","水面 · 天空反射 / 浅水","水面 · 局部镜像 / 浅水","实验 · 原生 SSR / 不透明"]:styles.add_item(text)
	styles.select(2);styles.item_selected.connect(water_manager.apply_style);box.add_child(styles)
	var places:=OptionButton.new()
	for text: String in ["水面机位 · 选择地点","南泻湖 · 环塔镜面","北泻湖 · 贴水镜面","南浅水 · 角色涉水"]:places.add_item(text)
	places.item_selected.connect(_water_review_view);box.add_child(places)
	var formal:=Button.new();formal.text="返回正式地图"
	formal.pressed.connect(func():get_tree().change_scene_to_file("res://scenes/map_1021.tscn"));box.add_child(formal)
