class_name HomeIntimacyCatalog
extends RefCounted
## Catalog of dual-role intimacy animations for home rooms.
## Categorized into 普通侍奉 (Normal Service) and 本番深入 (Honban Intimacy).
## Maps motions to required furniture (bed, chair, desk, or ground) and anchor sockets.

const SERVICE_MOTIONS: Array[Dictionary] = [
	{
		"id": "mmd_0a3f6ba5f5de",
		"name": "床沿仰卧胸部侍奉",
		"tier": "service",
		"furniture": "bed",
		"anchor": "Anchor_BedEdge_Front",
		"duration": 84.9,
		"role_a_motion": "res://assets/characters/mmd_selected/animations/mmd_0a3f6ba5f5de_a.tres",
		"role_b_motion": "res://assets/characters/mmd_selected/animations/mmd_0a3f6ba5f5de_b.tres",
		"desc": "床沿仰卧互动，前戏胸部轻柔抚慰"
	},
	{
		"id": "mmd_781d8c87fd79",
		"name": "沙发端坐受纳口交",
		"tier": "service",
		"furniture": "chair",
		"anchor": "Anchor_Seat",
		"duration": 140.0,
		"role_a_motion": "res://assets/characters/mmd_selected/animations/mmd_781d8c87fd79_a.tres",
		"role_b_motion": "res://assets/characters/mmd_selected/animations/mmd_781d8c87fd79_b.tres",
		"desc": "受纳方端坐椅上，侍奉方跪地侍奉"
	},
	{
		"id": "mmd_beee0d2eb57b",
		"name": "坐姿膝上怀抱把玩",
		"tier": "service",
		"furniture": "chair",
		"anchor": "Anchor_Seat",
		"duration": 33.6,
		"role_a_motion": "res://assets/characters/mmd_selected/animations/mmd_beee0d2eb57b_a.tres",
		"role_b_motion": "res://assets/characters/mmd_selected/animations/mmd_beee0d2eb57b_b.tres",
		"desc": "受纳方端坐椅上，侍奉方坐于膝上亲密相拥"
	},
	{
		"id": "kk_isu_matagari_fera",
		"name": "跨坐椅子俯身口交",
		"tier": "service",
		"furniture": "chair",
		"anchor": "Anchor_Seat",
		"duration": 1.3,
		"role_a_motion": "res://assets/characters/mmd_validation/paired/kk_isu_matagari_fera_a.tres",
		"role_b_motion": "res://assets/characters/mmd_validation/paired/kk_isu_matagari_fera_b.tres",
		"desc": "侍奉方反向跨坐椅背俯身侍奉"
	},
	{
		"id": "mmd_16a2ecfb7781",
		"name": "双人平躺口交侍奉",
		"tier": "service",
		"furniture": "ground",
		"anchor": "ground",
		"duration": 66.3,
		"role_a_motion": "res://assets/characters/mmd_selected/animations/mmd_16a2ecfb7781_a.tres",
		"role_b_motion": "res://assets/characters/mmd_selected/animations/mmd_16a2ecfb7781_b.tres",
		"desc": "双人同向平躺地面/席位轻柔侍奉"
	},
	{
		"id": "mmd_67d58e9d607e",
		"name": "女王踩踏足交",
		"tier": "service",
		"furniture": "ground",
		"anchor": "ground",
		"duration": 37.3,
		"role_a_motion": "res://assets/characters/mmd_selected/animations/mmd_67d58e9d607e_a.tres",
		"role_b_motion": "res://assets/characters/mmd_selected/animations/mmd_67d58e9d607e_b.tres",
		"desc": "受纳方仰卧地面，侍奉方站姿足下侍奉"
	},
	{
		"id": "mmd_fcc0340f8227",
		"name": "站姿受纳跪地侍奉",
		"tier": "service",
		"furniture": "ground",
		"anchor": "ground",
		"duration": 37.3,
		"role_a_motion": "res://assets/characters/mmd_selected/animations/mmd_fcc0340f8227_a.tres",
		"role_b_motion": "res://assets/characters/mmd_selected/animations/mmd_fcc0340f8227_b.tres",
		"desc": "受纳方站姿，侍奉方端正跪姿侍奉"
	},
	{
		"id": "mmd_8c5c490fb87c",
		"name": "背后贴身亲密爱抚",
		"tier": "service",
		"furniture": "ground",
		"anchor": "ground",
		"duration": 33.3,
		"role_a_motion": "res://assets/characters/mmd_selected/animations/mmd_8c5c490fb87c_a.tres",
		"role_b_motion": "res://assets/characters/mmd_selected/animations/mmd_8c5c490fb87c_b.tres",
		"desc": "双人站姿背后贴身紧密相依"
	},
	{
		"id": "mmd_86e40adc8f14",
		"name": "站姿相拥股间素股",
		"tier": "service",
		"furniture": "ground",
		"anchor": "ground",
		"duration": 49.6,
		"role_a_motion": "res://assets/characters/mmd_selected/animations/mmd_86e40adc8f14_a.tres",
		"role_b_motion": "res://assets/characters/mmd_selected/animations/mmd_86e40adc8f14_b.tres",
		"desc": "双人站姿相拥，腿部局部贴合温存"
	},
	{
		"id": "kk_sakiname",
		"name": "轻柔舔弄前戏",
		"tier": "service",
		"furniture": "ground",
		"anchor": "ground",
		"duration": 1.3,
		"role_a_motion": "res://assets/characters/mmd_validation/paired/kk_sakiname_a.tres",
		"role_b_motion": "res://assets/characters/mmd_validation/paired/kk_sakiname_b.tres",
		"desc": "跪姿轻柔抚弄前戏"
	},
	{
		"id": "kk_ryoutekoki",
		"name": "面对面双手手交",
		"tier": "service",
		"furniture": "ground",
		"anchor": "ground",
		"duration": 1.3,
		"role_a_motion": "res://assets/characters/mmd_validation/paired/kk_ryoutekoki_a.tres",
		"role_b_motion": "res://assets/characters/mmd_validation/paired/kk_ryoutekoki_b.tres",
		"desc": "面对面跪姿双手细腻侍奉"
	},
	{
		"id": "kk_nohand_fera",
		"name": "站姿无手纯口交",
		"tier": "service",
		"furniture": "ground",
		"anchor": "ground",
		"duration": 1.3,
		"role_a_motion": "res://assets/characters/mmd_validation/paired/kk_nohand_fera_a.tres",
		"role_b_motion": "res://assets/characters/mmd_validation/paired/kk_nohand_fera_b.tres",
		"desc": "站姿独立侍奉"
	},
	{
		"id": "kk_tachi_paizuri_kuwae",
		"name": "站姿夹胸兼含吮",
		"tier": "service",
		"furniture": "ground",
		"anchor": "ground",
		"duration": 1.3,
		"role_a_motion": "res://assets/characters/mmd_validation/paired/kk_tachi_paizuri_kuwae_a.tres",
		"role_b_motion": "res://assets/characters/mmd_validation/paired/kk_tachi_paizuri_kuwae_b.tres",
		"desc": "站姿多重局部亲密抚慰"
	},
	{
		"id": "kk_oshitsuke_paizuri",
		"name": "贴身压迫乳交",
		"tier": "service",
		"furniture": "ground",
		"anchor": "ground",
		"duration": 1.3,
		"role_a_motion": "res://assets/characters/mmd_validation/paired/kk_oshitsuke_paizuri_a.tres",
		"role_b_motion": "res://assets/characters/mmd_validation/paired/kk_oshitsuke_paizuri_b.tres",
		"desc": "站姿贴身紧密夹触"
	},
	{
		"id": "kk_mitchaku_tekoki",
		"name": "站姿贴身耳语手交",
		"tier": "service",
		"furniture": "ground",
		"anchor": "ground",
		"duration": 1.3,
		"role_a_motion": "res://assets/characters/mmd_validation/paired/kk_mitchaku_tekoki_a.tres",
		"role_b_motion": "res://assets/characters/mmd_validation/paired/kk_mitchaku_tekoki_b.tres",
		"desc": "站姿背后贴面亲昵手交"
	},
	{
		"id": "kk_tagai_ijiri",
		"name": "站姿双女相互爱抚",
		"tier": "service",
		"furniture": "ground",
		"anchor": "ground",
		"duration": 1.3,
		"role_a_motion": "res://assets/characters/mmd_validation/paired/kk_tagai_ijiri_a.tres",
		"role_b_motion": "res://assets/characters/mmd_validation/paired/kk_tagai_ijiri_b.tres",
		"desc": "两位女性站立面对面零距离贴靠并同步彼此挑逗爱抚"
	}
]

const HONBAN_MOTIONS: Array[Dictionary] = [
	{
		"id": "mmd_43916ffe3d35",
		"name": "双人夜色卧姿骑乘",
		"tier": "honban",
		"furniture": "bed",
		"anchor": "Anchor_Bed_Center",
		"duration": 234.3,
		"role_a_motion": "res://assets/characters/mmd_selected/animations/mmd_43916ffe3d35_a.tres",
		"role_b_motion": "res://assets/characters/mmd_selected/animations/mmd_43916ffe3d35_b.tres",
		"desc": "软榻正中双人相拥卧姿深入骑乘"
	},
	{
		"id": "kk_sofa_kijoui",
		"name": "长榻沙发骑乘深入",
		"tier": "honban",
		"furniture": "bed",
		"anchor": "Anchor_BedEdge_Front",
		"duration": 1.3,
		"role_a_motion": "res://assets/characters/mmd_validation/paired/kk_sofa_kijoui_a.tres",
		"role_b_motion": "res://assets/characters/mmd_validation/paired/kk_sofa_kijoui_b.tres",
		"desc": "床沿坐姿深入起伏骑乘"
	},
	{
		"id": "mmd_160b1e7a411c",
		"name": "浪漫情侣背面坐位",
		"tier": "honban",
		"furniture": "chair",
		"anchor": "Anchor_Seat",
		"duration": 78.0,
		"role_a_motion": "res://assets/characters/mmd_selected/animations/mmd_160b1e7a411c_a.tres",
		"role_b_motion": "res://assets/characters/mmd_selected/animations/mmd_160b1e7a411c_b.tres",
		"desc": "受纳方坐在单人椅上，侍奉方背面跨坐结合"
	},
	{
		"id": "kk_isu_taimen",
		"name": "椅子面对面抱坐位",
		"tier": "honban",
		"furniture": "chair",
		"anchor": "Anchor_Seat",
		"duration": 1.3,
		"role_a_motion": "res://assets/characters/mmd_validation/paired/kk_isu_taimen_a.tres",
		"role_b_motion": "res://assets/characters/mmd_validation/paired/kk_isu_taimen_b.tres",
		"desc": "椅子上正向相拥深入结合"
	},
	{
		"id": "kk_isu_back",
		"name": "扶椅背站姿后背位",
		"tier": "honban",
		"furniture": "chair",
		"anchor": "Anchor_Seat",
		"duration": 1.3,
		"role_a_motion": "res://assets/characters/mmd_validation/paired/kk_isu_back_a.tres",
		"role_b_motion": "res://assets/characters/mmd_validation/paired/kk_isu_back_b.tres",
		"desc": "侍奉方俯身扶椅背，后背深入结合"
	},
	{
		"id": "mmd_fca4bab1635f",
		"name": "经典俯身扶桌后背位",
		"tier": "honban",
		"furniture": "desk",
		"anchor": "Anchor_Desk_Surface",
		"duration": 56.7,
		"role_a_motion": "res://assets/characters/mmd_selected/animations/mmd_fca4bab1635f_a.tres",
		"role_b_motion": "res://assets/characters/mmd_selected/animations/mmd_fca4bab1635f_b.tres",
		"desc": "角色俯身手扶长案桌面，后背深入结合"
	},
	{
		"id": "kk_tsukue_nei",
		"name": "桌面仰卧站插位",
		"tier": "honban",
		"furniture": "desk",
		"anchor": "Anchor_Desk_Surface",
		"duration": 1.3,
		"role_a_motion": "res://assets/characters/mmd_validation/paired/kk_tsukue_nei_a.tres",
		"role_b_motion": "res://assets/characters/mmd_validation/paired/kk_tsukue_nei_b.tres",
		"desc": "角色仰卧于长案案面，站姿深入结合"
	},
	{
		"id": "mmd_87e004f6db53",
		"name": "日式仰卧正常位",
		"tier": "honban",
		"furniture": "ground",
		"anchor": "ground",
		"duration": 61.1,
		"role_a_motion": "res://assets/characters/mmd_selected/animations/mmd_87e004f6db53_a.tres",
		"role_b_motion": "res://assets/characters/mmd_selected/animations/mmd_87e004f6db53_b.tres",
		"desc": "经典地面/席位双人相拥仰卧正常位"
	},
	{
		"id": "mmd_2864892bd378",
		"name": "情趣后背跪趴位",
		"tier": "honban",
		"furniture": "ground",
		"anchor": "ground",
		"duration": 66.9,
		"role_a_motion": "res://assets/characters/mmd_selected/animations/mmd_2864892bd378_a.tres",
		"role_b_motion": "res://assets/characters/mmd_selected/animations/mmd_2864892bd378_b.tres",
		"desc": "跪趴地面后背位结合"
	},
	{
		"id": "mmd_1256ad646811",
		"name": "双人侧卧相拥汤匙位",
		"tier": "honban",
		"furniture": "ground",
		"anchor": "ground",
		"duration": 30.3,
		"role_a_motion": "res://assets/characters/mmd_selected/animations/mmd_1256ad646811_a.tres",
		"role_b_motion": "res://assets/characters/mmd_selected/animations/mmd_1256ad646811_b.tres",
		"desc": "亲密侧卧相拥，自然贴合结合"
	},
	{
		"id": "mmd_c63e75bc7057",
		"name": "悬空抱操结合",
		"tier": "honban",
		"furniture": "ground",
		"anchor": "ground",
		"duration": 33.3,
		"role_a_motion": "res://assets/characters/mmd_selected/animations/mmd_c63e75bc7057_a.tres",
		"role_b_motion": "res://assets/characters/mmd_selected/animations/mmd_c63e75bc7057_b.tres",
		"desc": "站姿托抱悬空深入结合"
	},
	{
		"id": "kk_tanetsuke_press",
		"name": "深压折腿正常位",
		"tier": "honban",
		"furniture": "ground",
		"anchor": "ground",
		"duration": 1.3,
		"role_a_motion": "res://assets/characters/mmd_validation/paired/kk_tanetsuke_press_a.tres",
		"role_b_motion": "res://assets/characters/mmd_validation/paired/kk_tanetsuke_press_b.tres",
		"desc": "地面深压折叠正常位深入结合"
	},
	{
		"id": "kk_manguri_seijoui",
		"name": "M字折叠压腿位",
		"tier": "honban",
		"furniture": "ground",
		"anchor": "ground",
		"duration": 1.3,
		"role_a_motion": "res://assets/characters/mmd_validation/paired/kk_manguri_seijoui_a.tres",
		"role_b_motion": "res://assets/characters/mmd_validation/paired/kk_manguri_seijoui_b.tres",
		"desc": "双腿展开M字压制位深入结合"
	},
	{
		"id": "kk_udehippari_kouhai",
		"name": "拉臂掌控后背位",
		"tier": "honban",
		"furniture": "ground",
		"anchor": "ground",
		"duration": 1.3,
		"role_a_motion": "res://assets/characters/mmd_validation/paired/kk_udehippari_kouhai_a.tres",
		"role_b_motion": "res://assets/characters/mmd_validation/paired/kk_udehippari_kouhai_b.tres",
		"desc": "地面后背位牵引深入结合"
	},
	{
		"id": "kk_neback",
		"name": "贴地俯卧后背位",
		"tier": "honban",
		"furniture": "ground",
		"anchor": "ground",
		"duration": 1.3,
		"role_a_motion": "res://assets/characters/mmd_validation/paired/kk_neback_a.tres",
		"role_b_motion": "res://assets/characters/mmd_validation/paired/kk_neback_b.tres",
		"desc": "贴地俯卧后背深入结合"
	},
	{
		"id": "kk_kabe_taimen_ashiage",
		"name": "面对面抬腿结合",
		"tier": "honban",
		"furniture": "ground",
		"anchor": "ground",
		"duration": 1.3,
		"role_a_motion": "res://assets/characters/mmd_validation/paired/kk_kabe_taimen_ashiage_a.tres",
		"role_b_motion": "res://assets/characters/mmd_validation/paired/kk_kabe_taimen_ashiage_b.tres",
		"desc": "面对面站姿抬单腿深入结合"
	},
	{
		"id": "kk_kabe_back_ashiage",
		"name": "扶墙抬腿后背位",
		"tier": "honban",
		"furniture": "ground",
		"anchor": "ground",
		"duration": 1.3,
		"role_a_motion": "res://assets/characters/mmd_validation/paired/kk_kabe_back_ashiage_a.tres",
		"role_b_motion": "res://assets/characters/mmd_validation/paired/kk_kabe_back_ashiage_b.tres",
		"desc": "后背站姿抬单腿深入结合"
	}
]

static func get_motions(tier: String) -> Array[Dictionary]:
	if tier == "honban":
		return HONBAN_MOTIONS
	return SERVICE_MOTIONS

static func can_play_in_room(motion: Dictionary, available_furniture: Array) -> bool:
	var req_furn: String = str(motion.get("furniture", "ground"))
	if req_furn == "ground" or req_furn.is_empty():
		return true
	if req_furn == "chair":
		return ("chair" in available_furniture) or ("bench" in available_furniture)
	return req_furn in available_furniture

static func get_furniture_label(furniture_key: String) -> String:
	match furniture_key:
		"bed":
			return "床榻"
		"chair":
			return "座椅"
		"desk":
			return "长案"
		_:
			return "地席"

static func get_role_placements(motion: Dictionary) -> Dictionary:
	if motion.has("role_a_placement") and motion.has("role_b_placement"):
		return {
			"role_a_placement": motion["role_a_placement"],
			"role_b_placement": motion["role_b_placement"]
		}
	var m_id: String = str(motion.get("id", ""))
	var furn: String = str(motion.get("furniture", "ground"))
	match m_id:
		"mmd_fca4bab1635f":
			return {
				"role_a_placement": {"offset": [0.0, -0.838, 0.0], "yaw_degrees": 0.0},
				"role_b_placement": {"offset": [0.0, -0.822, 0.0], "yaw_degrees": 0.0}
			}
		"kk_tsukue_nei":
			return {
				"role_a_placement": {"offset": [0.0, -0.838, 0.0], "yaw_degrees": 0.0},
				"role_b_placement": {"offset": [0.0, -0.838, 0.0], "yaw_degrees": 0.0}
			}
		"mmd_0a3f6ba5f5de":
			return {
				"role_a_placement": {"offset": [0.0, -0.42, 0.25], "yaw_degrees": 0.0},
				"role_b_placement": {"offset": [0.0, -0.335, 0.0], "yaw_degrees": 0.0}
			}
		"mmd_43916ffe3d35":
			return {
				"role_a_placement": {"offset": [0.0, -0.02, 0.0], "yaw_degrees": 0.0},
				"role_b_placement": {"offset": [0.0, 0.0, 0.22], "yaw_degrees": 0.0}
			}
		"kk_sofa_kijoui":
			return {
				"role_a_placement": {"offset": [0.0, 0.0, 0.0], "yaw_degrees": 0.0},
				"role_b_placement": {"offset": [0.0, 0.0, 0.0], "yaw_degrees": 0.0}
			}
		_:
			if furn == "chair":
				return {
					"role_a_placement": {"offset": [0.0, -0.42, 0.0], "yaw_degrees": 0.0},
					"role_b_placement": {"offset": [0.0, -0.42, 0.0], "yaw_degrees": 0.0}
				}
			elif furn == "desk":
				return {
					"role_a_placement": {"offset": [0.0, -0.838, 0.0], "yaw_degrees": 0.0},
					"role_b_placement": {"offset": [0.0, -0.838, 0.0], "yaw_degrees": 0.0}
				}
			else:
				return {
					"role_a_placement": {"offset": [0.0, 0.0, 0.0], "yaw_degrees": 0.0},
					"role_b_placement": {"offset": [0.0, 0.0, 0.0], "yaw_degrees": 0.0}
				}

static func calculate_role_targets(contact_transform: Transform3D, motion: Dictionary) -> Dictionary:
	var placements := get_role_placements(motion)
	var a_placement: Dictionary = placements.get("role_a_placement", {"offset": [0.0, 0.0, 0.0], "yaw_degrees": 0.0})
	var b_placement: Dictionary = placements.get("role_b_placement", {"offset": [0.0, 0.0, 0.0], "yaw_degrees": 0.0})
	return {
		"role_a_target": _calc_target(contact_transform, a_placement),
		"role_b_target": _calc_target(contact_transform, b_placement)
	}

static func _calc_target(contact: Transform3D, placement: Dictionary) -> Transform3D:
	var offset: Array = placement.get("offset", [0.0, 0.0, 0.0])
	var yaw: float = deg_to_rad(float(placement.get("yaw_degrees", 0.0)))
	var local := Transform3D(Basis(Vector3.UP, yaw), Vector3(float(offset[0]), float(offset[1]), float(offset[2])))
	return contact * local
