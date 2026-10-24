extends SceneTree
## Render the actual leaf/LOD shaders: both light paths must follow world zones.
const OUT := "res://.vegetation_art_build/tree_biome/"
const STYLE := preload("res://scripts/foliage_style.gd")
var failures: Array[String]=[]

func _initialize() -> void:call_deferred("run")
func frames(count: int) -> void:
	for i in count:await process_frame
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)

func sample_image() -> Image:
	await frames(8);await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func center(image: Image) -> Color:
	return image.get_pixel(image.get_width()/2,image.get_height()/2)

func difference(a: Color,b: Color) -> float:
	return absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)

func run() -> void:
	root.size=Vector2i(480,360);Engine.max_fps=60
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var world:=Node3D.new();root.add_child(world)
	var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color("202020");environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color.WHITE;environment.ambient_light_energy=0.6
	environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	var env:=WorldEnvironment.new();env.environment=environment;world.add_child(env)
	var sun:=DirectionalLight3D.new();sun.light_energy=0.7;world.add_child(sun)
	var camera:=Camera3D.new();camera.position=Vector3(0,0,4);world.add_child(camera);camera.make_current()
	var card:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(3,3);card.mesh=quad;world.add_child(card)
	var white:=Image.create(4,4,false,Image.FORMAT_RGBA8);white.fill(Color.WHITE)
	var texture:=ImageTexture.create_from_image(white)
	var noise:=NoiseTexture2D.new();noise.noise=FastNoiseLite.new();noise.width=32;noise.height=32
	var report: Array=[]
	for name: String in ["vegetation_wind","tree_hlod"]:
		var material:=ShaderMaterial.new();material.shader=load(STYLE.BASE+name+"_soft_backlight.gdshader")
		card.material_override=material
		material.set_shader_parameter("albedo_texture",texture)
		material.set_shader_parameter("biome_noise_texture",noise)
		material.set_shader_parameter("species_noise_texture",noise)
		material.set_shader_parameter("lod_dither_texture",texture)
		material.set_shader_parameter("wind_strength",0.0)
		material.set_shader_parameter("biome_warp_distance",0.0)
		material.set_shader_parameter("biome_transition_half_width",1.0)
		STYLE.configure_green_biome(material,null)
		for parameter: String in STYLE.GREEN_VALUES:
			if name=="vegetation_wind":card.set_instance_shader_parameter(parameter,STYLE.GREEN_VALUES[parameter])
			else:material.set_shader_parameter(parameter,STYLE.GREEN_VALUES[parameter])
		for direct: bool in [false,true]:
			environment.ambient_light_energy=0.0 if direct else 0.6;sun.visible=direct
			material.set_shader_parameter("biome_center_x",1000.0)
			var dry:=await sample_image();var dry_color:=center(dry)
			material.set_shader_parameter("biome_center_x",-1000.0)
			var green:=await sample_image();var green_color:=center(green)
			check(difference(dry_color,green_color)>0.025,"No world tint in %s direct=%s"%[name,direct])
			check(green_color.b/maxf(green_color.r,0.001)>dry_color.b/maxf(dry_color.r,0.001),"World tint hue reversed")
			var tag:=name+("_direct" if direct else "_ambient")
			dry.save_png(OUT+tag+"_dry.png");green.save_png(OUT+tag+"_green.png")
			report.append({"shader":name,"direct":direct,"dry":str(dry_color),"green":str(green_color)})
		# Flower opt-out: changing the zone must leave every pixel unchanged.
		material.set_shader_parameter("species_biome_tint",false)
		if name=="vegetation_wind":
			card.set_instance_shader_parameter("species_shadow_color",Color("c18da5"))
			card.set_instance_shader_parameter("species_mid_color",Color("e0b0c1"))
			card.set_instance_shader_parameter("species_light_color",Color("f1d2d9"))
		else:
			material.set_shader_parameter("species_shadow_color",Color("c18da5"))
			material.set_shader_parameter("species_mid_color",Color("e0b0c1"))
			material.set_shader_parameter("species_light_color",Color("f1d2d9"))
		material.set_shader_parameter("biome_center_x",1000.0);var flower_dry:=await sample_image()
		material.set_shader_parameter("biome_center_x",-1000.0);var flower_green:=await sample_image()
		check(flower_dry.get_data()==flower_green.get_data(),"Flower changed with biome: "+name)
	FileAccess.open(OUT+"render_validation.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"measurements":report,"failures":failures},"  "))
	print("TREE_BIOME_RENDER ",failures);quit(0 if failures.is_empty() else 1)
