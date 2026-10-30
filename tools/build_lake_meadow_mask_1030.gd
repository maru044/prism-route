extends SceneTree
## Trace only the marked north-lake pocket, on the documented overview camera.
const OUT="res://assets/world/meadow_zone_1030/"
const SCREEN=[Vector2(1008,315),Vector2(1105,325),Vector2(1125,350),Vector2(1126,456),Vector2(1110,533),Vector2(1070,573),Vector2(978,592),Vector2(862,624),Vector2(767,658),Vector2(735,652),Vector2(713,623),Vector2(697,584),Vector2(716,552),Vector2(770,529),Vector2(842,505),Vector2(922,476),Vector2(975,442),Vector2(994,402),Vector2(999,358)]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1920,1080)
	var camera:=Camera3D.new();root.add_child(camera);camera.fov=58.;camera.position=Vector3(-160,1800,2100);camera.look_at(Vector3(-250,15,400));camera.make_current()
	var polygon:=PackedVector2Array();var points: Array=[]
	for screen: Vector2 in SCREEN:
		var p: Vector3=Plane(Vector3.UP,20.).intersects_ray(camera.project_ray_origin(screen),camera.project_ray_normal(screen))
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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var texture:=ImageTexture.create_from_image(image)
	texture.set_meta("world_origin",bounds.position);texture.set_meta("world_extent",bounds.size)
	assert(ResourceSaver.save(texture,OUT+"lake_green_sdf.res",ResourceSaver.FLAG_COMPRESS)==OK)
	var data={"origin":[bounds.position.x,bounds.position.y],"extent":[bounds.size.x,bounds.size.y],"feather_inside_m":80.,"height_fade_m":[40.,60.],"polygon":points,"screen_polygon":SCREEN.map(func(p):return [p.x,p.y]),"reference_camera":{"position":[-160,1800,2100],"target":[-250,15,400],"fov":58},"signed_distance":"positive inside; feather entirely inside selected boundary"}
	FileAccess.open(OUT+"lake_region.json",FileAccess.WRITE).store_string(JSON.stringify(data,"  "))
	print("LAKE_MEADOW_MASK ",JSON.stringify(data));quit()
