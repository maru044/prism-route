extends RefCounted
## Stand positions from the world placement plan. Ruin points use live anchors.
## A fifth value of true marks an individual visitor in a mixed region.

const CAPE_VISITORS := "海岬小镇 · 来访角色"
const CLIFF_WALKWAY := "异形镂空崖壁 · 底层步道"

## Region and character identify a placement, so a visitor can use a different
## slot from the same character's main placement.
## Each binding names a world-relative furniture instance and its contact anchor.
const FURNITURE_BINDINGS := {
	"初始神殿与洞穴": {
		"sparkle": [
			[^"InitialRuin/FurnitureInteractions/seat_01", &"Anchor_Seat"],
			[^"InitialRuin/FurnitureInteractions/rest_01", &"Anchor_Bed_Center"],
			[^"InitialRuin/FurnitureInteractions/table_01", &"Anchor_Desk_Surface"],
		],
		"kafka": [[^"NPCWaypointRuins/kafka/Bench", &"Anchor_Seat"]],
	},
	"沙洲度假遗址": {
		"ganyu": [[^"SandbarPavilion/FurnitureInteractions/seat_01", &"Anchor_Seat"]],
		"keqing": [[^"SandbarPavilion/FurnitureInteractions/desk_01", &"Anchor_Desk_Surface"]],
		"yelan": [
			[^"SandbarPavilion/FurnitureInteractions/cafe_seat_01", &"Anchor_Seat"],
			[^"SandbarPavilion/FurnitureInteractions/cafe_desk", &"Anchor_Desk_Surface"],
		],
		"ningguang": [[^"SandbarPavilion/FurnitureInteractions/lounger_01", &"Anchor_Bed_Center"]],
	},
	"海岬小镇与神社": {
		"yae_miko": [[^"CapeTown/FurnitureInteractions/shrine_table", &"Anchor_Desk_Surface"]],
		"kirara": [[^"CapeTown/FurnitureInteractions/bench_2", &"Anchor_Seat"]],
	},
	"草甸与观景点": {
		"amber": [[^"NPCWaypointRuins/amber/Bench", &"Anchor_Seat"]],
		"eula": [[^"NPCWaypointRuins/eula/Bench", &"Anchor_Seat"]],
		"charlotte": [[^"NPCWaypointRuins/charlotte/Bench", &"Anchor_Seat"]],
		"sucrose": [[^"NPCWaypointRuins/sucrose/Bench", &"Anchor_Seat"]],
		"hutao": [[^"NPCWaypointRuins/hutao/Bench", &"Anchor_Seat"]],
		"lumine": [[^"NPCWaypointRuins/lumine/Bench", &"Anchor_Seat"]],
	},
	"次要点位": {
		"barbara": [[^"SandbarPavilion/FurnitureInteractions/cafe_seat_02", &"Anchor_Seat"]],
		"march7th": [[^"NPCWaypointRuins/amber/Bench", &"Anchor_Seat"]],
		"firefly": [[^"NPCWaypointRuins/eula/Bench", &"Anchor_Seat"]],
	},
}

static func resolve_furniture(world: Node, region: String, character_id: String) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	for binding: Array in FURNITURE_BINDINGS.get(region, {}).get(character_id, []):
		var furniture := world.get_node_or_null(binding[0]) as InteractiveFurniture
		if furniture == null:
			continue
		var approach := furniture.get_motion_anchor_node("Anchor_Front")
		var contact := furniture.get_motion_anchor_node(binding[1])
		if approach != null and contact != null:
			targets.append({
				"instance_id": furniture.get_meta("instance_id", str(binding[0])),
				"furniture": furniture,
				"approach": approach,
				"contact": contact,
			})
	return targets

const REGIONS := {
	"浅水庭院": [
		["furina", "芙宁娜", Vector3(-904.000, 0.280, 624.000), 0.0],
		["nilou", "妮露", Vector3(-915.000, 0.280, 633.000), 45.0],
		["kokomi", "珊瑚宫心海", Vector3(-895.0, 0.28, 622.0), -90.0],
	],
	"孤顶教堂": [
		["barbara", "芭芭拉", Vector3(-1326.000, 42.500, 88.000), -10.0],
		["rosaria", "罗莎莉亚", Vector3(-1345.000, 43.400, 113.000), -45.0],
		["jean", "琴", Vector3(-1341.000, 43.400, 117.000), 25.0],
		["noelle", "诺艾尔", Vector3(-1336.000, 43.400, 116.000), -90.0],
	],
	"海岬小镇与神社": [
		["yae_miko", "八重神子", Vector3(657.112, 1.770, -1223.655), -34.0],
		["raiden_shogun", "雷电将军", Vector3(660.000, 1.320, -1229.000), 145.0],
		["ayaka", "神里绫华 · 二层", Vector3(648.411, 4.840, -1147.240), 131.0],
		["yoimiya", "宵宫 · 首层", Vector3(611.399, 1.440, -1037.523), 26.0],
		["kirara", "绮良良", Vector3(669.745, 1.320, -1073.395), -34.0],
		["kuki_shinobu", "久岐忍 · 二层", Vector3(681.092, 4.840, -1082.469), -149.0],
		["silver_wolf", "银狼 · 三层", Vector3(614.407, 8.240, -1087.357), -174.0],
		["stelle", "星 · 首层", Vector3(608.796, 1.440, -1077.870), -19.0],
		["march7th", "三月七 · 三层", Vector3(676.177, 8.240, -1033.088), -99.0],
	],
	CAPE_VISITORS: [
		["furina", "芙宁娜 · 首层", Vector3(653.485, 1.440, -1099.433), 76.0],
		["sparkle", "花火 · 街角", Vector3(650.00, 1.32, -1080.00), 0.0],
		["yelan", "夜兰 · 首层", Vector3(685.241, 1.440, -1072.258), 16.0],
		["ningguang", "凝光 · 二层", Vector3(682.293, 4.840, -1040.295), 126.0],
		["lynette", "琳妮特 · 二层", Vector3(643.949, 4.840, -1100.643), -129.0],
		["tingyun", "停云 · 首层", Vector3(637.715, 1.440, -1019.381), -99.0],
	],
	"沙洲度假遗址": [
		["keqing", "刻晴", Vector3(-828.462, 0.100, -129.634), -128.0],
		["ganyu", "甘雨", Vector3(-833.190, 0.100, -130.330), 143.0],
		["yelan", "夜兰", Vector3(-891.410, 0.100, -113.120), 143.0],
		["ningguang", "凝光", Vector3(-881.390, 0.000, -91.480), 143.0],
	],
	"下沉档案馆": [
		["black_swan", "黑天鹅", Vector3(-1354.0, 11.5, 23.0), 0.0],
		["ruan_mei", "阮·梅", Vector3(-1348.0, 11.5, 5.0), 90.0],
		["herta", "黑塔", Vector3(-1345.0, 11.5, 0.0), -90.0],
		["faruzan", "珐露珊", Vector3(-1358.0, 11.5, 15.0), 45.0],
		["lisa", "丽莎", Vector3(-1350.0, 11.5, -5.0), 180.0],
		["layla", "莱依拉", Vector3(-1362.000, 11.500, -9.000), 135.0],
	],
	"东侧覆土庭院": [
		["huohuo", "藿藿", Vector3(432.291, 62.020, 271.000), 0.0],
		["tingyun", "停云", Vector3(455.290, 62.025, 269.000), -90.0],
		["yukong", "驭空", Vector3(470.000, 69.640, 268.000), 120.0],
		["yunjin", "云堇", Vector3(450.000, 62.025, 270.000), 180.0],
	],
	"上层环庭": [
		["jingliu", "镜流", Vector3(-917.000, 68.040, 1110.000), -45.0],
		["faruzan", "珐露珊 · 中庭水池旁", Vector3(-954.000, 70.080, 1041.000), 90.0, true],
		["yukong", "驭空 · 后侧弧廊", Vector3(-945.000, 70.080, 999.000), -21.0, true],
	],
	"椭圆中庭": [
		["fu_xuan", "符玄 · 中层上段", Vector3(-415.000, 57.800, 875.500), 119.0],
		["qingque", "青雀", Vector3(-417.000, 63.000, 910.000), 90.0],
		["miyabi", "星见雅", Vector3(-391.960, 35.000, 818.383), -135.0],
		["bronya", "布洛妮娅 · 中层下段", Vector3(-301.000, 45.800, 848.500), -91.0],
		["seele", "希儿", Vector3(-380.000, 35.000, 813.000), -60.0],
	],
	CLIFF_WALKWAY: [
		["nilou", "妮露 · 临水廊柱间", Vector3(-473.000, 0.660, 783.000), 147.0],
		["charlotte", "夏洛蒂 · 观水坐凳旁", Vector3(-423.000, 0.660, 738.000), 151.0],
	],
	"初始神殿与洞穴": [
		["sparkle", "花火", ^"NPC_Idle"],
		["kafka", "卡芙卡", ^"kafka/NPC_Primary"],
		["firefly", "流萤", Vector3(-175.000, 1.600, 894.000), 0.0],
	],
	"草甸与观景点": [
		["amber", "安柏", ^"amber/NPC_Primary"],
		["eula", "优菈", ^"eula/NPC_Primary"],
		["charlotte", "夏洛蒂", ^"charlotte/NPC_Primary"],
		["mona", "莫娜", Vector3(-262.535, 64.940, 631.250), -112.0],
		["sucrose", "砂糖", ^"sucrose/NPC_Primary"],
		["lynette", "琳妮特", Vector3(-258.000, 35.100, 639.000), 105.0],
		["fischl", "菲谢尔", Vector3(395.500, 95.180, 990.000), 90.0],
		["shenhe", "申鹤", Vector3(414.100, 92.320, 917.000), 90.0],
		["hutao", "胡桃", ^"hutao/NPC_Primary"],
		["lumine", "荧", ^"lumine/NPC_Primary"],
	],
	"次要点位": [
		["barbara", "芭芭拉", Vector3(-885.00, 0.10, -115.00), 0.0],
		["keqing", "刻晴", Vector3(455.000, 62.025, 265.000), 0.0],
		["ganyu", "甘雨", Vector3(440.000, 62.020, 260.000), 0.0],
		["yae_miko", "八重神子", Vector3(-1350.00, 11.50, 10.00), 0.0],
		["march7th", "三月七", ^"amber/NPC_Secondary"],
		["firefly", "流萤", ^"eula/NPC_Secondary"],
		["silver_wolf", "银狼", Vector3(-315.00, 72.60, 870.00), 0.0],
	],
}
