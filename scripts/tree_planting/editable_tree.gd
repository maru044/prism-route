extends Node3D
## Runtime handles for the in-game planting editor; visual children are not saved.
const LEAF_SHADER := preload("res://assets/vegetation/shaders/vegetation_wind_soft_backlight.gdshader")
const STYLE := preload("res://scripts/foliage_style.gd")
@export_storage var biome_source: ShaderMaterial
@export_storage var tree_id := ""
@export_storage var surface_id := ""
@export var species: Resource:
	set(value):
		species=value
		queue_visual_refresh()
@export var palette: Resource:
	set(value):
		palette=value
		queue_visual_refresh()
var visual: Node3D
var pending_refresh := false
var leaf_nodes: Array[MeshInstance3D] = []
var canopy_bounds:=AABB()
var pick_body: StaticBody3D

func _ready() -> void:
	set_notify_transform(true)
	set_meta("_edit_group_",true)
	queue_visual_refresh()

func queue_visual_refresh() -> void:
	if not is_inside_tree() or pending_refresh:return
	pending_refresh=true
	call_deferred("refresh_visual")

func refresh_visual() -> void:
	pending_refresh=false;leaf_nodes.clear()
	if not is_inside_tree() or is_queued_for_deletion():return
	if not is_instance_valid(visual):visual=get_node_or_null("TreeVisual")
	if is_instance_valid(visual):remove_child(visual);visual.queue_free()
	if species==null or species.model==null:return
	visual=species.model.instantiate();visual.name="TreeVisual";visual.scale=Vector3.ONE*species.model_scale
	add_child(visual)
	preload("res://scripts/tree_trunk_assets.gd").apply_visual(visual)
	var material:=ShaderMaterial.new();material.shader=LEAF_SHADER
	material.set_shader_parameter("albedo_texture",species.leaf_texture)
	material.set_shader_parameter("atlas_grid",species.atlas_grid)
	material.set_shader_parameter("alpha_cutoff",0.50)
	material.set_shader_parameter("alpha_antialiasing_edge",0.30)
	material.set_shader_parameter("card_edge_fade",0.075)
	material.set_shader_parameter("light_wrap",0.34)
	material.set_shader_parameter("wind_strength",0.075)
	material.set_shader_parameter("wind_speed",0.72)
	material.set_shader_parameter("foliage_backlight_fill",0.06)
	material.set_shader_parameter("foliage_shadow_relief",0.0)
	material.set_shader_parameter("use_view_angle_fade",true)
	material.set_shader_parameter("view_angle_fade_start",0.020)
	material.set_shader_parameter("view_angle_fade_end",0.140)
	var noise:=NoiseTexture2D.new();var generator:=FastNoiseLite.new();generator.seed=9139
	noise.noise=generator;noise.width=128;noise.height=128;noise.seamless=true
	material.set_shader_parameter("species_noise_texture",noise)
	var trunk:=StandardMaterial3D.new();trunk.albedo_color=Color("342a24");trunk.roughness=0.95
	var have_bounds:=false
	for mesh: MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
		if species.foliage_name_contains.to_lower() in mesh.name.to_lower():
			leaf_nodes.append(mesh);mesh.material_override=material
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var local:=global_transform.affine_inverse()*mesh.global_transform
			var bounds: AABB=local*mesh.get_aabb()
			canopy_bounds=canopy_bounds.merge(bounds) if have_bounds else bounds;have_bounds=true
		else:mesh.material_override=trunk
		mesh.set_meta("_edit_group_",true)
	apply_palette()
	update_canopy()
	if not Engine.is_editor_hint():update_pick_shape()

func update_pick_shape() -> void:
	if not is_instance_valid(pick_body):pick_body=get_node_or_null("TreePickBody")
	if is_instance_valid(pick_body):
		remove_child(pick_body);pick_body.queue_free()
	pick_body=StaticBody3D.new();pick_body.name="TreePickBody";pick_body.collision_layer=2;pick_body.collision_mask=0
	pick_body.set_meta("editable_tree",self)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new()
	box.size=canopy_bounds.size.max(Vector3.ONE*0.5)
	shape.shape=box;shape.position=canopy_bounds.get_center()
	pick_body.add_child(shape);add_child(pick_body)

func apply_palette() -> void:
	if palette==null:return
	for mesh: MeshInstance3D in leaf_nodes:
		var material:=mesh.material_override as ShaderMaterial
		material.set_shader_parameter("use_biome_palette",false)
		material.set_shader_parameter("species_biome_tint",false)
		if palette.follow_world_biome:STYLE.configure_green_biome(material,biome_source)
		mesh.set_instance_shader_parameter("use_species_palette",0.0 if palette.use_texture_color else 1.0)
		mesh.set_instance_shader_parameter("species_palette_stage",3.0)
		mesh.set_instance_shader_parameter("species_deep_color",palette.deep)
		mesh.set_instance_shader_parameter("species_shadow_color",palette.shadow)
		mesh.set_instance_shader_parameter("species_mid_color",palette.middle)
		mesh.set_instance_shader_parameter("species_light_color",palette.light)
		mesh.set_instance_shader_parameter("species_accent_color",palette.middle)
		mesh.set_instance_shader_parameter("species_accent_amount",0.0)
		mesh.set_instance_shader_parameter("species_seed",palette.seed)
		mesh.set_instance_shader_parameter("variant_tint",palette.texture_tint)

func _notification(what: int) -> void:
	if what==NOTIFICATION_TRANSFORM_CHANGED and is_inside_tree():update_canopy()

func update_canopy() -> void:
	if species==null or not is_inside_tree():return
	var radii:=canopy_bounds.size*global_basis.get_scale().abs()*0.5
	radii=Vector3(maxf(radii.x,0.1),maxf(radii.y,0.1),maxf(radii.z,0.1))
	for mesh: MeshInstance3D in leaf_nodes:
		mesh.set_instance_shader_parameter("use_tree_palette_anchor",1.0)
		mesh.set_instance_shader_parameter("tree_palette_anchor_world",global_position)
		mesh.set_instance_shader_parameter("use_tree_canopy_normal",1.0)
		mesh.set_instance_shader_parameter("tree_canopy_center_world",global_transform*canopy_bounds.get_center())
		mesh.set_instance_shader_parameter("tree_canopy_radii",radii)
		mesh.set_instance_shader_parameter("tree_local_normal_weight",species.canopy_normal_weight)

func to_record() -> Dictionary:
	if species==null or palette==null:return {}
	return {"id":tree_id,"position":[position.x,position.y,position.z],"yaw":rotation.y,"scale":scale.x,
		"species":species.id,"palette":palette.id,"surface":surface_id}

func load_record(row: Dictionary, profile: Resource) -> void:
	biome_source=profile.terrain_material
	tree_id=row.id;surface_id=row.get("surface","")
	species=profile.find_species(row.species);palette=profile.find_palette(row.palette)
	position=Vector3(row.position[0],row.position[1],row.position[2])
	rotation.y=float(row.yaw);scale=Vector3.ONE*float(row.scale)
	name="Tree_"+tree_id
