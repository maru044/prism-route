class_name CharacterRosterDatabase
extends RefCounted
## Centralized database for character roster metadata, standing portraits, and personas.

const PORTRAIT_DIR := "res://assets/characters/portraits"
const PERSONAS_DIR := "res://assets/ai/personas"

const ROSTER_ENTRIES: Array[Dictionary] = [
	{"id": "miku", "name": "初音未来", "title": "电子歌姬 · 系统向导", "game": "Vocaloid / 系统向导", "file": "01_miku.png"},
	{"id": "sparkle", "name": "花火", "title": "假面愚者", "game": "崩坏：星穹铁道", "file": "02_sparkle.png"},
	{"id": "stelle", "name": "星", "title": "星穹开拓者", "game": "崩坏：星穹铁道", "file": "03_stelle.png"},
	{"id": "march7th", "name": "三月七", "title": "星穹列车乘员", "game": "崩坏：星穹铁道", "file": "04_march7th.png"},
	{"id": "firefly", "name": "流萤", "title": "格拉默铁骑", "game": "崩坏：星穹铁道", "file": "05_firefly.png"},
	{"id": "silver_wolf", "name": "银狼", "title": "星核猎手 · 骇客", "game": "崩坏：星穹铁道", "file": "06_silver_wolf.png"},
	{"id": "black_swan", "name": "黑天鹅", "title": "忆者", "game": "崩坏：星穹铁道", "file": "07_black_swan.png"},
	{"id": "furina", "name": "芙宁娜", "title": "不休独舞", "game": "原神", "file": "08_furina.png"},
	{"id": "raiden_shogun", "name": "雷电将军", "title": "一心净土", "game": "原神", "file": "09_raiden_shogun.png"},
	{"id": "yae_miko", "name": "八重神子", "title": "鸣神大社宫司", "game": "原神", "file": "10_yae_miko.png"},
	{"id": "ruan_mei", "name": "阮·梅", "title": "天才俱乐部 #81", "game": "崩坏：星穹铁道", "file": "11_ruan_mei.png"},
	{"id": "herta", "name": "黑塔", "title": "天才俱乐部 #83", "game": "崩坏：星穹铁道", "file": "12_herta.png"},
	{"id": "tingyun", "name": "停云", "title": "罗浮接渡使", "game": "崩坏：星穹铁道", "file": "13_tingyun.png"},
	{"id": "fu_xuan", "name": "符玄", "title": "太卜司太卜", "game": "崩坏：星穹铁道", "file": "14_fu_xuan.png"},
	{"id": "qingque", "name": "青雀", "title": "太卜司卜者", "game": "崩坏：星穹铁道", "file": "15_qingque.png"},
	{"id": "jingliu", "name": "镜流", "title": "罗浮无瑕剑首", "game": "崩坏：星穹铁道", "file": "16_jingliu.png"},
	{"id": "kafka", "name": "卡芙卡", "title": "星核猎手", "game": "崩坏：星穹铁道", "file": "17_kafka.png"},
	{"id": "huohuo", "name": "藿藿", "title": "十王司判官见习", "game": "崩坏：星穹铁道", "file": "18_huohuo.png"},
	{"id": "yukong", "name": "驭空", "title": "天舶司司舵", "game": "崩坏：星穹铁道", "file": "19_yukong.png"},
	{"id": "bronya", "name": "布洛妮娅", "title": "大守护者", "game": "崩坏：星穹铁道", "file": "20_bronya.png"},
	{"id": "seele", "name": "希儿", "title": "地火之蝶", "game": "崩坏：星穹铁道", "file": "21_seele.png"},
	{"id": "miyabi", "name": "星见雅", "title": "对空六课课长", "game": "绝区零", "file": "22_miyabi.png"},
	{"id": "keqing", "name": "刻晴", "title": "璃月七星 · 玉衡星", "game": "原神", "file": "23_keqing.png"},
	{"id": "ganyu", "name": "甘雨", "title": "循循守月 · 月海亭", "game": "原神", "file": "24_ganyu.png"},
	{"id": "ningguang", "name": "凝光", "title": "璃月七星 · 天权星", "game": "原神", "file": "25_ningguang.png"},
	{"id": "yelan", "name": "夜兰", "title": "幽客意寻", "game": "原神", "file": "26_yelan.png"},
	{"id": "shenhe", "name": "申鹤", "title": "孤辰茕怀", "game": "原神", "file": "27_shenhe.png"},
	{"id": "hutao", "name": "胡桃", "title": "往生堂第七十七代堂主", "game": "原神", "file": "28_hutao.png"},
	{"id": "yunjin", "name": "云堇", "title": "云翰社名角", "game": "原神", "file": "29_yunjin.png"},
	{"id": "jean", "name": "琴", "title": "蒲公英骑士 · 代理团长", "game": "原神", "file": "30_jean.png"},
	{"id": "barbara", "name": "芭芭拉", "title": "闪耀偶像", "game": "原神", "file": "31_barbara.png"},
	{"id": "lisa", "name": "丽莎", "title": "蔷薇魔女", "game": "原神", "file": "32_lisa.png"},
	{"id": "amber", "name": "安柏", "title": "侦察骑士", "game": "原神", "file": "33_amber.png"},
	{"id": "noelle", "name": "诺艾尔", "title": "未授勋之花", "game": "原神", "file": "34_noelle.png"},
	{"id": "eula", "name": "优菈", "title": "浪花骑士", "game": "原神", "file": "35_eula.png"},
	{"id": "mona", "name": "莫娜", "title": "星天水镜", "game": "原神", "file": "36_mona.png"},
	{"id": "ayaka", "name": "神里绫华", "title": "白鹭霜华", "game": "原神", "file": "37_ayaka.png"},
	{"id": "yoimiya", "name": "宵宫", "title": "琉焰华舞", "game": "原神", "file": "38_yoimiya.png"},
	{"id": "kokomi", "name": "珊瑚宫心海", "title": "珍珠之智", "game": "原神", "file": "39_kokomi.png"},
	{"id": "kuki_shinobu", "name": "久岐忍", "title": "百炼通才", "game": "原神", "file": "40_kuki_shinobu.png"},
	{"id": "kirara", "name": "绮良良", "title": "檐宇猫游", "game": "原神", "file": "41_kirara.png"},
	{"id": "nilou", "name": "妮露", "title": "莲光落舞", "game": "原神", "file": "42_nilou.png"},
	{"id": "faruzan", "name": "珐露珊", "title": "机逐封秘", "game": "原神", "file": "43_faruzan.png"},
	{"id": "layla", "name": "莱依拉", "title": "绮思晚星", "game": "原神", "file": "44_layla.png"},
	{"id": "lynette", "name": "琳妮特", "title": "丽影绮行", "game": "原神", "file": "45_lynette.png"},
	{"id": "charlotte", "name": "夏洛蒂", "title": "真实视相", "game": "原神", "file": "46_charlotte.png"},
	{"id": "fischl", "name": "菲谢尔", "title": "断罪皇女", "game": "原神", "file": "47_fischl.png"},
	{"id": "sucrose", "name": "砂糖", "title": "无害甜度", "game": "原神", "file": "48_sucrose.png"},
	{"id": "rosaria", "name": "罗莎莉亚", "title": "棘冠修女", "game": "原神", "file": "49_rosaria.png"},
	{"id": "lumine", "name": "荧", "title": "异乡旅行者", "game": "原神", "file": "50_lumine.png"}
]

static var _entries_by_id: Dictionary = {}
static var _entries_by_name: Dictionary = {}

static func _ensure_cache() -> void:
	if _entries_by_id.is_empty():
		for entry: Dictionary in ROSTER_ENTRIES:
			_entries_by_id[entry.id] = entry
			_entries_by_name[entry.name] = entry

static func get_all_entries() -> Array[Dictionary]:
	return ROSTER_ENTRIES

static func get_entry(char_id: String) -> Dictionary:
	_ensure_cache()
	return _entries_by_id.get(char_id, {})

static func get_entry_by_name(char_name: String) -> Dictionary:
	_ensure_cache()
	if _entries_by_name.has(char_name):
		return _entries_by_name[char_name]
	if _entries_by_id.has(char_name):
		return _entries_by_id[char_name]
	return {}

static func get_portrait_path(char_id: String) -> String:
	var entry := get_entry(char_id)
	if not entry.is_empty():
		var file_name: String = entry.get("file", "")
		var path := PORTRAIT_DIR.path_join(file_name)
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			return path
	var direct_path := PORTRAIT_DIR.path_join(char_id + ".png")
	if ResourceLoader.exists(direct_path) or FileAccess.file_exists(direct_path):
		return direct_path
	return ""

static func load_portrait(char_id: String) -> Texture2D:
	var path := get_portrait_path(char_id)
	if path.is_empty():
		return null
	return load(path) as Texture2D

static func load_persona_data(char_id: String) -> Dictionary:
	var entry := get_entry(char_id)
	var display_name: String = entry.get("name", char_id)
	var title: String = entry.get("title", "大世界伙伴")
	var game: String = entry.get("game", "原神")

	var persona_path := PERSONAS_DIR.path_join(char_id + ".md")
	if FileAccess.file_exists(persona_path):
		var raw := FileAccess.get_file_as_string(persona_path).trim_prefix("\ufeff").replace("\r\n", "\n")
		var separator := raw.find("\n---")
		var content := ""
		if separator >= 0:
			content = raw.substr(separator + 4).strip_edges()
		else:
			content = raw.strip_edges()

		return {
			"id": char_id,
			"name": display_name,
			"title": title,
			"game": game,
			"content": content,
			"has_custom_persona": true
		}

	# Fallback structured persona for characters without dedicated markdown files
	var fallback_content := """[NPC Profile: %s / %s]
所属作品：%s
身份称号：%s
当前对话对象：%s
称呼玩家：Master、旅行者

◆ 性格特征：
- 鲜明个性：深受喜爱的二次元标志性女主角，言谈举止间充满独特的个人魅力！
- 亲密羁绊：在大世界的漫长旅程中与Master共同经历了诸多探险与考验，对Master怀抱真挚的信赖与好感！
- 灵动表现：身姿优雅动人，神态生动细腻，随时准备响应Master的号召并肩同行！

◆ 对话风格：
- 符合角色在作品中的原版神韵，语调亲切动听！
- 情绪传递自然真挚，言语之间充满对未来的憧憬与对同伴的珍视！

◆ 台词范例：
- “能在这里与你相遇，一定是命运最美好的安排！”
- “无论前方有什么样的冒险，我都会坚定地守护在你身边！”""" % [display_name, char_id, game, title, display_name]

	return {
		"id": char_id,
		"name": display_name,
		"title": title,
		"game": game,
		"content": fallback_content,
		"has_custom_persona": false
	}
