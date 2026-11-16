@tool
extends SceneTree
## Verifies that GameLLMClient dynamically resolves and injects character personas (Sparkle, Keqing) into dialogue prompts.

const GameLLMClientClass := preload("res://scripts/ai/game_llm_client.gd")

func _init() -> void:
	print("==================================================")
	print("[Test] Verifying LLM Persona Injection System...")
	print("==================================================")
	
	var client := GameLLMClientClass.new()
	var da_err := client._load_dialogue_markdown()
	if not da_err.is_empty():
		push_error("Failed to load worldbook: " + da_err)
		quit(1)
		return
		
	print("  ✓ Base worldbook loaded successfully (%d entries)" % client._dialogue_entries.size())
	
	# Test 1: Sparkle Persona Injection
	print("\n--- Test 1: Sparkle Persona Injection ---")
	client.context = {
		"character_id": "sparkle",
		"npc_name": "花火",
		"dialogue_location": "初始神殿"
	}
	var parsed_sparkle := client._parsed_dialogue_prompts()
	var found_sparkle := false
	for mid in parsed_sparkle.mid:
		if mid.name == "角色设定 · 花火":
			found_sparkle = true
			assert("假面愚者" in mid.content, "Persona content must contain 假面愚者")
			assert("小主人" in mid.content or "Master" in mid.content, "Persona content must contain Master reference")
			print("  ✓ Sparkle persona entry verified at depth %d: %s" % [mid.depth, mid.name])
			break
	assert(found_sparkle, "Sparkle persona entry must be injected into prompts")
	
	# Test 2: Keqing Persona Injection
	print("\n--- Test 2: Keqing Persona Injection ---")
	client.context = {
		"character_id": "keqing",
		"npc_name": "刻晴",
		"dialogue_location": "沙洲度假遗址"
	}
	var parsed_keqing := client._parsed_dialogue_prompts()
	var found_keqing := false
	for mid in parsed_keqing.mid:
		if mid.name == "角色设定 · 刻晴":
			found_keqing = true
			assert("玉衡星" in mid.content, "Persona content must contain 玉衡星")
			assert("斩尽芜杂" in mid.content, "Persona content must contain classic line")
			print("  ✓ Keqing persona entry verified at depth %d: %s" % [mid.depth, mid.name])
			break
	assert(found_keqing, "Keqing persona entry must be injected into prompts")
	
	# Test 3: Fallback resolution by npc_name
	print("\n--- Test 3: Fallback resolution by npc_name ---")
	client.context = {
		"npc_name": "花火",
		"dialogue_location": "海岬小镇"
	}
	var parsed_fallback := client._parsed_dialogue_prompts()
	var found_fallback := false
	for mid in parsed_fallback.mid:
		if mid.name == "角色设定 · 花火":
			found_fallback = true
			break
	assert(found_fallback, "Fallback by npc_name must resolve character_id and inject persona")
	print("  ✓ Fallback by npc_name verified successfully!")
	
	print("\n==================================================")
	print("[SUCCESS] LLM Persona Injection fully validated!")
	print("==================================================")
	quit(0)
