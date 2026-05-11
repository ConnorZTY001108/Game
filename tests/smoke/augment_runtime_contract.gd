extends SceneTree

const AugmentDataScript := preload("res://data/resources/augment_data.gd")
const AugmentEffectSpecScript := preload("res://data/resources/augment_effect_spec.gd")
const UpgradeDataScript := preload("res://data/resources/upgrade_data.gd")

const DAMAGE_UPGRADE_PATH := "res://data/content/upgrades/damage_focus.tres"
const RUN_SCENE_PATH := "res://scenes/run/RunScene.tscn"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var augment_system := root.get_node_or_null("AugmentSystem")
	var effect_runner := root.get_node_or_null("AugmentEffectRunner")
	var registry := root.get_node_or_null("AugmentRegistry")
	var upgrade_system := root.get_node_or_null("UpgradeSystem")
	if augment_system == null:
		failures.append("AugmentSystem autoload missing")
	if effect_runner == null:
		failures.append("AugmentEffectRunner autoload missing")
	if registry == null:
		failures.append("AugmentRegistry autoload missing")
	if upgrade_system == null:
		failures.append("UpgradeSystem autoload missing")
	if not failures.is_empty():
		_finish(failures)
		return

	registry.call("reload")
	augment_system.call("reset")
	upgrade_system.call("reset")

	_assert_direct_acquisition_and_pick_effects(registry, augment_system, failures)
	_assert_event_runtime_and_proc_guards(registry, augment_system, failures)
	_assert_representative_effect_families(augment_system, failures)
	_assert_active_cap_release_and_expiry(augment_system, failures)
	_assert_all_production_effects_are_handled(registry, effect_runner, failures)
	_assert_previously_unhandled_effects(augment_system, failures)
	_assert_low_hp_defense_burst_observable(registry, augment_system, failures)
	_assert_remaining_production_triggers_reachable(registry, augment_system, failures)
	_assert_invalid_resource_gating(augment_system, upgrade_system, failures)
	_assert_production_event_bridges(registry, augment_system, failures)
	_assert_upgrade_system_bridge(registry, upgrade_system, augment_system, failures)
	_assert_legacy_upgrade_still_applies(upgrade_system, failures)

	_finish(failures)

func _assert_direct_acquisition_and_pick_effects(registry: Node, augment_system: Node, failures: Array[String]) -> void:
	var owner := Node.new()
	root.add_child(owner)
	var game_events := root.get_node("GameEvents")
	var recorder := _AugmentSignalRecorder.new()
	root.add_child(recorder)
	if not game_events.has_signal("augment_acquired"):
		failures.append("GameEvents missing augment_acquired signal")
	if not game_events.has_signal("augment_effect_triggered"):
		failures.append("GameEvents missing augment_effect_triggered signal")
	if not game_events.has_signal("augment_state_changed"):
		failures.append("GameEvents missing augment_state_changed signal")
	if game_events.has_signal("augment_acquired"):
		game_events.connect("augment_acquired", recorder._on_acquired)
	if game_events.has_signal("augment_effect_triggered"):
		game_events.connect("augment_effect_triggered", recorder._on_effect_triggered)
	if game_events.has_signal("augment_state_changed"):
		game_events.connect("augment_state_changed", recorder._on_state_changed)
	var forge := registry.call("get_by_id", "aug_stats_forge") as Resource
	if forge == null:
		failures.append("missing aug_stats_forge")
		owner.free()
		recorder.free()
		return
	if not bool(augment_system.call("acquire_augment", forge, owner)):
		failures.append("AugmentSystem did not acquire aug_stats_forge")
	var snapshot: Dictionary = augment_system.call("get_runtime_snapshot")
	if int((snapshot.get("ranks", {}) as Dictionary).get("aug_stats_forge", 0)) != 1:
		failures.append("AugmentSystem did not track owned rank")
	if int((snapshot.get("route_counts", {}) as Dictionary).get("quest_forge", 0)) != 1:
		failures.append("AugmentSystem did not track route count")
	if not _string_array(snapshot.get("owned_tags", [])).has("forge"):
		failures.append("AugmentSystem did not mirror augment tags")
	if int((snapshot.get("choice_state", {}) as Dictionary).get("forge_choices_pending", 0)) < 2:
		failures.append("on_pick grant_forge_choice did not update runtime choice state")
	if int((snapshot.get("choice_state", {}) as Dictionary).get("forge_choices_pending", 0)) != 2:
		failures.append("on_pick grant_forge_choice executed more than once")
	if int((snapshot.get("effect_counts", {}) as Dictionary).get("grant_forge_choice", 0)) != 1:
		failures.append("on_pick grant_forge_choice effect count was not single-fire")
	if int((snapshot.get("augment_proc_counts", {}) as Dictionary).get("aug_stats_forge", 0)) != 1:
		failures.append("per-Augment proc count was not tracked for aug_stats_forge")
	if recorder.acquired_count != 1:
		failures.append("augment_acquired signal was not emitted once, got %d" % recorder.acquired_count)
	if recorder.effect_triggered_count != 1:
		failures.append("augment_effect_triggered signal was not emitted once, got %d" % recorder.effect_triggered_count)
	if recorder.state_changed_count < 1:
		failures.append("augment_state_changed signal was not emitted after acquisition/effect")
	if str(recorder.last_effect_payload.get("augment_id", "")) != "aug_stats_forge":
		failures.append("augment_effect_triggered payload did not include augment id: %s" % recorder.last_effect_payload)
	owner.free()
	recorder.free()

func _assert_event_runtime_and_proc_guards(registry: Node, augment_system: Node, failures: Array[String]) -> void:
	var damage_system := root.get_node("DamageSystem")
	var owner := Node.new()
	root.add_child(owner)
	var dual := registry.call("get_by_id", "aug_rune_dual_wield") as Resource
	if dual == null:
		failures.append("missing aug_rune_dual_wield")
		owner.free()
		return
	augment_system.call("reset")
	if not bool(augment_system.call("acquire_augment", dual, owner)):
		failures.append("failed to acquire aug_rune_dual_wield")
	var packet_tags: Array[String] = ["projectile", "weapon"]
	var weapon_tags: Array[String] = ["projectile"]
	var packet: Dictionary = damage_system.call("make_packet", 10.0, packet_tags, {
		"owner": owner,
		"weapon_id": "rune_bolt",
		"weapon_tags": weapon_tags,
		"cooldown_source_id": "rune_bolt",
		"hit_position": Vector2(2.0, 3.0)
	})
	augment_system.call("emit_synthetic_event", "on_attack_fire", packet, {"signal_name": "weapon_fired", "owner": owner})
	var snapshot: Dictionary = augment_system.call("get_runtime_snapshot")
	if int((snapshot.get("effect_counts", {}) as Dictionary).get("spawn_projectile", 0)) < 1:
		failures.append("weapon_fired did not execute spawn_projectile")
	if int((snapshot.get("effect_counts", {}) as Dictionary).get("modify_stat", 0)) < 1:
		failures.append("acquisition did not apply passive modify_stat")
	if int((snapshot.get("active_counts", {}) as Dictionary).get("projectile", 0)) < 1:
		failures.append("spawn_projectile did not update active projectile guard count")
	var child_packets: Array = snapshot.get("generated_packets", [])
	if child_packets.is_empty():
		failures.append("spawn_projectile did not create an observable proc packet")
	else:
		var child := child_packets[child_packets.size() - 1] as Dictionary
		if int(child.get("proc_depth", -1)) != 1:
			failures.append("proc packet did not increment depth")
		if not (child.get("proc_flags", []) as Array).has("spawn_projectile"):
			failures.append("proc packet did not append effect family flag")
		if not is_equal_approx(float(child.get("on_hit_efficiency", 0.0)), 0.4):
			failures.append("proc packet did not apply on-hit efficiency")

	var blocked_packet := packet.duplicate(true)
	blocked_packet["proc_flags"] = ["secondary_projectile"]
	augment_system.call("emit_synthetic_event", "on_attack_fire", blocked_packet, {"signal_name": "weapon_fired", "owner": owner})
	var after_block: Dictionary = augment_system.call("get_runtime_snapshot")
	if int((after_block.get("blocked_counts", {}) as Dictionary).get("recursion", 0)) < 1:
		failures.append("same-family/block flag guard was not recorded")
	owner.free()

func _assert_representative_effect_families(augment_system: Node, failures: Array[String]) -> void:
	var damage_system := root.get_node("DamageSystem")
	augment_system.call("reset")
	var owner := Node.new()
	var target := Node2D.new()
	root.add_child(owner)
	root.add_child(target)
	var synthetic := _make_synthetic_runtime_augment()
	if not bool(augment_system.call("acquire_augment", synthetic, owner)):
		failures.append("failed to acquire synthetic representative runtime augment")
		owner.free()
		target.free()
		return
	var packet_tags: Array[String] = ["projectile"]
	var packet: Dictionary = damage_system.call("make_packet", 20.0, packet_tags, {
		"owner": owner,
		"target": target,
		"source_kind": "weapon",
		"cooldown_source_id": "synthetic_weapon",
		"hit_position": Vector2(8.0, 4.0)
	})
	augment_system.call("emit_synthetic_event", "on_hit", packet, {"signal_name": "damage_applied_packet", "target": target, "owner": owner})
	augment_system.call("emit_synthetic_event", "on_hit", packet, {"signal_name": "damage_applied_packet", "target": target, "owner": owner})
	var snapshot: Dictionary = augment_system.call("get_runtime_snapshot")
	for effect_type in ["add_dot", "spawn_zone", "spawn_delayed_strike", "spawn_summon", "apply_shield", "heal_player", "apply_control", "progress_quest"]:
		if int((snapshot.get("effect_counts", {}) as Dictionary).get(effect_type, 0)) < 1:
			failures.append("representative effect did not execute: %s" % effect_type)
	if int((snapshot.get("blocked_counts", {}) as Dictionary).get("source_cooldown", 0)) < 1:
		failures.append("source cooldown guard did not block repeated trigger")
	if int((snapshot.get("active_counts", {}) as Dictionary).get("zone", 0)) > 12:
		failures.append("zone active guard exceeded cap")
	owner.free()
	target.free()

func _assert_active_cap_release_and_expiry(augment_system: Node, failures: Array[String]) -> void:
	var damage_system := root.get_node("DamageSystem")
	var owner := Node.new()
	var target := Node2D.new()
	root.add_child(owner)
	root.add_child(target)
	var packet_tags: Array[String] = ["skill"]
	var packet: Dictionary = damage_system.call("make_packet", 5.0, packet_tags, {
		"owner": owner,
		"target": target,
		"source_kind": "skill",
		"cooldown_source_id": "active_cap_contract",
		"hit_position": Vector2(1.0, 1.0)
	})

	augment_system.call("reset")
	var release_augment := _make_active_cap_augment("aug_active_release_contract", 60.0)
	if not bool(augment_system.call("acquire_augment", release_augment, owner)):
		failures.append("failed to acquire active release contract augment")
	else:
		augment_system.call("emit_synthetic_event", "on_hit", packet, {"signal_name": "damage_applied_packet", "owner": owner, "target": target})
		augment_system.call("emit_synthetic_event", "on_hit", packet, {"signal_name": "damage_applied_packet", "owner": owner, "target": target})
		var blocked_snapshot: Dictionary = augment_system.call("get_runtime_snapshot")
		if int((blocked_snapshot.get("effect_counts", {}) as Dictionary).get("spawn_zone", 0)) != 1:
			failures.append("active cap did not block second zone before release")
		if int((blocked_snapshot.get("blocked_counts", {}) as Dictionary).get("zone_cap", 0)) < 1:
			failures.append("active cap block was not recorded")
		augment_system.call("release_active_effect", "zone", "aug_active_release_contract", 1)
		var released_snapshot: Dictionary = augment_system.call("get_runtime_snapshot")
		if int((released_snapshot.get("active_counts", {}) as Dictionary).get("zone", 0)) != 0:
			failures.append("active cap release did not clear zone ledger")
		augment_system.call("emit_synthetic_event", "on_hit", packet, {"signal_name": "damage_applied_packet", "owner": owner, "target": target})
		var retrigger_snapshot: Dictionary = augment_system.call("get_runtime_snapshot")
		if int((retrigger_snapshot.get("effect_counts", {}) as Dictionary).get("spawn_zone", 0)) != 2:
			failures.append("active cap did not recover after explicit release")

	augment_system.call("reset")
	var expiry_augment := _make_active_cap_augment("aug_active_expiry_contract", 0.05)
	if not bool(augment_system.call("acquire_augment", expiry_augment, owner)):
		failures.append("failed to acquire active expiry contract augment")
	else:
		augment_system.call("emit_synthetic_event", "on_hit", packet, {"signal_name": "damage_applied_packet", "owner": owner, "target": target})
		augment_system.call("cleanup_active_effects", 1000000.0)
		var expired_snapshot: Dictionary = augment_system.call("get_runtime_snapshot")
		if int((expired_snapshot.get("active_counts", {}) as Dictionary).get("zone", 0)) != 0:
			failures.append("active cap expiry cleanup did not clear zone ledger")
		augment_system.call("emit_synthetic_event", "on_hit", packet, {"signal_name": "damage_applied_packet", "owner": owner, "target": target})
		var expiry_retrigger_snapshot: Dictionary = augment_system.call("get_runtime_snapshot")
		if int((expiry_retrigger_snapshot.get("effect_counts", {}) as Dictionary).get("spawn_zone", 0)) != 2:
			failures.append("active cap did not recover after expiry cleanup")

	owner.free()
	target.free()

func _assert_invalid_resource_gating(augment_system: Node, upgrade_system: Node, failures: Array[String]) -> void:
	var invalid = AugmentDataScript.new()
	invalid.id = "aug_invalid_runtime"
	invalid.display_name = "Invalid Runtime"
	invalid.route_id = "contract"
	invalid.rarity = "silver"
	var owner := Node.new()
	root.add_child(owner)
	if bool(augment_system.call("acquire_augment", invalid, owner)):
		failures.append("AugmentSystem acquired invalid AugmentData")
	if bool(upgrade_system.call("is_augment_available_for_selection", invalid)):
		failures.append("UpgradeSystem considered invalid AugmentData selectable")
	if bool(upgrade_system.call("apply_augment", invalid, owner)):
		failures.append("UpgradeSystem.apply_augment applied invalid AugmentData")
	var snapshot: Dictionary = augment_system.call("get_runtime_snapshot")
	if int((snapshot.get("ranks", {}) as Dictionary).get("aug_invalid_runtime", 0)) != 0:
		failures.append("invalid AugmentData was tracked in AugmentSystem")
	if int(upgrade_system.call("get_owned_augment_rank", "aug_invalid_runtime")) != 0:
		failures.append("invalid AugmentData was tracked in UpgradeSystem")
	owner.free()

func _assert_all_production_effects_are_handled(registry: Node, effect_runner: Node, failures: Array[String]) -> void:
	var unhandled: Array[String] = []
	for augment in registry.call("get_all"):
		var resource := augment as Resource
		if resource == null:
			continue
		for effect in resource.get("effects"):
			var effect_resource := effect as Resource
			if effect_resource == null:
				continue
			var effect_type := str(effect_resource.get("effect_type"))
			if not bool(effect_runner.call("is_effect_type_handled", effect_type)):
				if not unhandled.has(effect_type):
					unhandled.append(effect_type)
	if not unhandled.is_empty():
		failures.append("production effect types without observable handler: %s" % [unhandled])

func _assert_previously_unhandled_effects(augment_system: Node, failures: Array[String]) -> void:
	augment_system.call("reset")
	var owner := Node.new()
	var target := Node2D.new()
	root.add_child(owner)
	root.add_child(target)
	var synthetic := _make_specific_effect_augment([
		"refund_cooldown",
		"set_pending_next_hit",
		"activate_cooldown_mode",
		"add_stack_on_crit",
	])
	if not bool(augment_system.call("acquire_augment", synthetic, owner)):
		failures.append("failed to acquire previously-unhandled synthetic augment")
		owner.free()
		target.free()
		return
	var packet_tags: Array[String] = ["skill"]
	var packet: Dictionary = root.get_node("DamageSystem").call("make_packet", 8.0, packet_tags, {
		"owner": owner,
		"target": target,
		"cooldown_source_id": "specific_runtime",
		"is_crit": true
	})
	augment_system.call("emit_synthetic_event", "on_hit", packet, {"signal_name": "damage_applied_packet", "owner": owner, "target": target})
	var snapshot: Dictionary = augment_system.call("get_runtime_snapshot")
	for effect_type in ["refund_cooldown", "set_pending_next_hit", "activate_cooldown_mode", "add_stack_on_crit"]:
		if int((snapshot.get("effect_counts", {}) as Dictionary).get(effect_type, 0)) < 1:
			failures.append("previously unhandled effect did not execute: %s" % effect_type)
	if (snapshot.get("runtime_log", []) as Array).any(func(entry): return str((entry as Dictionary).get("event_type", "")) == "safe_unhandled_effect"):
		failures.append("effect runner still recorded safe_unhandled_effect")
	if (snapshot.get("cooldown_refunds", {}) as Dictionary).is_empty():
		failures.append("refund_cooldown did not create observable cooldown state")
	if (snapshot.get("pending_effects", {}) as Dictionary).is_empty():
		failures.append("set_pending_next_hit did not create pending state")
	if (snapshot.get("modes", {}) as Dictionary).is_empty():
		failures.append("activate_cooldown_mode did not create mode state")
	if (snapshot.get("counters", {}) as Dictionary).is_empty():
		failures.append("add_stack_on_crit did not create stack/counter state")
	owner.free()
	target.free()

func _assert_low_hp_defense_burst_observable(registry: Node, augment_system: Node, failures: Array[String]) -> void:
	augment_system.call("reset")
	var owner := Node.new()
	root.add_child(owner)
	var escape_plan := registry.call("get_by_id", "aug_escape_plan") as Resource
	if escape_plan == null:
		failures.append("missing aug_escape_plan for low_hp_defense_burst smoke")
		owner.free()
		return
	if not bool(augment_system.call("acquire_augment", escape_plan, owner)):
		failures.append("failed to acquire aug_escape_plan")
		owner.free()
		return
	var low_hp_tags: Array[String] = ["contact"]
	var packet: Dictionary = root.get_node("DamageSystem").call("make_packet", 4.0, low_hp_tags, {
		"owner": owner,
		"target": owner,
		"health_ratio": 0.25,
		"nearby_enemies": 3,
		"source_kind": "contact",
		"source_id": "low_hp_contract"
	})
	root.get_node("GameEvents").low_hp_entered.emit(owner, 0.25, packet)
	var snapshot: Dictionary = augment_system.call("get_runtime_snapshot")
	if int((snapshot.get("effect_counts", {}) as Dictionary).get("low_hp_defense_burst", 0)) < 1:
		failures.append("low_hp_defense_burst did not execute from low_hp_entered")
	if (snapshot.get("shields", {}) as Dictionary).is_empty():
		failures.append("low_hp_defense_burst did not create observable shield state")
	if (snapshot.get("mobility", {}) as Dictionary).is_empty():
		failures.append("low_hp_defense_burst did not create observable mobility state")
	if int((snapshot.get("controls", {}) as Dictionary).get("knockback", 0)) < 1:
		failures.append("low_hp_defense_burst did not create observable knockback/control state")
	if (snapshot.get("safe_states", {}) as Dictionary).is_empty():
		failures.append("low_hp_defense_burst did not create safe runtime state")
	owner.free()

func _assert_remaining_production_triggers_reachable(registry: Node, augment_system: Node, failures: Array[String]) -> void:
	var game_events := root.get_node("GameEvents")
	var damage_system := root.get_node("DamageSystem")
	var owner := Node.new()
	var target := Node2D.new()
	root.add_child(owner)
	root.add_child(target)

	augment_system.call("reset")
	var big_brain := registry.call("get_by_id", "aug_big_brain_barrier") as Resource
	if big_brain == null:
		failures.append("missing aug_big_brain_barrier")
	else:
		augment_system.call("acquire_augment", big_brain, owner)
		game_events.level_changed.emit(2)
		var wave_tags: Array[String] = ["wave"]
		var wave_packet: Dictionary = damage_system.call("make_packet", 0.0, wave_tags, {
			"owner": owner,
			"level": 2,
			"wave_phase_id": "contract_wave"
		})
		game_events.wave_phase_started.emit("contract_wave", 2, wave_packet)
		var level_snapshot: Dictionary = augment_system.call("get_runtime_snapshot")
		if int((level_snapshot.get("effect_counts", {}) as Dictionary).get("grant_stored_shield", 0)) < 2:
			failures.append("level_changed/wave_phase_started did not reach aug_big_brain_barrier")
		if (level_snapshot.get("shields", {}) as Dictionary).is_empty():
			failures.append("aug_big_brain_barrier did not create shield state")

	augment_system.call("reset")
	var chili_oil := registry.call("get_by_id", "aug_chili_oil") as Resource
	if chili_oil == null:
		failures.append("missing aug_chili_oil")
	else:
		augment_system.call("acquire_augment", chili_oil, owner)
		var burn_tags: Array[String] = ["burn"]
		var burn_packet: Dictionary = damage_system.call("make_packet", 0.0, burn_tags, {
			"target": target,
			"stacks_added": 20,
			"total_stacks": 20,
			"hit_position": Vector2(4.0, 5.0)
		})
		game_events.burn_stack_applied.emit(target, 20, 20, burn_packet)
		var burn_snapshot: Dictionary = augment_system.call("get_runtime_snapshot")
		if int((burn_snapshot.get("effect_counts", {}) as Dictionary).get("counter_on_event", 0)) < 1:
			failures.append("burn_stack_applied did not reach aug_chili_oil counter")
		if int((burn_snapshot.get("effect_counts", {}) as Dictionary).get("spawn_zone", 0)) < 1:
			failures.append("burn_stack_applied did not reach aug_chili_oil zone")

	augment_system.call("reset")
	var void_collapse := registry.call("get_by_id", "aug_void_collapse") as Resource
	if void_collapse == null:
		failures.append("missing aug_void_collapse")
	else:
		augment_system.call("acquire_augment", void_collapse, owner)
		var rift_tags: Array[String] = ["void", "rift"]
		var rift_packet: Dictionary = damage_system.call("make_packet", 0.0, rift_tags, {
			"region_id": "contract_region",
			"chain_count": 3,
			"hit_position": Vector2(7.0, 9.0)
		})
		game_events.rift_chain_triggered.emit("contract_region", 3, rift_packet)
		var rift_snapshot: Dictionary = augment_system.call("get_runtime_snapshot")
		if int((rift_snapshot.get("effect_counts", {}) as Dictionary).get("regional_counter", 0)) < 1:
			failures.append("rift_chain_triggered did not reach aug_void_collapse counter")
		if int((rift_snapshot.get("effect_counts", {}) as Dictionary).get("spawn_delayed_strike", 0)) < 1:
			failures.append("rift_chain_triggered did not reach aug_void_collapse delayed strike")

	owner.free()
	target.free()

func _assert_production_event_bridges(registry: Node, augment_system: Node, failures: Array[String]) -> void:
	var damage_system := root.get_node("DamageSystem")
	var game_events := root.get_node("GameEvents")
	var recorder := _SignalRecorder.new()
	root.add_child(recorder)
	game_events.connect("augment_periodic_tick", recorder._on_periodic)
	game_events.connect("pickup_collected", recorder._on_pickup)
	game_events.connect("boss_damaged", recorder._on_boss_damaged)
	game_events.connect("low_hp_entered", recorder._on_low_hp)
	game_events.connect("fatal_damage_received", recorder._on_fatal)

	root.get_node("GameRuntime").call("start_run")
	if recorder.periodic_count < 1:
		failures.append("GameRuntime did not emit augment_periodic_tick")

	augment_system.call("reset")
	var owner := Node.new()
	var boss := _BossTarget.new()
	root.add_child(owner)
	root.add_child(boss)
	var goldrend := registry.call("get_by_id", "aug_goldrend") as Resource
	if goldrend != null:
		augment_system.call("acquire_augment", goldrend, owner)
		var tags: Array[String] = ["weapon"]
		damage_system.call("apply_damage", boss, 4.0, tags, {"owner": owner, "cooldown_source_id": "bridge_weapon"})
		var snapshot: Dictionary = augment_system.call("get_runtime_snapshot")
		if recorder.boss_damaged_count < 1:
			failures.append("DamageSystem did not emit boss_damaged for boss target")
		if int((snapshot.get("effect_counts", {}) as Dictionary).get("open_gold_window_on_elite_boss_hit", 0)) < 1:
			failures.append("boss_damaged bridge did not reach AugmentSystem")
	else:
		failures.append("missing aug_goldrend for boss bridge smoke")

	augment_system.call("reset")
	var player := Node2D.new()
	root.add_child(player)
	var zhonya := registry.call("get_by_id", "aug_mobile_zhonya") as Resource
	if player == null or zhonya == null:
		failures.append("missing player or aug_mobile_zhonya for low/fatal bridge smoke")
	else:
		augment_system.call("acquire_augment", zhonya, player)
		var low_tags: Array[String] = ["contact"]
		var low_packet: Dictionary = damage_system.call("make_packet", 8.0, low_tags, {
			"owner": player,
			"target": player,
			"health_ratio": 0.25,
			"nearby_enemies": 2
		})
		game_events.low_hp_entered.emit(player, 0.25, low_packet)
		var low_snapshot: Dictionary = augment_system.call("get_runtime_snapshot")
		if recorder.low_hp_count < 1:
			failures.append("low_hp_entered signal was not observed")
		if int((low_snapshot.get("effect_counts", {}) as Dictionary).get("enter_stasis", 0)) < 1:
			failures.append("low_hp_entered bridge did not reach AugmentSystem")
		game_events.fatal_damage_received.emit(player, low_packet)
		if recorder.fatal_count < 1:
			failures.append("fatal_damage_received signal was not observed")
		var pickup := Node2D.new()
		root.add_child(pickup)
		var pickup_tags: Array[String] = ["pickup", "experience"]
		var pickup_packet: Dictionary = damage_system.call("make_packet", 0.0, pickup_tags, {
			"owner": player,
			"source_kind": "pickup",
			"source_id": "experience_pickup"
		})
		game_events.pickup_collected.emit(pickup, player, pickup_packet)
		if recorder.pickup_count < 1:
			failures.append("pickup_collected signal was not observed")
		pickup.free()
	player.free()

	recorder.free()
	if is_instance_valid(owner):
		owner.free()
	if is_instance_valid(boss):
		boss.free()

func _assert_upgrade_system_bridge(registry: Node, upgrade_system: Node, augment_system: Node, failures: Array[String]) -> void:
	augment_system.call("reset")
	upgrade_system.call("reset")
	var owner := Node.new()
	root.add_child(owner)
	var augment := registry.call("get_by_id", "aug_typhoon_split") as Resource
	if augment == null:
		failures.append("missing aug_typhoon_split")
		owner.free()
		return
	if not bool(upgrade_system.call("apply_augment", augment, owner)):
		failures.append("UpgradeSystem.apply_augment failed for valid AugmentData")
	var snapshot: Dictionary = augment_system.call("get_runtime_snapshot")
	if int((snapshot.get("ranks", {}) as Dictionary).get("aug_typhoon_split", 0)) != 1:
		failures.append("UpgradeSystem.apply_augment did not acquire into AugmentSystem")
	if int(upgrade_system.call("get_owned_augment_rank", "aug_typhoon_split")) != 1:
		failures.append("UpgradeSystem selection mirror rank was not preserved")
	owner.free()

func _assert_legacy_upgrade_still_applies(upgrade_system: Node, failures: Array[String]) -> void:
	var run_scene_packed := load(RUN_SCENE_PATH) as PackedScene
	var legacy_damage := load(DAMAGE_UPGRADE_PATH) as Resource
	if run_scene_packed == null or legacy_damage == null or not legacy_damage is UpgradeDataScript:
		failures.append("missing legacy upgrade smoke resources")
		return
	var run_scene := run_scene_packed.instantiate()
	root.add_child(run_scene)
	var player: Variant = run_scene.get_node_or_null("World/Player")
	if player == null:
		failures.append("RunScene missing player for legacy upgrade smoke")
		run_scene.free()
		return
	var before := float(player.damage_multiplier)
	if not bool(upgrade_system.call("apply_upgrade", legacy_damage, player)):
		failures.append("legacy UpgradeData apply_upgrade returned false")
	elif float(player.damage_multiplier) <= before:
		failures.append("legacy UpgradeData did not update player stat")
	run_scene.free()

func _make_synthetic_runtime_augment() -> Resource:
	var augment = AugmentDataScript.new()
	augment.id = "aug_synthetic_runtime"
	augment.display_name = "Synthetic Runtime"
	augment.route_id = "contract"
	augment.route_label = "Contract"
	augment.rarity = "gold"
	augment.max_rank = 1
	augment.unique = true
	augment.upgrade_type = "starter"
	augment.manifest_resource_path = "tests/fixtures/augments/contract/aug_synthetic_runtime.tres"
	augment.test_owner = "augment_runtime_contract.gd"
	augment.trigger_spec = {
		"trigger_id": "on_hit",
		"signal_names": ["damage_applied_packet"],
		"required_packet_keys": ["owner", "target"],
		"synthetic_test": "runtime representative hit",
		"source_cooldown": 1.0,
		"per_target_cooldown": 1.0
	}
	var blueprints: Array[Dictionary] = []
	for effect_type in ["add_dot", "spawn_zone", "spawn_delayed_strike", "spawn_summon", "apply_shield", "heal_player", "apply_control", "progress_quest"]:
		blueprints.append({
			"effect_type": effect_type,
			"effect_family": effect_type,
			"params": {"amount": 3.0, "duration": 1.0, "control_tag": "slow", "total": 2},
			"source_cooldown": 1.0,
			"per_target_cooldown": 1.0,
			"max_proc_depth": 2,
			"blocks_same_family_recursion": true
		})
	augment.effect_spec_blueprint = blueprints
	augment.ensure_runtime_specs_from_blueprint()
	return augment

func _make_specific_effect_augment(effect_types: Array[String]) -> Resource:
	var augment = AugmentDataScript.new()
	augment.id = "aug_specific_runtime"
	augment.display_name = "Specific Runtime"
	augment.route_id = "contract"
	augment.route_label = "Contract"
	augment.rarity = "gold"
	augment.max_rank = 1
	augment.unique = true
	augment.upgrade_type = "starter"
	augment.manifest_resource_path = "tests/fixtures/augments/contract/aug_specific_runtime.tres"
	augment.test_owner = "augment_runtime_contract.gd"
	augment.trigger_spec = {
		"trigger_id": "on_hit",
		"signal_names": ["damage_applied_packet"],
		"required_packet_keys": ["owner", "target"],
		"synthetic_test": "specific runtime event"
	}
	var blueprints: Array[Dictionary] = []
	for effect_type in effect_types:
		blueprints.append({
			"effect_type": effect_type,
			"effect_family": effect_type,
			"params": {"amount": 1.0, "mode": "urf", "stack_tag": "specific", "total": 3},
			"max_proc_depth": 2,
			"blocks_same_family_recursion": true
		})
	augment.effect_spec_blueprint = blueprints
	augment.ensure_runtime_specs_from_blueprint()
	return augment

func _make_active_cap_augment(augment_id: String, active_ttl_seconds: float) -> Resource:
	var augment = AugmentDataScript.new()
	augment.id = augment_id
	augment.display_name = "Active Cap Contract"
	augment.route_id = "contract"
	augment.route_label = "Contract"
	augment.rarity = "gold"
	augment.max_rank = 1
	augment.unique = true
	augment.upgrade_type = "starter"
	augment.manifest_resource_path = "tests/fixtures/augments/contract/%s.tres" % augment_id
	augment.test_owner = "augment_runtime_contract.gd"
	augment.trigger_spec = {
		"trigger_id": "on_hit",
		"signal_names": ["damage_applied_packet"],
		"required_packet_keys": ["owner", "target"],
		"synthetic_test": "active cap contract"
	}
	var blueprints: Array[Dictionary] = [{
		"effect_type": "spawn_zone",
		"effect_family": "spawn_zone",
		"params": {"max_active_per_owner": 1, "active_ttl_seconds": active_ttl_seconds, "amount": 1.0},
		"max_proc_depth": 2,
		"blocks_same_family_recursion": true
	}]
	augment.effect_spec_blueprint = blueprints
	augment.ensure_runtime_specs_from_blueprint()
	return augment

class _SignalRecorder:
	extends Node
	var periodic_count := 0
	var pickup_count := 0
	var boss_damaged_count := 0
	var low_hp_count := 0
	var fatal_count := 0

	func _on_periodic(_elapsed: float) -> void:
		periodic_count += 1

	func _on_pickup(_pickup: Node, _player: Node, _packet: Dictionary) -> void:
		pickup_count += 1

	func _on_boss_damaged(_enemy: Node, _packet: Dictionary) -> void:
		boss_damaged_count += 1

	func _on_low_hp(_player: Node, _ratio: float, _packet: Dictionary) -> void:
		low_hp_count += 1

	func _on_fatal(_player: Node, _packet: Dictionary) -> void:
		fatal_count += 1

class _AugmentSignalRecorder:
	extends Node
	var acquired_count := 0
	var effect_triggered_count := 0
	var state_changed_count := 0
	var last_effect_payload: Dictionary = {}

	func _on_acquired(_augment_id: String, _augment: Resource, _owner: Node, _snapshot: Dictionary) -> void:
		acquired_count += 1

	func _on_effect_triggered(payload: Dictionary) -> void:
		effect_triggered_count += 1
		last_effect_payload = payload.duplicate(true)

	func _on_state_changed(snapshot: Dictionary) -> void:
		state_changed_count += 1
		if not snapshot.has("augment_proc_counts"):
			push_error("augment_state_changed snapshot missing augment_proc_counts")

class _BossTarget:
	extends Node2D
	var total_damage := 0.0

	func apply_damage(amount: float, _tags: Array[String]) -> void:
		total_damage += amount

	func get_enemy_class() -> String:
		return "boss"

func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result

func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("PASS: augment acquisition runtime and generic effect runner contract")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
