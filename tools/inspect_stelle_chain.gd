@tool
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var stelle_scene: PackedScene = load("res://assets/characters/roster/stelle/stelle.vrm")
	var stelle: Node3D = stelle_scene.instantiate()
	root.add_child(stelle)
	var skel: Skeleton3D = stelle.find_child("GeneralSkeleton", true, false)
	
	var hips = skel.find_bone("Hips")
	print("--- Bone chain for Hips in Stelle ---")
	var curr = hips
	while curr >= 0:
		print("Bone [", curr, "] '", skel.get_bone_name(curr), "' rest: ", skel.get_bone_rest(curr).origin, " global_rest: ", skel.get_bone_global_rest(curr).origin)
		curr = skel.get_bone_parent(curr)
		
	var r_foot = skel.find_bone("RightFoot")
	print("\n--- Bone chain for RightFoot in Stelle ---")
	curr = r_foot
	while curr >= 0:
		print("Bone [", curr, "] '", skel.get_bone_name(curr), "' rest: ", skel.get_bone_rest(curr).origin, " global_rest: ", skel.get_bone_global_rest(curr).origin)
		curr = skel.get_bone_parent(curr)
		
	quit(0)
