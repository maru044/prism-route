@tool
extends SceneTree

func _init() -> void:
	var cat_path := "res://assets/characters/mmd_validation/paired/catalog.json"
	var file := FileAccess.open(cat_path, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	var packs: Array = data.get("packs", [])
	
	for p in packs:
		var pid: String = p.get("id", "")
		var lbl: String = p.get("label", "")
		if pid in ["mmd_6e891982bb51", "mmd_781d8c87fd79", "mmd_71dec5bd8390", "mmd_16a2ecfb7781", "mmd_160b1e7a411c"]:
			print("=== ", pid, " (", lbl, ") ===")
			for r in p.roles:
				var mpath: String = r.get("motion", "")
				var anim: Animation = load(mpath)
				if anim:
					for t in range(anim.get_track_count()):
						var path_str := str(anim.track_get_path(t))
						if path_str.to_lower().contains("hips") and anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
							var r0: Quaternion = anim.rotation_track_interpolate(t, 0.0)
							var e0: Vector3 = r0.get_euler()
							print("  Role ", r.id, " Hips Rot @0s: euler deg=", Vector3(rad_to_deg(e0.x), rad_to_deg(e0.y), rad_to_deg(e0.z)))
						if path_str.to_lower().contains("hips") and anim.track_get_type(t) == Animation.TYPE_POSITION_3D:
							var p0: Vector3 = anim.position_track_interpolate(t, 0.0)
							print("  Role ", r.id, " Hips Pos @0s: ", p0)
	quit(0)
