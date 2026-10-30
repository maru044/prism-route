extends RefCounted
## Local PBR palette and explicit dielectric optics; no geometry/cache authoring.
const CONFIG="res://assets/world/upper_ring_1030/materials.json"
const SOLID=preload("res://shaders/environment/upper_ring_solid.gdshader")
const DIELECTRIC=preload("res://shaders/environment/upper_ring_dielectric.gdshader")
const MICRO=preload("res://assets/world/cliff_b_test/textures/warm_white_architecture_normal.png")
const ROUGH=preload("res://assets/world/cliff_b_test/textures/warm_white_architecture_roughness.png")
const GLASS_LAYER=1<<16
const WATER_LAYER=1<<17
var settings: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
var materials: Dictionary={}
var water_mesh: MeshInstance3D
var glass_meshes: Array[MeshInstance3D]=[]
var probe: ReflectionProbe
var clock:=0.0

func build(terrain: ShaderMaterial) -> Dictionary:
	materials.ground=terrain
	for key: String in settings:
		var row: Dictionary=settings[key];var mat:=ShaderMaterial.new()
		if key in ["glass","water"]:
			mat.shader=DIELECTRIC
			mat.set_shader_parameter("transmission_tint",Color(row.tint))
			mat.set_shader_parameter("ior",float(row.ior));mat.set_shader_parameter("surface_roughness",float(row.roughness))
			mat.set_shader_parameter("density",float(row.density));mat.set_shader_parameter("nominal_thickness",float(row.thickness))
			mat.set_shader_parameter("water_surface",key=="water")
			if key=="water":mat.set_shader_parameter("wave_strength",float(row.wave_strength))
			mat.render_priority=2 if key=="glass" else 1
		else:
			mat.shader=SOLID
			mat.set_shader_parameter("base_color",Color(row.color))
			mat.set_shader_parameter("micro_normal",MICRO);mat.set_shader_parameter("roughness_texture",ROUGH)
			for pair: Array in [["roughness","base_roughness"],["metallic","metallic_amount"],["specular","specular_amount"],["normal_strength","normal_strength"],["roughness_variation","roughness_variation"],["clearcoat","clearcoat_amount"]]:
				mat.set_shader_parameter(pair[1],float(row[pair[0]]))
		mat.resource_name="UpperRing_"+key;materials[key]=mat
	return materials

func key_for(row: Dictionary) -> String:
	if row.material_key=="ivory":
		if row.category in ["01_foundation","02_floor_edges"]:return "concrete"
		if row.category=="09_courtyard":return "stone"
	return row.material_key

func configure_mesh(mesh: MeshInstance3D,row: Dictionary) -> void:
	var key:=key_for(row);mesh.material_override=materials[key];mesh.set_meta("upper_ring_material",key)
	if key=="glass":
		mesh.layers=GLASS_LAYER;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glass_meshes.append(mesh)
	elif key=="water":
		# Only the exposed top is optical water. Keep the original closed mesh's
		# collision, already created by the feature, and remove duplicate interfaces.
		var top:=ArrayMesh.new();var maximum:=mesh.mesh.get_aabb().end.y
		for surface in mesh.mesh.get_surface_count():
			var arrays:=mesh.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			var kept:=PackedInt32Array()
			for i in range(0,indices.size(),3):
				if minf(points[indices[i]].y,minf(points[indices[i+1]].y,points[indices[i+2]].y))>maximum-.01:
					kept.append_array(indices.slice(i,i+3))
			if kept.is_empty():continue
			arrays[Mesh.ARRAY_INDEX]=kept;top.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		assert(top.get_surface_count()>0)
		mesh.mesh=top;mesh.layers=WATER_LAYER;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;water_mesh=mesh

func add_probe(ring: Node3D) -> void:
	probe=ReflectionProbe.new();probe.name="CourtyardMaterialReflections"
	var center: Array=ring.manifest.center
	probe.position=Vector3(center[0],78.,center[2]);probe.size=Vector3(170,52,170)
	var pool: Vector3=water_mesh.global_transform*water_mesh.get_aabb().get_center()
	probe.origin_offset=pool+Vector3.UP*.18-probe.position
	probe.box_projection=true;probe.interior=false;probe.intensity=.85
	probe.cull_mask=1;probe.reflection_mask=GLASS_LAYER|WATER_LAYER
	probe.ambient_mode=ReflectionProbe.AMBIENT_DISABLED
	probe.max_distance=150.;probe.mesh_lod_threshold=2.;probe.enable_shadows=false
	probe.update_mode=ReflectionProbe.UPDATE_ONCE;ring.add_child(probe)

func advance(delta: float) -> void:
	clock+=delta
	materials.water.set_shader_parameter("water_clock",clock)
