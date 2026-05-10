extends SceneTree

const AugmentDataScript := preload("res://data/resources/augment_data.gd")
const UpgradeDataScript := preload("res://data/resources/upgrade_data.gd")

const RUN_SCENE_PATH := "res://scenes/run/RunScene.tscn"
const DAMAGE_UPGRADE_PATH := "res://data/content/upgrades/damage_focus.tres"
const COOLDOWN_UPGRADE_PATH := "res://data/content/upgrades/cooldown_focus.tres"
const PICKUP_UPGRADE_PATH := "res://data/content/upgrades/pickup_focus.tres"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var registry := root.get_node_or_null("AugmentRegistry")
	var upgrade_system := root.get_node_or_null("UpgradeSystem")
	if registry == null or upgrade_system == null:
		_fail(["AugmentRegistry or UpgradeSystem autoload missing"])
		return
	registry.call("reload")
	upgrade_system.call("reset")

	_assert_legacy_options_preserved(upgrade_system, failures)
	_assert_basic_augment_roll_rules(registry, upgrade_system, failures)
	_assert_tracking_and_weighting(registry, upgrade_system, failures)
	_assert_filter_rules(registry, upgrade_system, failures)
	_assert_level_up_panel_support(registry, upgrade_system, failures)

	if failures.is_empty():
		print("PASS: augment pool selection and LevelUpPanel resource choices")
		quit(0)
	else:
		_fail(failures)

func _assert_legacy_options_preserved(upgrade_system: Node, failures: Array[String]) -> void:
	var generated_paths := {}
	for index in range(12):
		var options: Array = upgrade_system.call("generate_options")
		if options.size() != 3:
			failures.append("legacy generate_options produced %d options at roll %d" % [options.size(), index])
			return
		for option in options:
			if not option is UpgradeDataScript:
				failures.append("legacy generate_options returned non-UpgradeData: %s" % [option])
				return
			generated_paths[(option as Resource).resource_path] = true
	for path in [DAMAGE_UPGRADE_PATH, COOLDOWN_UPGRADE_PATH, PICKUP_UPGRADE_PATH]:
		if not generated_paths.has(path):
			failures.append("legacy generate_options no longer reaches %s" % path)

func _assert_basic_augment_roll_rules(registry: Node, upgrade_system: Node, failures: Array[String]) -> void:
	upgrade_system.call("reset")
	var options: Array = upgrade_system.call("generate_augment_options", {"rng_seed": 11, "upgrade_index": 1})
	_assert_three_valid_augments(options, failures, "first augment roll")
	if not _has_starter(options):
		failures.append("first two augment offers must include at least one starter")
	if _count_high_risk(options) > 1:
		failures.append("first augment offer has more than one high-risk augment")

	upgrade_system.call("reset")
	options = upgrade_system.call("generate_augment_options", {"rng_seed": 31, "upgrade_index": 3})
	_assert_three_valid_augments(options, failures, "third augment roll without starter")
	if not _has_starter(options):
		failures.append("third augment offer without owned starter did not force a starter")

	upgrade_system.call("reset")
	options = upgrade_system.call("generate_augment_options", {"rng_seed": 3, "upgrade_index": 10})
	_assert_three_valid_augments(options, failures, "tenth augment roll")
	if not _has_rarity(options, "prismatic"):
		failures.append("level-up 10 did not guarantee a prismatic before any prismatic appeared")

	upgrade_system.call("reset")
	options = upgrade_system.call("generate_augment_options", {
		"rng_seed": 17,
		"upgrade_index": 5,
		"recent_dominated_routes": ["rune_volley", "rune_volley"]
	})
	_assert_three_valid_augments(options, failures, "route fatigue roll")
	if not _has_off_route_or_stabilizer(options, "rune_volley"):
		failures.append("route fatigue roll did not include an off-route/economy/survival option")

	var typhoon := registry.call("get_by_id", "aug_typhoon_split") as Resource
	if typhoon == null:
		failures.append("missing aug_typhoon_split fixture")
	elif bool(upgrade_system.call("is_augment_available_for_selection", typhoon, {"include_default_tags": false})):
		failures.append("hard weapon:projectile required tag did not filter without default player tags")

func _assert_tracking_and_weighting(registry: Node, upgrade_system: Node, failures: Array[String]) -> void:
	var fake_player := Node.new()
	root.add_child(fake_player)

	var starter := registry.call("get_by_id", "aug_rune_dual_wield") as Resource
	var support := registry.call("get_by_id", "aug_typhoon_split") as Resource
	var finisher := registry.call("get_by_id", "aug_collector_mark") as Resource
	if starter == null or support == null or finisher == null:
		failures.append("missing rune_volley weighting test augments")
		fake_player.free()
		return

	upgrade_system.call("reset")
	var support_base := float(upgrade_system.call("get_augment_candidate_weight", support, {"upgrade_index": 4}))
	var finisher_base := float(upgrade_system.call("get_augment_candidate_weight", finisher, {"upgrade_index": 4}))
	if not bool(upgrade_system.call("apply_augment", starter, fake_player)):
		failures.append("failed to apply starter augment for selection tracking")
		fake_player.free()
		return
	if bool(upgrade_system.call("is_augment_available_for_selection", starter)):
		failures.append("unique starter remained available after pick")
	var support_after_starter := float(upgrade_system.call("get_augment_candidate_weight", support, {"upgrade_index": 4}))
	if support_after_starter <= support_base:
		failures.append("route/starter weighting did not raise support weight: %.3f -> %.3f" % [support_base, support_after_starter])
	if not bool(upgrade_system.call("apply_augment", support, fake_player)):
		failures.append("failed to apply support augment for selection tracking")
	var finisher_after_chain := float(upgrade_system.call("get_augment_candidate_weight", finisher, {"upgrade_index": 4}))
	if finisher_after_chain <= finisher_base:
		failures.append("starter+support weighting did not raise finisher weight: %.3f -> %.3f" % [finisher_base, finisher_after_chain])

	upgrade_system.call("reset")
	if not bool(upgrade_system.call("apply_augment", support, fake_player)):
		failures.append("failed to apply first rankable augment")
	elif int(upgrade_system.call("get_owned_augment_rank", "aug_typhoon_split")) != 1:
		failures.append("rankable augment first pick was not tracked")
	elif not bool(upgrade_system.call("is_augment_available_for_selection", support)):
		failures.append("rankable augment disappeared before max_rank")
	if not bool(upgrade_system.call("apply_augment", support, fake_player)):
		failures.append("failed to apply second rankable augment")
	elif bool(upgrade_system.call("is_augment_available_for_selection", support)):
		failures.append("rankable augment remained available after max_rank")

	fake_player.free()

func _assert_filter_rules(registry: Node, upgrade_system: Node, failures: Array[String]) -> void:
	var fake_player := Node.new()
	root.add_child(fake_player)
	var finisher := registry.call("get_by_id", "aug_collector_mark") as Resource
	var pandora := registry.call("get_by_id", "aug_pandora_box") as Resource
	if finisher == null or pandora == null:
		failures.append("missing excludes_tags test augments")
		fake_player.free()
		return
	upgrade_system.call("reset")
	if not bool(upgrade_system.call("apply_augment", finisher, fake_player)):
		failures.append("failed to apply finisher for excludes_tags tracking")
	elif bool(upgrade_system.call("is_augment_available_for_selection", pandora)):
		failures.append("excludes_tags did not block Pandora after owning a finisher/unique marker")

	upgrade_system.call("reset")
	var blocker = _make_valid_contract_augment("aug_excludes_id_blocker")
	var blocked = _make_valid_contract_augment("aug_excludes_id_blocked")
	var blocked_excludes_ids: Array[String] = ["aug_excludes_id_blocker"]
	blocked.excludes_ids = blocked_excludes_ids
	if not bool(upgrade_system.call("apply_augment", blocker, fake_player)):
		failures.append("failed to apply in-memory excludes_ids blocker")
	elif bool(upgrade_system.call("is_augment_available_for_selection", blocked)):
		failures.append("excludes_ids did not block an explicitly incompatible augment id")
	fake_player.free()

func _assert_level_up_panel_support(registry: Node, upgrade_system: Node, failures: Array[String]) -> void:
	upgrade_system.call("reset")
	var run_scene_packed := load(RUN_SCENE_PATH) as PackedScene
	if run_scene_packed == null:
		failures.append("failed to load RunScene for LevelUpPanel smoke")
		return
	var run_scene := run_scene_packed.instantiate()
	root.add_child(run_scene)
	await process_frame

	var game_events := root.get_node("GameEvents")
	var game_runtime := root.get_node("GameRuntime")
	var experience_system := root.get_node("ExperienceSystem")
	var level_panel: Variant = run_scene.get_node_or_null("CanvasLayer/LevelUpPanel")
	var player: Variant = run_scene.get_node_or_null("World/Player")
	if level_panel == null or player == null:
		failures.append("RunScene missing LevelUpPanel or Player")
		run_scene.free()
		return

	var augment := registry.call("get_by_id", "aug_stats_forge") as Resource
	var legacy_damage := load(DAMAGE_UPGRADE_PATH) as Resource
	var legacy_cooldown := load(COOLDOWN_UPGRADE_PATH) as Resource
	var legacy_pickup := load(PICKUP_UPGRADE_PATH) as Resource
	if augment == null or legacy_damage == null or legacy_cooldown == null or legacy_pickup == null:
		failures.append("missing UI smoke resources")
		run_scene.free()
		return

	upgrade_system.call("reset")
	experience_system.call("reset")
	game_runtime.call("start_run")
	experience_system.call("add_experience", 5)
	await process_frame
	if level_panel.visible == false or level_panel.current_options.size() != 3:
		failures.append("live ExperienceSystem level-up did not show three options")
	elif not _all_augments(level_panel.current_options):
		failures.append("live ExperienceSystem level-up did not emit AugmentData choices by default")
	elif (upgrade_system.call("get_active_choice_ids") as Array).size() != 3:
		failures.append("UpgradeSystem did not track active live augment choice ids")
	else:
		var live_text := _first_button_text(level_panel)
		for required in ["Tags:", "Source:", "Effect:", "Condition:", "Fit:", "Risk:"]:
			if not live_text.contains(required):
				failures.append("Live augment UI text missing %s cue: %s" % [required, live_text])
	if level_panel.current_options.size() > 0:
		level_panel.call("_select_option", level_panel.current_options[0])
		await process_frame
		if level_panel.visible or level_panel.current_options.size() != 0 or not (upgrade_system.call("get_active_choice_ids") as Array).is_empty():
			failures.append("live augment selection did not clear panel/current choice state")

	upgrade_system.call("reset")
	upgrade_system.call("set_next_choice_refresh_per_slot", 1)
	var refreshed_options: Array = upgrade_system.call("generate_augment_options", {"rng_seed": 91, "upgrade_index": 4})
	if refreshed_options.size() != 3:
		failures.append("next-choice refresh state changed three-choice count")
	if int(upgrade_system.call("get_last_consumed_next_choice_refresh_per_slot")) != 1:
		failures.append("next-choice refresh state was not consumed on the next generated offer")
	if int(upgrade_system.call("get_pending_next_choice_refresh_per_slot")) != 0:
		failures.append("next-choice refresh state leaked after generated offer")

	upgrade_system.call("reset")
	game_runtime.call("start_run")
	game_events.emit_signal("level_up_requested", _resource_array([augment, legacy_damage, legacy_cooldown]))
	if level_panel.visible == false or level_panel.current_options.size() != 3:
		failures.append("LevelUpPanel did not display mixed augment/legacy options")
	else:
		var options_container: Node = level_panel.get_node("Panel/Margin/Content/Options")
		var augment_button := options_container.get_child(0) as Button
		var has_rarity_cue := augment_button != null and (augment_button.text.contains("Prismatic") or augment_button.text.contains("Silver") or augment_button.text.contains("Gold"))
		if not has_rarity_cue:
			failures.append("Augment option text did not include rarity cue: %s" % (augment_button.text if augment_button != null else "<null>"))
		if augment_button != null and not augment_button.text.contains(str(augment.get("route_id"))):
			failures.append("Augment option text did not include route cue: %s" % augment_button.text)
		for required in ["Tags:", "Source:", "Condition:", "Fit:", "Risk:"]:
			if augment_button != null and not augment_button.text.contains(required):
				failures.append("Augment option text did not include %s cue: %s" % [required, augment_button.text])

	game_runtime.call("enter_level_up")
	level_panel.call("_select_option", augment)
	await process_frame
	if level_panel.visible or level_panel.current_options.size() != 0:
		failures.append("LevelUpPanel did not clear augment options after selection")
	if int(upgrade_system.call("get_owned_augment_rank", "aug_stats_forge")) != 1:
		failures.append("LevelUpPanel did not pass AugmentData selection into UpgradeSystem")

	game_events.emit_signal("level_up_requested", _resource_array([legacy_damage, legacy_cooldown, legacy_pickup]))
	game_runtime.call("enter_level_up")
	var base_damage := float(player.damage_multiplier)
	level_panel.call("_select_option", legacy_damage)
	await process_frame
	if float(player.damage_multiplier) <= base_damage:
		failures.append("LevelUpPanel did not pass legacy UpgradeData selection into UpgradeSystem")
	if level_panel.visible or level_panel.current_options.size() != 0:
		failures.append("LevelUpPanel did not clear legacy options after selection")

	run_scene.free()

func _assert_three_valid_augments(options: Array, failures: Array[String], label: String) -> void:
	if options.size() != 3:
		failures.append("%s produced %d options, expected 3" % [label, options.size()])
	var ids := {}
	for option in options:
		if not option is AugmentDataScript:
			failures.append("%s included non-AugmentData: %s" % [label, option])
			continue
		var augment_id := str((option as Resource).get("id"))
		if ids.has(augment_id):
			failures.append("%s included duplicate augment id: %s" % [label, augment_id])
		ids[augment_id] = true

func _all_augments(options: Array) -> bool:
	for option in options:
		if not option is AugmentDataScript:
			return false
	return true

func _first_button_text(level_panel: Node) -> String:
	var options_container: Node = level_panel.get_node("Panel/Margin/Content/Options")
	if options_container.get_child_count() <= 0:
		return ""
	var button := options_container.get_child(0) as Button
	return button.text if button != null else ""

func _has_starter(options: Array) -> bool:
	for option in options:
		if _manifest_bool(option as Resource, "is_starter"):
			return true
	return false

func _has_rarity(options: Array, rarity: String) -> bool:
	for option in options:
		if str((option as Resource).get("rarity")) == rarity:
			return true
	return false

func _count_high_risk(options: Array) -> int:
	var count := 0
	for option in options:
		if _manifest_bool(option as Resource, "is_high_risk"):
			count += 1
	return count

func _has_off_route_or_stabilizer(options: Array, blocked_route: String) -> bool:
	for option in options:
		var resource := option as Resource
		if str(resource.get("route_id")) != blocked_route:
			return true
		var tags: Array = resource.get("synergy_tags")
		if tags.has("economy") or tags.has("survival"):
			return true
	return false

func _manifest_bool(resource: Resource, key: String) -> bool:
	if resource == null:
		return false
	var manifest: Variant = resource.get("manifest_fields")
	if manifest is Dictionary:
		return bool((manifest as Dictionary).get(key, false))
	return false

func _resource_array(values: Array) -> Array[Resource]:
	var result: Array[Resource] = []
	for value in values:
		result.append(value as Resource)
	return result

func _make_valid_contract_augment(augment_id: String) -> Resource:
	var augment = AugmentDataScript.new()
	augment.id = augment_id
	augment.display_name = augment_id
	augment.route_id = "contract"
	augment.route_label = "Contract"
	augment.rarity = "silver"
	augment.max_rank = 1
	augment.unique = true
	augment.manifest_resource_path = "tests/fixtures/augments/contract/%s.tres" % augment_id
	augment.test_owner = "augment_pool_selection_loop.gd"
	augment.trigger_spec = {
		"trigger_id": "on_pick",
		"signal_names": ["augment_acquired"],
		"required_packet_keys": ["owner", "augment_id"],
		"synthetic_test": "contract in-memory pick"
	}
	var blueprint: Array[Dictionary] = [{
		"effect_type": "modify_stat",
		"effect_family": "modify_stat",
		"params": {"stat": "damage_multiplier", "op": "add_percent", "value": 0.01},
		"max_proc_depth": 2,
		"blocks_same_family_recursion": true
	}]
	augment.effect_spec_blueprint = blueprint
	augment.ensure_runtime_specs_from_blueprint()
	return augment

func _fail(failures: Array[String]) -> void:
	for failure in failures:
		push_error(failure)
	quit(1)
