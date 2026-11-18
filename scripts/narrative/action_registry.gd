class_name ActionRegistry
extends RefCounted
## Independent execution boundary and lifecycle manager for narrative actions.
## Enforces parameter schema validation, security whitelisting, and async lifecycle contracts.

enum ActionStatus {
	IDLE,
	RUNNING,
	SUCCEEDED,
	FAILED,
	CANCELLED
}

class ActionDefinition extends RefCounted:
	var action_id: String
	var is_async: bool = false
	var required_params: Array[String] = []
	var allowed_params: Array[String] = []
	var param_types: Dictionary = {}
	var timeout_seconds: float = 30.0
	var validator: Callable = Callable() # (params: Dictionary, context: Dictionary) -> bool
	var handler: Callable = Callable() # (execution_context: Dictionary) -> void or ActionStatus

	func _init(
		p_id: String,
		p_handler: Callable = Callable(),
		p_async: bool = false,
		p_req: Array[String] = [],
		p_validator: Callable = Callable()
	) -> void:
		action_id = p_id
		handler = p_handler
		is_async = p_async
		required_params = p_req
		validator = p_validator

var _actions: Dictionary = {} # canonical_id -> ActionDefinition
var _aliases: Dictionary = {} # alias -> canonical_id
var _running: Dictionary = {}
static var _next_execution_id := 0

func _init() -> void:
	_register_builtins()

func _register_builtins() -> void:
	# Standard synchronous dialogue control actions
	register_action("close")
	register_action("enter_combat")
	register_action("resume_combat")
	register_action("kill")
	register_action("spare")
	register_action("spare_virgin")
	register_action("spare_honban")
	register_action("spare_desk")
	register_action("spare_seat")
	register_action("desk_service")
	register_action("seat_service")
	register_action("finish_service")

	# Aliases
	register_alias("choose_kill", "kill")
	register_alias("choose_spare", "spare")
	register_alias("choose_spare_virgin", "spare_virgin")
	register_alias("choose_spare_honban", "spare_honban")
	register_alias("choose_spare_desk", "spare_desk")
	register_alias("choose_spare_seat", "spare_seat")
	register_alias("encounter.enter_combat", "enter_combat")
	register_alias("encounter.resume_combat", "resume_combat")
	register_alias("encounter.kill", "kill")
	register_alias("encounter.spare", "spare")
	register_alias("encounter.spare_virgin", "spare_virgin")
	register_alias("encounter.spare_honban", "spare_honban")
	register_alias("encounter.spare_desk", "spare_desk")
	register_alias("encounter.spare_seat", "spare_seat")
	register_alias("encounter.desk_service", "desk_service")
	register_alias("encounter.seat_service", "seat_service")
	register_alias("desk_service", "spare_desk")
	register_alias("seat_service", "spare_seat")
	register_alias("encounter.finish_service", "finish_service")
	register_alias("encounter.close", "close")

func register_action(
	action_id: String,
	handler: Callable = Callable(),
	is_async: bool = false,
	required_params: Array[String] = [],
	validator: Callable = Callable(),
	param_types: Dictionary = {},
	timeout_seconds: float = 30.0
) -> void:
	var definition := ActionDefinition.new(action_id, handler, is_async, required_params, validator)
	definition.param_types = param_types.duplicate()
	definition.timeout_seconds = maxf(.001, timeout_seconds)
	for key: String in param_types:
		definition.allowed_params.append(key)
	_actions[action_id] = definition

func register_alias(alias: String, canonical_id: String) -> void:
	_aliases[alias] = canonical_id

func has_action(action_id: String) -> bool:
	var canonical: String = resolve_action_id(action_id)
	return _actions.has(canonical)

func get_action(action_id: String) -> ActionDefinition:
	var canonical: String = resolve_action_id(action_id)
	return _actions.get(canonical, null)

func resolve_action_id(action_id: String) -> String:
	if _aliases.has(action_id):
		return _aliases[action_id]
	return action_id

func get_registered_action_ids() -> Array:
	var ids: Array = _actions.keys()
	ids.append_array(_aliases.keys())
	return ids

## Validate whether action can execute with given params and context
func validate_action(action_id: String, params: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	var canonical: String = resolve_action_id(action_id)
	if not _actions.has(canonical):
		return {
			"valid": false,
			"reason": "unregistered_action: " + action_id,
			"canonical_id": canonical
		}
	var def: ActionDefinition = _actions[canonical]
	for req in def.required_params:
		if not params.has(req):
			return {
				"valid": false,
				"reason": "missing_required_param: " + req,
				"canonical_id": canonical
			}
	for key: Variant in params:
		if key not in def.required_params and key not in def.allowed_params:
			return {"valid": false, "reason": "unknown_param: " + str(key), "canonical_id": canonical}
		if def.param_types.has(key) and typeof(params[key]) != def.param_types[key]:
			# JSON numbers arrive as floats in Godot, including integer literals.
			if def.param_types[key] != TYPE_INT or not params[key] is float or not is_finite(params[key]) or floorf(params[key]) != params[key]:
				return {"valid": false, "reason": "invalid_param_type: " + str(key), "canonical_id": canonical}
	if def.validator.is_valid():
		var ok: bool = def.validator.call(params, context)
		if not ok:
			return {
				"valid": false,
				"reason": "custom_validation_failed",
				"canonical_id": canonical
			}
	return {
		"valid": true,
		"canonical_id": canonical,
		"definition": def
	}

## Execute action with lifecycle management
## Synchronous calls return their terminal status. Async dispatch returns RUNNING.
## on_complete is authoritative and fires once with status, execution_id and session_id.
func execute_action(action_id: String, params: Dictionary, context: Dictionary, on_complete: Callable) -> int:
	_next_execution_id += 1
	var id := _next_execution_id
	var owner: int = context.get("session_id", 0)
	_running[id] = {"session_id": owner, "callback": on_complete, "cancel": Callable()}
	var val_res := validate_action(action_id, params, context)
	if not val_res.get("valid", false):
		_finish(id, ActionStatus.FAILED, {"error": val_res.reason, "action": action_id})
		return ActionStatus.FAILED

	var def: ActionDefinition = val_res["definition"]
	var canonical: String = val_res["canonical_id"]

	if not def.handler.is_valid():
		# Built-in action without custom handler: succeed immediately
		_finish(id, ActionStatus.SUCCEEDED, {"action": canonical, "params": params})
		return ActionStatus.SUCCEEDED

	if def.is_async:
		var registry_ref: WeakRef = weakref(self)
		var execution_context := {
			"action_id": canonical,
			"execution_id": id,
			"session_id": owner,
			"params": params,
			"context": context,
			"complete": func(status: int, result: Dictionary = {}):
				var registry = registry_ref.get_ref()
				if registry != null:
					registry._finish(id, status, result),
			"is_running": func() -> bool:
				var registry = registry_ref.get_ref()
				return registry != null and registry._running.has(id),
			"on_cancel": func(cleanup: Callable):
				var registry = registry_ref.get_ref()
				if registry != null:
					registry._set_cleanup(id, cleanup),
		}
		var tree: SceneTree = context.get("tree")
		if tree == null:
			tree = Engine.get_main_loop() as SceneTree
		if tree == null:
			_finish(id, ActionStatus.FAILED, {"error": "missing_scene_tree"})
			return ActionStatus.FAILED
		tree.create_timer(def.timeout_seconds).timeout.connect(func():
			var registry = registry_ref.get_ref()
			if registry != null:
				registry._finish(id, ActionStatus.FAILED, {"error": "action_timeout"}, true)
		, CONNECT_ONE_SHOT)
		def.handler.call(execution_context)
		return ActionStatus.RUNNING
	else:
		var result = def.handler.call(params, context)
		var status: int = ActionStatus.SUCCEEDED
		if result is bool and not result:
			status = ActionStatus.FAILED
		elif result is int and result in [ActionStatus.SUCCEEDED, ActionStatus.FAILED, ActionStatus.CANCELLED]:
			status = result
		_finish(id, status, {"result": result, "action": canonical})
		return status

func cancel_session(session_id: int) -> void:
	for id: int in _running.keys():
		if _running.get(id, {}).get("session_id") == session_id:
			_finish(id, ActionStatus.CANCELLED, {"error": "session_cancelled"}, true)

func _set_cleanup(id: int, callback: Callable) -> void:
	if _running.has(id):
		_running[id]["cancel"] = callback

func _finish(id: int, status: int, result: Dictionary, cleanup := false) -> void:
	if not _running.has(id) or status not in [ActionStatus.SUCCEEDED, ActionStatus.FAILED, ActionStatus.CANCELLED]:
		return
	var execution: Dictionary = _running[id]
	_running.erase(id)
	var cancel: Callable = execution.cancel
	if (cleanup or status == ActionStatus.CANCELLED) and cancel.is_valid():
		cancel.call()
	var callback: Callable = execution.callback
	if callback.is_valid():
		var payload := result.duplicate()
		payload["status"] = status
		payload["execution_id"] = id
		payload["session_id"] = execution.session_id
		callback.call(status, payload)
