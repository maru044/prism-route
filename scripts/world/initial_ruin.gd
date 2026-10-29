extends Node3D
## Formal-map static feature and one-shot summon interaction. No preview/lab dependency.
signal printing_started
signal printing_completed
enum State { HOLOGRAM, PRINTING, PRINTED }
const MASK := preload("res://scripts/world/initial_ruin_mask.gd")
const KEQING := preload("res://scenes/characters/projected_keqing.tscn")
const GEOMETRY := preload("res://assets/world/initial_ruin_1029/ruin.glb")
const WALK_COLLISION := preload("res://assets/world/initial_ruin_1029/walk_collision.glb")
const WALK_MANIFEST := "res://assets/world/initial_ruin_1029/walk_collision.json"
const ACTOR_SOLID_LAYER := 32
var world
var planting_mask=MASK.new()
var walk_manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(WALK_MANIFEST))
var walk_geometry: Node3D
var geometry: Node3D
var avatar
var trigger: Area3D
var solid_body: StaticBody3D
var solid_shape: CollisionShape3D
var prompt_layer: CanvasLayer
var prompt: Label
var state := State.HOLOGRAM
var nearby := false
var completion_toast := 0.
var print_count := 0
var particles: Array[MeshInstance3D]=[]
var particle_material: StandardMaterial3D
var clock := 0.
var ready_for_interaction := false

func _ready() -> void:
	_build_geometry();_build_walk_collision();_build_projection();_build_trigger();_build_prompt()
	ready_for_interaction=true

func _build_geometry() -> void:
	geometry=GEOMETRY.instantiate();geometry.name="Architecture";add_child(geometry)
	var colors: Dictionary={"ivory":"d8d2bf","floor":"e2ddcf","base":"aeab9a","shadow":"999a90","cap":"c8c2ae","cyan":"39cbe6","dark":"2b4951","case":"6c7776"}
	var materials: Dictionary={}
	for key: String in colors:
		if key in ["ivory","floor","base","cap"]:
			var m: ShaderMaterial=load("res://assets/world/cliff_b_test/architecture.tres").duplicate()
			m.set_shader_parameter("warm_white",Color(colors[key]));materials[key]=m
		else:
			var m:=StandardMaterial3D.new();m.albedo_color=Color(colors[key]);m.roughness=.9
			if key=="cyan":m.emission_enabled=true;m.emission=m.albedo_color;m.emission_energy_multiplier=2.
			materials[key]=m
	var rows: Dictionary={}
	for row: Dictionary in planting_mask.manifest.objects:rows[row.id]=row
	for mesh: MeshInstance3D in geometry.find_children("*","MeshInstance3D",true,false):
		var id:=str(mesh.name).get_slice("_",1);var row: Dictionary=rows[id]
		mesh.material_override=materials[row.material_key]
		if not row.collision:mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;continue
		var body:=StaticBody3D.new();body.collision_layer=1 if id in walk_manifest.replaced_actor_collision_ids else 1|ACTOR_SOLID_LAYER;body.collision_mask=0
		body.set_meta("surface_kind","Structure");body.set_meta("source_id",id);body.set_meta("initial_ruin",true)
		mesh.add_child(body)
		var shape:=mesh.mesh.create_trimesh_shape();shape.backface_collision=true
		var collider:=CollisionShape3D.new();collider.shape=shape;body.add_child(collider)

func _build_walk_collision() -> void:
	# Godot imports the authored -colonly meshes as static bodies with no visuals.
	walk_geometry=WALK_COLLISION.instantiate();walk_geometry.name="SmoothWalkCollision";add_child(walk_geometry)
	for body: StaticBody3D in walk_geometry.find_children("*","StaticBody3D",true,false):
		body.collision_layer=ACTOR_SOLID_LAYER;body.collision_mask=0
		body.set_meta("surface_kind","Structure");body.set_meta("smooth_ruin_walk",true)
		for row: Dictionary in walk_manifest.cad_objects:
			if str(body.name)==str(row.name).trim_suffix("-colonly"):
				body.set_meta("source_id",row.id);body.set_meta("walk_role",row.role);break

func _build_projection() -> void:
	avatar=KEQING.instantiate();avatar.name="Keqing"
	var a: Array=planting_mask.manifest.summon_anchor
	avatar.position=Vector3(a[0],a[1],a[2])
	var forward: Array=planting_mask.manifest.forward
	avatar.rotation.y=atan2(-float(forward[0]),-float(forward[2]))
	add_child(avatar);avatar.effect.printing_finished.connect(_finish_printing)
	solid_body=StaticBody3D.new();solid_body.name="PrintedCharacterBody"
	solid_body.position=avatar.position;solid_body.collision_layer=ACTOR_SOLID_LAYER;solid_body.collision_mask=0;add_child(solid_body)
	solid_shape=CollisionShape3D.new();solid_shape.position.y=.75
	var capsule:=CapsuleShape3D.new();capsule.radius=.27;capsule.height=1.5
	solid_shape.shape=capsule;solid_shape.disabled=true;solid_body.add_child(solid_shape)
	var sphere:=SphereMesh.new();sphere.radius=.004;sphere.height=.008;sphere.radial_segments=6;sphere.rings=3
	particle_material=StandardMaterial3D.new();particle_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	particle_material.albedo_color=Color(.2,.8,1,.8);particle_material.emission_enabled=true
	particle_material.emission=Color(.2,.8,1);particle_material.emission_energy_multiplier=1.4
	for i in 36:
		var node:=MeshInstance3D.new();node.mesh=sphere;node.material_override=particle_material
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;avatar.add_child(node);particles.append(node)

func _build_trigger() -> void:
	trigger=Area3D.new();trigger.name="PrintInteractionBox";trigger.position=avatar.position+Vector3.UP*.9
	trigger.collision_layer=0;trigger.collision_mask=2;trigger.monitorable=false
	var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(5.5,3.,5.5);collider.shape=box
	trigger.add_child(collider);add_child(trigger)
	trigger.body_entered.connect(func(body):
		if body==world.character:nearby=true)
	trigger.body_exited.connect(func(body):
		if body==world.character:nearby=false)

func _build_prompt() -> void:
	prompt_layer=CanvasLayer.new();prompt_layer.name="SummonPrompt";add_child(prompt_layer)
	world.review_ui_layers.append(prompt_layer)
	var root:=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	prompt_layer.add_child(root)
	prompt=Label.new();prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	prompt.offset_top=-116;prompt.offset_bottom=-70;prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size",25);prompt.add_theme_color_override("font_shadow_color",Color.BLACK)
	prompt.add_theme_constant_override("shadow_outline_size",5);prompt.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(prompt)

func can_interact() -> bool:
	if not ready_for_interaction or not world.test_ready or not nearby:return false
	if not world.character_mode or world.free_mode or world.overview_mode or world.switching_actor:return false
	if world.spawn_menu!=null and world.spawn_menu.get_popup().visible:return false
	var focus: Control=get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:return false
	# Prevent use through the podium/floor if the trigger overlaps someone below it.
	var query:=PhysicsRayQueryParameters3D.create(world.character.global_position+Vector3.UP,avatar.global_position+Vector3.UP*.9,ACTOR_SOLID_LAYER)
	query.exclude=[world.character.get_rid(),solid_body.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func try_print() -> bool:
	if state!=State.HOLOGRAM or not can_interact():return false
	state=State.PRINTING;print_count+=1;avatar.effect.start_printing(3.5);printing_started.emit()
	return true

func _finish_printing() -> void:
	if state!=State.PRINTING:return
	state=State.PRINTED;completion_toast=3.
	solid_shape.set_deferred("disabled",false);printing_completed.emit()

func reset_projection() -> void:
	state=State.HOLOGRAM;completion_toast=0.;avatar.effect.reset_projection();solid_shape.set_deferred("disabled",true)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and try_print():get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not ready_for_interaction:return
	clock+=delta;completion_toast=maxf(0.,completion_toast-delta)
	var interactive:=can_interact()
	prompt.visible=interactive or completion_toast>0.
	if state==State.PRINTING:prompt.text="正在打印刻晴 · %d%%"%roundi(avatar.effect.materialization_progress*100.)
	elif state==State.PRINTED:prompt.text="打印完成 · 刻晴已实体化"
	else:prompt.text="[E] 打印刻晴"
	var alpha:=1.-smoothstep(.8,1.,avatar.effect.materialization_progress)
	particle_material.albedo_color.a=alpha*.8
	for i in particles.size():
		particles[i].visible=alpha>.001
		var angle:=i*2.399963
		particles[i].position=Vector3(cos(angle)*.57,.2+fmod(clock*.12+i*.137,1.8),sin(angle)*.57)
