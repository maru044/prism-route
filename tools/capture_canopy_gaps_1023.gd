extends SceneTree
## Actual Forward+ grove materials, with matched isolated-tree camera views.
const OUT := "res://.vegetation_art_build/canopy_gaps_1023/"
var world
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await process_frame
func save(name: String) -> void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUT+name+".png")==OK)
func run() -> void:
	root.size=Vector2i(1600,1000);Engine.max_fps=60
	var stage:="before"
	var full:=false;var baseline:=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="):stage=arg.trim_prefix("--stage=")
		if arg=="--full":full=true
		if arg=="--baseline":baseline=true
	world=load("res://scenes/vegetation_grove_test.tscn").instantiate();root.add_child(world)
	await frames(25)
	world.get_node("Instructions").hide()
	world.get_node("OrbitCamera").set_process(false)
	for n: MeshInstance3D in world.find_children("*","MeshInstance3D",true,false):
		if n.material_override is ShaderMaterial:
			n.material_override=n.material_override.duplicate()
			n.material_override.set_shader_parameter("wind_strength",0.)
	var broad: Node3D=world.find_child("BroadClusteredFlowerTree",true,false)
	var upright: Node3D=world.find_child("UprightAsymmetricAutumnTree",true,false)
	assert(broad!=null and upright!=null)
	if baseline:
		for key: String in ["broad","upright"]:
			var original: Node3D=broad if key=="broad" else upright
			var leaf_material: Material
			var trunk_material: Material
			for n: MeshInstance3D in original.find_children("*","MeshInstance3D",true,false):
				if "foliage" in n.name.to_lower():leaf_material=n.material_override
				else:trunk_material=n.material_override
			var stem: String="tree_medium_broad_clustered_canopy" if key=="broad" else "tree_medium_upright_asymmetric_canopy"
			var doc:=GLTFDocument.new();var state:=GLTFState.new()
			assert(doc.append_from_file(ProjectSettings.globalize_path(OUT+"before/"+stem+".glb"),state)==OK)
			var old: Node3D=doc.generate_scene(state);original.get_parent().add_child(old);old.global_transform=original.global_transform
			for n: MeshInstance3D in old.find_children("*","MeshInstance3D",true,false):
				n.material_override=leaf_material if "foliage" in n.name.to_lower() else trunk_material
				n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if "foliage" in n.name.to_lower() else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if key=="broad":broad=old
			else:upright=old
			original.free()
	var geometry: Array=world.find_children("*","GeometryInstance3D",true,false)
	var camera:=Camera3D.new();camera.fov=44;camera.far=300;world.add_child(camera);camera.make_current()
	var env: Environment=world.get_node("RosendalParkEnvironment").environment
	var saved_background:=env.background_mode
	var silhouette_shader:=Shader.new()
	silhouette_shader.code="""shader_type spatial;
render_mode unshaded,cull_back,depth_prepass_alpha,alpha_to_coverage;
uniform sampler2D leaf : filter_linear_mipmap_anisotropic;
void fragment(){
 vec4 tex=texture(leaf,UV);vec2 cell=fract(UV*2.0);
 float edge=min(min(cell.x,1.-cell.x),min(cell.y,1.-cell.y));
 vec3 plane=normalize(cross(dFdx(VERTEX),dFdy(VERTEX)));
 float facing=abs(dot(plane,normalize(VIEW)));
 ALBEDO=vec3(1.);ALPHA=tex.a*smoothstep(0.,.075,edge)*smoothstep(.02,.14,facing);
 ALPHA_SCISSOR_THRESHOLD=.5;ALPHA_ANTIALIASING_EDGE=.3;
}"""
	var silhouette:=ShaderMaterial.new();silhouette.shader=silhouette_shader
	silhouette.set_shader_parameter("leaf",load("res://assets/vegetation/textures/leaf_clusters_witness_sparse_flat_v11.png"))
	var metrics: Array=[]
	for key: String in ["broad","upright"]:
		var tree: Node3D=broad if key=="broad" else upright
		for n: GeometryInstance3D in geometry:n.visible=tree.is_ancestor_of(n)
		var leaf_nodes: Array[MeshInstance3D]=[];var materials: Array[Material]=[]
		var triangle_count:=0
		for n: MeshInstance3D in tree.find_children("*","MeshInstance3D",true,false):
			for surface in n.mesh.get_surface_count():
				var arrays:=n.mesh.surface_get_arrays(surface)
				triangle_count+=(arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()/3
			if "foliage" in n.name.to_lower():leaf_nodes.append(n);materials.append(n.material_override)
		for i in (8 if full else 2):
			var azimuth: float=i*45. if full else [0.,135.][i];var angle:=deg_to_rad(azimuth)
			var target: Vector3=tree.global_position+Vector3(0,7.8 if key=="broad" else 8.9,0)
			var distance:=22. if full else 25.
			camera.position=target+Vector3(cos(angle)*distance,-4.6,sin(angle)*distance);camera.look_at(target)
			env.background_mode=saved_background
			for j in leaf_nodes.size():leaf_nodes[j].material_override=materials[j]
			await frames(25);await save(stage+"_"+key+"_%d"%i)
			for n: MeshInstance3D in leaf_nodes:n.material_override=silhouette
			env.background_mode=Environment.BG_COLOR;env.background_color=Color.BLACK
			for n: MeshInstance3D in tree.find_children("*","MeshInstance3D",true,false):
				if "trunk" in n.name.to_lower():n.hide()
			await frames(8);await save(stage+"_"+key+"_%d_mask"%i)
			for n: MeshInstance3D in tree.find_children("*","MeshInstance3D",true,false):n.show()
		for j in leaf_nodes.size():leaf_nodes[j].material_override=materials[j]
		metrics.append({"species":key,"triangles":triangle_count,"leaf_meshes":leaf_nodes.size()})
	env.background_mode=saved_background
	for n: GeometryInstance3D in geometry:n.show()
	camera.position=Vector3(-20,9,22);camera.look_at(Vector3(0,7,2));await frames(25);await save(stage+"_grove")
	if stage=="full_after":
		for n: GeometryInstance3D in geometry:n.hide()
		var streamer: Node3D=load("res://scripts/vegetation_lod_streamer.gd").new()
		var noise:=NoiseTexture2D.new();noise.noise=FastNoiseLite.new()
		streamer.biome_noise_texture=noise;streamer._load_meshes_and_materials()
		for key: String in ["broad","upright"]:
			for level in [1,2]:
				var prefix: String="tree_large_"+key+"_lod%d_"%level
				var leaf_mesh: Mesh=streamer.get(prefix+"leaf_mesh")
				var trunk_mesh: Mesh=streamer.get("tree_large_"+key+"_lod1_trunk_mesh")
				var base_material: ShaderMaterial=streamer.get("tree_"+key+"_lod%d_material"%level)
				var material: ShaderMaterial=streamer._get_tree_palette_material(base_material,1 if key=="broad" else 3)
				material.set_shader_parameter("tree_lod_fade",Vector4(-2,-1,1000,1100));material.set_shader_parameter("wind_strength",0.)
				var leaf:=MeshInstance3D.new();leaf.mesh=leaf_mesh;leaf.material_override=material;leaf.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;world.add_child(leaf)
				var trunk:=MeshInstance3D.new();trunk.mesh=trunk_mesh;trunk.material_override=streamer.trunk_material;world.add_child(trunk)
				assert(leaf_mesh.get_faces().size()>0 and leaf_mesh.get_faces().size()<6000)
				camera.position=Vector3(21,4.5,13);camera.look_at(Vector3(0,8,0));await frames(25);await save("after_"+key+"_lod%d"%level)
				metrics.append({"species":key,"lod":level,"leaf_triangles":leaf_mesh.get_faces().size()/3})
				leaf.free();trunk.free()
		streamer.free()
	FileAccess.open(OUT+stage+"_godot.json",FileAccess.WRITE).store_string(JSON.stringify(metrics,"  "))
	print("CANOPY_CAPTURE_DONE ",stage," ",JSON.stringify(metrics));quit()
