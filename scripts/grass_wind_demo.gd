extends Node
## Small-grove comparison only: a smooth additional gust over the original breeze.
enum Mode { BREEZE, STRONG, AUTO }
const TRANSITION_SECONDS := 3.0
const CYCLE_SECONDS := 24.0
var material: ShaderMaterial
var mode := Mode.AUTO
var elapsed := 0.0
var blend := 0.0
var running := true
var menu: OptionButton
var status: Label
var ui_clock := 0.0

func initialize(value: ShaderMaterial) -> void:
	material=value
	var layer:=CanvasLayer.new();layer.name="GrassWindControls";add_child(layer)
	var panel:=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left=-290;panel.offset_top=20;panel.offset_right=-20;panel.offset_bottom=124
	var style:=StyleBoxFlat.new();style.bg_color=Color(0.05,0.10,0.12,0.68)
	style.content_margin_left=14;style.content_margin_right=14;style.content_margin_top=10;style.content_margin_bottom=10
	style.set_corner_radius_all(7);panel.add_theme_stylebox_override("panel",style);layer.add_child(panel)
	var box:=VBoxContainer.new();panel.add_child(box)
	var title:=Label.new();title.text="草地风力测试";box.add_child(title)
	menu=OptionButton.new();menu.name="WindMode"
	for text: String in ["微风","大风 · 全场同步弯折","自动 · 微风 / 大风"]:menu.add_item(text)
	menu.select(Mode.AUTO);menu.item_selected.connect(set_mode);box.add_child(menu)
	status=Label.new();status.add_theme_font_size_override("font_size",14);box.add_child(status)
	advance(0.0)

func set_mode(value: int) -> void:
	mode=clampi(value,Mode.BREEZE,Mode.AUTO);menu.select(mode)
	# Returning to auto begins with a calm interval, without resetting the wind clock.
	if mode==Mode.AUTO:auto_epoch=elapsed

var auto_epoch := 0.0

func _process(delta: float) -> void:
	if running:advance(delta)

func advance(delta: float) -> void:
	elapsed+=delta
	var phase:=fposmod(elapsed-auto_epoch,CYCLE_SECONDS)
	var strong:=mode==Mode.STRONG or (mode==Mode.AUTO and phase>=8.0 and phase<19.0)
	blend=move_toward(blend,1.0 if strong else 0.0,delta/TRANSITION_SECONDS)
	material.set_shader_parameter("gust_mix",blend)
	material.set_shader_parameter("gust_time",elapsed)
	ui_clock+=delta
	if ui_clock>=0.1 or delta==0.0:
		ui_clock=0.0
		status.text=("正在增强" if strong and blend<1 else "正在减弱" if not strong and blend>0 else "同步弯折 / 回弹 · 约 2 次/秒" if strong else "微风轻摆")+" · %d%%"%roundi(blend*100)
