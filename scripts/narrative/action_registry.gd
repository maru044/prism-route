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
	register_action("finish_service")

	# Aliases
	register_alias("choose_kill", "kill")
	register_alias("choose_spare", "spare")
	register_alias("choose_spare_virgin", "spare_virgin")
	register_alias("choose_spare_honban", "spare_honban")
	register_alias("encounter.enter_combat", "enter_combat")
	register_alias("encounter.resume_combat", "resume_combat")
	register_alias("encounter.kill", "kill")
	register_alias("encounter.spare", "spare")
	register_alias("encounter.spare_virgin", "spare_virgin")
	register_alias("encounter.spare_honban", "spare_honban")
	register_alias("encounter.finish_service", "finish_service")
	register_alias("encounter.close", "close")

func register_action(
	action_id: String,
	handler: Callable = Callable(),
	is_async: bool = false,
	required_params: Array[String] = [],
	validator: Callable = Callable()
) -> void:
	_actions[action_id] = ActionDefinition.new(action_id, handler, is_async, required_params, validator)

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
## on_complete callback: Callable(status: ActionStatus, result: Dictionary)
func execute_action(action_id: String, params: Dictionary, context: Dictionary, on_complete: Callable) -> int:
	var val_res := validate_action(action_id, params, context)
	if not val_res.get("valid", false):
		push_error("[ActionRegistry] Action validation failed: " + str(val_res.get("reason", "unknown")))
		if on_complete.is_valid():
			on_complete.call(ActionStatus.FAILED, {"error": val_res.get("reason"), "action": action_id})
		return ActionStatus.FAILED

	var def: ActionDefinition = val_res["definition"]
	var canonical: String = val_res["canonical_id"]

	if not def.handler.is_valid():
		# Built-in action without custom handler: succeed immediately
		if on_complete.is_valid():
			on_complete.call(ActionStatus.SUCCEEDED, {"action": canonical, "params": params})
		return ActionStatus.SUCCEEDED

	if def.is_async:
		var execution_context := {
			"action_id": canonical,
			"params": params,
			"context": context,
			"complete": func(status: int, result: Dictionary = {}):
				if on_complete.is_valid():
					on_complete.call(status, result)
		}
		def.handler.call(execution_context)
		return ActionStatus.RUNNING
	else:
		var result = def.handler.call(params, context)
		var status: int = ActionStatus.SUCCEEDED
		if result is bool and not result:
			status = ActionStatus.FAILED
		if on_complete.is_valid():
			on_complete.call(status, {"result": result, "action": canonical})
		return status
