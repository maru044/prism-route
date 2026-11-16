@tool
extends SceneTree
## Tests upgraded DialogueManager with DialogueSession and ChoiceProvider.

const DialogueManagerClass := preload("res://scripts/narrative/dialogue_manager.gd")

func _init() -> void:
	print("Testing upgraded DialogueManager...")
	var root := Node.new()
	var mgr := DialogueManagerClass.new()
	root.add_child(mgr)
	
	var test_graph := {
		"id": "test_graph",
		"nodes": {
			"start": {
				"type": "text",
				"speaker": "测试角色",
				"text": "你好，{master_name}！",
				"next": "choice_node"
			},
			"choice_node": {
				"type": "choice",
				"speaker": "测试角色",
				"text": "请选择行动：",
				"choice_provider_id": "dynamic_provider",
				"choices": [
					{"text": "静态选项1", "target": "end_node"}
				]
			},
			"end_node": {
				"type": "text",
				"speaker": "测试角色",
				"text": "结束测试",
				"action": "close"
			}
		}
	}
	
	# Register a dynamic choice provider
	mgr.register_choice_provider("dynamic_provider", func(session):
		return [
			{"text": "【动态注入选项】由Provider提供", "target": "end_node"}
		]
	)
	
	var received := {
		"speaker": "",
		"text": "",
		"choices": []
	}
	mgr.text_updated.connect(func(sp, tx, em):
		print("SIGNAL text_updated received: speaker=", sp, " text=", tx)
		received["speaker"] = sp
		received["text"] = tx
	)
	mgr.choices_presented.connect(func(ch):
		received["choices"] = ch
	)
	
	mgr.start_dialogue(test_graph, "start")
	print("mgr.session_active: ", mgr.session_active, " current_node_id: ", mgr.current_node_id)
	assert(received["speaker"] == "测试角色")
	assert(received["text"] == "你好，主人！", "Variable interpolation must work")
	print("  ✓ Text interpolation verified: %s" % received["text"])
	
	mgr.advance_text()
	assert(received["choices"].size() == 2, "Choices must contain static + dynamic choice")
	assert(received["choices"][1]["text"] == "【动态注入选项】由Provider提供")
	print("  ✓ ChoiceProvider dynamic choice injection verified cleanly!")
	
	mgr.choose_option(1)
	assert(mgr.current_node_id == "end_node")
	
	received["ended"] = false
	mgr.dialogue_ended.connect(func(payload):
		received["ended"] = true
		assert(payload["action"] == "close")
	)
	mgr.advance_text()
	assert(received["ended"] == true)
	print("  ✓ Dialogue session ended cleanly!")
	
	print("[SUCCESS] Upgraded DialogueManager fully validated!")
	quit(0)
