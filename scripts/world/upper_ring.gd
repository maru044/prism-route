extends Node3D
## Formal-map CAD feature, regional vegetation integration and authored courtyard grove.
const GEOMETRY := preload("res://assets/world/upper_ring_1030/pavilion.glb")
const MASK := preload("res://scripts/world/upper_ring_mask.gd")
const MATERIALS := preload("res://scripts/world/upper_ring_materials.gd")
const ACTOR_SOLID_LAYER := 32
var world
var planting_mask=MASK.new()
var manifest: Dictionary=planting_mask.manifest
var geometry: Node3D
var tree_nodes: Array[Node3D]=[]
var tree_records: Array[Dictionary]=[]
var materials: Dictionary={}
var material_set=MATERIALS.new()

func _ready() -> void:
	geometry=GEOMETRY.instantiate();geometry.name="ArchitectureAndHills";add_child(geometry)
	materials=material_set.build(world.terrain_material)
	var by_id: Dictionary={}
	for row: Dictionary in manifest.objects:by_id[row.id]=row
	for mesh: MeshInstance3D in geometry.find_children("*","MeshInstance3D",true,false):
		var id:=str(mesh.name).get_slice("_",1);var row: Dictionary=by_id[id]
		mesh.material_override=materials[row.material_key]
		var body:=StaticBody3D.new();body.collision_mask=0
		body.collision_layer=1|ACTOR_SOLID_LAYER|(16 if row.kind=="Terrain" else 0)
		body.set_meta("source_id",id);body.set_meta("surface_kind",row.kind);body.set_meta("upper_ring",true)
		mesh.add_child(body)
		var shape:=CollisionShape3D.new();shape.shape=mesh.mesh.create_trimesh_shape()
		shape.shape.backface_collision=true;body.add_child(shape)
		material_set.configure_mesh(mesh,row)

func adjusted_tree_position(p: Vector3) -> Vector3:
	if p.y<55 or p.y>75:return p
	var height:=planting_mask.height_at(p)
	if not is_finite(height) or height<=p.y+.04:return p
	# Match Jolt precisely once per nearby fixed tree; all remote tree records retain their coordinates.
	var query:=PhysicsRayQueryParameters3D.create(Vector3(p.x,height+.25,p.z),Vector3(p.x,height-.25,p.z),16)
	query.hit_back_faces=true
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	return Vector3(p.x,height,p.z) if hit.is_empty() else hit.position

func plant_courtyard(streamer: Node) -> void:
	for row: Dictionary in manifest.trees:
		var id: String=world.planting.ring_id(row)
		var effective: Dictionary=world.planting.store.all_records().get(id,{})
		if effective.is_empty():continue
		var p: Vector3=world.vec(effective.position)
		var model: int=world.planting.model_index(effective.species)
		var palette: int=world.planting.palette_index(effective.palette)
		var tree:=Node3D.new();tree.name=row.name;add_child(tree);tree_nodes.append(tree)
		var transform:=Transform3D(Basis(Vector3.UP,float(effective.yaw)).scaled(Vector3.ONE*float(effective.scale)),p)
		var transforms: Array[Transform3D]=[transform]
		for level in 3:streamer._add_tree_lod_level(tree,model,transforms,palette,level,0.)
		world.planting.bind_bucket([id],tree)
		for node: MultiMeshInstance3D in tree.find_children("*","MultiMeshInstance3D",true,false):
			if "LOD2" in str(node.name):node.visibility_range_end=6000.
		var body:=StaticBody3D.new();body.position=p;body.collision_layer=ACTOR_SOLID_LAYER;body.collision_mask=0;tree.add_child(body)
		body.set_meta("planting_id",id)
		var shape:=CollisionShape3D.new();var cylinder:=CylinderShape3D.new()
		cylinder.radius=.40*float(effective.scale);cylinder.height=2.5*float(effective.scale)
		shape.shape=cylinder;shape.position.y=cylinder.height*.5;body.add_child(shape)
		tree_records.append({"name":row.name,"model":model,"scale":effective.scale,"position":p,"bed":row.bed,"id":id})
		streamer.tree_instance_count+=1
		if model>0:streamer.large_tree_instance_count+=1
	print("UPPER_RING_COURTYARD_READY trees=",tree_records.size())
	material_set.add_probe(self)

func register_reflections(manager: Node) -> void:
	for mesh: MeshInstance3D in geometry.find_children("*","MeshInstance3D",true,false):
		if mesh.get_meta("upper_ring_material","") in ["glass","water"]:continue
		var color:=Color("e4e0d3")
		if mesh.material_override is StandardMaterial3D:color=mesh.material_override.albedo_color
		if mesh.material_override==world.terrain_material:color=Color("91a46b")
		manager.register_reflector(mesh,color)

func _process(delta: float) -> void:
	if not materials.is_empty():material_set.advance(delta)
