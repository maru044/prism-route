extends Node
## Accepted B wind for the 1021 world. Presentation only: reuse baked roots,
## instance buffers, density LOD and actor interaction without a new bake.
enum Mode { BREEZE, STRONG, AUTO }
const MESH := preload("res://assets/vegetation/models/grass_star_3card_gust_v7.glb")
const SHADER := preload("res://assets/vegetation/shaders/grass_world_wind.gdshader")
const REFERENCE_SHADER := preload("res://assets/vegetation/shaders/grass_gust.gdshader")
const SETTINGS := preload("res://scripts/grass_wind_settings.gd")
const TRANSITION_SECONDS := SETTINGS.TRANSITION_SECONDS
const CYCLE_SECONDS := SETTINGS.CYCLE_SECONDS
const CULL_MARGIN := 1.8
var vegetation
var material: ShaderMaterial
var mode := Mode.AUTO
var elapsed := 0.0
var blend := 0.0
var auto_epoch := 0.0
var running := true
var mesh: Mesh
var reference_mesh: Mesh
var lod_meshes: Dictionary = {}
var grass_nodes: Array[MultiMeshInstance3D] = []
var lod_clock := 0.0
var optimized := true
var resident_cpu_cache_bytes:=0
var last_lod_change_usec:=0
const LOD_CHANGE_BUDGET_USEC:=1000
var profile_enabled := "--grass-profile" in OS.get_cmdline_user_args()
var profile := {"configure_usec":0,"configure_count":0,"lod_refresh_usec":0,"lod_refresh_max_usec":0,"mesh_switch_usec":0,"mesh_switch_max_usec":0,"mesh_switch_count":0}

func initialize(owner_vegetation) -> void:
	vegetation = owner_vegetation
	material = vegetation.grass_material
	# Preserve the exact world's biome, alpha, LOD and interaction settings.
	var settings: Dictionary = {}
	for uniform: Dictionary in material.shader.get_shader_uniform_list():
		var value: Variant = material.get_shader_parameter(uniform.name)
		if value != null:
			settings[uniform.name] = value
	material.shader = SHADER
	for parameter: String in settings:
		material.set_shader_parameter(parameter, settings[parameter])
	SETTINGS.apply(material, SETTINGS.DEFAULT_PARAMETERS)
	mesh = vegetation._extract_first_mesh(MESH)
	mesh.surface_set_material(0, material)
	reference_mesh = mesh
	# Both models have the same unbent envelope. The baked-store AABB already
	# grows that envelope conservatively to include wind and actor interaction.
	assert(mesh.get_aabb().is_equal_approx(vegetation.grass_mesh.get_aabb()))
	mesh = _build_lod_mesh(4)
	vegetation.grass_mesh = mesh
	lod_meshes = {4:mesh, 2:_build_lod_mesh(2), 1:_build_lod_mesh(1)}
	material.set_shader_parameter("gust_shared_curve",true)
	material.set_shader_parameter("gust_distance_lod",true)
	var stream: Node = vegetation.volume_streamer
	stream.presentation_mesh_selector=select_mesh_for_bounds
	stream.presentation_far_mesh=lod_meshes[1]
	stream.child_entered_tree.connect(_track_chunk)
	for chunk: Node in stream.get_children():
		_track_chunk(chunk)
	advance(0.0)

func _track_chunk(chunk: Node) -> void:
	if not chunk.child_entered_tree.is_connected(_configure_node):
		chunk.child_entered_tree.connect(_configure_node)
	for node: Node in chunk.get_children():
		_configure_node(node)

func _configure_node(node: Node) -> void:
	if node is MultiMeshInstance3D:
		var started:=Time.get_ticks_usec()
		node.material_override = material
		node.extra_cull_margin = maxf(node.extra_cull_margin, CULL_MARGIN)
		var existing: Mesh=node.multimesh.mesh
		node.set_meta("wind_mesh",existing)
		node.set_meta("wind_bounds",node.global_transform*node.multimesh.custom_aabb)
		node.set_meta("wind_lod",4 if existing==mesh else (2 if existing==lod_meshes[2] else 1))
		grass_nodes.append(node)
		_update_node_lod(node)
		if profile_enabled:
			profile.configure_usec+=Time.get_ticks_usec()-started;profile.configure_count+=1

func _build_lod_mesh(segments: int) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var width := mesh.get_aabb().size.x
	var height := mesh.get_aabb().size.y
	for card in 3:
		var angle := float(card)*PI/3.0
		var right := Vector3(cos(angle),0,-sin(angle))*width*0.5
		var base := vertices.size()
		for row in segments+1:
			var u := float(row)/segments
			for side: int in [-1,1]:
				vertices.append(right*side+Vector3.UP*height*u)
				normals.append(Vector3.UP);colors.append(Color(u,u,u,1))
				# glTF flips Blender's V: roots sample the atlas bottom (V=1).
				uvs.append(Vector2(float(side+1)*0.5,1.0-u))
		for row in segments:
			var a := base+row*2
			indices.append_array([a,a+1,a+3,a,a+3,a+2])
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	result.surface_set_material(0,material)
	return result

func _update_node_lod(node: MultiMeshInstance3D, allow_change:=true) -> void:
	last_lod_change_usec=0
	var box: AABB=node.get_meta("wind_bounds")
	var level:=_level_for_bounds(box,node.get_meta("wind_lod",4))
	var desired: Mesh = lod_meshes[level] if optimized else reference_mesh
	if optimized and level==1:
		var camera:=get_viewport().get_camera_3d()
		if camera!=null and camera.global_position.distance_to(camera.global_position.clamp(box.position,box.end))<64.0:
			var source: Dictionary=node.get_meta("wind_source",{})
			if not source.is_empty():vegetation.volume_streamer.store.request(source.cell)
	if node.get_meta("wind_mesh")!=desired:
		if not allow_change:return
		var started:=Time.get_ticks_usec()
		var has_local:=int(node.get_meta("wind_cpu_cache_bytes",0))>0
		var needs_local:=not optimized or level!=1
		if has_local!=needs_local:
			var buffer:=PackedFloat32Array()
			if has_local:
				# This is a CPU-cache read, not a GPU readback. Drop that cache
				# when leaving the near/middle region instead of retaining it.
				buffer=node.multimesh.buffer
			else:
				var source: Dictionary=node.get_meta("wind_source",{})
				if source.is_empty():return
				var store=vegetation.volume_streamer.store
				var data: Dictionary=store.get_data(source.cell)
				if data.is_empty():
					if not optimized:
						# Explicit offline reference comparisons may synchronously
						# read back; this branch is never used during normal play.
						buffer=node.multimesh.buffer
					else:
						store.request(source.cell)
						return # Keep existing coarse grass visible while loading.
				else:
					var original: PackedFloat32Array=data[source.group]
					buffer=original.slice(source.offset*16,(source.offset+source.count)*16)
			var bounds: AABB=node.multimesh.custom_aabb
			node.multimesh=vegetation.volume_streamer.make_display_multimesh(desired,buffer,bounds,needs_local)
			node.set_meta("wind_cpu_cache_bytes",buffer.size()*4 if needs_local else 0)
		else:
			node.multimesh.mesh=desired
		node.set_meta("wind_mesh",desired)
		node.set_meta("wind_lod",level)
		last_lod_change_usec=Time.get_ticks_usec()-started
		if profile_enabled:
			var cost:=Time.get_ticks_usec()-started
			profile.mesh_switch_usec+=cost;profile.mesh_switch_max_usec=maxi(profile.mesh_switch_max_usec,cost);profile.mesh_switch_count+=1

func select_mesh_for_bounds(box: AABB) -> Mesh:
	return lod_meshes[_level_for_bounds(box,4)] if optimized else reference_mesh

func _level_for_bounds(box: AABB, old: int) -> int:
	var level := 4
	var camera := get_viewport().get_camera_3d()
	if optimized and camera!=null:
		var point := camera.global_position
		var distance := point.distance_to(point.clamp(box.position,box.end))
		# Switch only beyond each shader morph's completed range. Hysteresis
		# avoids mesh oscillation while the camera sits on a threshold.
		if distance>(42.0 if old==1 else 44.0):level=1
		elif distance>(16.0 if old==2 else 18.0):level=2
	return level

func set_optimized(enabled: bool) -> void:
	optimized=enabled
	material.shader=SHADER if enabled else REFERENCE_SHADER
	material.set_shader_parameter("gust_shared_curve",enabled)
	material.set_shader_parameter("gust_distance_lod",enabled)
	refresh_lods(true)

func refresh_lods(force:=false) -> void:
	var started:=Time.get_ticks_usec()
	grass_nodes=grass_nodes.filter(func(node):return is_instance_valid(node))
	resident_cpu_cache_bytes=0
	var changes_usec:=0
	for node in grass_nodes:
		_update_node_lod(node,force or changes_usec<LOD_CHANGE_BUDGET_USEC)
		changes_usec+=last_lod_change_usec
		resident_cpu_cache_bytes+=int(node.get_meta("wind_cpu_cache_bytes",0))
	if profile_enabled:
		var cost:=Time.get_ticks_usec()-started
		profile.lod_refresh_usec+=cost;profile.lod_refresh_max_usec=maxi(profile.lod_refresh_max_usec,cost)

func set_mode(value: int) -> void:
	mode = clampi(value, Mode.BREEZE, Mode.AUTO)
	if mode == Mode.AUTO:
		auto_epoch = elapsed

func _process(delta: float) -> void:
	if running:
		advance(delta)
	lod_clock+=delta
	if lod_clock>=0.1:
		lod_clock=0.0
		refresh_lods()

func advance(delta: float) -> void:
	elapsed += delta
	var phase := fposmod(elapsed - auto_epoch, CYCLE_SECONDS)
	var strong := mode == Mode.STRONG or (mode == Mode.AUTO and phase >= 8.0 and phase < 19.0)
	blend = move_toward(blend, 1.0 if strong else 0.0, delta / TRANSITION_SECONDS)
	material.set_shader_parameter("gust_mix", blend)
	material.set_shader_parameter("gust_time", elapsed)
	if optimized:
		SETTINGS.update_shared_curve(material,elapsed)
