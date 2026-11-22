extends Node
class_name LocalAirpClient

const ComposerScript := preload("res://scripts/ai/local_airp/local_airp_composer.gd")

@export var data_directory: String = "res://assets/ai/local_airp"
@export var clarify_threshold: float = 0.58
@export var window_size: int = 5
@export var force_probe_error: bool = false

var composer: RefCounted
var templates: Array = []
var reference_embeddings: Dictionary = {}
var recent_reply_ids: Array = []

var _probe_pipe: Dictionary = {}
var _probe_stdio: FileAccess
var _probe_pid: int = 0
var _probe_ready: bool = false

func _init() -> void:
	composer = ComposerScript.new()

func _ready() -> void:
	load_resources()

func load_resources() -> void:
	composer.load_data(data_directory)
	templates = _load_json_array(data_directory.path_join("templates.json"))
	var ref_data := _load_json_dict(data_directory.path_join("reference_embeddings.json"))
	
	reference_embeddings.clear()
	for reply_id in ref_data.keys():
		var item: Dictionary = ref_data[reply_id]
		var raw_vectors: Array = item.get("vectors", [])
		var packed_vectors: Array = []
		for raw_v in raw_vectors:
			var pvec := PackedFloat32Array()
			pvec.resize(512)
			for i in range(mini(512, raw_v.size())):
				pvec[i] = float(raw_v[i])
			packed_vectors.append(pvec)
		reference_embeddings[reply_id] = {
			"reference_queries": item.get("reference_queries", []),
			"vectors": packed_vectors
		}

func get_probe_path() -> String:
	var candidates := [
		OS.get_executable_path().get_base_dir().path_join("tools/embedding_probe.exe"),
		OS.get_executable_path().get_base_dir().path_join("embedding_probe.exe"),
		ProjectSettings.globalize_path("res://../tools/local-intent-retrieval/native-probe/embedding_probe.exe"),
		ProjectSettings.globalize_path("res://tools/local-intent-retrieval/native-probe/embedding_probe.exe"),
		ProjectSettings.globalize_path("res://bin/embedding_probe.exe")
	]
	for p in candidates:
		if FileAccess.file_exists(p):
			return p
	return ""

func get_model_path() -> String:
	var candidates := [
		OS.get_executable_path().get_base_dir().path_join("models/bge-small-zh-v1.5-q8_0/bge-small-zh-v1.5-q8_0.gguf"),
		OS.get_executable_path().get_base_dir().path_join("models/bge-small-zh-v1.5-q8_0.gguf"),
		ProjectSettings.globalize_path("res://../tools/local-intent-retrieval/models/bge-small-zh-v1.5-q8_0/bge-small-zh-v1.5-q8_0.gguf"),
		ProjectSettings.globalize_path("res://models/bge-small-zh-v1.5-q8_0/bge-small-zh-v1.5-q8_0.gguf")
	]
	for p in candidates:
		if FileAccess.file_exists(p):
			return p
	return ""

func check_readiness() -> Dictionary:
	var probe_bin := get_probe_path()
	var model_path := get_model_path()
	var has_probe: bool = not probe_bin.is_empty() and FileAccess.file_exists(probe_bin)
	var has_model: bool = not model_path.is_empty() and FileAccess.file_exists(model_path)
	var err := ""
	if not has_probe:
		err = "缺少嵌入探针组件 (embedding_probe.exe)"
	elif not has_model:
		err = "缺少 BGE 模型文件 (bge-small-zh-v1.5-q8_0.gguf)"
	return {
		"ready": has_probe and has_model,
		"has_probe": has_probe,
		"has_model": has_model,
		"probe_path": probe_bin,
		"model_path": model_path,
		"error": err
	}

const TOPIC_DESCRIPTIONS: Dictionary = {
	"greet": "日常问候打招呼",
	"home_meal_share": "一起品尝美食",
	"home_island_01": "浮空岛与风景",
	"chat_island": "浮空岛与风景",
	"home_rest_nap": "休息小憩",
	"home_patrol_work": "巡逻与工作",
	"home_night_whisper": "夜晚与星空谈心",
	"home_compliment": "夸奖赞美",
	"compliment": "夸奖赞美",
	"tease": "恶作剧与捉弄",
	"sparkle_prank": "恶作剧与捉弄",
	"keqing_duty": "工作与摸鱼闲聊",
	"invite_intimacy": "邀请亲密互动",
	"intimate_touch": "亲密抚摸与接触",
	"intimate_rhythm_faster": "加快节奏",
	"intimate_rhythm_slower": "放慢节奏",
	"intimate_deep": "深处结合",
	"intimate_peak": "绝顶高潮",
	"intimate_deep_kiss": "深吻接吻",
	"intimate_initiative": "主动侍奉",
	"intimate_tease_reverse": "反向调戏",
	"intimate_submission": "顺从服从",
	"intimate_aftercare_sweet": "事后温存照料",
	"combat_pleasure_25": "对战快感初阶",
	"combat_pleasure_50": "对战快感中阶",
	"combat_pleasure_75": "对战快感高阶",
	"combat_pleasure_100": "对战绝顶溃败",
	"combat_restraint": "对战拘束玩弄",
	"combat_surrender": "对战彻底臣服",
	"post_intimate": "事后谈心温存",
	"resume_intimacy": "继续亲密侍奉"
}

static func is_strict_stop(input: String) -> bool:
	var clean := input.strip_edges()
	if clean.is_empty():
		return false

	# 1. 优先检查矛盾输入：同时表达「先停/先等」与「再继续/接着做」
	# 规则：若一句话同时表达「先等一下」和「再继续」，先暂停本轮，等新的明确指令再恢复
	var has_pause_marker := false
	var pause_conflict_markers := ["等一下", "先等", "稍等", "先停", "暂停", "先歇", "先休息", "缓一下", "缓口气"]
	for pm in pause_conflict_markers:
		if clean.contains(pm):
			has_pause_marker = true
			break
			
	var has_continue_marker := (clean.contains("再继续") or clean.contains("后继续") or clean.contains("接着") or clean.contains("继续"))
	if has_pause_marker and has_continue_marker:
		return true

	# 2. 正向继续或否定叫停请求（如 "不要停", "别停", "不能停", "继续吧", "请继续"）
	var continue_phrases := ["不要停", "别停", "不能停", "继续", "接着来", "请继续"]
	for cp in continue_phrases:
		if clean.contains(cp):
			# 若同时含有“不要继续 / 别继续”，则仍为叫停
			if not (clean.contains("不要继续") or clean.contains("别继续") or clean.contains("不能继续") or clean.contains("停止继续")):
				return false

	# 3. 明确叫停复合短语
	var explicit_stop_phrases := [
		"不要继续", "别继续", "不能继续", "停止继续", "不要再继续",
		"到此为止", "到这就好", "到这儿就好", "到这里就好", "今天先到这里", "今天到这", "先到这里吧",
		"我改变主意了", "改变主意", "不想做了", "不做了", "别做了", "不要做了",
		"停一下", "先停", "停下", "停手", "停住", "暂停",
		"别动", "先别", "先等等", "等一下", "先歇", "歇会儿", "缓口气", "先休息", "受不了了先停",
		"算了吧", "改天吧", "放过我吧", "饶了我吧"
	]
	for phrase in explicit_stop_phrases:
		if clean.contains(phrase):
			return true

	# 严格移除单凭出现单个「停」字就判定暂停的规则（避免误判「停电了吗？」）
	return false

static func is_stop_intent(input: String) -> bool:
	return is_strict_stop(input)

static func is_anaphoric_short_query(input_text: String) -> bool:
	var clean := input_text.strip_edges()
	if clean.length() > 14:
		return false
	var anaphoric_markers := [
		"那个呢", "刚才那个", "照刚才那个", "照刚才", "换一种", "换一个", "再来一次",
		"继续刚才", "接着刚才", "还要", "再来", "还想", "换别的", "那个呢？", "这个呢"
	]
	for m in anaphoric_markers:
		if clean.contains(m):
			return true
	return false

static func build_augmented_query(input_text: String, last_topic_tag: String) -> String:
	var clean := input_text.strip_edges()
	if not is_anaphoric_short_query(clean) or last_topic_tag.is_empty():
		return clean
	var topic_desc: String = str(TOPIC_DESCRIPTIONS.get(last_topic_tag, last_topic_tag))
	return "[%s] %s" % [topic_desc, clean]

func ensure_probe() -> bool:
	if _probe_ready and _probe_stdio != null:
		return true
		
	var probe_bin := get_probe_path()
	var model_path := get_model_path()
	
	if probe_bin.is_empty() or not FileAccess.file_exists(probe_bin):
		push_warning("LocalAirpClient: embedding_probe.exe not found!")
		return false
	if model_path.is_empty() or not FileAccess.file_exists(model_path):
		push_warning("LocalAirpClient: bge model GGUF not found!")
		return false
		
	_probe_pipe = OS.execute_with_pipe(probe_bin, [model_path, "2"])
	if not _probe_pipe.has("stdio"):
		push_warning("LocalAirpClient: Failed to start probe pipe!")
		return false
		
	_probe_stdio = _probe_pipe["stdio"]
	_probe_pid = _probe_pipe.get("pid", 0)
	
	var ready_line := _probe_stdio.get_line().strip_edges()
	if ready_line != "READY":
		push_warning("LocalAirpClient: Probe ready failed: " + ready_line)
		close_probe()
		return false
		
	_probe_ready = true
	return true

func embed_text(text: String) -> PackedFloat32Array:
	if force_probe_error:
		return PackedFloat32Array()
	if not ensure_probe():
		return PackedFloat32Array()
		
	var clean := text.replace("\n", " ").replace("\r", " ").strip_edges()
	if clean.is_empty():
		clean = "空"
		
	_probe_stdio.store_string("embed\t" + clean + "\n")
	_probe_stdio.flush()
	
	var line := _probe_stdio.get_line()
	var parts := line.split(" ", false)
	if parts.is_empty() or parts[0] != "VECTOR":
		push_warning("LocalAirpClient: Unexpected probe output: " + line.substr(0, 50))
		return PackedFloat32Array()
		
	var vec := PackedFloat32Array()
	vec.resize(512)
	var norm_sq: float = 0.0
	for i in range(512):
		if i + 1 < parts.size():
			var val := float(parts[i + 1])
			vec[i] = val
			norm_sq += val * val
		else:
			vec[i] = 0.0
			
	var norm := sqrt(norm_sq)
	if norm > 0.0:
		for i in range(512):
			vec[i] /= norm
			
	return vec

func retrieve_and_compose(player_input: String, character_id: String, scene_id: String, context: Dictionary = {}, seed_val: int = -1) -> Dictionary:
	if templates.is_empty():
		load_resources()
		
	var readiness := check_readiness()
	if not readiness.get("ready", false):
		return {
			"text": "【本地组件缺失】未找到 BGE 嵌入模型或探针程序，无法执行本地语义检索。",
			"reply_id": "error_missing_model",
			"content_tag": "error",
			"score": 0.0,
			"raw_score": 0.0,
			"adjusted_score": 0.0,
			"path_reason": "组件缺失异常",
			"is_augmented": false,
			"is_fallback": true,
			"error": readiness.get("error", "缺少本地 AIRP 嵌入模型或探针程序")
		}

	# 1. 明确叫停最高优先级安全门禁 (Strict Stop Fast-Path: 零 BGE 向量耗时)
	if is_strict_stop(player_input):
		var stop_tmpl: Dictionary = _find_template("pause_request_01")
		if stop_tmpl.is_empty():
			for tmpl in templates:
				if tmpl.get("content_tag") == "pause_stop":
					stop_tmpl = tmpl
					break
		if not stop_tmpl.is_empty():
			var comp_stop: Dictionary = composer.compose(stop_tmpl, character_id, scene_id, context, seed_val)
			return {
				"text": comp_stop["text"],
				"reply_id": stop_tmpl.get("reply_id", "pause_request_01"),
				"content_tag": "pause_stop",
				"score": 1.0,
				"raw_score": 1.0,
				"adjusted_score": 1.0,
				"path_reason": "显式叫停直接截断",
				"is_augmented": false,
				"matched_reference_query": "停止指令直接截断",
				"character_id": character_id,
				"scene_id": scene_id,
				"template_skeleton": comp_stop["template_skeleton"],
				"slots_filled": comp_stop["slots_filled"],
				"is_fallback": false
			}

	var candidates: Array = []
	for tmpl in templates:
		var c_tag: String = tmpl.get("content_tag", "")
		if c_tag == "pause_stop" or c_tag == "clarify_unknown":
			continue
		var char_match: bool = (tmpl.get("character_id") == "shared" or tmpl.get("character_id") == character_id)
		var scene_match: bool = (scene_id in tmpl.get("scene_tags", []))
		if char_match and scene_match:
			candidates.append(tmpl)
			
	if candidates.is_empty():
		candidates = templates

	var last_topic_tag: String = str(context.get("last_topic", ""))
	var is_anaphoric := is_anaphoric_short_query(player_input)
	
	# 如果是无指代短句且没有任何可用前文，触发角色口吻追问澄清
	if is_anaphoric and last_topic_tag.is_empty():
		var clarify_tmpl: Dictionary = _find_template("clarify_unknown_01")
		var comp_clarify: Dictionary = composer.compose(clarify_tmpl, character_id, scene_id, context, seed_val)
		return {
			"text": comp_clarify["text"],
			"reply_id": "clarify_unknown_01",
			"content_tag": "clarify_unknown",
			"score": 0.0,
			"raw_score": 0.0,
			"adjusted_score": 0.0,
			"path_reason": "缺少上下文指代澄清",
			"is_augmented": false,
			"matched_reference_query": "缺少上下文指代澄清",
			"character_id": character_id,
			"scene_id": scene_id,
			"template_skeleton": comp_clarify["template_skeleton"],
			"slots_filled": comp_clarify["slots_filled"],
			"is_fallback": true
		}

	var query_to_embed := build_augmented_query(player_input, last_topic_tag)
	var is_augmented := (query_to_embed != player_input.strip_edges())
		
	var player_vec := embed_text(query_to_embed)
	if player_vec.is_empty():
		return {
			"text": "【本地探针异常】未能从输入文本中提取语义向量。",
			"reply_id": "error_probe_failed",
			"content_tag": "error",
			"score": 0.0,
			"raw_score": 0.0,
			"adjusted_score": 0.0,
			"path_reason": "探针推理异常",
			"is_augmented": is_augmented,
			"is_fallback": true,
			"error": "本地 AIRP 探针推理异常"
		}

	var turn_count: int = int(context.get("turn_count", 1))

	var scored_candidates: Array = []
	for tmpl in candidates:
		var r_id: String = tmpl.get("reply_id", "")
		var ref_entry: Dictionary = reference_embeddings.get(r_id, {})
		var ref_vectors: Array = ref_entry.get("vectors", [])
		var ref_queries: Array = ref_entry.get("reference_queries", [])
		
		var best_sim: float = -1.0
		var best_q: String = ""
		
		for ref_idx in range(ref_vectors.size()):
			var v: PackedFloat32Array = ref_vectors[ref_idx]
			var dot: float = 0.0
			for k in range(512):
				dot += player_vec[k] * v[k]
			if dot > best_sim:
				best_sim = dot
				best_q = ref_queries[ref_idx] if ref_idx < ref_queries.size() else ""
				
		var adjusted_score := best_sim
		if r_id in recent_reply_ids:
			adjusted_score -= 0.15
			
		var c_tag: String = tmpl.get("content_tag", "")
		if is_augmented and (c_tag == last_topic_tag or r_id == str(context.get("last_reply_id", ""))):
			adjusted_score += 0.30
		elif turn_count > 1 and c_tag == "greet":
			adjusted_score -= 0.25

		if tmpl.get("character_id") == character_id:
			adjusted_score += 0.05

		scored_candidates.append({
			"template": tmpl,
			"raw_score": best_sim,
			"adjusted_score": adjusted_score,
			"matched_ref": best_q
		})
		
	scored_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["adjusted_score"] > b["adjusted_score"]
	)
	
	var top: Dictionary = scored_candidates[0]
	var chosen_tmpl: Dictionary
	var chosen_score: float
	var matched_ref: String
	var is_fallback: bool = false
	var path_reason: String = "普通语义检索"
	
	if top["raw_score"] < clarify_threshold:
		chosen_tmpl = _find_template("clarify_unknown_01")
		chosen_score = top["raw_score"]
		matched_ref = top["matched_ref"]
		is_fallback = true
		path_reason = "低置信度澄清"
	else:
		chosen_tmpl = top["template"]
		chosen_score = top["raw_score"]
		matched_ref = top["matched_ref"]
		is_fallback = false
		path_reason = "多轮短句承接" if is_augmented else "普通语义检索"
		
	var r_id_chosen: String = chosen_tmpl.get("reply_id", "")
	recent_reply_ids.append(r_id_chosen)
	while recent_reply_ids.size() > window_size:
		recent_reply_ids.pop_front()
		
	var comp_result: Dictionary = composer.compose(chosen_tmpl, character_id, scene_id, context, seed_val)
	
	return {
		"text": comp_result["text"],
		"reply_id": r_id_chosen,
		"content_tag": chosen_tmpl.get("content_tag", ""),
		"score": snapped(top["adjusted_score"] if not is_fallback else chosen_score, 0.0001),
		"raw_score": snapped(chosen_score, 0.0001),
		"adjusted_score": snapped(top["adjusted_score"], 0.0001),
		"path_reason": path_reason,
		"is_augmented": is_augmented,
		"augmented_query": query_to_embed if is_augmented else "",
		"matched_reference_query": matched_ref,
		"character_id": character_id,
		"scene_id": scene_id,
		"template_skeleton": comp_result["template_skeleton"],
		"slots_filled": comp_result["slots_filled"],
		"is_fallback": is_fallback
	}

func _find_template(target_reply_id: String) -> Dictionary:
	for t in templates:
		if t.get("reply_id") == target_reply_id:
			return t
	return templates[0] if not templates.is_empty() else {}

func compose_followup(character_id: String, scene_id: String, context: Dictionary = {}, seed_val: int = -1) -> String:
	if templates.is_empty():
		load_resources()
	return composer.compose_followup(character_id, scene_id, context, seed_val)

func reset_history() -> void:
	recent_reply_ids.clear()
	composer.reset_history()

func close_probe() -> void:
	if _probe_pid > 0:
		OS.kill(_probe_pid)
		_probe_pid = 0
	_probe_stdio = null
	_probe_ready = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		close_probe()

func _load_json_array(file_path: String) -> Array:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_warning("Failed to open file: " + file_path)
		return []
	var text := file.get_as_text()
	var json_res: Variant = JSON.parse_string(text)
	if json_res is Array:
		return json_res
	return []

func _load_json_dict(file_path: String) -> Dictionary:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_warning("Failed to open file: " + file_path)
		return {}
	var text := file.get_as_text()
	var json_res: Variant = JSON.parse_string(text)
	if json_res is Dictionary:
		return json_res
	return {}
