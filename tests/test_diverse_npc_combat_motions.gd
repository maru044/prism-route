@tool
extends SceneTree
## Verifies that all 48 NPC encounters have diverse, valid combat/ground service motions assigned.

const NPCRegistryClass := preload("res://scripts/npc/npc_registry.gd")
const MotionResolverClass := preload("res://scripts/world/motion_resolver.gd")

const EXPECTED_MOTIONS := [
	"res://assets/characters/mmd_selected/animations/mmd_c63e75bc7057_a.tres",
	"res://assets/characters/mmd_selected/animations/mmd_67d58e9d607e_a.tres",
	"res://assets/characters/mmd_selected/animations/mmd_2864892bd378_a.tres",
	"res://assets/characters/mmd_selected/animations/mmd_87e004f6db53_a.tres",
	"res://assets/characters/mmd_selected/animations/mmd_1256ad646811_a.tres",
	"res://assets/characters/mmd_selected/animations/mmd_16a2ecfb7781_a.tres",
]

func _init() -> void:
	print("==================================================")
	print("[Test] Verifying Diverse NPC Combat/Ground Service Motions")
	print("==================================================")

	NPCRegistryClass.ensure_initialized()
	var encounters: Array = NPCRegistryClass._encounters.keys()
	assert(encounters.size() >= 48, "Expected at least 48 registered encounters, found %d" % encounters.size())
	print("  [Pass] Loaded %d total NPC encounters" % encounters.size())

	var motion_distribution := {}
	for motion_path in EXPECTED_MOTIONS:
		motion_distribution[motion_path] = []

	var verified_count := 0
	for encounter_id in encounters:
		var bundle := NPCRegistryClass.assemble_encounter(encounter_id)
		assert(bundle.get("valid", false), "Encounter assembly failed for: " + encounter_id)

		var motions_dict: Dictionary = bundle.get("motions", {})
		assert(not motions_dict.is_empty(), "Motions dict missing for: " + encounter_id)

		# Resolve ground service
		var resolution := MotionResolverClass.resolve_motion(motions_dict, "ground_service")
		assert(resolution.get("found", false), "Failed to resolve ground_service for: " + encounter_id)

		var role_a: String = resolution.get("role_a_motion", "")
		var role_b: String = resolution.get("role_b_motion", "")

		assert(ResourceLoader.exists(role_a), "role_a_motion resource missing: " + role_a)
		assert(ResourceLoader.exists(role_b), "role_b_motion resource missing: " + role_b)

		if motion_distribution.has(role_a):
			motion_distribution[role_a].append(bundle.character.get("character_id", encounter_id))

		verified_count += 1

	print("  [Pass] Verified all %d encounters have valid and existing role_a and role_b motion resources" % verified_count)

	# Verify distribution across the 6 selected motion categories
	print("\n--- Motion Distribution Across 48 Characters ---")
	for motion_path in EXPECTED_MOTIONS:
		var chars: Array = motion_distribution.get(motion_path, [])
		var motion_name: String = motion_path.get_file().trim_suffix("_a.tres")
		print("  - Motion %s: %d characters %s" % [motion_name, chars.size(), str(chars)])
		assert(chars.size() >= 5, "Expected balanced distribution, but %s only had %d characters" % [motion_name, chars.size()])

	# Verify preserved furniture bindings for key characters
	print("\n--- Preserved Furniture Bindings Check ---")
	var ganyu_bundle := NPCRegistryClass.assemble_encounter("sandbar_ganyu")
	assert(ganyu_bundle.motions.bindings.has("seat_service"), "Ganyu must preserve seat_service")
	print("  [Pass] Ganyu preserved seat_service")

	var keqing_bundle := NPCRegistryClass.assemble_encounter("sandbar_keqing")
	assert(keqing_bundle.motions.bindings.has("desk_service"), "Keqing must preserve desk_service")
	print("  [Pass] Keqing preserved desk_service")

	var sparkle_bundle := NPCRegistryClass.assemble_encounter("initial_temple_sparkle")
	assert(sparkle_bundle.motions.bindings.has("virgin"), "Sparkle must preserve virgin service")
	assert(sparkle_bundle.motions.bindings.has("honban"), "Sparkle must preserve honban service")
	print("  [Pass] Sparkle preserved virgin and honban furniture services")

	print("\n==================================================")
	print("[SUCCESS] All 48 NPC combat motions verified diverse, balanced, and fully valid")
	print("==================================================")
	quit(0)
