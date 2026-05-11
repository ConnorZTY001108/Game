class_name AugmentRouteSmokeHelper
extends RefCounted

const RUN_SCENE_PATH := "res://scenes/run/RunScene.tscn"

static func run_route(tree: SceneTree, route_id: String, covered_ids: Array[String], smoke_name: String) -> Array[String]:
	var failures: Array[String] = []
	var root := tree.root
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
		return failures

	registry.call("reload")
	upgrade_system.call("reset")
	augment_system.call("reset")

	var route_augments: Array = registry.call("get_by_route", route_id)
	_assert_exact_route_load(route_augments, route_id, covered_ids, smoke_name, failures)
	_assert_level_up_panel_displays_route(tree, route_augments, route_id, failures)
	_assert_route_runtime(tree, route_augments, route_id, smoke_name, failures)
	return failures

static func _assert_exact_route_load(route_augments: Array, route_id: String, covered_ids: Array[String], smoke_name: String, failures: Array[String]) -> void:
	if covered_ids.size() != 8:
		failures.append("%s COVERED_AUGMENT_IDS must contain exactly 8 ids, got %d" % [smoke_name, covered_ids.size()])
	var seen := {}
	for augment_id in covered_ids:
		if seen.has(augment_id):
			failures.append("%s duplicate covered id: %s" % [smoke_name, augment_id])
		seen[augment_id] = true
	if route_augments.size() != 8:
		failures.append("%s registry route %s should load exactly 8 augments, got %d" % [smoke_name, route_id, route_augments.size()])
	var loaded_ids: Array[String] = []
	for augment_value in route_augments:
		var augment := augment_value as Resource
		if augment == null:
			failures.append("%s loaded null augment for route %s" % [smoke_name, route_id])
			continue
		var augment_id := str(augment.get("id"))
		loaded_ids.append(augment_id)
		if str(augment.get("route_id")) != route_id:
			failures.append("%s loaded off-route augment %s route=%s" % [smoke_name, augment_id, str(augment.get("route_id"))])
		if str(augment.get("test_owner")) != smoke_name:
			failures.append("%s test_owner mismatch for %s: %s" % [smoke_name, augment_id, str(augment.get("test_owner"))])
	for augment_id in covered_ids:
		if not loaded_ids.has(augment_id):
			failures.append("%s missing covered route augment %s from registry load: %s" % [smoke_name, augment_id, loaded_ids])
	for augment_id in loaded_ids:
		if not covered_ids.has(augment_id):
			failures.append("%s loaded route augment not declared in COVERED_AUGMENT_IDS: %s" % [smoke_name, augment_id])

static func _assert_level_up_panel_displays_route(tree: SceneTree, route_augments: Array, route_id: String, failures: Array[String]) -> void:
	var run_scene_packed := load(RUN_SCENE_PATH) as PackedScene
	if run_scene_packed == null:
		failures.append("failed to load RunScene for LevelUpPanel route smoke: %s" % route_id)
		return
	var run_scene := run_scene_packed.instantiate()
	tree.root.add_child(run_scene)
	var level_panel: Variant = run_scene.get_node_or_null("CanvasLayer/LevelUpPanel")
	if level_panel == null:
		failures.append("RunScene missing LevelUpPanel for route smoke: %s" % route_id)
		run_scene.free()
		return
	for augment_value in route_augments:
		var augment := augment_value as Resource
		if augment == null:
			continue
		level_panel.call("_show_options", _resource_array([augment]))
		var augment_id := str(augment.get("id"))
		if not bool(level_panel.visible):
			failures.append("LevelUpPanel did not become visible for %s" % augment_id)
			continue
		if int(level_panel.current_options.size()) != 1:
			failures.append("LevelUpPanel did not keep one option for %s" % augment_id)
		var text := _first_button_text(level_panel)
		for required in [
			str(augment.get("display_name")),
			str(augment.get("route_id")),
		]:
			if required != "" and not text.contains(required):
				failures.append("LevelUpPanel text for %s missing cue %s: %s" % [augment_id, required, text])
		for forbidden in ["Tags:", "Source:", "Effect:", "Condition:", "Fit:", "Risk:"]:
			if text.contains(forbidden):
				failures.append("LevelUpPanel text for %s contains debug cue %s: %s" % [augment_id, forbidden, text])
		if text.split("\n", false).size() != 4:
			failures.append("LevelUpPanel text for %s should use four player-facing lines: %s" % [augment_id, text])
		var rarity_cue := _rarity_label(str(augment.get("rarity")))
		if rarity_cue != "" and not text.contains(rarity_cue):
			failures.append("LevelUpPanel text for %s missing rarity cue %s: %s" % [augment_id, rarity_cue, text])
	run_scene.free()

static func _assert_route_runtime(tree: SceneTree, route_augments: Array, route_id: String, smoke_name: String, failures: Array[String]) -> void:
	var root := tree.root
	var augment_system := root.get_node("AugmentSystem")
	var upgrade_system := root.get_node("UpgradeSystem")
	var damage_system := root.get_node("DamageSystem")
	var game_events := root.get_node("GameEvents")
	var route_runtime_ids: Array[String] = []
	var route_ui_ids: Array[String] = []
	var route_proc_ids: Array[String] = []
	for augment_value in route_augments:
		var augment := augment_value as Resource
		if augment == null:
			continue
		var augment_id := str(augment.get("id"))
		var owner := Node2D.new()
		owner.name = "%sOwner" % augment_id
		var target := _RouteSmokeTarget.new()
		target.name = "%sTarget" % augment_id
		root.add_child(owner)
		root.add_child(target)
		upgrade_system.call("reset")
		augment_system.call("reset")
		var before := augment_system.call("get_runtime_snapshot") as Dictionary
		if not bool(augment_system.call("acquire_augment", augment, owner, {"smoke": smoke_name, "route_id": route_id})):
			failures.append("%s failed to acquire %s" % [smoke_name, augment_id])
			owner.free()
			target.free()
			continue
		route_ui_ids.append(augment_id)
		if int(augment_system.call("get_owned_augment_rank", augment_id)) < 1:
			failures.append("%s did not track acquired rank for %s" % [smoke_name, augment_id])
		if int(augment_system.call("get_route_count", route_id)) != 1:
			failures.append("%s did not track isolated route count for %s" % [smoke_name, augment_id])
		var trigger_id := _trigger_id(augment)
		var signal_name := _primary_signal_name(augment)
		if signal_name != "augment_acquired":
			var packet := _packet_for_trigger(damage_system, trigger_id, signal_name, owner, target, augment_id)
			_emit_runtime_trigger(game_events, augment_system, signal_name, trigger_id, owner, target, packet)
		var after := augment_system.call("get_runtime_snapshot") as Dictionary
		_assert_every_effect_executed(augment, before, after, smoke_name, failures)
		_assert_every_effect_has_artifact(augment, before, after, smoke_name, failures)
		_assert_generated_packets_safe(augment, before, after, damage_system, smoke_name, failures)
		if _has_runtime_artifact_delta(augment, before, after):
			route_runtime_ids.append(augment_id)
		else:
			failures.append("%s accepted no runtime artifact for %s" % [smoke_name, augment_id])
		if _has_packet_effect(augment):
			_assert_recursion_blocks_packet_effects(augment, augment_system, damage_system, game_events, owner, target, smoke_name, failures)
			route_proc_ids.append(augment_id)
		owner.free()
		target.free()
	if route_runtime_ids.size() != 8:
		failures.append("%s runtime coverage should include 8 augments, got %d: %s" % [smoke_name, route_runtime_ids.size(), route_runtime_ids])
	if route_ui_ids.size() != 8:
		failures.append("%s UI coverage should include 8 augments, got %d: %s" % [smoke_name, route_ui_ids.size(), route_ui_ids])
	if _route_has_packet_effects(route_augments) and route_proc_ids.is_empty():
		failures.append("%s expected proc coverage for packet-producing route %s" % [smoke_name, route_id])

static func _assert_every_effect_executed(augment: Resource, before: Dictionary, after: Dictionary, smoke_name: String, failures: Array[String]) -> void:
	var expected_counts := {}
	for effect_value in augment.get("effects"):
		var effect := effect_value as Resource
		if effect == null:
			continue
		var effect_type := str(effect.get("effect_type"))
		expected_counts[effect_type] = int(expected_counts.get(effect_type, 0)) + 1
	var before_counts: Dictionary = before.get("effect_counts", {})
	var after_counts: Dictionary = after.get("effect_counts", {})
	for effect_type in expected_counts.keys():
		var delta := int(after_counts.get(effect_type, 0)) - int(before_counts.get(effect_type, 0))
		if delta < int(expected_counts[effect_type]):
			failures.append("%s %s did not execute effect %s; delta=%d expected_at_least=%d" % [
				smoke_name,
				str(augment.get("id")),
				effect_type,
				delta,
				int(expected_counts[effect_type])
			])

static func _assert_every_effect_has_artifact(augment: Resource, before: Dictionary, after: Dictionary, smoke_name: String, failures: Array[String]) -> void:
	for effect_value in augment.get("effects"):
		var effect := effect_value as Resource
		if effect == null:
			continue
		var effect_type := str(effect.get("effect_type"))
		var artifact_keys := _artifact_keys_for_effect(effect_type)
		if artifact_keys.is_empty():
			failures.append("%s %s has no route-smoke artifact mapping for effect %s" % [smoke_name, str(augment.get("id")), effect_type])
			continue
		if not _any_snapshot_key_changed(before, after, artifact_keys):
			failures.append("%s %s effect %s only changed effect counters/logs; expected artifact keys %s" % [
				smoke_name,
				str(augment.get("id")),
				effect_type,
				artifact_keys
			])

static func _assert_generated_packets_safe(augment: Resource, before: Dictionary, after: Dictionary, damage_system: Node, smoke_name: String, failures: Array[String]) -> void:
	var before_packets: Array = before.get("generated_packets", [])
	var after_packets: Array = after.get("generated_packets", [])
	if after_packets.size() <= before_packets.size():
		return
	for index in range(before_packets.size(), after_packets.size()):
		var packet := after_packets[index] as Dictionary
		if packet == null:
			failures.append("%s %s generated a non-dictionary packet" % [smoke_name, str(augment.get("id"))])
			continue
		var packet_errors: Array = damage_system.call("validate_packet", packet)
		if not packet_errors.is_empty():
			failures.append("%s %s generated invalid proc packet: %s" % [smoke_name, str(augment.get("id")), packet_errors])
		if str(packet.get("augment_id", "")) != str(augment.get("id")):
			failures.append("%s %s generated packet without owning augment id: %s" % [smoke_name, str(augment.get("id")), packet])
		if int(packet.get("proc_depth", 0)) < 1:
			failures.append("%s %s generated packet without incremented proc_depth: %s" % [smoke_name, str(augment.get("id")), packet])
		if str(packet.get("proc_chain_id", "")) == "":
			failures.append("%s %s generated packet without proc_chain_id" % [smoke_name, str(augment.get("id"))])
		if (packet.get("proc_flags", []) as Array).is_empty():
			failures.append("%s %s generated packet without proc_flags" % [smoke_name, str(augment.get("id"))])

static func _assert_recursion_blocks_packet_effects(augment: Resource, augment_system: Node, damage_system: Node, game_events: Node, owner: Node, target: Node, smoke_name: String, failures: Array[String]) -> void:
	var trigger_id := _trigger_id(augment)
	var signal_name := _primary_signal_name(augment)
	if signal_name == "augment_acquired":
		return
	for effect_value in augment.get("effects"):
		var effect := effect_value as Resource
		if effect == null:
			continue
		var effect_type := str(effect.get("effect_type"))
		if not _effect_generates_packet(effect_type):
			continue
		var family := str(effect.call("get_effect_family")) if effect.has_method("get_effect_family") else effect_type
		augment_system.call("reset")
		if not bool(augment_system.call("acquire_augment", augment, owner, {"smoke": smoke_name, "recursion": true})):
			failures.append("%s failed to acquire %s for recursion check" % [smoke_name, str(augment.get("id"))])
			continue
		var before := augment_system.call("get_runtime_snapshot") as Dictionary
		var packet := _packet_for_trigger(damage_system, trigger_id, signal_name, owner, target, str(augment.get("id")))
		packet["proc_flags"] = [family]
		packet["proc_depth"] = 0
		packet["cooldown_source_id"] = "%s_recursion_%s" % [str(augment.get("id")), family]
		if _signal_lacks_packet_context(signal_name):
			augment_system.call("emit_synthetic_event", trigger_id, packet, {"signal_name": signal_name, "owner": owner, "target": target})
		else:
			_emit_runtime_trigger(game_events, augment_system, signal_name, trigger_id, owner, target, packet)
		var after := augment_system.call("get_runtime_snapshot") as Dictionary
		var before_blocks := int((before.get("blocked_counts", {}) as Dictionary).get("recursion", 0))
		var after_blocks := int((after.get("blocked_counts", {}) as Dictionary).get("recursion", 0))
		if after_blocks <= before_blocks:
			failures.append("%s %s did not record same-family recursion block for %s" % [smoke_name, str(augment.get("id")), family])

static func _packet_for_trigger(damage_system: Node, trigger_id: String, signal_name: String, owner: Node, target: Node, augment_id: String) -> Dictionary:
	var tags: Array[String] = ["projectile", "weapon", "skill", "rune", "element", "fire", "burn", "dot", "void", "rift", "summon", "pickup"]
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
	elif signal_name == "control_applied":
		source_kind = "control"
	elif signal_name == "pickup_collected":
		source_kind = "pickup"
	var payload := {
		"owner": owner,
		"target": target,
		"amount": 16.0,
		"final_amount": 16.0,
		"source_kind": source_kind,
		"source_id": "%s_source" % augment_id,
		"weapon_id": "%s_weapon" % augment_id,
		"weapon_tags": ["projectile", "weapon"],
		"element_tags": ["fire"],
		"cooldown_source_id": "%s_cooldown" % augment_id,
		"hit_position": Vector2(12.0, 8.0),
		"source_position": Vector2.ZERO,
		"distance": 640.0,
		"parent_event_id": "%s_parent" % augment_id,
		"proc_flags": [],
		"on_hit_efficiency": 1.0,
		"can_crit": true,
		"crit_chance": 1.0,
		"crit_multiplier": 1.6,
		"is_crit": trigger_id == "on_crit",
		"dot_tag": "burn",
		"stacks": 8,
		"stacks_added": 8,
		"total_stacks": 8,
		"region_id": "%s_region" % augment_id,
		"chain_count": 4,
		"current_health": 35.0,
		"max_health": 100.0,
		"health_ratio": 0.25,
		"target_health_ratio": 0.05,
		"enemy_class": "elite",
		"target_class": "elite",
		"shield_active": true,
		"recent_heal_seconds": 0.5,
		"control_tag": "slow",
		"ratio": 0.25,
		"nearby_enemies": 4,
		"absorbed_damage_ledger": {"amount": 20.0},
		"spawn_position": Vector2(6.0, 6.0),
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
	var packet := damage_system.call("make_packet", 16.0, tags, payload) as Dictionary
	packet["trigger_id"] = trigger_id
	packet["signal_name"] = signal_name
	return packet

static func _signal_lacks_packet_context(signal_name: String) -> bool:
	return signal_name in ["augment_periodic_tick", "enemy_died", "level_changed"]

static func _emit_runtime_trigger(game_events: Node, augment_system: Node, signal_name: String, trigger_id: String, owner: Node, target: Node, packet: Dictionary) -> void:
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
			game_events.emit_signal("burn_stack_applied", target, int(packet.get("stacks_added", 8)), int(packet.get("total_stacks", 8)), packet)
		"burn_stack_threshold":
			game_events.emit_signal("burn_stack_threshold", target, int(packet.get("stacks", 8)), packet)
		"rift_chain_triggered":
			game_events.emit_signal("rift_chain_triggered", str(packet.get("region_id", "route_region")), int(packet.get("chain_count", 4)), packet)
		"shield_broken":
			game_events.emit_signal("shield_broken", owner, float(packet.get("amount", 16.0)), packet)
		"shield_gained":
			game_events.emit_signal("shield_gained", owner, float(packet.get("amount", 16.0)), packet)
		"heal_received":
			game_events.emit_signal("heal_received", owner, float(packet.get("amount", 16.0)), packet)
		"regen_tick":
			game_events.emit_signal("regen_tick", owner, float(packet.get("amount", 16.0)), packet)
		"low_hp_entered":
			game_events.emit_signal("low_hp_entered", owner, float(packet.get("ratio", 0.25)), packet)
		"fatal_damage_received":
			game_events.emit_signal("fatal_damage_received", owner, packet)
		"control_applied":
			game_events.emit_signal("control_applied", target, str(packet.get("control_tag", "slow")), packet)
		"dash_started":
			game_events.emit_signal("dash_started", owner, packet)
		"dash_finished":
			game_events.emit_signal("dash_finished", owner, packet)
		"blink_used":
			game_events.emit_signal("blink_used", owner, packet)
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
			game_events.emit_signal("augment_periodic_tick", 30.0)
		"enemy_died":
			game_events.emit_signal("enemy_died", target, 1)
		"level_changed":
			game_events.emit_signal("level_changed", 2)
		"wave_phase_started":
			game_events.emit_signal("wave_phase_started", "route_smoke_wave", 2, packet)
		_:
			augment_system.call("emit_synthetic_event", trigger_id, packet, {"signal_name": signal_name, "owner": owner, "target": target})

static func _has_runtime_artifact_delta(augment: Resource, before: Dictionary, after: Dictionary) -> bool:
	for effect_value in augment.get("effects"):
		var effect := effect_value as Resource
		if effect != null and _any_snapshot_key_changed(before, after, _artifact_keys_for_effect(str(effect.get("effect_type")))):
			return true
	return false

static func _any_snapshot_key_changed(before: Dictionary, after: Dictionary, keys: Array[String]) -> bool:
	for key in keys:
		var before_value: Variant = before.get(key, [] if key == "generated_packets" else {})
		var after_value: Variant = after.get(key, [] if key == "generated_packets" else {})
		if before_value is Array and after_value is Array:
			if (after_value as Array).size() > (before_value as Array).size():
				return true
		elif before_value is Dictionary and after_value is Dictionary:
			if _dictionary_score(after_value as Dictionary) > _dictionary_score(before_value as Dictionary):
				return true
		elif str(after_value) != str(before_value):
			return true
	return false

static func _dictionary_score(value: Dictionary) -> int:
	var score := value.size()
	for key in value.keys():
		var entry = value[key]
		if entry is Dictionary:
			score += int((entry as Dictionary).get("amount", 0))
			score += int((entry as Dictionary).get("total", 0))
			score += int((entry as Dictionary).get("complete", false))
		elif entry is int or entry is float:
			score += int(entry)
	return score

static func _artifact_keys_for_effect(effect_type: String) -> Array[String]:
	if effect_type.contains("cooldown") or effect_type.begins_with("refund_"):
		if effect_type == "activate_cooldown_mode":
			return ["modes", "cooldown_refunds"]
		return ["cooldown_refunds"]
	if effect_type == "set_pending_next_hit" or effect_type == "apply_on_hit_package":
		return ["pending_effects"]
	if _is_counter_effect(effect_type):
		return ["counters"]
	if _is_stat_effect(effect_type):
		return ["stat_modifiers"]
	if _is_projectile_effect(effect_type):
		return ["generated_packets", "active_counts"]
	if _is_dot_effect(effect_type):
		return ["generated_packets"]
	if _is_zone_effect(effect_type):
		return ["generated_packets", "active_counts"]
	if _is_delayed_effect(effect_type):
		return ["generated_packets", "active_counts"]
	if _is_summon_effect(effect_type):
		return ["generated_packets", "active_counts"]
	if _is_damage_effect(effect_type):
		return ["generated_packets"]
	if _is_shield_heal_effect(effect_type):
		return ["shields", "heals", "safe_states", "mobility", "controls"]
	if _is_control_mobility_effect(effect_type):
		return ["controls", "mobility", "safe_states"]
	if _is_choice_effect(effect_type):
		return ["choice_state", "rewards"]
	if _is_quest_effect(effect_type):
		return ["quest_progress"]
	if _is_mode_effect(effect_type):
		return ["modes", "safe_states"]
	if _is_safe_state_effect(effect_type):
		return ["safe_states", "shields", "controls"]
	return []

static func _route_has_packet_effects(route_augments: Array) -> bool:
	for augment_value in route_augments:
		var augment := augment_value as Resource
		if augment != null and _has_packet_effect(augment):
			return true
	return false

static func _has_packet_effect(augment: Resource) -> bool:
	for effect_value in augment.get("effects"):
		var effect := effect_value as Resource
		if effect != null and _effect_generates_packet(str(effect.get("effect_type"))):
			return true
	return false

static func _effect_generates_packet(effect_type: String) -> bool:
	return _is_projectile_effect(effect_type) or _is_dot_effect(effect_type) or _is_zone_effect(effect_type) or _is_delayed_effect(effect_type) or _is_summon_effect(effect_type) or _is_damage_effect(effect_type)

static func _is_stat_effect(effect_type: String) -> bool:
	return effect_type.begins_with("modify_") or effect_type.begins_with("convert_") or effect_type in ["enable_crit_sources", "enable_dot_crit", "enable_heal_shield_crit", "scale_summons", "grant_omnivamp", "missing_hp_scaling", "boost_heal_conversion", "skill_hit_speed_buff", "damage_scale_by_speed_delta"]

static func _is_projectile_effect(effect_type: String) -> bool:
	return effect_type.contains("projectile") or effect_type.contains("missile") or effect_type.contains("boomerang") or effect_type.contains("foxfire") or effect_type.contains("shard") or effect_type == "chain_lightning"

static func _is_dot_effect(effect_type: String) -> bool:
	return effect_type.contains("dot") or effect_type.contains("burn") or effect_type.contains("aura") or effect_type == "periodic_self_drain"

static func _is_zone_effect(effect_type: String) -> bool:
	return effect_type.contains("zone") or effect_type.contains("rift") or effect_type.contains("laser") or effect_type.contains("shockwave") or effect_type.contains("pulse")

static func _is_delayed_effect(effect_type: String) -> bool:
	return effect_type.contains("delayed") or effect_type.contains("comet") or effect_type.contains("cluster_strike") or effect_type.contains("orbital") or effect_type == "delayed_fire_beam" or effect_type == "replace_every_nth_on_class"

static func _is_summon_effect(effect_type: String) -> bool:
	return effect_type.contains("summon") or effect_type.contains("poro") or effect_type.contains("minion") or effect_type.contains("soldier")

static func _is_damage_effect(effect_type: String) -> bool:
	return effect_type.contains("damage") or effect_type.contains("execute") or effect_type.contains("explosion") or effect_type.contains("collapse") or effect_type.contains("slash") or effect_type.contains("true") or effect_type.contains("vulnerability") or effect_type == "max_hp_damage" or effect_type == "long_range_bonus_projectile" or effect_type == "mixed_damage_burst" or effect_type == "burn_threshold_explosion"

static func _is_shield_heal_effect(effect_type: String) -> bool:
	return effect_type.contains("shield") or effect_type.contains("heal") or effect_type.contains("regen") or effect_type == "prevent_fatal_damage" or effect_type == "enter_stasis" or effect_type == "low_hp_defense_burst"

static func _is_control_mobility_effect(effect_type: String) -> bool:
	return effect_type.contains("control") or effect_type.contains("dash") or effect_type.contains("blink") or effect_type.contains("slow") or effect_type.contains("stasis") or effect_type.contains("taunt")

static func _is_choice_effect(effect_type: String) -> bool:
	return effect_type.contains("forge") or effect_type.contains("choice") or effect_type.contains("reroll") or effect_type.contains("random_augment") or effect_type.contains("option_count") or effect_type.contains("currency") or effect_type.contains("pickup") or effect_type == "open_gold_window_on_elite_boss_hit"

static func _is_quest_effect(effect_type: String) -> bool:
	return effect_type.contains("quest") or effect_type.contains("progress")

static func _is_counter_effect(effect_type: String) -> bool:
	return effect_type.contains("stack") or effect_type.contains("counter") or effect_type.contains("charge") or effect_type == "dual_stack" or effect_type == "regional_counter" or effect_type == "add_stack_on_crit" or effect_type == "periodic_auto_mark"

static func _is_mode_effect(effect_type: String) -> bool:
	return effect_type.contains("temporary") or effect_type.contains("mode") or effect_type.contains("invulnerable") or effect_type == "elite_kill_stealth" or effect_type == "contact_effect_while_invulnerable"

static func _is_safe_state_effect(effect_type: String) -> bool:
	return effect_type in ["apply_state_at_threshold", "cleanse_control", "control_grants_resists", "control_grants_shield", "grant_stored_shield", "permanent_max_health_on_control", "prevent_fatal_damage", "protection_pulse", "temporary_resists_on_protection"]

static func _trigger_id(augment: Resource) -> String:
	var trigger = augment.get("trigger")
	if trigger != null:
		var value: Variant = trigger.get("trigger_id")
		if typeof(value) != TYPE_NIL and str(value) != "":
			return str(value)
	return str(augment.get("source_trigger"))

static func _primary_signal_name(augment: Resource) -> String:
	var trigger = augment.get("trigger")
	if trigger != null:
		var signals: Array = trigger.get("signal_names")
		if not signals.is_empty():
			return str(signals[0])
	return _trigger_id(augment)

static func _resource_array(values: Array) -> Array[Resource]:
	var result: Array[Resource] = []
	for value in values:
		result.append(value as Resource)
	return result

static func _first_button_text(level_panel: Node) -> String:
	var options_container: Node = level_panel.get_node("Panel/Margin/Content/Options")
	if options_container.get_child_count() <= 0:
		return ""
	var button := options_container.get_child(0) as Button
	return button.text if button != null else ""

static func _rarity_label(value: String) -> String:
	match value:
		"silver":
			return "Silver"
		"gold":
			return "Gold"
		"prismatic":
			return "Prismatic"
		_:
			return value

class _RouteSmokeTarget:
	extends Node2D
	var total_damage := 0.0

	func apply_damage(amount: float, _tags: Array[String]) -> void:
		total_damage += amount

	func get_enemy_class() -> String:
		return "elite"
