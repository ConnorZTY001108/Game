extends SceneTree

const AugmentDataScript := preload("res://data/resources/augment_data.gd")

const RUN_SCENE_PATH := "res://scenes/run/RunScene.tscn"

const EXPECTED_MVP20_IDS := [
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
	upgrade_system.call("reset")
	augment_system.call("reset")

	var mvp20 := _mvp20_from_checkpoint_priority(registry, failures)
	_assert_route_and_rarity_checkpoint_shape(mvp20, failures)
	_assert_level_up_panel_displays_mvp20(mvp20, failures)
	_assert_selection_bridge_acquires_mvp20(mvp20, upgrade_system, augment_system, failures)
	_assert_mvp20_runtime_triggers(mvp20, augment_system, damage_system, game_events, failures)
	_assert_mobile_zhonya_fatal_path(registry, augment_system, damage_system, game_events, failures)

	_finish(failures)

func _mvp20_from_checkpoint_priority(registry: Node, failures: Array[String]) -> Array[Resource]:
	var mvp20: Array[Resource] = []
	var seen := {}
	var all_augments: Array = registry.call("get_all")
	if all_augments.size() != 72:
		failures.append("registry should still load all 72 augments, got %d" % all_augments.size())
	for augment_value in all_augments:
		var augment := augment_value as Resource
		if augment == null:
			continue
		var priority := int(augment.get("checkpoint_priority"))
		if priority <= 0:
			continue
		var augment_id := str(augment.get("id"))
		if seen.has(augment_id):
			failures.append("duplicate MVP20 checkpoint id: %s" % augment_id)
		seen[augment_id] = true
		mvp20.append(augment)
	mvp20.sort_custom(func(a: Resource, b: Resource) -> bool:
		return int(a.get("checkpoint_priority")) < int(b.get("checkpoint_priority"))
	)
	var ids := _resource_ids(mvp20)
	if ids.size() != 20:
		failures.append("checkpoint_priority > 0 should contain exactly 20 unique ids, got %d: %s" % [ids.size(), ids])
	if ids != EXPECTED_MVP20_IDS:
		failures.append("MVP20 checkpoint order mismatch. expected=%s actual=%s" % [EXPECTED_MVP20_IDS, ids])
	return mvp20

func _assert_route_and_rarity_checkpoint_shape(mvp20: Array[Resource], failures: Array[String]) -> void:
	var routes := {}
	var rarities := {}
	for augment in mvp20:
		routes[str(augment.get("route_id"))] = true
		rarities[str(augment.get("rarity"))] = true
	for required_route in ["rune_volley", "inferno_conduit", "void_cascade", "aegis_transmutation", "blood_reaver", "quest_forge"]:
		if not routes.has(required_route):
			failures.append("MVP20 route coverage missing %s" % required_route)
	for required_rarity in ["silver", "gold", "prismatic"]:
		if not rarities.has(required_rarity):
			failures.append("MVP20 rarity coverage missing %s" % required_rarity)

func _assert_level_up_panel_displays_mvp20(mvp20: Array[Resource], failures: Array[String]) -> void:
	var run_scene_packed := load(RUN_SCENE_PATH) as PackedScene
	if run_scene_packed == null:
		failures.append("failed to load RunScene for MVP20 LevelUpPanel smoke")
		return
	var run_scene := run_scene_packed.instantiate()
	root.add_child(run_scene)
	var level_panel: Variant = run_scene.get_node_or_null("CanvasLayer/LevelUpPanel")
	if level_panel == null:
		failures.append("RunScene missing LevelUpPanel for MVP20 display smoke")
		run_scene.free()
		return
	for augment in mvp20:
		level_panel.call("_show_options", _resource_array([augment]))
		if not bool(level_panel.visible):
			failures.append("LevelUpPanel did not become visible for %s" % str(augment.get("id")))
			continue
		if int(level_panel.current_options.size()) != 1:
			failures.append("LevelUpPanel did not keep one MVP20 option for %s" % str(augment.get("id")))
		var text := _first_button_text(level_panel)
		var augment_id := str(augment.get("id"))
		for required in [str(augment.get("display_name")), str(augment.get("route_id")), "Tags:", "Source:", "Effect:", "Condition:", "Fit:", "Risk:"]:
			if required != "" and not text.contains(required):
				failures.append("LevelUpPanel text for %s missing %s cue: %s" % [augment_id, required, text])
		var rarity_cue := _rarity_label(str(augment.get("rarity")))
		if rarity_cue != "" and not text.contains(rarity_cue):
			failures.append("LevelUpPanel text for %s missing rarity cue %s: %s" % [augment_id, rarity_cue, text])
	run_scene.free()

func _assert_selection_bridge_acquires_mvp20(mvp20: Array[Resource], upgrade_system: Node, augment_system: Node, failures: Array[String]) -> void:
	for augment in mvp20:
		var owner := Node2D.new()
		root.add_child(owner)
		upgrade_system.call("reset")
		augment_system.call("reset")
		var augment_id := str(augment.get("id"))
		if not bool(upgrade_system.call("is_augment_available_for_selection", augment, {"include_default_tags": true})):
			failures.append("UpgradeSystem did not consider MVP20 augment selectable from a clean state: %s" % augment_id)
		elif not bool(upgrade_system.call("apply_augment", augment, owner)):
			failures.append("UpgradeSystem.apply_augment failed for MVP20 augment: %s" % augment_id)
		else:
			if int(upgrade_system.call("get_owned_augment_rank", augment_id)) != 1:
				failures.append("UpgradeSystem did not mirror selected MVP20 rank for %s" % augment_id)
			if int(augment_system.call("get_owned_augment_rank", augment_id)) != 1:
				failures.append("AugmentSystem did not acquire selected MVP20 augment %s" % augment_id)
			if int(augment_system.call("get_route_count", str(augment.get("route_id")))) != 1:
				failures.append("AugmentSystem did not track selected MVP20 route for %s" % augment_id)
		owner.free()

func _assert_mvp20_runtime_triggers(mvp20: Array[Resource], augment_system: Node, damage_system: Node, game_events: Node, failures: Array[String]) -> void:
	var categories := {
		"stat_passive": false,
		"on_hit_proc": false,
		"chain_splash_damage": false,
		"dot_zone_delayed": false,
		"shield_heal_lowhp_fatal": false,
		"choice_progression": false,
	}
	for augment in mvp20:
		var owner := Node2D.new()
		owner.name = "MVP20Owner"
		var target := _MVP20Target.new()
		target.name = "MVP20Target"
		root.add_child(owner)
		root.add_child(target)
		augment_system.call("reset")
		var augment_id := str(augment.get("id"))
		var before := augment_system.call("get_runtime_snapshot") as Dictionary
		if not bool(augment_system.call("acquire_augment", augment, owner, {"checkpoint": "MVP20"})):
			failures.append("AugmentSystem direct acquire failed for MVP20 augment: %s" % augment_id)
			owner.free()
			target.free()
			continue
		var trigger_id := _trigger_id(augment)
		var signal_name := _primary_signal_name(augment)
		if signal_name != "augment_acquired":
			var packet := _packet_for_trigger(damage_system, trigger_id, signal_name, owner, target, augment_id)
			_emit_runtime_trigger(game_events, augment_system, signal_name, trigger_id, owner, target, packet)
		var after := augment_system.call("get_runtime_snapshot") as Dictionary
		_assert_effects_executed(augment, before, after, failures)
		if _observable_score(after) <= _observable_score(before):
			failures.append("MVP20 augment produced no observable runtime state/proc ledger: %s" % augment_id)
		_assert_generated_packets_safe(augment, before, after, failures)
		_assert_recursion_blocks_packet_generators(augment, augment_system, damage_system, game_events, owner, target, failures)
		_mark_runtime_categories(augment, categories)
		owner.free()
		target.free()
	for category in categories.keys():
		if not bool(categories[category]):
			failures.append("MVP20 runtime category was not represented: %s" % category)

func _assert_mobile_zhonya_fatal_path(registry: Node, augment_system: Node, damage_system: Node, game_events: Node, failures: Array[String]) -> void:
	var zhonya := registry.call("get_by_id", "aug_mobile_zhonya") as Resource
	if zhonya == null:
		failures.append("missing aug_mobile_zhonya for fatal-path checkpoint")
		return
	var owner := Node2D.new()
	root.add_child(owner)
	augment_system.call("reset")
	if not bool(augment_system.call("acquire_augment", zhonya, owner)):
		failures.append("failed to acquire aug_mobile_zhonya for fatal-path checkpoint")
		owner.free()
		return
	var packet := _packet_for_trigger(damage_system, "on_low_hp_or_controlled", "fatal_damage_received", owner, owner, "aug_mobile_zhonya")
	game_events.emit_signal("fatal_damage_received", owner, packet)
	var snapshot := augment_system.call("get_runtime_snapshot") as Dictionary
	var effect_counts: Dictionary = snapshot.get("effect_counts", {})
	if int(effect_counts.get("enter_stasis", 0)) < 1:
		failures.append("aug_mobile_zhonya fatal_damage_received did not enter stasis")
	if (snapshot.get("heals", {}) as Dictionary).is_empty():
		failures.append("aug_mobile_zhonya fatal_damage_received did not create heal state")
	if (snapshot.get("controls", {}) as Dictionary).is_empty():
		failures.append("aug_mobile_zhonya fatal_damage_received did not create cleanse/control state")
	owner.free()

func _assert_effects_executed(augment: Resource, before: Dictionary, after: Dictionary, failures: Array[String]) -> void:
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
			failures.append("%s did not execute effect %s exactly through checkpoint trigger; delta=%d expected_at_least=%d" % [
				str(augment.get("id")),
				effect_type,
				delta,
				int(expected_counts[effect_type])
			])

func _assert_generated_packets_safe(augment: Resource, before: Dictionary, after: Dictionary, failures: Array[String]) -> void:
	var before_packets: Array = before.get("generated_packets", [])
	var after_packets: Array = after.get("generated_packets", [])
	if after_packets.size() <= before_packets.size():
		return
	for index in range(before_packets.size(), after_packets.size()):
		var packet := after_packets[index] as Dictionary
		if packet == null:
			failures.append("%s generated a non-dictionary packet" % str(augment.get("id")))
			continue
		var packet_errors: Array = root.get_node("DamageSystem").call("validate_packet", packet)
		if not packet_errors.is_empty():
			failures.append("%s generated invalid proc packet: %s" % [str(augment.get("id")), packet_errors])
		if str(packet.get("augment_id", "")) != str(augment.get("id")):
			failures.append("%s generated packet without owning augment id: %s" % [str(augment.get("id")), packet])
		if int(packet.get("proc_depth", 0)) < 1:
			failures.append("%s generated packet without incremented proc_depth: %s" % [str(augment.get("id")), packet])
		if str(packet.get("proc_chain_id", "")) == "":
			failures.append("%s generated packet without proc_chain_id" % str(augment.get("id")))
		if (packet.get("proc_flags", []) as Array).is_empty():
			failures.append("%s generated packet without proc_flags" % str(augment.get("id")))

func _assert_recursion_blocks_packet_generators(augment: Resource, augment_system: Node, damage_system: Node, game_events: Node, owner: Node, target: Node, failures: Array[String]) -> void:
	var packet_effects: Array[String] = []
	for effect_value in augment.get("effects"):
		var effect := effect_value as Resource
		if effect == null:
			continue
		if _effect_generates_packet(str(effect.get("effect_type"))):
			var family := str(effect.call("get_effect_family")) if effect.has_method("get_effect_family") else str(effect.get("effect_type"))
			if not packet_effects.has(family):
				packet_effects.append(family)
	if packet_effects.is_empty():
		return
	var trigger_id := _trigger_id(augment)
	var signal_name := _primary_signal_name(augment)
	if signal_name == "augment_acquired":
		return
	var before := augment_system.call("get_runtime_snapshot") as Dictionary
	var packet := _packet_for_trigger(damage_system, trigger_id, signal_name, owner, target, str(augment.get("id")))
	packet["proc_flags"] = [packet_effects[0]]
	packet["proc_depth"] = 0
	_emit_runtime_trigger(game_events, augment_system, signal_name, trigger_id, owner, target, packet)
	var after := augment_system.call("get_runtime_snapshot") as Dictionary
	var before_blocks := int((before.get("blocked_counts", {}) as Dictionary).get("recursion", 0))
	var after_blocks := int((after.get("blocked_counts", {}) as Dictionary).get("recursion", 0))
	if after_blocks <= before_blocks:
		failures.append("%s did not record same-family recursion block for %s" % [str(augment.get("id")), packet_effects[0]])

func _packet_for_trigger(damage_system: Node, trigger_id: String, signal_name: String, owner: Node, target: Node, augment_id: String) -> Dictionary:
	var tags: Array[String] = ["projectile", "weapon", "skill", "rune", "element", "burn", "dot", "void", "rift"]
	var source_kind := "skill"
	if signal_name == "weapon_fired":
		source_kind = "weapon"
	elif signal_name == "dot_tick":
		source_kind = "dot"
	elif signal_name in ["shield_gained", "shield_broken"]:
		source_kind = "shield"
	elif signal_name in ["heal_received", "regen_tick"]:
		source_kind = "heal"
	elif signal_name == "control_applied":
		source_kind = "control"
	var payload := {
		"owner": owner,
		"target": target,
		"amount": 12.0,
		"source_kind": source_kind,
		"source_id": "%s_source" % augment_id,
		"weapon_id": "mvp20_rune_bolt",
		"weapon_tags": ["projectile"],
		"element_tags": ["fire"],
		"cooldown_source_id": "%s_cooldown" % augment_id,
		"hit_position": Vector2(12.0, 8.0),
		"source_position": Vector2.ZERO,
		"distance": 600.0,
		"parent_event_id": "%s_parent" % augment_id,
		"proc_flags": [],
		"on_hit_efficiency": 1.0,
		"can_crit": true,
		"crit_chance": 1.0,
		"crit_multiplier": 1.6,
		"is_crit": trigger_id == "on_crit",
		"dot_tag": "burn",
		"stacks": 6,
		"stacks_added": 6,
		"total_stacks": 6,
		"region_id": "mvp20_region",
		"chain_count": 3,
		"current_health": 40.0,
		"max_health": 100.0,
		"health_ratio": 0.25,
		"target_health_ratio": 0.05,
		"enemy_class": "normal",
		"target_class": "normal",
		"shield_active": true,
		"recent_heal_seconds": 0.5,
		"control_tag": "slow",
		"ratio": 0.25,
		"stasis_cooldown": 0.0,
		"incoming_packet": {},
		"cooldown_state": {},
		"selection_state": {},
		"stat_snapshot": {},
		"window_state": {},
	}
	var packet := damage_system.call("make_packet", 12.0, tags, payload) as Dictionary
	packet["trigger_id"] = trigger_id
	packet["signal_name"] = signal_name
	return packet

func _emit_runtime_trigger(game_events: Node, augment_system: Node, signal_name: String, trigger_id: String, owner: Node, target: Node, packet: Dictionary) -> void:
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
		"burn_stack_threshold":
			game_events.emit_signal("burn_stack_threshold", target, int(packet.get("stacks", 6)), packet)
		"rift_chain_triggered":
			game_events.emit_signal("rift_chain_triggered", str(packet.get("region_id", "mvp20_region")), int(packet.get("chain_count", 3)), packet)
		"shield_broken":
			game_events.emit_signal("shield_broken", owner, float(packet.get("amount", 12.0)), packet)
		"shield_gained":
			game_events.emit_signal("shield_gained", owner, float(packet.get("amount", 12.0)), packet)
		"heal_received":
			game_events.emit_signal("heal_received", owner, float(packet.get("amount", 12.0)), packet)
		"regen_tick":
			game_events.emit_signal("regen_tick", owner, float(packet.get("amount", 12.0)), packet)
		"low_hp_entered":
			game_events.emit_signal("low_hp_entered", owner, float(packet.get("ratio", 0.25)), packet)
		"fatal_damage_received":
			game_events.emit_signal("fatal_damage_received", owner, packet)
		"control_applied":
			game_events.emit_signal("control_applied", target, str(packet.get("control_tag", "slow")), packet)
		"augment_periodic_tick":
			game_events.emit_signal("augment_periodic_tick", 10.0)
		_:
			augment_system.call("emit_synthetic_event", trigger_id, packet, {"signal_name": signal_name, "owner": owner, "target": target})

func _mark_runtime_categories(augment: Resource, categories: Dictionary) -> void:
	for effect_value in augment.get("effects"):
		var effect := effect_value as Resource
		if effect == null:
			continue
		var effect_type := str(effect.get("effect_type"))
		if effect_type.begins_with("modify_") or effect_type.begins_with("enable_") or effect_type == "missing_hp_scaling":
			categories["stat_passive"] = true
		if effect_type.contains("projectile") or effect_type.contains("on_hit") or effect_type.contains("shard") or effect_type.contains("missile") or effect_type == "split_projectile":
			categories["on_hit_proc"] = true
		if effect_type.contains("split") or effect_type.contains("splash") or effect_type.contains("explosion") or effect_type.contains("collapse") or effect_type.contains("damage") or effect_type.contains("execute"):
			categories["chain_splash_damage"] = true
		if effect_type.contains("dot") or effect_type.contains("burn") or effect_type.contains("rift") or effect_type.contains("zone") or effect_type.contains("delayed") or effect_type.contains("shockwave"):
			categories["dot_zone_delayed"] = true
		if effect_type.contains("shield") or effect_type.contains("heal") or effect_type.contains("stasis") or _trigger_id(augment).contains("low_hp") or _trigger_id(augment).contains("fatal"):
			categories["shield_heal_lowhp_fatal"] = true
		if effect_type.contains("forge") or effect_type.contains("choice") or effect_type.contains("reroll") or effect_type.contains("progress"):
			categories["choice_progression"] = true

func _observable_score(snapshot: Dictionary) -> int:
	var score := 0
	score += (snapshot.get("generated_packets", []) as Array).size()
	for key in [
		"active_counts",
		"stat_modifiers",
		"choice_state",
		"quest_progress",
		"shields",
		"heals",
		"controls",
		"mobility",
		"cooldown_refunds",
		"pending_effects",
		"modes",
		"counters",
		"rewards",
		"safe_states",
	]:
		score += (snapshot.get(key, {}) as Dictionary).size()
	return score

func _effect_generates_packet(effect_type: String) -> bool:
	return effect_type.contains("projectile") or effect_type.contains("missile") or effect_type.contains("shard") or effect_type.contains("dot") or effect_type.contains("burn") or effect_type.contains("zone") or effect_type.contains("rift") or effect_type.contains("laser") or effect_type.contains("shockwave") or effect_type.contains("delayed") or effect_type.contains("explosion") or effect_type.contains("damage") or effect_type.contains("execute") or effect_type.contains("collapse") or effect_type.contains("true")

func _trigger_id(augment: Resource) -> String:
	var trigger = augment.get("trigger")
	if trigger != null:
		var value: Variant = trigger.get("trigger_id")
		if typeof(value) != TYPE_NIL and str(value) != "":
			return str(value)
	return str(augment.get("source_trigger"))

func _primary_signal_name(augment: Resource) -> String:
	var trigger = augment.get("trigger")
	if trigger != null:
		var signals: Array = trigger.get("signal_names")
		if not signals.is_empty():
			return str(signals[0])
	return _trigger_id(augment)

func _resource_ids(resources: Array[Resource]) -> Array[String]:
	var ids: Array[String] = []
	for resource in resources:
		ids.append(str(resource.get("id")))
	return ids

func _resource_array(values: Array) -> Array[Resource]:
	var result: Array[Resource] = []
	for value in values:
		result.append(value as Resource)
	return result

func _first_button_text(level_panel: Node) -> String:
	var options_container: Node = level_panel.get_node("Panel/Margin/Content/Options")
	if options_container.get_child_count() <= 0:
		return ""
	var button := options_container.get_child(0) as Button
	return button.text if button != null else ""

func _rarity_label(value: String) -> String:
	match value:
		"silver":
			return "Silver"
		"gold":
			return "Gold"
		"prismatic":
			return "Prismatic"
		_:
			return value

func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("PASS: MVP20 checkpoint augments selected, displayed, and triggered without no-op runtime behavior")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

class _MVP20Target:
	extends Node2D
	var total_damage := 0.0

	func apply_damage(amount: float, _tags: Array[String]) -> void:
		total_damage += amount

	func get_enemy_class() -> String:
		return "normal"
