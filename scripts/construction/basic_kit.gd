extends RefCounted
## Shared imported meshes/materials, inexpensive box or convex-wedge collisions.
const LIBRARY:=preload("res://assets/construction/basic_kit/kit.glb")
const BED:=preload("res://assets/furniture/prism/prism_geo_bed.tscn")
const CHAIR:=preload("res://assets/furniture/prism/prism_geo_chair.tscn")
const DESK:=preload("res://assets/furniture/prism/prism_geo_desk.tscn")
const WALL:=preload("res://assets/world/cliff_b_test/architecture.tres")
const TIMBER:=preload("res://assets/world/sandbar_pavilion_1109/materials_v3/honey_timber.tres")
const ROOF:=preload("res://assets/world/sandbar_pavilion_1109/materials_v3/sea_green_roof.tres")
var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/construction/basic_kit/catalog.json"))
var parts: Dictionary={}
var materials: Dictionary={}

func initialize() -> void:
	materials={"wall":WALL,"timber":TIMBER,"roof":ROOF}
	var glass:=StandardMaterial3D.new();glass.albedo_color=Color(.25,.55,.63,.24);glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS;glass.roughness=.18;glass.cull_mode=BaseMaterial3D.CULL_DISABLED
	var metal:=StandardMaterial3D.new();metal.albedo_color=Color("7d8e92");metal.metallic=.5;metal.roughness=.4
	materials.glass=glass;materials.metal=metal
	var library:=LIBRARY.instantiate()
	for row: Dictionary in catalog.parts:
		var node:=library.find_child(row.name,true,false) as MeshInstance3D
		assert(node!=null,"Missing imported construction part: "+str(row.name))
		if not parts.has(row.component):parts[row.component]=[]
		parts[row.component].append({"mesh":node.mesh,"material":materials[row.material]})
	library.free()

static func v(values: Array) -> Vector3:return Vector3(values[0],values[1],values[2])

func add_collision(parent: Node3D,row: Dictionary) -> void:
	var body:=StaticBody3D.new();body.collision_layer=33;body.collision_mask=0;body.set_meta("surface_kind","Structure");parent.add_child(body)
	var node:=CollisionShape3D.new()
	if row.shape=="box":
		var shape:=BoxShape3D.new();shape.size=v(row.size);node.shape=shape;node.position=v(row.position)
	else:
		var shape:=ConvexPolygonShape3D.new();var w:=float(row.width);var d:=float(row.length);var h:=float(row.height)
		shape.points=PackedVector3Array([Vector3(0,0,0),Vector3(w,0,0),Vector3(0,0,d),Vector3(w,0,d),Vector3(0,h,0),Vector3(w,h,0)])
		node.shape=shape;body.set_meta("colonly_ramp",true)
	body.add_child(node)

func make(definition: String) -> Node3D:
	var d: Dictionary=catalog.definitions[definition]
	var root: Node3D
	if d.kind=="furniture":
		root={"bed":BED,"chair":CHAIR,"desk":DESK}[definition].instantiate()
		for body: StaticBody3D in root.find_children("*","StaticBody3D",true,false):body.collision_layer=33;body.collision_mask=0
		if definition=="chair":
			# Existing chair wrapper has no collision. Actual sitting surface remains .42m.
			add_collision(root,{"shape":"box","size":[.88,.42,.86],"position":[0,.21,-.02]})
			add_collision(root,{"shape":"box","size":[.88,.42,.16],"position":[0,.63,-.39]})
		var approach:=Marker3D.new();approach.name="Anchor_Front";approach.position=v(d.approach);approach.rotation.y=PI;root.add_child(approach)
		root.set_meta("interaction_status","anchors_ready");root.set_meta("sleep_slots",d.get("sleep_slots",0))
	else:
		root=Node3D.new()
		for part: Dictionary in parts.get(definition,[]):
			var mesh:=MeshInstance3D.new();mesh.mesh=part.mesh;mesh.material_override=part.material;root.add_child(mesh)
		for collision: Dictionary in d.collisions:add_collision(root,collision)
		if definition=="door":
			var hinge:=make("door_leaf");hinge.name="DoorHinge";hinge.position.x=.32;root.add_child(hinge)
	root.set_meta("definition",definition)
	return root

func set_door(node: Node3D,opened: bool,direction: float=-1.) -> void:
	var hinge:=node.get_node_or_null("DoorHinge") as Node3D
	if hinge==null:return
	hinge.rotation.y=direction*PI*.5 if opened else 0.
