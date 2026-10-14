extends RefCounted
## Material-level B study. Geometry, actor and vegetation shaders are untouched.

var world: Node3D
var environment: Environment
var sun: DirectionalLight3D
var architecture: ShaderMaterial = preload("res://assets/world/cliff_b_test/architecture_toon.tres").duplicate()
var architecture_meshes: Array[MeshInstance3D] = []
var road_material: ShaderMaterial
var enabled := true
var compare_button: Button

func attach_controls(panel) -> void:
	compare_button = panel._button("", panel.aa_choice.get_parent(), func(): set_enabled(not enabled))
	compare_button.name = "ArchitectureComparison"
	panel._paragraph("M：暖白建筑效果 / 原版对照\nP：显示种植范围", panel.controls_label.get_parent())
	refresh_label()

func refresh_label() -> void:
	if compare_button != null:
		compare_button.text = "M 建筑：%s（点击切换）" % ("柔和暖白" if enabled else "原版对照")

func setup(scene: Node3D, road: ShaderMaterial) -> void:
	world = scene
	road_material = road
	environment = world.get_node("FreshSkyEnvironment").environment
	for child in world.get_children():
		if child is DirectionalLight3D:
			sun = child
	var meshes: Array[MeshInstance3D] = []
	world._collect_meshes(world.model, meshes)
	for mesh in meshes:
		if str(mesh.name).begins_with("Architecture_"):
			architecture_meshes.append(mesh)
	set_enabled(world.stylized_architecture)

func sync_sun() -> void:
	architecture.set_shader_parameter("main_light_direction", sun.global_basis.z)
	for material in [road_material, world.terrain_material]:
		material.set_shader_parameter("main_light_direction", sun.global_basis.z)
	architecture.set_shader_parameter("sky_yaw", environment.sky_rotation.y)

func set_enabled(value: bool) -> void:
	enabled = value
	world.stylized_architecture = value
	for mesh in architecture_meshes:
		mesh.material_override = architecture if value else preload("res://assets/world/cliff_b_test/architecture.tres")
	road_material.shader = preload("res://assets/world/cliff_b_test/road.gdshader") if value else preload("res://assets/world/map_1012_test/road.gdshader")
	world.terrain_material.shader = preload("res://assets/world/cliff_b_test/terrain.gdshader") if value else preload("res://assets/world/terrain/shaders/terrain_draft.gdshader")
	var color := Color(0.42, 0.43, 0.42) if value else Color(0.23, 0.25, 0.25)
	for material: ShaderMaterial in [road_material, world.terrain_material]:
		material.set_shader_parameter("road_color", color)
	sync_sun()
	refresh_label()
