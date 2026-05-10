extends SceneTree

const CONTENT_ROOT := "res://data/content/augments"
const FIXTURE_PRODUCTION_PATH := "res://data/content/augments/contract_fixture/aug_contract_fixture.tres"
const EXPECTED_TOTAL := 72
const EXPECTED_PER_ROUTE := 8

const REQUIRED_MANIFEST_FIELDS: Array[String] = [
	"id",
	"display_name",
	"source_augment_name",
	"source_augment_rarity",
	"route_id",
	"route_label",
	"rarity",
	"max_rank",
	"unique",
	"upgrade_type",
	"trigger",
	"effect",
	"condition",
	"value",
	"synergy_tags",
	"required_tags",
	"excludes_tags",
	"combo_value",
	"fit",
	"risk",
	"why_close",
	"implementation_hint",
	"resource_path",
	"test_owner",
	"checkpoint_priority",
	"trigger_spec",
	"effect_spec_blueprint",
	"is_starter",
	"is_finisher",
	"is_high_risk",
]

const EXPECTED_ROUTE_IDS := {
	"rune_volley": [
		"aug_rune_dual_wield",
		"aug_typhoon_split",
		"aug_jeweled_rune",
		"aug_critical_shards",
		"aug_ethereal_weapon",
		"aug_press_chain",
		"aug_crit_cast_engine",
		"aug_collector_mark",
	],
	"inferno_conduit": [
		"aug_infernal_conduit",
		"aug_firebrand_runes",
		"aug_slow_cooker_aura",
		"aug_chili_oil",
		"aug_holy_fire_conversion",
		"aug_vulnerable_flame",
		"aug_tormentor_brand",
		"aug_infernal_detonation",
	],
	"void_cascade": [
		"aug_void_rift",
		"aug_magic_missile",
		"aug_trueshot_prod",
		"aug_erosion_loop",
		"aug_hextech_chain",
		"aug_pinball_rift",
		"aug_duality_charge",
		"aug_void_collapse",
	],
	"aegis_transmutation": [
		"aug_shield_egg",
		"aug_circle_of_death",
		"aug_critical_healing",
		"aug_windspeaker",
		"aug_sonic_holy",
		"aug_big_brain_barrier",
		"aug_faith_shockwave",
		"aug_laser_heal_array",
	],
	"blood_reaver": [
		"aug_ominous_pact",
		"aug_devil_shoulder",
		"aug_vampirism",
		"aug_escape_plan",
		"aug_dawn_resolve",
		"aug_blood_debt_execute",
		"aug_final_transit",
		"aug_glass_cannon",
	],
	"snowstep_vanguard": [
		"aug_holy_snowmark",
		"aug_flash2",
		"aug_flashbang",
		"aug_dashing_engine",
		"aug_shadow_runner",
		"aug_poro_king_bounce",
		"aug_dropkick_dash",
		"aug_speed_demon",
	],
	"colossus_furnace": [
		"aug_colossus_courage",
		"aug_cruel_comet",
		"aug_impassable",
		"aug_adamant_layers",
		"aug_soul_eater",
		"aug_immolate_engine",
		"aug_goliath",
		"aug_stuck_with_me",
	],
	"summon_engine": [
		"aug_orbital_laser",
		"aug_quantum_slash",
		"aug_boomerang",
		"aug_firefox",
		"aug_poro_blaster",
		"aug_minionmancer",
		"aug_hand_of_baron",
		"aug_divine_intervention",
	],
	"quest_forge": [
		"aug_stats_forge",
		"aug_stats_on_stats",
		"aug_red_envelope",
		"aug_goldrend",
		"aug_pandora_box",
		"aug_transmute_chaos",
		"aug_urf_champion",
		"aug_mobile_zhonya",
	],
}

const EXPECTED_TEST_OWNERS := {
	"rune_volley": "augment_rune_volley_loop.gd",
	"inferno_conduit": "augment_inferno_loop.gd",
	"void_cascade": "augment_void_loop.gd",
	"aegis_transmutation": "augment_aegis_loop.gd",
	"blood_reaver": "augment_blood_loop.gd",
	"snowstep_vanguard": "augment_snowstep_loop.gd",
	"colossus_furnace": "augment_colossus_loop.gd",
	"summon_engine": "augment_summon_loop.gd",
	"quest_forge": "augment_forge_loop.gd",
}

const MVP20_IDS: Array[String] = [
	"aug_rune_dual_wield",
	"aug_infernal_conduit",
	"aug_void_rift",
	"aug_shield_egg",
	"aug_typhoon_split",
	"aug_critical_shards",
	"aug_vulnerable_flame",
	"aug_magic_missile",
	"aug_jeweled_rune",
	"aug_ethereal_weapon",
	"aug_circle_of_death",
	"aug_holy_fire_conversion",
	"aug_infernal_detonation",
	"aug_void_collapse",
	"aug_faith_shockwave",
	"aug_blood_debt_execute",
	"aug_ominous_pact",
	"aug_glass_cannon",
	"aug_stats_forge",
	"aug_mobile_zhonya",
]

const VALID_NORMALIZED_RARITIES: Array[String] = ["silver", "gold", "prismatic"]
const FORBIDDEN_PLACEHOLDER_TERMS: Array[String] = ["todo", "stub", "skipped", "placeholder", "fixture only", "resource-only", "not implemented"]

const AugmentDataScript := preload("res://data/resources/augment_data.gd")
const AugmentEffectSpecScript := preload("res://data/resources/augment_effect_spec.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	if ResourceLoader.exists(FIXTURE_PRODUCTION_PATH):
		failures.append("contract fixture still exists under production content root: %s" % FIXTURE_PRODUCTION_PATH)

	var registry := root.get_node_or_null("AugmentRegistry")
	if registry == null:
		failures.append("AugmentRegistry autoload is not registered")
		_finish(failures)
		return
	registry.call("reload", CONTENT_ROOT)
	failures.append_array(_string_array(registry.call("get_validation_errors")))
	failures.append_array(_string_array(registry.call("validate_all")))

	var augments: Array = registry.call("get_all")
	if augments.size() != EXPECTED_TOTAL:
		failures.append("expected %d production augments, found %d" % [EXPECTED_TOTAL, augments.size()])
	if registry.call("get_by_id", "aug_contract_fixture") != null:
		failures.append("contract fixture was loaded by production registry")

	var known_effect_types: Array[String] = AugmentEffectSpecScript.KNOWN_EFFECT_TYPES
	var ids_seen := {}
	var route_counts := {}
	var checkpoint_ids: Array[String] = []

	for augment in augments:
		if augment == null or (augment as Resource).get_script() != AugmentDataScript:
			failures.append("non-AugmentData resource loaded: %s" % [augment])
			continue
		var resource := augment as Resource
		var augment_id := str(resource.get("id"))
		var route_id := str(resource.get("route_id"))
		var expected_path := "%s/%s/%s.tres" % [CONTENT_ROOT.trim_prefix("res://"), route_id, augment_id]
		var native_path := resource.resource_path.trim_prefix("res://")
		var declared_path := str(resource.get("manifest_resource_path"))

		if ids_seen.has(augment_id):
			failures.append("duplicate augment id: %s" % augment_id)
		ids_seen[augment_id] = true
		route_counts[route_id] = int(route_counts.get(route_id, 0)) + 1

		if not EXPECTED_ROUTE_IDS.has(route_id):
			failures.append("%s has unknown route_id %s" % [augment_id, route_id])
		elif not (EXPECTED_ROUTE_IDS[route_id] as Array).has(augment_id):
			failures.append("%s is not in expected route list for %s" % [augment_id, route_id])
		if native_path != expected_path:
			failures.append("%s native path mismatch: %s != %s" % [augment_id, native_path, expected_path])
		if declared_path != expected_path:
			failures.append("%s manifest_resource_path mismatch: %s != %s" % [augment_id, declared_path, expected_path])

		var validate_errors: Array = resource.call("validate", expected_path)
		if not validate_errors.is_empty():
			failures.append("%s validate() errors: %s" % [augment_id, validate_errors])

		_validate_manifest_fields(resource, augment_id, route_id, expected_path, failures)
		_validate_specs(resource, augment_id, known_effect_types, failures)

		var priority := int(resource.get("checkpoint_priority"))
		if priority > 0:
			checkpoint_ids.append(augment_id)
			var expected_index := MVP20_IDS.find(augment_id) + 1
			if expected_index <= 0:
				failures.append("%s has checkpoint_priority %d but is not in MVP20" % [augment_id, priority])
			elif priority != expected_index:
				failures.append("%s checkpoint_priority mismatch: %d != %d" % [augment_id, priority, expected_index])

	for route_id in EXPECTED_ROUTE_IDS.keys():
		var count := int(route_counts.get(route_id, 0))
		if count != EXPECTED_PER_ROUTE:
			failures.append("route %s expected %d augments, found %d" % [route_id, EXPECTED_PER_ROUTE, count])
		for augment_id in EXPECTED_ROUTE_IDS[route_id]:
			if not ids_seen.has(augment_id):
				failures.append("missing expected augment id: %s" % augment_id)

	for augment_id in MVP20_IDS:
		if not checkpoint_ids.has(augment_id):
			failures.append("MVP20 augment missing checkpoint_priority: %s" % augment_id)
	if checkpoint_ids.size() != MVP20_IDS.size():
		failures.append("expected %d MVP20 checkpoint augments, found %d" % [MVP20_IDS.size(), checkpoint_ids.size()])

	_finish(failures)

func _validate_manifest_fields(resource: Resource, augment_id: String, route_id: String, expected_path: String, failures: Array[String]) -> void:
	var manifest_fields: Dictionary = resource.get("manifest_fields")
	if manifest_fields.is_empty():
		failures.append("%s missing manifest_fields dictionary" % augment_id)
	for field in REQUIRED_MANIFEST_FIELDS:
		if not manifest_fields.has(field):
			failures.append("%s manifest_fields missing %s" % [augment_id, field])

	for field in ["display_name", "source_augment_name", "source_augment_rarity", "route_label", "upgrade_type", "effect", "condition", "value", "combo_value", "fit", "risk", "why_close", "implementation_hint"]:
		if str(manifest_fields.get(field, "")).strip_edges() == "":
			failures.append("%s manifest field %s is empty" % [augment_id, field])

	if str(manifest_fields.get("id", "")) != augment_id:
		failures.append("%s manifest id mismatch" % augment_id)
	if str(manifest_fields.get("route_id", "")) != route_id:
		failures.append("%s manifest route_id mismatch" % augment_id)
	if str(manifest_fields.get("resource_path", "")) != expected_path:
		failures.append("%s manifest resource_path mismatch" % augment_id)
	if str(resource.get("test_owner")) != str(EXPECTED_TEST_OWNERS.get(route_id, "")):
		failures.append("%s test_owner mismatch: %s" % [augment_id, str(resource.get("test_owner"))])
	if str(manifest_fields.get("test_owner", "")) != str(resource.get("test_owner")):
		failures.append("%s manifest test_owner mismatch" % augment_id)
	if not VALID_NORMALIZED_RARITIES.has(str(resource.get("rarity"))):
		failures.append("%s normalized rarity is not known: %s" % [augment_id, str(resource.get("rarity"))])
	if int(manifest_fields.get("max_rank", 0)) != int(resource.get("max_rank")):
		failures.append("%s max_rank not preserved" % augment_id)
	if bool(manifest_fields.get("unique", false)) != bool(resource.get("unique")):
		failures.append("%s unique flag not preserved" % augment_id)

	var text_blob := "%s %s %s" % [str(resource.get("effect")), str(resource.get("implementation_hint")), str(resource.get("effect_spec_blueprint"))]
	var lower_blob := text_blob.to_lower()
	for term in FORBIDDEN_PLACEHOLDER_TERMS:
		if lower_blob.contains(term):
			failures.append("%s contains forbidden placeholder language: %s" % [augment_id, term])

func _validate_specs(resource: Resource, augment_id: String, known_effect_types: Array[String], failures: Array[String]) -> void:
	var trigger_spec: Dictionary = resource.get("trigger_spec")
	if trigger_spec.is_empty():
		failures.append("%s has empty trigger_spec" % augment_id)
	else:
		if str(trigger_spec.get("trigger_id", "")) == "":
			failures.append("%s trigger_spec missing trigger_id" % augment_id)
		if (trigger_spec.get("signal_names", []) as Array).is_empty():
			failures.append("%s trigger_spec missing signal_names" % augment_id)
		if (trigger_spec.get("required_packet_keys", []) as Array).is_empty():
			failures.append("%s trigger_spec missing required_packet_keys" % augment_id)
		if str(trigger_spec.get("synthetic_test", "")) == "":
			failures.append("%s trigger_spec missing synthetic_test" % augment_id)

	var blueprint: Array = resource.get("effect_spec_blueprint")
	if blueprint.is_empty():
		failures.append("%s has empty effect_spec_blueprint" % augment_id)
	for index in range(blueprint.size()):
		var effect_spec = blueprint[index]
		if not effect_spec is Dictionary:
			failures.append("%s effect_spec_blueprint[%d] is not a Dictionary" % [augment_id, index])
			continue
		var effect_type := str(effect_spec.get("effect_type", ""))
		if not known_effect_types.has(effect_type):
			failures.append("%s effect_spec_blueprint[%d] unknown effect_type %s" % [augment_id, index, effect_type])
		if str(effect_spec.get("effect_family", "")) == "":
			failures.append("%s effect_spec_blueprint[%d] missing effect_family" % [augment_id, index])
		if not effect_spec.get("params", {}) is Dictionary:
			failures.append("%s effect_spec_blueprint[%d] params is not a Dictionary" % [augment_id, index])
		elif (effect_spec.get("params", {}) as Dictionary).is_empty():
			failures.append("%s effect_spec_blueprint[%d] params is empty" % [augment_id, index])
		if int(effect_spec.get("max_proc_depth", -1)) < 0:
			failures.append("%s effect_spec_blueprint[%d] has negative max_proc_depth" % [augment_id, index])
		if not effect_spec.has("blocks_same_family_recursion"):
			failures.append("%s effect_spec_blueprint[%d] missing recursion block metadata" % [augment_id, index])

func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result

func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("PASS: all 72 augment content resources satisfy the manifest contract")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
