extends SceneTree

const Validator := preload("res://tools/npc_content_validator.gd")

func _initialize() -> void:
	var content := Validator.CONTENT
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--npc-root="):
			content = argument.trim_prefix("--npc-root=")
	var validator := Validator.new()
	var ok := validator.validate(content)
	for error in validator.errors:
		printerr(error)
	print("NPC content validation: %s (%d errors)" % ["PASS" if ok else "FAIL", validator.errors.size()])
	quit(0 if ok else 1)
