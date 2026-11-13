extends Node3D
## One authored ruin, with a level platform and a fitted entry at each site.

const MODEL := preload("res://scenes/world/npc_waypoint_ruin.tscn")
const CONCRETE := preload("res://assets/world/cliff_b_test/architecture.tres")
const STORE := preload("res://scripts/grass_baked_store.gd")
const BAKE := "res://assets/world/npc_waypoint_ruins/grass_bake.json"
const GRASS_MARGIN := 0.42
const RAMP_END := 5.5
const RAMP_HALF_WIDTH := 1.3
const SITES := [
	# ID, finished floor, front yaw, three ground heights across the ramp toe.
	["amber", Vector3(248, 16.26, -30), 90.0, Vector3(16.144, 16.086, 16.028)],
	["eula", Vector3(-48, 1.37, -550), 0.0, Vector3(0.795, 0.823, 0.852)],
	["charlotte", Vector3(-322, 8.09, 439), 315.0, Vector3(7.462, 7.574, 7.686)],
	["sucrose", Vector3(106, 18.91, 160), 225.0, Vector3(18.765, 18.479, 18.188)],
	["hutao", Vector3(186, 25.56, 60), 90.0, Vector3(25.118, 25.000, 24.874)],
	["lumine", Vector3(-100, 7.98, 350), 270.0, Vector3(7.747, 7.822, 7.904)],
	["kafka", Vector3(-895, 35.06, 1151), 135.0, Vector3(35.0, 35.0, 35.0)],
]

var instances: Dictionary = {}
var installed_cells := 0


func _ready() -> void:
	name = "NPCWaypointRuins"
	for site: Array in SITES:
		var id: String = site[0]
		var ruin := MODEL.instantiate() as Node3D
		ruin.name = id
		ruin.position = site[1]
		ruin.rotation.y = deg_to_rad(site[2])
		ruin.get_node("Bench").set_meta("instance_id", "waypoint_" + id + "_bench")
		ruin.get_node("Structure").set_meta("source_id", "waypoint_" + id + "_structure")
		ruin.get_node("Bench/Body").set_meta("source_id", "waypoint_" + id + "_bench")
		_add_footing(ruin)
		_add_approach(ruin, site[3])
		add_child(ruin)
		instances[id] = ruin


func _add_footing(ruin: Node3D) -> void:
	# Set back from the slab edge, with the bottom below the measured slope.
	var footing := MeshInstance3D.new()
	footing.name = "Footing"
	var block := BoxMesh.new()
	block.size = Vector3(5.92, 0.76, 3.92)
	footing.mesh = block
	footing.position.y = -0.59
	footing.material_override = CONCRETE
	ruin.add_child(footing)
	var collider := CollisionShape3D.new()
	collider.name = "FootingCollision"
	var shape := BoxShape3D.new()
	shape.size = block.size
	collider.shape = shape
	collider.position = footing.position
	ruin.get_node("Structure").add_child(collider)


func _add_approach(ruin: Node3D, ground: Vector3) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var edge: Array[Vector3] = []
	var toe: Array[Vector3] = []
	for column in range(3):
		var x := float(column - 1) * RAMP_HALF_WIDTH
		edge.append(Vector3(x, -0.002, 1.985))
		toe.append(Vector3(x, ground[column] - ruin.position.y + 0.025, RAMP_END))
	for column in range(2):
		_quad(surface, faces, edge[column], edge[column+1], toe[column+1], toe[column])
		var drop := Vector3.DOWN * 0.82
		if column == 0:
			_quad(surface, faces, edge[0], toe[0], toe[0]+drop, edge[0]+drop)
		else:
			_quad(surface, faces, toe[2], edge[2], edge[2]+drop, toe[2]+drop)
		_quad(surface, faces, toe[column], toe[column+1], toe[column+1]+drop, toe[column]+drop)
	surface.generate_normals()
	var ramp := MeshInstance3D.new()
	ramp.name = "Approach"
	ramp.mesh = surface.commit()
	ramp.material_override = CONCRETE
	ruin.add_child(ramp)
	var collider := CollisionShape3D.new()
	collider.name = "ApproachCollision"
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	collider.shape = shape
	ruin.get_node("Structure").add_child(collider)


func _quad(surface: SurfaceTool, faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for point in [a,b,c,a,c,d]:
		faces.append(point)
		surface.add_vertex(point)


func blocks_grass(point: Vector3, margin := GRASS_MARGIN) -> bool:
	for site: Array in SITES:
		var offset: Vector3 = point - site[1]
		if absf(offset.y) > 1.05 or absf(offset.x) > 7.0 or absf(offset.z) > 7.0:
			continue
		var local := offset.rotated(Vector3.UP, -deg_to_rad(site[2]))
		if absf(local.x) < 3.0 + margin and absf(local.z) < 2.0 + margin:
			return true
		if absf(local.x) < RAMP_HALF_WIDTH + margin and local.z >= 2.0 and local.z < RAMP_END + margin:
			return true
	return false


func blocks_tree(point: Vector3) -> bool:
	# Preserve the approach sightline as well as the paved footprint.
	for site: Array in SITES:
		var offset: Vector3 = point - site[1]
		if absf(offset.y) > 2.0 or absf(offset.x) > 13.0 or absf(offset.z) > 13.0:
			continue
		var local := offset.rotated(Vector3.UP, -deg_to_rad(site[2]))
		if absf(local.x) < 3.45 and local.z > -2.45 and local.z < 2.45:
			return true
		if absf(local.x) < 2.15 and local.z >= 2.45 and local.z < 12.5:
			return true
	return false


func bind_grass(material: ShaderMaterial) -> void:
	var origins := PackedVector4Array()
	for site: Array in SITES:
		var p: Vector3 = site[1]
		origins.append(Vector4(p.x, p.y, p.z, deg_to_rad(site[2])))
	material.set_shader_parameter("waypoint_grass_sites", origins)
	material.set_shader_parameter("use_waypoint_grass_cut", true)


func overlaps_grass_cell(cell: Vector3i, cell_size: float) -> bool:
	var bounds := AABB(Vector3(cell) * cell_size, Vector3.ONE * cell_size)
	for site: Array in SITES:
		var center: Vector3 = site[1]
		if bounds.intersects(AABB(center - Vector3(7, 1.5, 7), Vector3(14, 3, 14))):
			return true
	return false


func bake_signature() -> String:
	return str(SITES, GRASS_MARGIN, RAMP_END, RAMP_HALF_WIDTH).sha256_text()


func install_grass_cells(stream: Node, world: Node) -> void:
	if not FileAccess.file_exists(BAKE):
		push_warning("Missing waypoint ruin grass bake.")
		return
	var bake: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BAKE))
	if bake.get("layout") != bake_signature() or bake.get("signature") != STORE.signature(world):
		push_warning("Stale waypoint ruin grass bake.")
		return
	for key: String in bake.cells:
		var row: Dictionary = bake.cells[key]
		var current: Dictionary = stream.store.manifest.get("cells", {}).get(key, {})
		if current.get("sha256", "") != row.source_sha256:
			push_warning("Waypoint grass source changed in cell " + key)
			continue
		stream.store.manifest.cells[key] = row
		var parts := key.split("_")
		stream.empty.erase(Vector3i(int(parts[0]), int(parts[1]), int(parts[2])))
		installed_cells += 1
	print("WAYPOINT_GRASS_CELLS ", installed_cells)
