extends RefCounted
## Height-aware footprints. Geometry and planting share the same read-only CAD delta.
const MANIFEST := "res://assets/world/initial_ruin_1029/manifest.json"
const BUCKET := 12.0
var entries: Array[Dictionary]=[]
var buckets: Dictionary={}
var bounds := Rect2()
var manifest: Dictionary={}

func _init() -> void:
	manifest=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var first:=true
	for row: Dictionary in manifest.exclusions:
		var polygon:=PackedVector2Array()
		for p: Array in row.polygon:polygon.append(Vector2(p[0],p[1]))
		var minimum:=Vector2(row.bounds[0][0],row.bounds[0][1])
		var maximum:=Vector2(row.bounds[1][0],row.bounds[1][1])
		var rect:=Rect2(minimum,maximum-minimum)
		var index:=entries.size()
		entries.append({"polygon":polygon,"rect":rect,"low":float(row.height[0]),"high":float(row.height[1])})
		bounds=rect if first else bounds.merge(rect);first=false
		var expanded:=rect.grow(3.5)
		for x in range(floori(expanded.position.x/BUCKET),floori(expanded.end.x/BUCKET)+1):
			for z in range(floori(expanded.position.y/BUCKET),floori(expanded.end.y/BUCKET)+1):
				var key:=Vector2i(x,z)
				if not buckets.has(key):buckets[key]=[]
				buckets[key].append(index)

func blocks(point: Vector3,margin: float=.55) -> bool:
	var p:=Vector2(point.x,point.z)
	if not bounds.grow(margin).has_point(p):return false
	var key:=Vector2i(floori(p.x/BUCKET),floori(p.y/BUCKET))
	for index: int in buckets.get(key,[]):
		var entry: Dictionary=entries[index]
		if point.y<entry.low or point.y>entry.high or not (entry.rect as Rect2).grow(margin).has_point(p):continue
		var polygon: PackedVector2Array=entry.polygon
		if Geometry2D.is_point_in_polygon(p,polygon):return true
		if margin<=0.:continue
		for i in polygon.size():
			if p.distance_squared_to(Geometry2D.get_closest_point_to_segment(p,polygon[i],polygon[(i+1)%polygon.size()]))<=margin*margin:return true
	return false
