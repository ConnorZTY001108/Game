extends SceneTree

const AUGMENT_DATA_PATH := "res://data/resources/augment_data.gd"
const TRIGGER_SPEC_PATH := "res://data/resources/augment_trigger_spec.gd"
const EFFECT_SPEC_PATH := "res://data/resources/augment_effect_spec.gd"
const CONDITION_SPEC_PATH := "res://data/resources/augment_condition_spec.gd"
const FORGE_OPTION_PATH := "res://data/resources/augment_forge_option.gd"
const FIXTURE_ROOT := "res://tests/fixtures/augments"
const FIXTURE_PATH := "res://tests/fixtures/augments/contract_fixture/aug_contract_fixture.tres"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for script_path in [AUGMENT_DATA_PATH, TRIGGER_SPEC_PATH, EFFECT_SPEC_PATH, CONDITION_SPEC_PATH, FORGE_OPTION_PATH]:
		if ResourceLoader.exists(script_path) == false:
			push_error("Missing augment schema script: %s" % script_path)
			quit(1)
			return
		if load(script_path) == null:
			push_error("Failed to load augment schema script: %s" % script_path)
			quit(1)
			return

	var augment_data_script := load(AUGMENT_DATA_PATH)
	var trigger_spec_script := load(TRIGGER_SPEC_PATH)
	var effect_spec_script := load(EFFECT_SPEC_PATH)
	var condition_spec_script := load(CONDITION_SPEC_PATH)
	var forge_option_script := load(FORGE_OPTION_PATH)

	var generated_augment = augment_data_script.new()
	generated_augment.id = "aug_generated_contract"
	generated_augment.display_name = "Generated Contract"
	generated_augment.route_id = "contract_fixture"
	generated_augment.route_label = "Contract Fixture"
	generated_augment.rarity = "gold"
	generated_augment.max_rank = 1
	generated_augment.unique = true
	generated_augment.upgrade_type = "starter"
	generated_augment.source_trigger = "on_attack_fire"
	generated_augment.effect = "Generated from blueprint."
	generated_augment.source_condition = "Projectile only."
	var generated_required_tags: Array[String] = ["weapon:projectile"]
	generated_augment.required_tags = generated_required_tags
	generated_augment.manifest_resource_path = "tests/fixtures/augments/contract_fixture/aug_generated_contract.tres"
	generated_augment.test_owner = "augment_resource_contract.gd"
	generated_augment.trigger_spec = {
		"trigger_id": "on_attack_fire",
		"signal_names": ["weapon_fired"],
		"required_packet_keys": ["owner", "weapon_id"],
		"synthetic_test": "contract synthetic event"
	}
	var generated_blueprint: Array[Dictionary] = [{
		"effect_type": "modify_stat",
		"effect_family": "modify_stat",
		"params": {"stat": "attack_speed_multiplier", "op": "add_percent", "value": 0.25}
	}]
	generated_augment.effect_spec_blueprint = generated_blueprint
	var generated_errors: Array = generated_augment.call("validate", "tests/fixtures/augments/contract_fixture/aug_generated_contract.tres")
	if not generated_errors.is_empty():
		push_error("Generated AugmentData validation failed: %s" % [generated_errors])
		quit(1)
		return
	if generated_augment.effects.size() != 1 or generated_augment.trigger == null:
		push_error("Generated AugmentData did not derive trigger/effect runtime specs")
		quit(1)
		return

	var runtime_metadata: Dictionary = generated_augment.call("get_runtime_metadata")
	if (runtime_metadata.get("effects", []) as Array).is_empty():
		push_error("Generated AugmentData runtime metadata has no effects")
		quit(1)
		return
	if str(((runtime_metadata["effects"] as Array)[0] as Dictionary).get("effect_type", "")) != "modify_stat":
		push_error("Generated runtime metadata did not preserve effect_type")
		quit(1)
		return

	var invalid_augment = augment_data_script.new()
	var invalid_errors: Array = invalid_augment.call("validate")
	for expected in ["augment_missing_id", "augment_missing_route_id", "augment_invalid_trigger_spec", "augment_missing_effects", "augment_missing_trigger_spec", "augment_missing_effect_spec_blueprint"]:
		if not _has_error(invalid_errors, expected):
			push_error("Invalid AugmentData did not report %s in %s" % [expected, invalid_errors])
			quit(1)
			return

	var runtime_trigger = trigger_spec_script.new()
	runtime_trigger.trigger_id = "on_attack_fire"
	var runtime_signal_names: Array[String] = ["weapon_fired"]
	runtime_trigger.signal_names = runtime_signal_names
	var runtime_required_keys: Array[String] = ["owner", "weapon_id"]
	runtime_trigger.required_packet_keys = runtime_required_keys

	var runtime_effect = effect_spec_script.new()
	runtime_effect.effect_type = "modify_stat"
	runtime_effect.effect_family = "modify_stat"
	runtime_effect.params = {"stat": "damage_multiplier", "op": "add_percent", "value": 0.1}

	var hand_authored_missing_trigger_spec = _make_minimal_contract_augment(augment_data_script, "aug_missing_trigger_spec")
	hand_authored_missing_trigger_spec.trigger = runtime_trigger
	hand_authored_missing_trigger_spec.effects = _resource_array([runtime_effect])
	hand_authored_missing_trigger_spec.effect_spec_blueprint = _blueprint_array([{
		"effect_type": "modify_stat",
		"effect_family": "modify_stat",
		"params": {"stat": "damage_multiplier", "op": "add_percent", "value": 0.1}
	}])
	var missing_trigger_spec_errors: Array = hand_authored_missing_trigger_spec.call("validate", "tests/fixtures/augments/contract_fixture/aug_missing_trigger_spec.tres")
	if not _has_error(missing_trigger_spec_errors, "augment_missing_trigger_spec"):
		push_error("Hand-authored runtime trigger bypassed missing trigger_spec contract: %s" % [missing_trigger_spec_errors])
		quit(1)
		return

	var hand_authored_empty_blueprint = _make_minimal_contract_augment(augment_data_script, "aug_empty_effect_spec_blueprint")
	hand_authored_empty_blueprint.trigger = runtime_trigger
	hand_authored_empty_blueprint.effects = _resource_array([runtime_effect])
	hand_authored_empty_blueprint.trigger_spec = {
		"trigger_id": "on_attack_fire",
		"signal_names": ["weapon_fired"],
		"required_packet_keys": ["owner", "weapon_id"],
		"synthetic_test": "contract synthetic event"
	}
	var empty_blueprint_errors: Array = hand_authored_empty_blueprint.call("validate", "tests/fixtures/augments/contract_fixture/aug_empty_effect_spec_blueprint.tres")
	if not _has_error(empty_blueprint_errors, "augment_missing_effect_spec_blueprint"):
		push_error("Hand-authored runtime effects bypassed empty effect_spec_blueprint contract: %s" % [empty_blueprint_errors])
		quit(1)
		return

	var bad_effect = effect_spec_script.new()
	bad_effect.effect_type = "not_a_manifest_effect"
	var bad_effect_errors: Array = bad_effect.call("validate")
	if not _has_error_prefix(bad_effect_errors, "effect_unknown_type"):
		push_error("Unknown effect type was not rejected: %s" % [bad_effect_errors])
		quit(1)
		return

	var valid_trigger = trigger_spec_script.new()
	valid_trigger.trigger_id = "on_pick"
	var valid_signal_names: Array[String] = ["augment_acquired"]
	valid_trigger.signal_names = valid_signal_names
	if not (valid_trigger.call("validate") as Array).is_empty():
		push_error("Valid trigger spec was rejected")
		quit(1)
		return

	var valid_condition = condition_spec_script.new()
	valid_condition.min_upgrade_index = 1
	valid_condition.max_upgrade_index = 3
	if not (valid_condition.call("validate") as Array).is_empty():
		push_error("Valid condition spec was rejected")
		quit(1)
		return

	var forge_option = forge_option_script.new()
	forge_option.id = "forge_damage"
	forge_option.stat_key = "damage"
	forge_option.value = 0.1
	if not (forge_option.call("validate") as Array).is_empty():
		push_error("Valid forge option was rejected")
		quit(1)
		return

	var registry := root.get_node_or_null("AugmentRegistry")
	if registry == null:
		push_error("AugmentRegistry autoload is not registered")
		quit(1)
		return
	registry.call("reload", FIXTURE_ROOT)
	var registry_errors: Array = registry.call("get_validation_errors")
	if not registry_errors.is_empty():
		push_error("AugmentRegistry reported fixture validation errors: %s" % [registry_errors])
		quit(1)
		return
	var fixture := registry.call("get_by_id", "aug_contract_fixture") as Resource
	if fixture == null:
		push_error("AugmentRegistry did not load aug_contract_fixture")
		quit(1)
		return
	if str(fixture.get("resource_path")).trim_prefix("res://") != FIXTURE_PATH.trim_prefix("res://"):
		push_error("Fixture native resource_path was %s" % str(fixture.get("resource_path")))
		quit(1)
		return
	if (registry.call("get_by_route", "contract_fixture") as Array).size() != 1:
		push_error("AugmentRegistry route query did not return the fixture only")
		quit(1)
		return
	var tag_query: Array = registry.call("query_candidates", {
		"route_id": "contract_fixture",
		"rarity": "gold",
		"tags": ["projectile"],
		"owned_tags": ["weapon:projectile"],
		"rng_seed": 7
	})
	if tag_query.size() != 1 or str((tag_query[0] as Resource).get("id")) != "aug_contract_fixture":
		push_error("AugmentRegistry query did not find fixture: %s" % [tag_query])
		quit(1)
		return
	var excluded_query: Array = registry.call("query_candidates", {
		"route_id": "contract_fixture",
		"owned_tags": ["weapon:projectile", "exclusive:test_block"]
	})
	if not excluded_query.is_empty():
		push_error("AugmentRegistry did not apply excludes_tags")
		quit(1)
		return
	if not (registry.call("validate_all") as Array).is_empty():
		push_error("AugmentRegistry validate_all reported errors after load")
		quit(1)
		return

	print("PASS: augment resource schema and registry contract")
	quit(0)

func _has_error(errors: Array, expected: String) -> bool:
	for error in errors:
		if str(error) == expected:
			return true
	return false

func _has_error_prefix(errors: Array, prefix: String) -> bool:
	for error in errors:
		if str(error).begins_with(prefix):
			return true
	return false

func _make_minimal_contract_augment(augment_data_script: Script, augment_id: String) -> Resource:
	var augment = augment_data_script.new()
	augment.id = augment_id
	augment.display_name = "Contract Negative"
	augment.route_id = "contract_fixture"
	augment.route_label = "Contract Fixture"
	augment.rarity = "gold"
	augment.max_rank = 1
	augment.unique = true
	augment.upgrade_type = "starter"
	augment.manifest_resource_path = "tests/fixtures/augments/contract_fixture/%s.tres" % augment_id
	augment.test_owner = "augment_resource_contract.gd"
	return augment

func _resource_array(values: Array) -> Array[Resource]:
	var result: Array[Resource] = []
	for value in values:
		result.append(value)
	return result

func _blueprint_array(values: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value in values:
		result.append(value)
	return result
