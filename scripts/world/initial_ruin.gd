extends Node3D
## World-aligned temple, ordinary NPC and furniture sockets exported from Rhino.
## Encounter and combat lifecycle is cleanly delegated to InitialTempleEncounterController.

const MASK := preload("res://scripts/world/initial_ruin_mask.gd")
const NPC := preload("res://scenes/characters/shared_humanoid_actor.tscn")
const FURNITURE := preload("res://scripts/world/interactive_furniture.gd")
const MTOON := preload("res://scripts/characters/mtoon_materials.gd")
const GEOMETRY := preload("res://assets/world/initial_ruin_1029/ruin.glb")
const WALK_COLLISION := preload("res://assets/world/initial_ruin_1029/walk_collision.glb")
const WALK_MANIFEST := "res://assets/world/initial_ruin_1029/walk_collision.json"
const ENCOUNTER_CONTROLLER := preload("res://scripts/world/initial_temple_encounter_controller.gd")

const ACTOR_SOLID_LAYER := 32
const NPC_SOLID_LAYER := 64
const RESPAWN_POINT := ENCOUNTER_CONTROLLER.RESPAWN_POINT
const RESPAWN_HEADING := ENCOUNTER_CONTROLLER.RESPAWN_HEADING

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

var encounter: Node

# Forwarded compatibility properties
var interact_prompt: Label:
	get:
		return encounter.interact_prompt if encounter else null

var dialogue_manager:
	get:
		return encounter.dialogue_manager if encounter else null

var combat_manager:
	get:
		return encounter.combat_manager if encounter else null

var dialogue_panel:
	get:
		return encounter.dialogue_panel if encounter else null

var combat_hud:
	get:
		return encounter.combat_hud if encounter else null

var player_pleasure:
	get:
		return encounter.player_pleasure if encounter else null

var npc_pleasure:
	get:
		return encounter.npc_pleasure if encounter else null

var combat_actors_root:
	get:
		return encounter.combat_actors_root if encounter else null

var defeat_count: int:
	get:
		return encounter.defeat_count if encounter else 0
	set(val):
		if encounter:
			encounter.defeat_count = val

var is_in_dialogue_or_combat: bool:
	get:
		if not encounter:
			return false
		return (
			encounter.current_state != ENCOUNTER_CONTROLLER.EncounterState.AVAILABLE
			and encounter.current_state != ENCOUNTER_CONTROLLER.EncounterState.COMPLETED
		)

func _ready() -> void:
	_build_geometry()
	_build_walk_collision()
	_build_furniture()
	_build_npc()
	_build_encounter_controller()

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

func _build_encounter_controller() -> void:
	encounter = ENCOUNTER_CONTROLLER.new()
	encounter.name = "InitialTempleEncounterController"
	add_child(encounter)
	encounter.initialize(self, world, npc_anchor, avatar, npc_body)

func _process(delta: float) -> void:
	if encounter:
		encounter.tick(delta)

# Compatibility helper
func _start_in_world_dialogue() -> void:
	if encounter:
		encounter.start_encounter_dialogue()
