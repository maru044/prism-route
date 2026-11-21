extends Node
class_name LocalAirpClient

const ComposerScript := preload("res://scripts/ai/local_airp/local_airp_composer.gd")

@export var data_directory: String = "res://assets/ai/local_airp"
@export var clarify_threshold: float = 0.58
@export var window_size: int = 5

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

static func is_stop_intent(input: String) -> bool:
	var text := input.strip_edges()
	if text.is_empty():
		return false
	if text.contains("不要停") or text.contains("别停") or text.contains("不能停") or text.contains("继续"):
		return false
	var stop_words := [
		"停", "暂停", "先停", "停下", "别动", "先歇", "到这儿", "到这里", "结束",
		"改变主意", "算了吧", "不想做", "不做了", "今天先到", "先等等", "等一下",
		"歇会儿", "缓口气", "先休息", "受不了了先停", "先别", "到此为止", "改天吧"
	]
	for word in stop_words:
		if text.contains(word):
			return true
	return false

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
			"is_fallback": true,
			"error": readiness.get("error", "缺少本地 AIRP 嵌入模型或探针程序")
		}

	var candidates: Array = []
	for tmpl in templates:
		var char_match: bool = (tmpl.get("character_id") == "shared" or tmpl.get("character_id") == character_id)
		var scene_match: bool = (scene_id in tmpl.get("scene_tags", []))
		if tmpl.get("content_tag") in ["pause_stop", "clarify_unknown"]:
			scene_match = true
		if char_match and scene_match:
			candidates.append(tmpl)
			
	if candidates.is_empty():
		candidates = templates
		
	var player_vec := embed_text(player_input)
	if player_vec.is_empty():
		return {
			"text": "【本地探针异常】未能从输入文本中提取语义向量。",
			"reply_id": "error_probe_failed",
			"content_tag": "error",
			"score": 0.0,
			"is_fallback": true,
			"error": "本地 AIRP 探针推理异常"
		}

	var explicit_stop := is_stop_intent(player_input)
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
		if explicit_stop:
			if c_tag == "pause_stop":
				adjusted_score += 0.40
			elif c_tag in ["intimate_tease_reverse", "tease", "intimate_initiative", "intimate_deep", "combat_restraint", "intimate_touch"]:
				adjusted_score -= 0.35
		elif turn_count > 1 and c_tag == "greet":
			adjusted_score -= 0.25

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
	
	if top["raw_score"] < clarify_threshold and not explicit_stop:
		chosen_tmpl = _find_template("clarify_unknown_01")
		chosen_score = top["raw_score"]
		matched_ref = top["matched_ref"]
		is_fallback = true
	else:
		chosen_tmpl = top["template"]
		chosen_score = top["raw_score"]
		matched_ref = top["matched_ref"]
		is_fallback = false
		
	var r_id_chosen: String = chosen_tmpl.get("reply_id", "")
	recent_reply_ids.append(r_id_chosen)
	while recent_reply_ids.size() > window_size:
		recent_reply_ids.pop_front()
		
	var comp_result: Dictionary = composer.compose(chosen_tmpl, character_id, scene_id, context, seed_val)
	
	return {
		"text": comp_result["text"],
		"reply_id": r_id_chosen,
		"content_tag": chosen_tmpl.get("content_tag", ""),
		"score": snapped(chosen_score, 0.0001),
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
