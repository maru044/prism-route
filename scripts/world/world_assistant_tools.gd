extends RefCounted

const WORLD_STATUS := "get_world_status"
const TELEPORT := "propose_teleport"

var _read_world: Callable
var _teleport: Callable

func register_tools(client: Node, read_world: Callable, teleport: Callable) -> void:
	_read_world = read_world
	_teleport = teleport
	var read_error: Error = client.register_tool(
		WORLD_STATUS, "读取当前角色、位置和有效定位点。",
		{"type": "object", "properties": {}}, _get_world_status
	)
	var propose_error: Error = client.register_tool(
		TELEPORT, "准备由玩家确认的传送提议。",
		{"type": "object", "properties": {"destination_id": {"type": "string"}}, "required": ["destination_id"]},
		_propose_teleport
	)
	if read_error != OK or propose_error != OK:
		push_error("无法注册大世界助手工具")

func _get_world_status(_args: Dictionary, turn: Dictionary) -> Dictionary:
	if not _read_world.is_valid():
		return {"error": "tool_or_destination_unavailable"}
	var state: Dictionary = _read_world.call()
	if not state.has("error"):
		turn["empty_reply_notice"] = "已查询游戏状态，模型未返回说明。"
	return state

func _propose_teleport(args: Dictionary, turn: Dictionary) -> Dictionary:
	if not _read_world.is_valid() or not _teleport.is_valid():
		return {"error": "tool_or_destination_unavailable"}
	if turn.has("offer"):
		return {"error": "one_teleport_proposal_per_turn", "destination_id": turn.offer.id.trim_prefix(TELEPORT + "/")}
	var state: Dictionary = _read_world.call()
	for destination: Dictionary in state.get("destinations", []):
		if destination.id == args.destination_id:
			var id: String = destination.id
			turn["offer"] = {
				"id": TELEPORT + "/" + id,
				"label": "确认传送 · " + str(destination.get("name", id)),
				"confirm": _teleport.bind(id),
				"pending": "已有待确认的传送提议。",
				"replaced": "已替换上一条待确认的传送提议。",
				"retry_suffix": " · 传送提议仍可确认。",
			}
			return {"status": "awaiting_player_confirmation", "destination": destination}
	return {"error": "tool_or_destination_unavailable"}
