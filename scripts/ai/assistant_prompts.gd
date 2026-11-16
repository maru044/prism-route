extends RefCounted

const DIRECTORY := "res://assets/ai/assistant"
const REQUIRED := ["system", "tool_guide"]

var _role := ""
var _overview := ""
var _guides: Dictionary = {}

func load_directory(path: String) -> String:
	var documents := {}
	for file: String in DirAccess.get_files_at(path):
		if file.get_extension() != "md":
			continue
		var filename := path.path_join(file)
		var raw := FileAccess.get_file_as_string(filename).trim_prefix("\ufeff").replace("\r\n", "\n")
		var lines := raw.split("\n", true, 2)
		if lines.size() != 3:
			return "游戏助手提示词缺少文件头或正文 · " + filename
		var header: Variant = JSON.parse_string(lines[0])
		if lines[1] != "---" or not header is Dictionary \
				or header.get("agent") != "assistant" or header.get("kind") not in REQUIRED \
				or not header.get("name") is String or header.name.strip_edges().is_empty():
			return "游戏助手提示词文件头无效 · " + filename
		var kind: String = header.kind
		var content := lines[2].strip_edges()
		if content.is_empty() or documents.has(kind):
			return "游戏助手提示词为空或类型重复 · " + filename
		documents[kind] = content
	for kind: String in REQUIRED:
		if not documents.has(kind):
			return "缺少游戏助手提示词 · " + kind
	_role = documents.system
	return _parse_guide(documents.tool_guide)

func _parse_guide(markdown: String) -> String:
	_guides.clear()
	var sections := {"": PackedStringArray()}
	var tool := ""
	for line: String in markdown.split("\n"):
		if line.begins_with("## "):
			tool = line.substr(3).strip_edges()
			if tool.is_empty() or sections.has(tool):
				return "助手工具指南的工具标题为空或重复 · " + tool
			sections[tool] = PackedStringArray()
		else:
			sections[tool].append(line)
	_overview = "\n".join(sections[""]).strip_edges()
	sections.erase("")
	for name: String in sections:
		var body := "\n".join(sections[name]).strip_edges()
		if body.is_empty():
			return "助手工具指南缺少使用说明 · " + name
		_guides[name] = body
	return ""

func validate_tools(tools: Dictionary) -> String:
	for name: String in tools:
		if not _guides.has(name):
			return "已注册工具缺少使用说明 · " + name
	return ""

func system_message(tools: Dictionary) -> Dictionary:
	var parts := PackedStringArray([_role])
	if tools.is_empty():
		parts.append("本次请求没有开放工具。若已有工具结果，请据此整理答复。")
	else:
		if not _overview.is_empty():
			parts.append(_overview)
		for name: String in tools:
			parts.append("## %s\n%s" % [name, _guides[name]])
	return {"role": "system", "content": "\n\n".join(parts)}
