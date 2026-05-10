extends SceneTree

const AugmentDataScript := preload("res://data/resources/augment_data.gd")

const EXPECTED_AUGMENT_COUNT := 72
const ACQUISITION_CYCLES := 3
const STRESS_ROUNDS := 8
const STRESS_SIGNALS: Array[String] = [
	"weapon_fired",
	"projectile_hit",
	"damage_applied_packet",
	"damage_roll_requested",
	"dot_tick",
	"burn_stack_applied",
	"burn_stack_threshold",
	"rift_chain_triggered",
	"shield_gained",
	"shield_broken",
	"heal_received",
	"regen_tick",
	"control_applied",
	"dash_started",
	"dash_finished",
	"blink_used",
	"low_hp_entered",
	"fatal_damage_received",
	"pickup_collected",
	"elite_killed",
	"boss_damaged",
	"augment_periodic_tick",
	"enemy_died",
	"level_changed",
	"wave_phase_started",
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var registry := root.get_node_or_null("AugmentRegistry")
	var augment_system := root.get_node_or_null("AugmentSystem")
	var upgrade_system := root.get_node_or_null("UpgradeSystem")
	var damage_system := root.get_node_or_null("DamageSystem")
	var game_events := root.get_node_or_null("GameEvents")
	if registry == null:
		failures.append("AugmentRegistry autoload missing")
	if augment_system == null:
		failures.append("AugmentSystem autoload missing")
	if upgrade_system == null:
		failures.append("UpgradeSystem autoload missing")
	if damage_system == null:
		failures.append("DamageSystem autoload missing")
	if game_events == null:
		failures.append("GameEvents autoload missing")
	if not failures.is_empty():
		_finish(failures)
		return

	registry.call("reload")
	var augments: Array = registry.call("get_all")
	if augments.size() != EXPECTED_AUGMENT_COUNT:
		failures.append("expected %d production augments, got %d" % [EXPECTED_AUGMENT_COUNT, augments.size()])
		_finish(failures)
		return

	_assert_repeated_all_acquisition(augments, augment_system, failures)
	_assert_duplicate_rank_and_passive_bounds(augments, augment_system, failures)
	_assert_invalid_resource_gating(augment_system, failures)
	_assert_high_density_event_stress(augments, augment_system, upgrade_system, damage_system, game_events, failures)
	_assert_same_family_recursion_blocks(augments, augment_system, damage_system, game_events, failures)
	_assert_active_release_and_expiry_after_density(augments, augment_system, damage_system, game_events, failures)
	_assert_choice_and_high_risk_guards(upgrade_system, failures)
	_assert_boss_scalar_policy(augments, augment_system, damage_system, game_events, failures)

	_finish(failures)

func _assert_repeated_all_acquisition(augments: Array, augment_system: Node, failures: Array[String]) -> void:
	for cycle in range(ACQUISITION_CYCLES):
		augment_system.call("reset")
		var owner := Node2D.new()
		owner.name = "StressAcquireOwner%d" % cycle
		root.add_child(owner)
		var acquired := 0
		for augment_value in augments:
			var augment := augment_value as Resource
			if augment == null:
				continue
			if bool(augment_system.call("acquire_augment", augment, owner, {"stress_cycle": cycle})):
				acquired += 1
		var snapshot: Dictionary = augment_system.call("get_runtime_snapshot")
		if acquired != EXPECTED_AUGMENT_COUNT:
			failures.append("cycle %d acquired %d/%d augments" % [cycle, acquired, EXPECTED_AUGMENT_COUNT])
		if (snapshot.get("owned_ids", []) as Array).size() != EXPECTED_AUGMENT_COUNT:
			failures.append("cycle %d owned id count is not 72: %s" % [cycle, snapshot.get("owned_ids", [])])
		var route_counts: Dictionary = snapshot.get("route_counts", {})
		if route_counts.size() != 9:
			failures.append("cycle %d route count dictionary should contain 9 routes, got %d" % [cycle, route_counts.size()])
		for route_id in route_counts.keys():
			if int(route_counts[route_id]) != 8:
				failures.append("cycle %d route %s acquired %d augments, expected 8" % [cycle, str(route_id), int(route_counts[route_id])])
		owner.free()

func _assert_duplicate_rank_and_passive_bounds(augments: Array, augment_system: Node, failures: Array[String]) -> void:
	augment_system.call("reset")
	var owner := Node2D.new()
	owner.name = "StressDuplicateOwner"
	root.add_child(owner)
	for augment_value in augments:
		var augment := augment_value as Resource
		if augment != null and not bool(augment_system.call("acquire_augment", augment, owner, {"duplicate_pass": "initial"})):
			failures.append("initial duplicate-bound acquisition failed for %s" % str(augment.get("id")))
	for augment_value in augments:
		var augment := augment_value as Resource
		if augment == null:
			continue
		var augment_id := str(augment.get("id"))
		var before_rank := int(augment_system.call("get_owned_augment_rank", augment_id))
		var accepted := bool(augment_system.call("acquire_augment", augment, owner, {"duplicate_pass": "second"}))
		var after_rank := int(augment_system.call("get_owned_augment_rank", augment_id))
		var max_rank := int(augment.get("max_rank"))
		if bool(augment.get("unique")) and accepted:
			failures.append("unique augment accepted duplicate acquisition: %s" % augment_id)
		if max_rank > 0 and after_rank > max_rank:
			failures.append("augment rank exceeded max_rank for %s: %d > %d" % [augment_id, after_rank, max_rank])
		if after_rank < before_rank:
			failures.append("augment rank regressed for %s: %d -> %d" % [augment_id, before_rank, after_rank])
	var snapshot: Dictionary = augment_system.call("get_runtime_snapshot")
	var ranks: Dictionary = snapshot.get("ranks", {})
	if ranks.size() != EXPECTED_AUGMENT_COUNT:
		failures.append("duplicate-bound rank dictionary lost augment ids: %d" % ranks.size())
	_assert_stat_sources_within_rank_bounds(augments, snapshot, failures)
	owner.free()

func _assert_stat_sources_within_rank_bounds(augments: Array, snapshot: Dictionary, failures: Array[String]) -> void:
	var ranks: Dictionary = snapshot.get("ranks", {})
	var stat_modifiers: Dictionary = snapshot.get("stat_modifiers", {})
	var max_by_id := {}
	for augment_value in augments:
		var augment := augment_value as Resource
		if augment == null:
			continue
		var max_rank := int(augment.get("max_rank"))
		max_by_id[str(augment.get("id"))] = max_rank if max_rank > 0 else 1
	for stat_key in stat_modifiers.keys():
		var entry: Dictionary = stat_modifiers.get(stat_key, {})
		var sources: Dictionary = entry.get("sources", {})
		for source_id in sources.keys():
			var rank := int(ranks.get(source_id, 0))
			var max_rank := int(max_by_id.get(source_id, 1))
			if rank > max_rank:
				failures.append("passive source %s for stat %s stacked beyond rank bound: %d > %d" % [str(source_id), str(stat_key), rank, max_rank])

func _assert_invalid_resource_gating(augment_system: Node, failures: Array[String]) -> void:
	augment_system.call("reset")
	var owner := Node2D.new()
	owner.name = "StressInvalidOwner"
	root.add_child(owner)
	var invalid = AugmentDataScript.new()
	invalid.id = "aug_invalid_high_density"
	invalid.display_name = "Invalid High Density"
	invalid.route_id = "stress"
	invalid.rarity = "silver"
	if bool(augment_system.call("acquire_augment", invalid, owner)):
		failures.append("invalid in-memory AugmentData was acquired during stress")
	var snapshot: Dictionary = augment_system.call("get_runtime_snapshot")
	if int((snapshot.get("ranks", {}) as Dictionary).get("aug_invalid_high_density", 0)) != 0:
		failures.append("invalid in-memory AugmentData polluted ranks")
	if int((snapshot.get("blocked_counts", {}) as Dictionary).get("invalid_augment", 0)) < 1:
		failures.append("invalid in-memory AugmentData did not record invalid_augment block")
	owner.free()

func _assert_high_density_event_stress(augments: Array, augment_system: Node, upgrade_system: Node, damage_system: Node, game_events: Node, failures: Array[String]) -> void:
	upgrade_system.call("reset")
	augment_system.call("reset")
	var owner := Node2D.new()
	owner.name = "StressOwner"
	var target := _StressTarget.new()
	target.name = "StressTarget"
	var boss := _BossTarget.new()
	boss.name = "StressBoss"
	root.add_child(owner)
	root.add_child(target)
	root.add_child(boss)
	for augment_value in augments:
		var augment := augment_value as Resource
		if augment != null and not bool(augment_system.call("acquire_augment", augment, owner, {"stress": "high_density"})):
			failures.append("high-density acquisition failed for %s" % str(augment.get("id")))
	for round_index in range(STRESS_ROUNDS):
		for signal_name in STRESS_SIGNALS:
			var event_target: Node = boss if signal_name == "boss_damaged" else target
			var packet := _packet_for_signal(damage_system, signal_name, owner, event_target, round_index, "density")
			_emit_runtime_trigger(game_events, augment_system, signal_name, owner, event_target, packet)
	var snapshot: Dictionary = augment_system.call("get_runtime_snapshot")
	_assert_density_snapshot_bounds(snapshot, damage_system, failures)
	_assert_effect_volume(snapshot, failures)
	_assert_active_counts_bounded(snapshot, failures)
	owner.free()
	target.free()
	boss.free()

func _assert_density_snapshot_bounds(snapshot: Dictionary, damage_system: Node, failures: Array[String]) -> void:
	var generated_packets: Array = snapshot.get("generated_packets", [])
	if generated_packets.is_empty():
		failures.append("high-density stress produced no generated packets")
	if generated_packets.size() > 32:
		failures.append("generated packet ring buffer grew beyond 32: %d" % generated_packets.size())
	var runtime_log: Array = snapshot.get("runtime_log", [])
	if runtime_log.size() > 96:
		failures.append("runtime log grew beyond 96: %d" % runtime_log.size())
	for packet_value in generated_packets:
		var packet := packet_value as Dictionary
		if packet == null:
			failures.append("generated packet is not a Dictionary")
			continue
		var packet_errors: Array = damage_system.call("validate_packet", packet)
		if not packet_errors.is_empty():
			failures.append("high-density generated invalid packet: %s" % [packet_errors])
		if int(packet.get("proc_depth", 0)) < 1 or int(packet.get("proc_depth", 0)) > 2:
			failures.append("generated packet proc_depth out of bounded range: %s" % [packet])
		if str(packet.get("proc_chain_id", "")) == "":
			failures.append("generated packet missing proc_chain_id")
		if (packet.get("proc_flags", []) as Array).is_empty():
			failures.append("generated packet missing proc_flags")
		if not _allowed_generated_source_kind(str(packet.get("source_kind", ""))):
			failures.append("generated packet has unexpected source_kind: %s" % str(packet.get("source_kind", "")))

func _assert_effect_volume(snapshot: Dictionary, failures: Array[String]) -> void:
	var effect_counts: Dictionary = snapshot.get("effect_counts", {})
	var total_effects := 0
	for key in effect_counts.keys():
		total_effects += int(effect_counts[key])
	if total_effects < 250:
		failures.append("high-density stress executed too few effect applications: %d" % total_effects)
	var blocked_counts: Dictionary = snapshot.get("blocked_counts", {})
	var total_blocks := 0
	for key in blocked_counts.keys():
		total_blocks += int(blocked_counts[key])
	if total_blocks < 1:
		failures.append("high-density stress did not exercise any guard/block path")

func _assert_active_counts_bounded(snapshot: Dictionary, failures: Array[String]) -> void:
	var active_counts: Dictionary = snapshot.get("active_counts", {})
	var caps := {
		"projectile": EXPECTED_AUGMENT_COUNT * 48,
		"zone": EXPECTED_AUGMENT_COUNT * 12,
		"summon": EXPECTED_AUGMENT_COUNT * 16,
		"delayed_strike": EXPECTED_AUGMENT_COUNT * 10,
	}
	for key in caps.keys():
		var value := int(active_counts.get(key, 0))
		if value < 0:
			failures.append("active count went negative for %s: %d" % [str(key), value])
		if value > int(caps[key]):
			failures.append("active count exceeded aggregate cap for %s: %d > %d" % [str(key), value, int(caps[key])])
	var ledgers: Dictionary = snapshot.get("active_ledgers", {})
	var active_total := 0
	for key in caps.keys():
		active_total += int(active_counts.get(key, 0))
	if ledgers.size() > active_total:
		failures.append("active ledger count exceeded aggregate active counts: %d > %d" % [ledgers.size(), active_total])

func _assert_same_family_recursion_blocks(augments: Array, augment_system: Node, damage_system: Node, game_events: Node, failures: Array[String]) -> void:
	augment_system.call("reset")
	var owner := Node2D.new()
	owner.name = "StressRecursionOwner"
	var target := _StressTarget.new()
	target.name = "StressRecursionTarget"
	root.add_child(owner)
	root.add_child(target)
	for augment_value in augments:
		var augment := augment_value as Resource
		if augment != null:
			augment_system.call("acquire_augment", augment, owner, {"stress": "recursion"})
	var packet_families := _packet_effect_families(augments)
	if packet_families.is_empty():
		failures.append("no packet effect families were found for recursion stress")
		owner.free()
		target.free()
		return
	var before: Dictionary = augment_system.call("get_runtime_snapshot")
	for signal_name in ["weapon_fired", "projectile_hit", "damage_applied_packet", "dot_tick", "burn_stack_threshold", "rift_chain_triggered", "augment_periodic_tick", "boss_damaged"]:
		var packet := _packet_for_signal(damage_system, signal_name, owner, target, STRESS_ROUNDS + packet_families.size(), "recursion")
		packet["proc_flags"] = packet_families.duplicate()
		packet["proc_depth"] = 0
		packet["cooldown_source_id"] = "recursion_%s" % signal_name
		_emit_runtime_trigger(game_events, augment_system, signal_name, owner, target, packet)
	var after: Dictionary = augment_system.call("get_runtime_snapshot")
	var before_recursion := int((before.get("blocked_counts", {}) as Dictionary).get("recursion", 0))
	var after_recursion := int((after.get("blocked_counts", {}) as Dictionary).get("recursion", 0))
	if after_recursion <= before_recursion:
		failures.append("same-family recursion stress did not record recursion blocks")
	var before_packets: Array = before.get("generated_packets", [])
	var after_packets: Array = after.get("generated_packets", [])
	if after_packets.size() > before_packets.size() and after_packets.size() > 32:
		failures.append("recursion-block stress grew generated packet buffer beyond cap")
	owner.free()
	target.free()

func _assert_active_release_and_expiry_after_density(augments: Array, augment_system: Node, damage_system: Node, game_events: Node, failures: Array[String]) -> void:
	augment_system.call("reset")
	var owner := Node2D.new()
	owner.name = "StressCleanupOwner"
	var target := _StressTarget.new()
	target.name = "StressCleanupTarget"
	root.add_child(owner)
	root.add_child(target)
	for augment_value in augments:
		var augment := augment_value as Resource
		if augment != null:
			augment_system.call("acquire_augment", augment, owner, {"stress": "cleanup"})
	for index in range(12):
		var packet := _packet_for_signal(damage_system, "damage_applied_packet", owner, target, index, "cleanup")
		_emit_runtime_trigger(game_events, augment_system, "damage_applied_packet", owner, target, packet)
	var before: Dictionary = augment_system.call("get_runtime_snapshot")
	var ledgers: Dictionary = before.get("active_ledgers", {})
	if ledgers.is_empty():
		failures.append("cleanup stress did not create active ledgers")
	else:
		var first_entry := ledgers[ledgers.keys()[0]] as Dictionary
		var kind := str(first_entry.get("kind", ""))
		var augment_id := str(first_entry.get("augment_id", ""))
		var before_kind_count := int((before.get("active_counts", {}) as Dictionary).get(kind, 0))
		augment_system.call("release_active_effect", kind, augment_id, 1)
		var released: Dictionary = augment_system.call("get_runtime_snapshot")
		var after_kind_count := int((released.get("active_counts", {}) as Dictionary).get(kind, 0))
		if after_kind_count >= before_kind_count:
			failures.append("explicit active release did not reduce %s count: %d -> %d" % [kind, before_kind_count, after_kind_count])
	augment_system.call("cleanup_active_effects", 1000000.0)
	var expired: Dictionary = augment_system.call("get_runtime_snapshot")
	if not (expired.get("active_ledgers", {}) as Dictionary).is_empty():
		failures.append("expiry cleanup did not clear all active ledgers after density")
	for key in ["projectile", "zone", "summon", "delayed_strike"]:
		if int((expired.get("active_counts", {}) as Dictionary).get(key, 0)) != 0:
			failures.append("expiry cleanup left active count for %s: %d" % [key, int((expired.get("active_counts", {}) as Dictionary).get(key, 0))])
	owner.free()
	target.free()

func _assert_choice_and_high_risk_guards(upgrade_system: Node, failures: Array[String]) -> void:
	var owner := Node2D.new()
	owner.name = "StressChoiceOwner"
	root.add_child(owner)
	upgrade_system.call("reset")
	for index in range(40):
		upgrade_system.call("set_next_choice_refresh_per_slot", 1)
		var options: Array = upgrade_system.call("generate_augment_options", {"rng_seed": 2000 + index, "upgrade_index": (index % 12) + 1})
		if options.size() > 3:
			failures.append("augment option roll returned more than three choices: %d" % options.size())
		if (upgrade_system.call("get_active_choice_ids") as Array).size() > 3:
			failures.append("active choice ids grew beyond three")
		if int(upgrade_system.call("get_pending_next_choice_refresh_per_slot")) != 0:
			failures.append("pending next-choice refresh leaked after offer generation")
		if int(upgrade_system.call("get_last_consumed_next_choice_refresh_per_slot")) != 1:
			failures.append("next-choice refresh was not consumed for roll %d" % index)
		if _count_high_risk(options) > 1:
			failures.append("high-risk guard allowed multiple high-risk options in one offer")
		if ((index % 12) + 1) <= 3 and _count_high_risk(options) > 1:
			failures.append("early high-risk guard allowed multiple high-risk options")
		if not options.is_empty():
			upgrade_system.call("apply_augment", options[0], owner)
			if not (upgrade_system.call("get_active_choice_ids") as Array).is_empty():
				failures.append("active choice ids were not cleared after applying an augment")
	upgrade_system.call("reset")
	owner.free()

func _assert_boss_scalar_policy(augments: Array, augment_system: Node, damage_system: Node, game_events: Node, failures: Array[String]) -> void:
	augment_system.call("reset")
	var owner := Node2D.new()
	owner.name = "StressBossOwner"
	var boss := _BossTarget.new()
	boss.name = "StressBossTarget"
	root.add_child(owner)
	root.add_child(boss)
	for augment_value in augments:
		var augment := augment_value as Resource
		if augment != null:
			augment_system.call("acquire_augment", augment, owner, {"stress": "boss_scalar"})
	for index in range(4):
		for signal_name in ["damage_applied_packet", "boss_damaged", "rift_chain_triggered", "augment_periodic_tick"]:
			var packet := _packet_for_signal(damage_system, signal_name, owner, boss, 300 + index, "boss")
			packet["target_class"] = "boss"
			packet["enemy_class"] = "boss"
			packet["target_health_ratio"] = 0.05
			packet["tags"] = _merge_string_arrays([packet.get("tags", []), ["true_damage", "max_hp", "skill", "void", "rift"]])
			packet["source_kind"] = "skill"
			packet["cooldown_source_id"] = "boss_scalar_%s_%d" % [signal_name, index]
			_emit_runtime_trigger(game_events, augment_system, signal_name, owner, boss, packet)
	var snapshot: Dictionary = augment_system.call("get_runtime_snapshot")
	var seen_boss_policy_packet := false
	for packet_value in snapshot.get("generated_packets", []):
		var packet := packet_value as Dictionary
		if packet == null or str(packet.get("target_class", "")) != "boss":
			continue
		var effect_type := str(packet.get("augment_effect_type", ""))
		var damage_type := str(packet.get("damage_type", ""))
		if damage_type == "true" or effect_type == "max_hp_damage" or effect_type.contains("true"):
			seen_boss_policy_packet = true
			var scalar := float(packet.get("boss_scalar", 1.0))
			if scalar <= 0.0 or scalar > 0.4:
				failures.append("boss true/max-hp generated packet has unbounded boss_scalar %.3f: %s" % [scalar, packet])
	if not seen_boss_policy_packet:
		failures.append("boss scalar stress did not observe a boss true/max-hp generated packet")
	owner.free()
	boss.free()

func _packet_for_signal(damage_system: Node, signal_name: String, owner: Node, target: Node, index: int, label: String) -> Dictionary:
	var tags: Array[String] = ["projectile", "weapon", "skill", "rune", "element", "fire", "burn", "dot", "void", "rift", "summon", "pickup", "damage_build", "crit_chance"]
	var source_kind := "skill"
	if signal_name == "weapon_fired":
		source_kind = "weapon"
	elif signal_name == "projectile_hit":
		source_kind = "projectile"
	elif signal_name == "dot_tick":
		source_kind = "dot"
	elif signal_name in ["shield_gained", "shield_broken"]:
		source_kind = "shield"
	elif signal_name in ["heal_received", "regen_tick"]:
		source_kind = "heal"
	elif signal_name == "pickup_collected":
		source_kind = "pickup"
	var payload := {
		"owner": owner,
		"target": target,
		"amount": 18.0 + float(index % 5),
		"final_amount": 18.0 + float(index % 5),
		"source_kind": source_kind,
		"source_id": "%s_%s_source" % [label, signal_name],
		"weapon_id": "%s_weapon" % label,
		"weapon_tags": ["projectile", "weapon"],
		"element_tags": ["fire"],
		"cooldown_source_id": "%s_%s_%d" % [label, signal_name, index],
		"hit_position": Vector2(float(index % 17), float(index % 11)),
		"source_position": Vector2.ZERO,
		"distance": 720.0,
		"parent_event_id": "%s_parent_%s_%d" % [label, signal_name, index],
		"proc_flags": [],
		"on_hit_efficiency": 1.0,
		"can_crit": true,
		"crit_chance": 1.0,
		"crit_multiplier": 1.6,
		"is_crit": true,
		"dot_tag": "burn",
		"stacks": 12,
		"stacks_added": 12,
		"total_stacks": 12,
		"region_id": "%s_region_%d" % [label, index],
		"chain_count": 4,
		"current_health": 20.0,
		"max_health": 100.0,
		"health_ratio": 0.20,
		"target_health_ratio": 0.05,
		"enemy_class": "elite",
		"target_class": "elite",
		"shield_active": true,
		"recent_heal_seconds": 0.25,
		"control_tag": "slow",
		"ratio": 0.20,
		"nearby_enemies": 12,
		"absorbed_damage_ledger": {"amount": 30.0},
		"spawn_position": Vector2(4.0, 6.0),
		"pickup_cap": 2,
		"bounce_count": 0,
		"pending_next_hit_state": {},
		"progress_state": {},
		"once_per_run_state": {},
		"stasis_cooldown": 0.0,
		"incoming_packet": {},
		"cooldown_state": {},
		"selection_state": {},
		"stat_snapshot": {},
		"window_state": {},
		"kill_count": 600,
		"elite_count": 6,
		"cast_count": 1,
	}
	var packet := damage_system.call("make_packet", float(payload["amount"]), tags, payload) as Dictionary
	packet["trigger_id"] = signal_name
	packet["signal_name"] = signal_name
	return packet

func _emit_runtime_trigger(game_events: Node, augment_system: Node, signal_name: String, owner: Node, target: Node, packet: Dictionary) -> void:
	match signal_name:
		"weapon_fired":
			game_events.emit_signal("weapon_fired", owner, null, packet)
		"projectile_hit":
			game_events.emit_signal("projectile_hit", target, packet)
		"damage_applied_packet":
			game_events.emit_signal("damage_applied_packet", target, packet)
		"damage_roll_requested":
			game_events.emit_signal("damage_roll_requested", packet)
		"dot_tick":
			game_events.emit_signal("dot_tick", target, packet)
		"burn_stack_applied":
			game_events.emit_signal("burn_stack_applied", target, int(packet.get("stacks_added", 12)), int(packet.get("total_stacks", 12)), packet)
		"burn_stack_threshold":
			game_events.emit_signal("burn_stack_threshold", target, int(packet.get("stacks", 12)), packet)
		"rift_chain_triggered":
			game_events.emit_signal("rift_chain_triggered", str(packet.get("region_id", "stress_region")), int(packet.get("chain_count", 4)), packet)
		"shield_gained":
			game_events.emit_signal("shield_gained", owner, float(packet.get("amount", 18.0)), packet)
		"shield_broken":
			game_events.emit_signal("shield_broken", owner, float(packet.get("amount", 18.0)), packet)
		"heal_received":
			game_events.emit_signal("heal_received", owner, float(packet.get("amount", 18.0)), packet)
		"regen_tick":
			game_events.emit_signal("regen_tick", owner, float(packet.get("amount", 18.0)), packet)
		"control_applied":
			game_events.emit_signal("control_applied", target, str(packet.get("control_tag", "slow")), packet)
		"dash_started":
			game_events.emit_signal("dash_started", owner, packet)
		"dash_finished":
			game_events.emit_signal("dash_finished", owner, packet)
		"blink_used":
			game_events.emit_signal("blink_used", owner, packet)
		"low_hp_entered":
			game_events.emit_signal("low_hp_entered", owner, float(packet.get("ratio", 0.20)), packet)
		"fatal_damage_received":
			game_events.emit_signal("fatal_damage_received", owner, packet)
		"pickup_collected":
			var pickup := Node2D.new()
			owner.add_child(pickup)
			game_events.emit_signal("pickup_collected", pickup, owner, packet)
			pickup.free()
		"elite_killed":
			game_events.emit_signal("elite_killed", target, packet)
		"boss_damaged":
			game_events.emit_signal("boss_damaged", target, packet)
		"augment_periodic_tick":
			augment_system.call("emit_synthetic_event", "augment_periodic_tick", packet, {"signal_name": "augment_periodic_tick", "owner": owner, "target": target})
		"enemy_died":
			game_events.emit_signal("enemy_died", target, 1)
		"level_changed":
			game_events.emit_signal("level_changed", 2)
		"wave_phase_started":
			game_events.emit_signal("wave_phase_started", "stress_wave", 2, packet)
		_:
			augment_system.call("emit_synthetic_event", signal_name, packet, {"signal_name": signal_name, "owner": owner, "target": target})

func _packet_effect_families(augments: Array) -> Array[String]:
	var families: Array[String] = []
	for augment_value in augments:
		var augment := augment_value as Resource
		if augment == null:
			continue
		for effect_value in augment.get("effects"):
			var effect := effect_value as Resource
			if effect == null:
				continue
			var effect_type := str(effect.get("effect_type"))
			if not _effect_generates_packet(effect_type):
				continue
			var family := str(effect.call("get_effect_family")) if effect.has_method("get_effect_family") else effect_type
			if family != "" and not families.has(family):
				families.append(family)
	return families

func _effect_generates_packet(effect_type: String) -> bool:
	return _is_projectile_effect(effect_type) or _is_dot_effect(effect_type) or _is_zone_effect(effect_type) or _is_delayed_effect(effect_type) or _is_summon_effect(effect_type) or _is_damage_effect(effect_type)

func _is_projectile_effect(effect_type: String) -> bool:
	return effect_type.contains("projectile") or effect_type.contains("missile") or effect_type.contains("boomerang") or effect_type.contains("foxfire") or effect_type.contains("shard") or effect_type == "chain_lightning"

func _is_dot_effect(effect_type: String) -> bool:
	return effect_type.contains("dot") or effect_type.contains("burn") or effect_type.contains("aura") or effect_type == "periodic_self_drain"

func _is_zone_effect(effect_type: String) -> bool:
	return effect_type.contains("zone") or effect_type.contains("rift") or effect_type.contains("laser") or effect_type.contains("shockwave") or effect_type.contains("pulse")

func _is_delayed_effect(effect_type: String) -> bool:
	return effect_type.contains("delayed") or effect_type.contains("comet") or effect_type.contains("cluster_strike") or effect_type.contains("orbital") or effect_type == "delayed_fire_beam" or effect_type == "replace_every_nth_on_class"

func _is_summon_effect(effect_type: String) -> bool:
	return effect_type.contains("summon") or effect_type.contains("poro") or effect_type.contains("minion") or effect_type.contains("soldier")

func _is_damage_effect(effect_type: String) -> bool:
	return effect_type.contains("damage") or effect_type.contains("execute") or effect_type.contains("explosion") or effect_type.contains("collapse") or effect_type.contains("slash") or effect_type.contains("true") or effect_type.contains("vulnerability") or effect_type == "max_hp_damage" or effect_type == "long_range_bonus_projectile" or effect_type == "mixed_damage_burst" or effect_type == "burn_threshold_explosion"

func _allowed_generated_source_kind(source_kind: String) -> bool:
	return source_kind in ["augment", "dot", "summon", "zone", "delayed_strike"]

func _count_high_risk(options: Array) -> int:
	var count := 0
	for option in options:
		if option is Resource and _manifest_bool(option as Resource, "is_high_risk"):
			count += 1
	return count

func _manifest_bool(resource: Resource, key: String) -> bool:
	if resource == null:
		return false
	var manifest: Variant = resource.get("manifest_fields")
	if manifest is Dictionary:
		return bool((manifest as Dictionary).get(key, false))
	return false

func _merge_string_arrays(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		if value is PackedStringArray:
			for item in value:
				if str(item) != "" and not result.has(str(item)):
					result.append(str(item))
		elif value is Array:
			for item in value:
				if str(item) != "" and not result.has(str(item)):
					result.append(str(item))
		elif value is String and str(value) != "":
			if not result.has(str(value)):
				result.append(str(value))
	return result

func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("PASS: augment high-density proc stress, cleanup, and guardrail contract")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

class _StressTarget:
	extends Node2D
	var total_damage := 0.0

	func apply_damage(amount: float, _tags: Array[String]) -> void:
		total_damage += amount

	func get_enemy_class() -> String:
		return "elite"

class _BossTarget:
	extends Node2D
	var total_damage := 0.0

	func apply_damage(amount: float, _tags: Array[String]) -> void:
		total_damage += amount

	func get_enemy_class() -> String:
		return "boss"
