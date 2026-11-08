@tool
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== DIAGNOSING CHARACTER FLOATING ===")
	
	# 1. Inspect Ganyu
	var ganyu_scene: PackedScene = load("res://scenes/characters/ganyu.tscn")
	var ganyu: Node3D = ganyu_scene.instantiate()
	root.add_child(ganyu)
	var g_skel: Skeleton3D = ganyu.find_child("GeneralSkeleton", true, false)
	var g_hips = g_skel.find_bone("Hips")
	var g_hips_rest = g_skel.get_bone_global_rest(g_hips)
	print("Ganyu Hips rest Y: ", g_hips_rest.origin.y)
	
	# Find lowest vertex of Ganyu in rest pose
	var g_min_y = 999.0
	for m in ganyu.find_children("*", "MeshInstance3D", true, false):
		var mesh = m.mesh
		for s in mesh.get_surface_count():
			var arr = mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for v in verts:
				if v.y < g_min_y: g_min_y = v.y
	print("Ganyu Mesh min Y (rest): ", g_min_y)
	
	# 2. Inspect Stelle
	var stelle_scene: PackedScene = load("res://assets/characters/roster/stelle/stelle.vrm")
	var stelle: Node3D = stelle_scene.instantiate()
	root.add_child(stelle)
	var s_skel: Skeleton3D = stelle.find_child("GeneralSkeleton", true, false)
	var s_hips = s_skel.find_bone("Hips")
	var s_hips_rest = s_skel.get_bone_global_rest(s_hips)
	print("Stelle Hips rest Y: ", s_hips_rest.origin.y)
	
	# Lowest vertex of Stelle in rest pose
	var s_min_y = 999.0
	for m in stelle.find_children("*", "MeshInstance3D", true, false):
		var mesh = m.mesh
		for s in mesh.get_surface_count():
			var arr = mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for v in verts:
				if v.y < s_min_y: s_min_y = v.y
	print("Stelle Mesh min Y (rest): ", s_min_y)
	
	# 3. Inspect Lumine and Firefly
	var lumine_scene: PackedScene = load("res://assets/characters/roster/lumine/lumine.vrm")
	var lumine: Node3D = lumine_scene.instantiate()
	root.add_child(lumine)
	var l_skel: Skeleton3D = lumine.find_child("GeneralSkeleton", true, false)
	var l_hips = l_skel.find_bone("Hips")
	var l_hips_rest = l_skel.get_bone_global_rest(l_hips)
	print("Lumine Hips rest Y: ", l_hips_rest.origin.y)
	
	var firefly_scene: PackedScene = load("res://assets/characters/roster/firefly/firefly.vrm")
	var firefly: Node3D = firefly_scene.instantiate()
	root.add_child(firefly)
	var f_skel: Skeleton3D = firefly.find_child("GeneralSkeleton", true, false)
	var f_hips = f_skel.find_bone("Hips")
	var f_hips_rest = f_skel.get_bone_global_rest(f_hips)
	print("Firefly Hips rest Y: ", f_hips_rest.origin.y)

	# 4. Inspect Animation A01.tres
	var a01: Animation = load("res://assets/characters/motion_review/A01.tres")
	print("\n--- A01.tres tracks ---")
	for t in a01.get_track_count():
		var path = str(a01.track_get_path(t))
		if "Hips" in path or "Root" in path:
			print("Track: ", path, " type: ", a01.track_get_type(t))
			if a01.track_get_type(t) == Animation.TYPE_POSITION_3D:
				var key0 = a01.position_track_interpolate(t, 0.0)
				print("   Pos @ t=0: ", key0)

	# 5. Test WorldCharacterController instantiated
	print("\n--- WorldCharacterController Test ---")
	var world_scene = load("res://scenes/characters/world_ganyu.tscn")
	var controller = world_scene.instantiate()
	root.add_child(controller)
	controller.active_character_id = "stelle"
	controller._apply_character_setup("stelle", true)
	
	for i in 5:
		await physics_frame
	
	var cur_hips_pose = controller.skeleton.get_bone_pose_position(controller.skeleton.find_bone("Hips"))
	print("Stelle in Controller Hips pose pos: ", cur_hips_pose)
	var cur_hips_global = controller.skeleton.get_bone_global_pose(controller.skeleton.find_bone("Hips"))
	print("Stelle in Controller Hips global pos: ", cur_hips_global.origin)
	
	# Check feet bones
	var l_foot = controller.skeleton.find_bone("LeftFoot")
	var r_foot = controller.skeleton.find_bone("RightFoot")
	var l_foot_g = controller.skeleton.get_bone_global_pose(l_foot).origin if l_foot >= 0 else Vector3.ZERO
	var r_foot_g = controller.skeleton.get_bone_global_pose(r_foot).origin if r_foot >= 0 else Vector3.ZERO
	print("Stelle LeftFoot global pose Y: ", l_foot_g.y)
	print("Stelle RightFoot global pose Y: ", r_foot_g.y)
	
	# Compare with Ganyu in Controller
	controller.switch_character("ganyu")
	for i in 5:
		await physics_frame
	var g_l_foot = controller.skeleton.find_bone("LeftFoot")
	var g_l_foot_g = controller.skeleton.get_bone_global_pose(g_l_foot).origin if g_l_foot >= 0 else Vector3.ZERO
	print("Ganyu LeftFoot global pose Y: ", g_l_foot_g.y)
	
	quit(0)
