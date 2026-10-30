extends SceneTree
const OUT="res://assets/world/meadow_zone_1030/"
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var annotation: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"shore_annotation.json"))
	root.size=Vector2i(1920,1080)
	var camera:=Camera3D.new();root.add_child(camera);camera.fov=58.;camera.position=Vector3(-160,1800,2100);camera.look_at(Vector3(-250,15,400));camera.make_current()
	var polygon:=PackedVector2Array();var points: Array=[]
	for screen: Array in annotation.screen_polygon:
		var point:=Vector2(screen[0],screen[1])
		var p: Vector3=Plane(Vector3.UP,20.).intersects_ray(camera.project_ray_origin(point),camera.project_ray_normal(point))
		polygon.append(Vector2(p.x,p.z));points.append([p.x,p.z])
	var bounds:=Rect2(polygon[0],Vector2.ZERO)
	for p: Vector2 in polygon:bounds=bounds.expand(p)
	bounds=bounds.grow(12.)
	var image:=Image.create(384,384,false,Image.FORMAT_RF)
	for y in image.get_height():
		for x in image.get_width():
			var p:=bounds.position+(Vector2(x+.5,y+.5)/Vector2(image.get_size()))*bounds.size
			var distance:=INF
			for i in polygon.size():distance=minf(distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,polygon[i],polygon[(i+1)%polygon.size()])))
			if not Geometry2D.is_point_in_polygon(p,polygon):distance=-distance
			image.set_pixel(x,y,Color(distance,0,0,1))
	var texture:=ImageTexture.create_from_image(image)
	texture.set_meta("world_origin",bounds.position);texture.set_meta("world_extent",bounds.size)
	assert(ResourceSaver.save(texture,OUT+"shore_green_sdf.res",ResourceSaver.FLAG_COMPRESS)==OK)
	var data={"origin":[bounds.position.x,bounds.position.y],"extent":[bounds.size.x,bounds.size.y],"polygon":points,"feather_inside_m":80.,"source_annotation":annotation.source,"alignment_error_px":annotation.median_alignment_error_px,"existing_lake_mask":"preserved separately and combined by maximum weight"}
	FileAccess.open(OUT+"shore_region.json",FileAccess.WRITE).store_string(JSON.stringify(data,"  "))
	print("LAKE_SHORE_MASK origin=",bounds.position," extent=",bounds.size," vertices=",polygon.size());quit()
