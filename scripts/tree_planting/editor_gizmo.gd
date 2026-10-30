extends Control
## Screen-size handles remain easy to grab regardless of tree size or distance.
var ui
const COLORS={"X":Color("f07571"),"Y":Color("91dc87"),"Z":Color("76b8f5")}
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func endpoints() -> Dictionary:
	if not is_instance_valid(ui.selected):return {}
	var camera: Camera3D=ui.scene.camera;var p: Vector3=ui.selected.global_position
	if camera.is_position_behind(p):return {}
	var result: Dictionary={"root":camera.unproject_position(p)}
	var length: float=maxf(.3,camera.global_position.distance_to(p)*.13)
	for key: String in COLORS:
		var direction: Vector3={"X":Vector3.RIGHT,"Y":Vector3.UP,"Z":Vector3.BACK}[key]
		result[key]=camera.unproject_position(p+direction*length)
	return result
func pick(screen: Vector2) -> String:
	var points:=endpoints()
	if points.is_empty():return ""
	if ui.mode=="rotate":return "ROTATE" if absf(screen.distance_to(points.root)-55.)<12. else ""
	if ui.mode=="scale":return "SCALE" if screen.distance_to(points.root+Vector2(55,-55))<15. else ""
	if ui.mode!="move" or screen.distance_to(points.root)<16:return ""
	var result:="";var nearest:=12.
	for key: String in COLORS:
		if not axis_visible(points.root,points[key]):continue
		var distance: float=screen.distance_to(Geometry2D.get_closest_point_to_segment(screen,points.root,points[key]))
		if distance<nearest:nearest=distance;result=key
	return result
func axis_visible(root: Vector2,end: Vector2) -> bool:
	# A view-aligned axis can project to a point; its arrow triangle has no area.
	return root.is_finite() and end.is_finite() and root.distance_squared_to(end)>4.
func _draw() -> void:
	var points:=endpoints()
	if points.is_empty():return
	var root: Vector2=points.root
	if ui.mode=="move":
		for key: String in COLORS:
			if not axis_visible(root,points[key]):continue
			var end: Vector2=points[key];var direction: Vector2=(end-root).normalized()
			var color: Color=COLORS[key]
			if ui.gesture.dragging and ui.gesture.axis==key:color=Color.WHITE
			draw_line(root,end,color,3.,true)
			var side:=direction.orthogonal()*5.
			draw_colored_polygon(PackedVector2Array([end,end-direction*13.+side,end-direction*13.-side]),color)
			draw_string(ThemeDB.fallback_font,end+Vector2(7,-7),key,HORIZONTAL_ALIGNMENT_LEFT,-1,17,color)
		draw_circle(root,5,Color.WHITE)
	elif ui.mode=="rotate":
		draw_arc(root,55.,0,TAU,64,Color("ffcf82"),3.,true)
	elif ui.mode=="scale":
		var end:=root+Vector2(55,-55);draw_line(root,end,Color("ffcf82"),2.,true)
		draw_rect(Rect2(end-Vector2.ONE*6,Vector2.ONE*12),Color("ffcf82"),false,3.)
