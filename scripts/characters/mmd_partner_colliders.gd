extends Node3D
## Query-only partner proxies. They never push the authored body animation.
var skeleton: Skeleton3D
var layer: int
var enabled := true
var proxies: Array = []

func configure(p_skeleton: Skeleton3D, p_layer: int) -> void:
	skeleton = p_skeleton
	layer = p_layer
	_add("Head", "", .10, true)
	_add("Chest", "Neck", .10)
	_add("Pelvis", "Chest", .10)
	for side in ["Left", "Right"]:
		_add(side+"UpperArm", side+"LowerArm", .035)
		_add(side+"LowerArm", side+"Hand", .028)
		_add(side+"UpperLeg", side+"LowerLeg", .06)
		_add(side+"LowerLeg", side+"Foot", .04)
	update_proxies()

func _add(from: String, to: String, radius: float, sphere := false) -> void:
	var body := AnimatableBody3D.new()
	body.name = "Partner"+from
	body.sync_to_physics = false
	body.collision_layer = layer
	body.collision_mask = 0
	var node := CollisionShape3D.new()
	if sphere:
		var shape := SphereShape3D.new()
		shape.radius = radius
		node.shape = shape
	else:
		var shape := CapsuleShape3D.new()
		shape.radius = radius
		node.shape = shape
	body.add_child(node)
	add_child(body)
	proxies.append({"from":from,"to":to,"radius":radius,"sphere":sphere,"body":body,"shape":node.shape})

func _point(name: String) -> Vector3:
	if name == "Pelvis": return (_point("LeftUpperLeg")+_point("RightUpperLeg"))*.5
	var index := skeleton.find_bone(name)
	assert(index>=0, "Missing partner collider bone: "+name)
	return (skeleton.global_transform*skeleton.get_bone_global_pose(index)).origin

func update_proxies() -> void:
	if skeleton == null: return
	skeleton.force_update_all_bone_transforms()
	for proxy in proxies:
		proxy.body.collision_layer = layer if enabled else 0
		var a := _point(proxy.from)
		if proxy.sphere:
			var pose := skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone(proxy.from))
			proxy.body.global_position = a+pose.basis*Vector3(0,.08,0)
		else:
			var b := _point(proxy.to)
			var vector := b-a
			proxy.shape.height = vector.length()+2.0*proxy.radius
			proxy.body.global_transform = Transform3D(Basis(Quaternion(Vector3.UP,vector.normalized())),(a+b)*.5)
		proxy.body.force_update_transform()
		# Publish the kinematic target; Jolt exposes it after the physics step.
		PhysicsServer3D.body_set_state(proxy.body.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM,proxy.body.global_transform)
