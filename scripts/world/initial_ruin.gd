extends Node3D
## World-aligned temple, ordinary NPC, furniture sockets and integrated Battle Fuck tutorial combat.

const MASK := preload("res://scripts/world/initial_ruin_mask.gd")
const NPC := preload("res://scenes/characters/shared_humanoid_actor.tscn")
const FURNITURE := preload("res://scripts/world/interactive_furniture.gd")
const MTOON := preload("res://scripts/characters/mtoon_materials.gd")
const GEOMETRY := preload("res://assets/world/initial_ruin_1029/ruin.glb")
const WALK_COLLISION := preload("res://assets/world/initial_ruin_1029/walk_collision.glb")
const WALK_MANIFEST := "res://assets/world/initial_ruin_1029/walk_collision.json"

const DialogueManagerClass := preload("res://scripts/narrative/dialogue_manager.gd")
const TurnCombatManagerClass := preload("res://scripts/combat/turn_combat_manager.gd")
const DialoguePanelClass := preload("res://scenes/narrative/dialogue_panel.gd")
const TurnCombatHUDClass := preload("res://scenes/combat/turn_combat_hud.gd")
const PleasureComponentClass := preload("res://scripts/combat/pleasure_component.gd")
const SparkleTutorialDialogueClass := preload("res://scripts/narrative/sparkle_tutorial_dialogue.gd")

const ACTOR_SOLID_LAYER := 32
const NPC_SOLID_LAYER := 64
const RESPAWN_POINT := Vector3(-1012.685, 61.1, 1262.287) # Temple doorway entrance position
const RESPAWN_HEADING := 0.38 # Facing inward towards Sparkle

const MOTION_SPARKLE_BLOWJOB := "res://assets/characters/mmd_selected/animations/mmd_781d8c87fd79_a.tres"
const MOTION_MASTER_RECEIVING := "res://assets/characters/mmd_selected/animations/mmd_781d8c87fd79_b.tres"

var world
var planting_mask = MASK.new()
var walk_manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WALK_MANIFEST))
var walk_geometry: Node3D
var geometry: Node3D
var avatar
var npc_anchor: Marker3D
var npc_body: StaticBody3D
var npc_ready := false
var furniture_instances: Dictionary = {}

# Battle Fuck & Narrative In-World Subsystems
var dialogue_manager
var combat_manager
var dialogue_panel
var combat_hud
var player_pleasure
var npc_pleasure

var combat_actors_root: Node3D
var sparkle_combat_actor: Node3D
var master_combat_actor: Node3D
var combat_camera: Camera3D

var interact_prompt: Label
var is_in_dialogue_or_combat: bool = false
var defeat_count: int = 0

func _ready() -> void:
	_build_geometry()
	_build_walk_collision()
	_build_furniture()
	_build_npc()
	_build_combat_and_narrative_subsystems()

func _build_geometry() -> void:
	geometry = GEOMETRY.instantiate()
	geometry.name = "Architecture"
	add_child(geometry)
	var colors: Dictionary = {"ivory":"d8d2bf","floor":"e2ddcf","base":"aeab9a","shadow":"999a90","cap":"c8c2ae"}
	var materials: Dictionary = {}
	for key: String in colors:
		if key in ["ivory","floor","base","cap"]:
			var material: ShaderMaterial = load("res://assets/world/cliff_b_test/architecture.tres").duplicate()
			material.set_shader_parameter("warm_white", Color(colors[key]))
			materials[key] = material
		else:
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(colors[key])
			material.roughness = .9
			materials[key] = material
	var rows: Dictionary = {}
	for row: Dictionary in planting_mask.manifest.objects:
		rows[row.id] = row
	for mesh: MeshInstance3D in geometry.find_children("*","MeshInstance3D",true,false):
		var id := str(mesh.name).get_slice("_",1)
		var row: Dictionary = rows[id]
		mesh.material_override = materials[row.material_key]
		if not row.collision:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			continue
		var body := StaticBody3D.new()
		body.collision_layer = 1 if id in walk_manifest.replaced_actor_collision_ids else 1 | ACTOR_SOLID_LAYER
		body.collision_mask = 0
		body.set_meta("surface_kind","Structure")
		body.set_meta("source_id",id)
		body.set_meta("initial_ruin",true)
		mesh.add_child(body)
		var shape := mesh.mesh.create_trimesh_shape()
		shape.backface_collision = true
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)

func _build_walk_collision() -> void:
	walk_geometry = WALK_COLLISION.instantiate()
	walk_geometry.name = "SmoothWalkCollision"
	add_child(walk_geometry)
	for body: StaticBody3D in walk_geometry.find_children("*","StaticBody3D",true,false):
		body.collision_layer = ACTOR_SOLID_LAYER
		body.collision_mask = 0
		body.set_meta("surface_kind","Structure")
		body.set_meta("smooth_ruin_walk",true)
		for row: Dictionary in walk_manifest.cad_objects:
			if str(body.name) == str(row.name).trim_suffix("-colonly"):
				body.set_meta("source_id",row.id)
				body.set_meta("walk_role",row.role)
				break

func _frame(position: Array, forward: Array) -> Transform3D:
	var f := Vector3(forward[0],forward[1],forward[2]).normalized()
	return Transform3D(Basis(Vector3.UP.cross(f).normalized(),Vector3.UP,f),
			Vector3(position[0],position[1],position[2]))

func _build_furniture() -> void:
	var container := Node3D.new()
	container.name = "FurnitureInteractions"
	add_child(container)
	for row: Dictionary in planting_mask.manifest.interactions.furniture:
		var furniture = FURNITURE.new()
		furniture.name = row.id
		furniture.furniture_id = "temple_" + str(row.type)
		furniture.seat_surface_height = float(row.surface_height)
		furniture.transform = _frame(row.position,row.forward)
		furniture.set_meta("instance_id","initial_temple_" + str(row.id))
		furniture.set_meta("interaction_type",row.type)
		furniture.set_meta("interaction_status",row.interaction_status)
		for anchor: Dictionary in row.anchors:
			var marker := Marker3D.new()
			marker.name = anchor.name
			marker.transform = furniture.transform.affine_inverse() * _frame(anchor.position,anchor.forward)
			marker.set_meta("cad_source_id",anchor.source_id)
			furniture.add_child(marker)
		container.add_child(furniture)
		furniture_instances[row.id] = furniture

func _build_npc() -> void:
	var row: Dictionary = planting_mask.manifest.interactions.npc_idle
	npc_anchor = Marker3D.new()
	npc_anchor.name = "NPC_Idle"
	npc_anchor.transform = _frame(row.position,row.forward)
	npc_anchor.set_meta("instance_id",row.id)
	add_child(npc_anchor)
	avatar = NPC.instantiate()
	avatar.name = "SparkleIdle"
	avatar.model_resource = "res://assets/characters/import_tests_local/huahuo/huahuo_fixed.vrm"
	avatar.motion_resource = "res://assets/characters/roster/motions/shared_world_A01.tres"
	avatar.environment_mask = 1 | ACTOR_SOLID_LAYER
	avatar.auto_play = true
	avatar.initialized.connect(func():
		MTOON.apply(avatar.character, "huahuo")
		npc_ready = true
	)
	npc_anchor.add_child(avatar)
	npc_body = StaticBody3D.new()
	npc_body.name = "NPCBody"
	npc_body.collision_layer = NPC_SOLID_LAYER
	npc_body.collision_mask = 0
	npc_anchor.add_child(npc_body)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .24
	capsule.height = 1.45
	shape.position.y = .725
	shape.shape = capsule
	npc_body.add_child(shape)

func _build_combat_and_narrative_subsystems() -> void:
	# 1. Combat Dual-Actors (Hidden during normal exploration)
	combat_actors_root = Node3D.new()
	combat_actors_root.name = "CombatDualActors"
	combat_actors_root.transform = npc_anchor.transform
	combat_actors_root.visible = false
	add_child(combat_actors_root)
	
	sparkle_combat_actor = NPC.instantiate()
	sparkle_combat_actor.name = "SparkleBlowjob"
	sparkle_combat_actor.model_resource = "res://assets/characters/import_tests_local/huahuo/huahuo_fixed.vrm"
	sparkle_combat_actor.motion_resource = MOTION_SPARKLE_BLOWJOB
	sparkle_combat_actor.auto_play = true
	sparkle_combat_actor.environment_mask = 33
	sparkle_combat_actor.initialized.connect(func():
		MTOON.apply(sparkle_combat_actor.character, "huahuo")
	)
	combat_actors_root.add_child(sparkle_combat_actor)
	
	master_combat_actor = NPC.instantiate()
	master_combat_actor.name = "MasterReceiving"
	master_combat_actor.model_resource = "res://assets/characters/roster/lumine/lumine.vrm"
	master_combat_actor.motion_resource = MOTION_MASTER_RECEIVING
	master_combat_actor.auto_play = true
	master_combat_actor.environment_mask = 33
	master_combat_actor.initialized.connect(func():
		MTOON.apply(master_combat_actor.character, "lumine")
	)
	combat_actors_root.add_child(master_combat_actor)
	
	# Dedicated Combat Camera
	combat_camera = Camera3D.new()
	combat_camera.name = "CombatCamera"
	combat_camera.current = false
	add_child(combat_camera)
	
	# 2. Pleasure components
	player_pleasure = PleasureComponentClass.new()
	player_pleasure.name = "PlayerPleasure"
	player_pleasure.character_name = "主人"
	add_child(player_pleasure)
	
	npc_pleasure = PleasureComponentClass.new()
	npc_pleasure.name = "NPCPleasure"
	npc_pleasure.character_name = "花火"
	add_child(npc_pleasure)
	
	# 3. Combat manager
	combat_manager = TurnCombatManagerClass.new()
	combat_manager.name = "TurnCombatManager"
	add_child(combat_manager)
	combat_manager.setup(player_pleasure, npc_pleasure)
	
	# 4. Dialogue manager
	dialogue_manager = DialogueManagerClass.new()
	dialogue_manager.name = "DialogueManager"
	add_child(dialogue_manager)
	
	# 5. UI Canvas Layer
	var canvas := CanvasLayer.new()
	canvas.name = "TempleCombatCanvas"
	add_child(canvas)
	
	# Interaction Prompt Label
	interact_prompt = Label.new()
	interact_prompt.text = "【E】与花火交涉"
	interact_prompt.anchor_left = 0.4
	interact_prompt.anchor_right = 0.6
	interact_prompt.anchor_top = 0.72
	interact_prompt.anchor_bottom = 0.76
	interact_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interact_prompt.add_theme_font_size_override("font_size", 18)
	interact_prompt.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	interact_prompt.visible = false
	canvas.add_child(interact_prompt)
	
	combat_hud = TurnCombatHUDClass.new()
	combat_hud.name = "TurnCombatHUD"
	combat_hud.visible = false
	canvas.add_child(combat_hud)
	
	dialogue_panel = DialoguePanelClass.new()
	dialogue_panel.name = "DialoguePanel"
	dialogue_panel.visible = false
	canvas.add_child(dialogue_panel)
	
	# Signal bindings
	dialogue_manager.text_updated.connect(dialogue_panel.display_text)
	dialogue_manager.choices_presented.connect(dialogue_panel.display_choices)
	dialogue_panel.option_selected.connect(dialogue_manager.choose_option)
	dialogue_panel.next_pressed.connect(dialogue_manager.advance_text)
	dialogue_manager.dialogue_ended.connect(_on_dialogue_ended)
	
	combat_manager.log_message_emitted.connect(combat_hud.append_log)
	combat_manager.phase_changed.connect(_on_combat_phase_changed)
	combat_manager.combat_ended.connect(_on_combat_ended)
	combat_manager.mid_battle_dialogue_requested.connect(_on_mid_battle_dialogue_requested)
	
	combat_hud.action_chosen.connect(combat_manager.execute_player_action)
	combat_hud.meta_dialogue_requested.connect(combat_manager.request_in_battle_negotiation)
	
	player_pleasure.pleasure_changed.connect(combat_hud.update_player_pleasure)
	npc_pleasure.pleasure_changed.connect(combat_hud.update_npc_pleasure)

func _process(_delta: float) -> void:
	if not world or not is_instance_valid(world.character) or is_in_dialogue_or_combat:
		if interact_prompt and interact_prompt.visible:
			interact_prompt.visible = false
		return
		
	var player_pos: Vector3 = world.character.global_position
	var npc_pos: Vector3 = npc_anchor.global_position
	var dist: float = player_pos.distance_to(npc_pos)
	
	# Show prompt when within 2.8 meters
	if dist <= 2.8:
		interact_prompt.visible = true
		if Input.is_key_pressed(KEY_E) or Input.is_action_just_pressed("ui_accept"):
			_start_in_world_dialogue()
	else:
		interact_prompt.visible = false

func _start_in_world_dialogue() -> void:
	is_in_dialogue_or_combat = true
	interact_prompt.visible = false
	
	# Lock player character movement and camera
	if world and is_instance_valid(world.character):
		world.character.set_control_enabled(false)
		
	dialogue_panel.visible = true
	var graph: Dictionary = SparkleTutorialDialogueClass.get_dialogue_graph()
	var start_node := "start" if defeat_count == 0 else "respawn_dialogue"
	dialogue_manager.start_dialogue(graph, start_node)

func _set_combat_visuals(active: bool) -> void:
	if npc_anchor:
		npc_anchor.visible = not active
	combat_actors_root.visible = active
	
	if active:
		if world and is_instance_valid(world.character):
			world.character.visible = false
		var npc_pos: Vector3 = npc_anchor.global_position
		var basis: Basis = npc_anchor.global_transform.basis
		var forward: Vector3 = basis.z.normalized()
		var right: Vector3 = basis.x.normalized()
		var cam_pos: Vector3 = npc_pos + forward * 1.5 + right * 0.9 + Vector3.UP * 0.85
		combat_camera.global_position = cam_pos
		combat_camera.look_at(npc_pos + Vector3.UP * 0.65, Vector3.UP)
		combat_camera.current = true
	else:
		combat_camera.current = false
		if world and is_instance_valid(world.character):
			world.character.visible = true
			if world.character.camera:
				world.character.camera.current = true

func _on_dialogue_ended(payload: Dictionary) -> void:
	var action: String = payload.get("action", "close")
	
	# Mid-battle dialogue floating completion
	if combat_manager.current_phase == TurnCombatManagerClass.Phase.MID_BATTLE_DIALOGUE:
		dialogue_panel.visible = false
		combat_hud.visible = true
		var cheat_mode: String = dialogue_manager.blackboard.get("meta_cheat_mode", "none")
		if cheat_mode == "distracted":
			combat_manager.npc_pleasure.damage_taken_multiplier = 2.5
			combat_manager.log_message_emitted.emit("【战中识趣】花火故意走神了！受到的快感倍率提升至 2.5 倍！")
		elif cheat_mode == "lock_master_pleasure":
			combat_manager.player_pleasure.pleasure_locked = true
			combat_manager.player_pleasure.pleasure_cap = 90.0
			combat_manager.log_message_emitted.emit("【战中识趣】花火施加了保护！主人的快感上限被锁定在90%！")
		if dialogue_manager.blackboard.get("edging_endure", false):
			dialogue_manager.blackboard["edging_endure"] = false
			combat_manager.player_defense_ratio = 0.5
			combat_manager.log_message_emitted.emit("【咬牙忍耐】主人集中精神咬牙忍耐，本轮快感减免 50%！")
		var instant: bool = (cheat_mode == "instant_surrender")
		var is_edging: bool = (dialogue_manager.current_node_id.begins_with("mid_battle_edging"))
		combat_manager.resume_combat_after_dialogue(instant, is_edging)
		return
		
	if action == "enter_combat":
		dialogue_panel.visible = false
		combat_hud.visible = true
		_set_combat_visuals(true)
		
		var is_tutorial := (defeat_count == 0)
		var meta_rules := {
			"meta_cheat_mode": dialogue_manager.blackboard.get("meta_cheat_mode", "none")
		}
		combat_manager.start_combat(is_tutorial, meta_rules)
	elif action == "kill":
		dialogue_panel.visible = false
		_set_combat_visuals(false)
		is_in_dialogue_or_combat = false
		if world and is_instance_valid(world.character):
			world.character.set_control_enabled(true)
		print("【大世界结算】主人选择【杀掉】花火！激活物理玩弄尸体分支！")
	elif action == "spare":
		dialogue_panel.visible = false
		_set_combat_visuals(false)
		is_in_dialogue_or_combat = false
		if world and is_instance_valid(world.character):
			world.character.set_control_enabled(true)
		print("【大世界结算】主人选择【放过】花火！乞命侍奉达成，花火永久解锁为可用伙伴！")
	elif action == "close":
		dialogue_panel.visible = false
		is_in_dialogue_or_combat = false
		if world and is_instance_valid(world.character):
			world.character.set_control_enabled(true)
			if world.character.camera:
				world.character.camera.current = true

func _on_combat_phase_changed(phase: int) -> void:
	combat_hud.update_round(combat_manager.round_count)
	combat_hud.set_input_enabled(phase == TurnCombatManagerClass.Phase.PLAYER_INPUT)

func _on_combat_ended(winner: String, _loser: String, _reason: String) -> void:
	await get_tree().create_timer(1.0).timeout
	combat_hud.visible = false
	_set_combat_visuals(false)
	
	var graph: Dictionary = SparkleTutorialDialogueClass.get_dialogue_graph()
	if winner == "Sparkle":
		# Master defeated in teaching kill -> Respawn at temple doorway
		defeat_count += 1
		dialogue_manager.blackboard["defeat_count"] = defeat_count
		
		# Respawn master character at temple door and face inward
		if world and is_instance_valid(world.character):
			world.character.set_spawn(RESPAWN_POINT, RESPAWN_HEADING)
			world.character.set_control_enabled(true)
			if world.character.camera:
				world.character.camera.current = true
			
		dialogue_panel.visible = false
		is_in_dialogue_or_combat = false
		print("【大世界】主人败北射精虚脱，已在神殿门口重整旗鼓！请主人走入神殿再次与花火交涉。")
	else:
		# Sparkle defeated
		dialogue_panel.visible = true
		dialogue_manager.start_dialogue(graph, "victory_node")

func _on_mid_battle_dialogue_requested(reason: String) -> void:
	dialogue_panel.visible = true
	var graph: Dictionary = SparkleTutorialDialogueClass.get_dialogue_graph()
	var start_node := "mid_battle_manual" if reason == "player_manual_call" else "mid_battle_edging"
	dialogue_manager.start_dialogue(graph, start_node)
