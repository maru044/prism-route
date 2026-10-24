extends RefCounted
## Approved foliage style. Source materials retain the legacy green palette.
const BASE := "res://assets/vegetation/shaders/"
const SHADERS := {
	BASE+"vegetation_wind.gdshader": preload("res://assets/vegetation/shaders/vegetation_wind_soft_backlight.gdshader"),
	BASE+"tree_hlod.gdshader": preload("res://assets/vegetation/shaders/tree_hlod_soft_backlight.gdshader"),
}
const FILL_STRENGTH := 0.06
const SHADOW_RELIEF := 0.0
const GREEN_VALUES := {
	"use_species_palette":1.0,"species_palette_stage":3.0,
	"species_deep_color":Color("2e7d32"),"species_shadow_color":Color("388e3c"),
	"species_mid_color":Color("66bb6a"),"species_light_color":Color("81c784"),
	"species_accent_color":Color("66bb6a"),"species_accent_amount":0.0,"species_seed":0.29,
}
var records: Array[Dictionary] = []
var copies: Dictionary = {}

func bind_streamer(streamer: Node) -> void:
	for property: String in ["tree_lod0_nodes","tree_lod1_nodes","tree_lod2_nodes"]:
		for node: GeometryInstance3D in streamer.get(property):_register(node)

func bind_grove(grove: Node) -> void:
	for node: MeshInstance3D in grove.find_children("*","MeshInstance3D",true,false):
		if "foliage" in node.name.to_lower():_register(node)

func _register(node: GeometryInstance3D) -> void:
	var source:=node.material_override as ShaderMaterial
	if source==null or source.shader==null or not SHADERS.has(source.shader.resource_path):return
	var instance_palette:=source.shader.resource_path==BASE+"vegetation_wind.gdshader"
	var species: Variant=node.get_instance_shader_parameter("use_species_palette") if instance_palette else source.get_shader_parameter("use_species_palette")
	var green: bool=species==null or float(species)<0.5
	# Green and flower instances may share a source material in the grove.
	var id: String="%d:%s"%[source.get_instance_id(),str(green)]
	if not copies.has(id):
		var material:=source.duplicate() as ShaderMaterial
		var parameters: Dictionary={}
		for uniform: Dictionary in source.shader.get_shader_uniform_list():
			var value: Variant=source.get_shader_parameter(uniform.name)
			if value!=null:parameters[uniform.name]=value
		material.shader=SHADERS[source.shader.resource_path]
		for name: String in parameters:material.set_shader_parameter(name,parameters[name])
		material.set_shader_parameter("foliage_backlight_fill",FILL_STRENGTH)
		material.set_shader_parameter("foliage_shadow_relief",SHADOW_RELIEF)
		# Keep source values available for future species and offline art review.
		records.append({"material":material,"baseline":source.shader,"candidate":material.shader,
			"parameters":parameters,"green":green,"nodes":[],
			"instance_palette":instance_palette,"node_parameters":{}})
		copies[id]=records.back()
	var row: Dictionary=copies[id]
	row.nodes.append(node)
	if instance_palette:
		var values: Dictionary={}
		for name: String in GREEN_VALUES:values[name]=node.get_instance_shader_parameter(name)
		row.node_parameters[node.get_instance_id()]=values
	node.material_override=row.material
	if green:_apply_green(row)

func _apply_green(row: Dictionary) -> void:
	var material: ShaderMaterial=row.material
	for name: String in GREEN_VALUES:
		if row.instance_palette:
			# Only the newly registered instance needs setting.
			row.nodes.back().set_instance_shader_parameter(name,GREEN_VALUES[name])
		else:material.set_shader_parameter(name,GREEN_VALUES[name])
	material.set_shader_parameter("use_biome_palette",false)
