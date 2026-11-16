extends RefCounted

static var _tool_name := RegEx.create_from_string("^[A-Za-z0-9_-]{1,64}\\z")
var _tools: Dictionary = {}

func register(name: String, description: String, parameters: Dictionary, handler: Callable) -> Error:
	if _tools.has(name):
		return ERR_ALREADY_EXISTS
	if _tool_name.search(name) == null or description.strip_edges().is_empty() \
			or parameters.get("type") != "object" or not handler.is_valid():
		return ERR_INVALID_PARAMETER
	var schema := parameters.duplicate(true)
	if not schema.has("additionalProperties"):
		schema["additionalProperties"] = false
	if not _valid_schema(schema):
		return ERR_INVALID_PARAMETER
	_tools[name] = {
		"spec": {"type": "function", "function": {
			"name": name, "description": description, "parameters": schema,
		}},
		"handler": handler,
	}
	return OK

func snapshot() -> Dictionary:
	return _tools.duplicate(true)

static func specifications(tools: Dictionary) -> Array:
	var specs: Array = []
	for entry: Dictionary in tools.values():
		specs.append(entry.spec)
	return specs

static func execute(tools: Dictionary, name: String, raw_arguments: String, turn: Dictionary) -> Dictionary:
	if not tools.has(name) or not tools[name].handler.is_valid():
		return {"error": "tool_or_destination_unavailable"}
	var entry: Dictionary = tools[name]
	var args: Variant = JSON.parse_string(raw_arguments)
	if not _matches(args, entry.spec.function.parameters):
		return {"error": "invalid_arguments"}
	var result: Variant = entry.handler.call(args, turn)
	return result if result is Dictionary else {"error": "invalid_tool_result"}

static func _valid_schema(schema: Variant) -> bool:
	if not schema is Dictionary:
		return false
	# Keep the supported subset explicit so schema and runtime checks agree.
	var keys := ["type", "description", "enum"]
	var kind: Variant = schema.get("type")
	if kind == "object":
		keys.append_array(["properties", "required", "additionalProperties"])
	elif kind == "array":
		keys.append("items")
	for key: Variant in schema:
		if key not in keys:
			return false
	if schema.has("description") and not schema.description is String:
		return false
	if schema.has("enum") and (not schema.enum is Array or schema.enum.is_empty()):
		return false
	match kind:
		"object":
			var properties: Variant = schema.get("properties", {})
			var required: Variant = schema.get("required", [])
			if not properties is Dictionary or not required is Array or not schema.get("additionalProperties", true) is bool:
				return false
			for key: Variant in properties:
				if not key is String or not _valid_schema(properties[key]):
					return false
			for key: Variant in required:
				if not key is String or not properties.has(key):
					return false
			return true
		"array":
			return _valid_schema(schema.get("items"))
		"string", "boolean", "integer", "number", "null":
			return true
	return false

static func _matches(value: Variant, schema: Dictionary) -> bool:
	if schema.has("enum") and value not in schema.enum:
		return false
	match schema.type:
		"object":
			if not value is Dictionary:
				return false
			var properties: Dictionary = schema.get("properties", {})
			for key: String in schema.get("required", []):
				if not value.has(key):
					return false
			for key: String in value:
				if not properties.has(key):
					if not schema.get("additionalProperties", true):
						return false
				elif not _matches(value[key], properties[key]):
					return false
			return true
		"array":
			if not value is Array:
				return false
			for item: Variant in value:
				if not _matches(item, schema.items):
					return false
			return true
		"string":
			return value is String
		"boolean":
			return value is bool
		"integer":
			return value is int or (value is float and is_finite(value) and value == floorf(value))
		"number":
			return value is int or (value is float and is_finite(value))
		"null":
			return value == null
	return false
