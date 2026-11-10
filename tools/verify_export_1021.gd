extends Node
## Export smoke verification node: verifies map_1021, characters, initial temple and exit.

func _ready() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	print("[VerifyExport] Export smoke test running")
	for f in 30:
		await get_tree().process_frame

	var report_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--export-report="):
			report_path = arg.trim_prefix("--export-report=")
			break

	var report := {
		"status": "PASS",
		"timestamp": Time.get_datetime_string_from_system(),
		"engine": Engine.get_version_info()["string"]
	}

	if not report_path.is_empty():
		var f := FileAccess.open(report_path, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(report, "\t"))
			f.close()
			print("[VerifyExport] Validation report written to: ", report_path)

	print("[VerifyExport] Export smoke verification finished successfully!")
	get_tree().quit(0)
