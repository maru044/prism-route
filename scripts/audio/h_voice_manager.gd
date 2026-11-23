class_name HVoiceManager
extends Node
## Audio manager for progressive erotic voice clips (家园亲密侍奉、战斗Battle Fuck、随手摸胸微交互).
## Manages voice pools, progressive intensity ramp-up, natural breathing intervals, and playback routing.

signal voice_played(pool_id: String, clip_name: String)
signal intimacy_intensity_increased(stage: int)

static var instance: HVoiceManager

# Voice Pool Definitions
const POOLS: Dictionary = {
	# 家园日常亲密侍奉 (8大受纳体位)
	"voice_pool_oral": [
		"hime2561.ogg", # 0: 轻嘬柱身
		"hime2634.ogg", # 1: 深含吞吐
		"hime0860.ogg"  # 2: 深喉呜咽
	],
	"voice_pool_paizuri_chest": [
		"hime2009.ogg", # 0: 敏感抚弄
		"hime0139.ogg", # 1: 持续揉捻
		"hime2930.ogg"  # 2: 乳交夹触
	],
	"voice_pool_service_manual": [
		"hime0070.ogg", # 0: 指尖触碰
		"hime1996.ogg", # 1: 发热动情
		"hime3858.ogg"  # 2: 双女爱抚
	],
	"voice_pool_honban_cowgirl": [
		"hime1459.ogg", # 0: 跨坐深入
		"hime3035.ogg", # 1: 起伏颠簸
		"hime3056.ogg"  # 2: 深层满足
	],
	"voice_pool_honban_missionary": [
		"hime2029.ogg", # 0: 面对面受纳
		"hime2056.ogg", # 1: 密集抽送
		"hime2076.ogg"  # 2: 宫口深顶
	],
	"voice_pool_honban_doggy": [
		"hime1999.ogg", # 0: 背后贴入
		"hime2060.ogg", # 1: 剧烈冲撞
		"hime2102.ogg"  # 2: 抓扶边缘绝叫
	],
	"voice_pool_orgasm": [
		"hime2107.ogg", # 0: 临界攀升
		"hime2108.ogg", # 1: 爆发绝顶
		"hime0209.ogg"  # 2: 痉挛脱力
	],
	"voice_pool_aftercare": [
		"hime3007.ogg", # 0: 脱力慵懒喘息
		"hime0437.ogg"  # 1: 平复余韵轻柔询问
	],

	# 战斗色色对决 Battle Fuck
	"voice_battle_taunt": [
		"char0001.ogg", # 魔女冷嘲宣战
		"elle0111.ogg"   # 小恶魔戏谑反讽
	],
	"voice_battle_pleasure_low": [
		"elle0205.ogg", # 嘴硬强撑
		"muts0651.ogg"  # 皱眉抽气抵抗
	],
	"voice_battle_pleasure_mid": [
		"sall0153.ogg", # 防线动摇尖叫
		"elle0248.ogg"  # 呼吸凌乱失控
	],
	"voice_battle_pleasure_high": [
		"char0263.ogg", # 贯穿沦陷浪叫
		"sall0180.ogg"  # 暴风绝顶失神悲鸣
	],
	"voice_battle_defeat": [
		"char0306.ogg", # 魔女沉沦自白
		"elle0288.ogg"  # 小恶魔屈辱臣服
	],

	# 微交互
	"voice_touch_chest": [
		"hime0068.ogg", # 0: 轻按微颤
		"hime5294.ogg"  # 1: 拉扯娇嗔抗议
	],
	"voice_chat_greet": [
		"hime0013.ogg", # 温和轻唤
		"char0088.ogg"  # 优雅轻笑
	]
}

var player: AudioStreamPlayer
var _stream_cache: Dictionary = {}
var rng := RandomNumberGenerator.new()

# Intimacy state
var is_intimacy_active: bool = false
var current_intimacy_pool: String = ""
var motion_stage: int = 0 # 0: 初入浅尝, 1: 渐入佳境/持续升温
var time_in_stage: float = 0.0
var next_clip_timer: float = 0.0
var min_interval: float = 2.8
var max_interval: float = 5.2
var last_clip_played: String = ""

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
	_setup_bus()
	add_child(player)

func _setup_bus() -> void:
	var bus_name := &"PR_Voice"
	if AudioServer.get_bus_index(bus_name) < 0:
		var send_bus: StringName = &"PR_Actions" if AudioServer.get_bus_index(&"PR_Actions") >= 0 else (&"PR_World" if AudioServer.get_bus_index(&"PR_World") >= 0 else &"Master")
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, send_bus)
	if is_instance_valid(player):
		player.bus = bus_name

func _process(delta: float) -> void:
	if not is_intimacy_active:
		return

	time_in_stage += delta
	next_clip_timer -= delta

	if next_clip_timer <= 0.0:
		if is_instance_valid(player) and player.playing:
			return # 等待当前音声播完后再计算间隔

		_advance_intimacy_cycle()

func _advance_intimacy_cycle() -> void:
	if not POOLS.has(current_intimacy_pool):
		return
	var pool: Array = POOLS[current_intimacy_pool]
	if pool.is_empty():
		return

	if motion_stage == 0:
		# 刚进入或初入阶段结束，步入持续高潮段
		motion_stage = 1
		intimacy_intensity_increased.emit(motion_stage)

	# 持续阶段：在深层夹吸与高潮喘息（索引 1 与 2）之间轮播，不倒退回初入浅尝
	var pick_idx := 0
	if pool.size() > 1:
		pick_idx = rng.randi_range(1, pool.size() - 1)

	var clip_name: String = str(pool[pick_idx])
	var len_s := _play_clip(clip_name, current_intimacy_pool)
	next_clip_timer = len_s + rng.randf_range(min_interval, max_interval)

## 家园亲密侍奉动作启动
func start_intimacy(motion: Dictionary) -> void:
	var pool_id := resolve_intimacy_pool(motion)
	current_intimacy_pool = pool_id
	motion_stage = 0
	time_in_stage = 0.0
	is_intimacy_active = true

	if not POOLS.has(pool_id):
		return
	var pool: Array = POOLS[pool_id]
	if pool.is_empty():
		return

	# 初入浅尝：锁定第 0 条（结合/初入/浅尝）
	var clip_name: String = str(pool[0])
	var len_s := _play_clip(clip_name, pool_id)
	next_clip_timer = len_s + rng.randf_range(min_interval, max_interval)

## 家园亲密侍奉动作停止
func stop_intimacy(play_aftercare: bool = true) -> void:
	is_intimacy_active = false
	current_intimacy_pool = ""
	motion_stage = 0
	time_in_stage = 0.0
	next_clip_timer = 0.0

	if is_instance_valid(player):
		player.stop()

	if play_aftercare:
		_play_random_from_pool("voice_pool_aftercare")

## 触发绝顶高潮释出
func trigger_orgasm() -> void:
	_play_random_from_pool("voice_pool_orgasm")
	# 高潮期间推迟常规喘息
	next_clip_timer = 12.0

## 战斗开始挑衅
func play_battle_taunt() -> void:
	_play_random_from_pool("voice_battle_taunt")

## 战斗快感阶梯受击（传入快感比率 0.0~1.0 或 0~100）
func play_battle_reaction(pleasure_ratio: float) -> void:
	var pct := pleasure_ratio if pleasure_ratio > 1.0 else (pleasure_ratio * 100.0)
	if pct < 40.0:
		_play_random_from_pool("voice_battle_pleasure_low")
	elif pct < 75.0:
		_play_random_from_pool("voice_battle_pleasure_mid")
	else:
		_play_random_from_pool("voice_battle_pleasure_high")

## 战斗战败臣服
func play_battle_defeat() -> void:
	_play_random_from_pool("voice_battle_defeat")

## 随手摸胸即时短反馈（单发轻触 vs 快速连续拖拽）
func play_chest_fondle(continuous: bool = false) -> void:
	var now := float(Time.get_ticks_msec()) / 1000.0
	var is_rapid := (now - _last_chest_touch_time) < 1.6
	_last_chest_touch_time = now

	var pool: Array = POOLS.get("voice_touch_chest", [])
	if pool.is_empty():
		return

	if (continuous or is_rapid) and pool.size() > 1:
		_play_clip(str(pool[1]), "voice_touch_chest")
	else:
		_play_clip(str(pool[0]), "voice_touch_chest")

## 自由对话面板开启招呼
func play_chat_greet(character_id: String = "") -> void:
	var cid := character_id.to_lower()
	if cid in ["char", "charlotte", "夏洛特"]:
		_play_clip("char0088.ogg", "voice_chat_greet")
	else:
		_play_clip("hime0013.ogg", "voice_chat_greet")

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

func _play_random_from_pool(pool_id: String) -> float:
	if not POOLS.has(pool_id):
		return 0.0
	var pool: Array = POOLS[pool_id]
	if pool.is_empty():
		return 0.0
	var clip_name: String = str(pool[rng.randi_range(0, pool.size() - 1)])
	return _play_clip(clip_name, pool_id)

func _play_clip(clip_name: String, pool_id: String = "") -> float:
	_setup_player()
	var stream := get_stream(clip_name)
	if stream == null:
		return 0.0

	last_clip_played = clip_name
	voice_played.emit(pool_id, clip_name)

	if not is_inside_tree() or player == null or not player.is_inside_tree():
		return stream.get_length()

	player.stop()
	player.stream = stream
	player.play()
	return stream.get_length()

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
