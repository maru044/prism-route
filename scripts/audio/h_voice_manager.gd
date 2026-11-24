class_name HVoiceManager
extends Node
## Audio manager for progressive erotic voice clips (家园亲密侍奉、战斗Battle Fuck、随手摸胸微交互).
## Manages voice pools, progressive intensity ramp-up, natural breathing intervals, and playback routing.

signal voice_played(pool_id: String, clip_name: String)
signal intimacy_intensity_increased(stage: int)

static var instance: HVoiceManager

# Voice Pool Definitions (精选 6 句全场景通用纯拟声，温和克制自然)
const POOLS: Dictionary = {
	# 口交侍奉 (轻舐水声与敏感轻哼自然配合)
	"voice_pool_oral": [
		"hime2561.ogg", # 06: 前端含吮轻舐水声
		"hime0072.ogg", # 01: 敏感轻哼
		"hime0634.ogg"  # 02: 浅层受纳
	],
	# 揉胸与手足前戏
	"voice_pool_paizuri_chest": [
		"hime0072.ogg", # 01: 前戏抚触敏感轻哼
		"hime0779.ogg", # 03: 敏感抚弄动情娇喘
		"hime0482.ogg"  # 04: 深入承欢隐忍闷哼
	],
	"voice_pool_service_manual": [
		"hime0072.ogg", # 01: 前戏抚触敏感轻哼
		"hime0779.ogg", # 03: 敏感抚弄动情娇喘
		"hime0482.ogg"  # 04: 深入承欢隐忍闷哼
	],
	# 本番深入体位 (骑乘/正常位/后背等，通用阶梯推进)
	"voice_pool_honban_cowgirl": [
		"hime0634.ogg", # 02: 初次结合浅层受纳
		"hime0779.ogg", # 03: 敏感抚弄动情娇喘
		"hime0482.ogg", # 04: 深入承欢隐忍闷哼
		"hime0706.ogg"  # 05: 节律抽送颠簸喘息
	],
	"voice_pool_honban_missionary": [
		"hime0634.ogg", # 02: 初次结合浅层受纳
		"hime0779.ogg", # 03: 敏感抚弄动情娇喘
		"hime0482.ogg", # 04: 深入承欢隐忍闷哼
		"hime0706.ogg"  # 05: 节律抽送颠簸喘息
	],
	"voice_pool_honban_doggy": [
		"hime0634.ogg", # 02: 初次结合浅层受纳
		"hime0779.ogg", # 03: 敏感抚弄动情娇喘
		"hime0482.ogg", # 04: 深入承欢隐忍闷哼
		"hime0706.ogg"  # 05: 节律抽送颠簸喘息
	],
	"voice_pool_orgasm": [
		"hime0706.ogg"  # 05: 节律深喘沉沦
	],
	"voice_pool_aftercare": [
		"hime0072.ogg"  # 01: 平复轻哼温存
	],

	# 战斗色色对决 Battle Fuck (温和生理娇喘，零台词出戏)
	"voice_battle_taunt": [
		"hime0072.ogg"  # 01: 敏感情哼
	],
	"voice_battle_pleasure_low": [
		"hime0634.ogg"  # 02: 浅层受纳轻吟
	],
	"voice_battle_pleasure_mid": [
		"hime0779.ogg"  # 03: 动情娇喘
	],
	"voice_battle_pleasure_high": [
		"hime0482.ogg"  # 04: 深入承欢隐忍深顶
	],
	"voice_battle_defeat": [
		"hime0706.ogg"  # 05: 节律颠簸沦陷
	],

	# 微交互反馈
	"voice_touch_chest": [
		"hime0072.ogg", # 01: 单发抚按敏感轻哼
		"hime0779.ogg"  # 03: 连续揉按动情娇喘
	]
}

var player: AudioStreamPlayer
var _feedback_player: AudioStreamPlayer
var _stream_cache: Dictionary = {}
var rng := RandomNumberGenerator.new()

const OPENING_DELAY := 3.5
const MIN_PAUSE := 3.0
const MAX_PAUSE := 5.0
const FADE_DURATION := 0.30

enum SceneVoice { NONE, BATTLE, INTIMACY }
var _scene_voice := SceneVoice.NONE
var _scene_owner_id := 0
var _motion_ready: Callable
var _pending_opening := false
var _next_clip_delay := 0.0
var _intimacy_pool := ""
var _motion_stage := 0
var _fade: Tween

# Tactile interaction state
var _last_chest_touch_time: float = -100.0

func _init() -> void:
	if instance == null:
		instance = self
	rng.randomize()

func _enter_tree() -> void:
	if instance == null:
		instance = self
	_setup_player()

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _setup_player() -> void:
	if is_instance_valid(player):
		return
	player = AudioStreamPlayer.new()
	player.name = "HVoicePlayer"
	_feedback_player = AudioStreamPlayer.new()
	_feedback_player.name = "FeedbackVoicePlayer"
	_setup_bus()
	add_child(player)
	add_child(_feedback_player)
	player.finished.connect(_on_scene_clip_finished)

func _setup_bus() -> void:
	var world_bus := &"PR_World"
	if AudioServer.get_bus_index(world_bus) < 0:
		AudioServer.add_bus()
		var world_idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(world_idx, world_bus)
		AudioServer.set_bus_send(world_idx, &"Master")
	var bus_name := &"PR_Voice"
	if AudioServer.get_bus_index(bus_name) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	AudioServer.set_bus_send(AudioServer.get_bus_index(bus_name), world_bus)
	player.bus = bus_name
	_feedback_player.bus = bus_name

func _process(delta: float) -> void:
	if _scene_voice == SceneVoice.NONE:
		return
	if not is_instance_id_valid(_scene_owner_id):
		_end_scene()
		return
	if _motion_ready.is_valid():
		if _motion_ready.call():
			_motion_ready = Callable()
		return
	if not _pending_opening and player.playing:
		return
	_next_clip_delay = maxf(0.0, _next_clip_delay - delta)
	if _next_clip_delay > 0.0 or _fade != null:
		return

	if _pending_opening:
		_pending_opening = false
		if _scene_voice == SceneVoice.BATTLE:
			_play_clip("hime0072.ogg", "voice_battle_taunt", player)
		else:
			_play_clip(str(POOLS[_intimacy_pool][0]), _intimacy_pool, player)
	elif _scene_voice == SceneVoice.INTIMACY:
		_advance_intimacy_cycle()

func _advance_intimacy_cycle() -> void:
	var pool: Array = POOLS.get(_intimacy_pool, [])
	if pool.is_empty():
		return
	_motion_stage += 1
	intimacy_intensity_increased.emit(_motion_stage)
	# 确定性顺序推进，到达最深层后维持高强度纯拟声
	var idx: int = mini(_motion_stage, pool.size() - 1)
	_play_clip(str(pool[idx]), _intimacy_pool, player)

static func paired_motion_started(first: Node3D, second: Node3D) -> bool:
	return _motion_started(first) and _motion_started(second)

static func _motion_started(actor: Node3D) -> bool:
	return is_instance_valid(actor) and actor.is_visible_in_tree() and actor.ready_for_review \
		and actor.is_active_playback and actor.auto_play and actor.time > 0.0

func start_intimacy(owner: Node, motion: Dictionary, motion_ready: Callable = Callable()) -> void:
	_begin_scene(owner, SceneVoice.INTIMACY, motion_ready)
	_intimacy_pool = resolve_intimacy_pool(motion)

func start_battle(owner: Node, motion_ready: Callable = Callable()) -> void:
	_begin_scene(owner, SceneVoice.BATTLE, motion_ready)

func _begin_scene(owner: Node, kind: SceneVoice, motion_ready: Callable) -> void:
	_end_scene()
	_scene_voice = kind
	_scene_owner_id = owner.get_instance_id()
	_motion_ready = motion_ready
	_pending_opening = true
	_next_clip_delay = OPENING_DELAY
	_feedback_player.stop()

func stop_scene(owner: Node) -> void:
	if owner.get_instance_id() == _scene_owner_id:
		_end_scene()

func _end_scene() -> void:
	_scene_voice = SceneVoice.NONE
	_scene_owner_id = 0
	_motion_ready = Callable()
	_pending_opening = false
	_next_clip_delay = 0.0
	_intimacy_pool = ""
	_motion_stage = 0
	if not player.playing or _fade != null:
		return
	_fade = create_tween().set_ignore_time_scale(true)
	_fade.tween_property(player, "volume_db", -60.0, FADE_DURATION)
	_fade.tween_callback(_finish_scene_fade)

func _finish_scene_fade() -> void:
	player.stop()
	player.volume_db = 0.0
	_fade = null

func _on_scene_clip_finished() -> void:
	if _scene_voice != SceneVoice.NONE and _fade == null:
		_next_clip_delay = rng.randf_range(MIN_PAUSE, MAX_PAUSE)

## 战斗快感阶梯受击（传入快感比率 0.0~1.0 或 0~100）
func play_battle_reaction(owner: Node, pleasure_ratio: float) -> void:
	if _scene_voice != SceneVoice.BATTLE or owner.get_instance_id() != _scene_owner_id \
			or _pending_opening or _next_clip_delay > 0.0 or player.playing or _fade != null:
		return
	var pct := pleasure_ratio if pleasure_ratio > 1.0 else (pleasure_ratio * 100.0)
	if pct < 35.0:
		_play_clip("hime0634.ogg", "voice_battle_pleasure_low", player)
	elif pct < 70.0:
		_play_clip("hime0779.ogg", "voice_battle_pleasure_mid", player)
	elif pct < 90.0:
		_play_clip("hime0482.ogg", "voice_battle_pleasure_high", player)
	else:
		_play_clip("hime0706.ogg", "voice_battle_defeat", player)

## 随手摸胸即时短反馈（单发轻触 vs 快速连续拖拽）
func play_chest_fondle(continuous: bool = false) -> void:
	if _scene_voice != SceneVoice.NONE or _fade != null:
		return
	var now := float(Time.get_ticks_msec()) / 1000.0
	var is_rapid := (now - _last_chest_touch_time) < 1.6
	_last_chest_touch_time = now

	var pool: Array = POOLS.get("voice_touch_chest", [])
	if pool.is_empty():
		return

	if (continuous or is_rapid) and pool.size() > 1:
		_play_clip(str(pool[1]), "voice_touch_chest", _feedback_player)
	else:
		_play_clip(str(pool[0]), "voice_touch_chest", _feedback_player)

## 自由对话时机已移除音频播放，保持空函数避免破坏外部调用
func play_chat_greet(_character_id: String = "") -> void:
	pass

## 动作目录自动匹配到 8 大受纳体位池
func resolve_intimacy_pool(motion: Dictionary) -> String:
	var m_id: String = str(motion.get("id", "")).to_lower()
	var m_name: String = str(motion.get("name", ""))
	var m_desc: String = str(motion.get("desc", ""))
	var tier: String = str(motion.get("tier", "service"))

	# 如果是日常轻度侍奉（tier == "service"）
	if tier == "service":
		# 1. 口交奉仕
		if "fera" in m_id or "口交" in m_name or "含吮" in m_name or "口交" in m_desc:
			return "voice_pool_oral"
		# 2. 胸部玩弄与乳交
		if "paizuri" in m_id or "胸" in m_name or "乳交" in m_name or "胸" in m_desc:
			return "voice_pool_paizuri_chest"
		# 3. 其余手交、足交、素股、爱抚皆归入手足侍奉温存池
		return "voice_pool_service_manual"

	# 如果是本番深入（tier == "honban"）
	# 1. 骑乘位与主动坐姿
	if "骑乘" in m_name or "跨坐" in m_name or "坐位" in m_name or "坐姿" in m_name or "骑乘" in m_desc:
		return "voice_pool_honban_cowgirl"

	# 2. 后背位犬交冲撞
	if "后背" in m_name or "背面" in m_name or "犬交" in m_name or "推车" in m_name or "后进" in m_name or "背后" in m_desc:
		return "voice_pool_honban_doggy"

	# 3. 仰卧正常位被动承欢（包含正常位、仰卧、折腿、抬腿、面对面等）
	return "voice_pool_honban_missionary"

func _play_random_from_pool(pool_id: String) -> void:
	var pool: Array = POOLS[pool_id]
	var clip_name: String = str(pool[rng.randi_range(0, pool.size() - 1)])
	_play_clip(clip_name, pool_id, player)

func _play_clip(clip_name: String, pool_id: String, target: AudioStreamPlayer) -> void:
	var stream := get_stream(clip_name)
	if stream == null:
		if target == player:
			_on_scene_clip_finished()
		return
	target.stop()
	target.stream = stream
	target.play()
	voice_played.emit(pool_id, clip_name)

## 获取或缓存 AudioStream 资源
func get_stream(clip_name: String) -> AudioStream:
	if _stream_cache.has(clip_name):
		return _stream_cache[clip_name]

	var res_path := "res://assets/audio/h_voice/" + clip_name
	var stream: AudioStream = null

	if ResourceLoader.exists(res_path):
		stream = load(res_path) as AudioStream

	if stream == null:
		var abs_path := ProjectSettings.globalize_path(res_path)
		if FileAccess.file_exists(abs_path):
			stream = AudioStreamOggVorbis.load_from_file(abs_path)

	if stream != null:
		_stream_cache[clip_name] = stream

	return stream
