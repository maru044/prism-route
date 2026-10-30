extends RefCounted
## Exact CAD height-field triangles, shared by turf exclusion and tree placement.
const MANIFEST := "res://assets/world/upper_ring_1030/manifest.json"
const HEIGHTS := "res://assets/world/upper_ring_1030/height_field.json"
var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
var field: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(HEIGHTS))
var bounds: Rect2
var center := Vector2(-940,1035)

func _init() -> void:
	var b: Array=manifest.terrain_bounds
	bounds=Rect2(Vector2(b[0][0],b[0][1]),Vector2(b[1][0]-b[0][0],b[1][1]-b[0][1]))

func height_at(p: Vector3) -> float:
	if not bounds.has_point(Vector2(p.x,p.z)):return -INF
	var x: float=(p.x+1450.-float(field.origin_cad[0]))/float(field.step)
	var y: float=(1150.-p.z-float(field.origin_cad[1]))/float(field.step)
	var i:=floori(x);var j:=floori(y);var width:=int(field.width)
	if i<0 or j<0 or i>=width-1 or j>=int(field.height)-1:return -INF
	var diagonal:=int(field.diagonals[j*(width-1)+i])
	if diagonal<0:return -INF
	var u:=x-i;var v:=y-j
	var a: float=field.heights[j*width+i];var b: float=field.heights[j*width+i+1]
	var c: float=field.heights[(j+1)*width+i];var d: float=field.heights[(j+1)*width+i+1]
	if diagonal==0:
		return a*(1-u)+b*(u-v)+d*v if u>=v else a*(1-v)+c*(v-u)+d*u
	return a*(1-u-v)+b*u+c*v if u+v<=1 else b*(1-v)+c*(1-u)+d*(u+v-1)

func blocks(p: Vector3,margin: float=.55) -> bool:
	if p.y<55 or p.y>80 or not bounds.grow(margin).has_point(Vector2(p.x,p.z)):return false
	if Vector2(p.x,p.z).distance_to(center)<float(manifest.outer_radius)+margin:return true
	var top:=height_at(p)
	return is_finite(top) and p.y<top-.08

func excludes_tree(p: Vector3) -> bool:
	return p.y>55 and p.y<83 and Vector2(p.x,p.z).distance_to(center)<float(manifest.outer_radius)+3
