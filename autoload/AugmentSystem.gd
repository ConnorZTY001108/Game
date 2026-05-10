extends Node

const AugmentDataScript := preload("res://data/resources/augment_data.gd")
const AugmentRuntimeStateScript := preload("res://autoload/AugmentRuntimeState.gd")

var _state = AugmentRuntimeStateScript.new()
var _owned_augments: Dictionary = {}

func _ready() -> void:
	_connect_events()

func reset() -> void:
	_connect_events()
	_state.reset()
	_owned_augments.clear()

func acquire_augment(augment: Resource, owner: Node = null, context: Dictionary = {}) -> bool:
	if not is_augment_runtime_valid(augment):
		_state.mark_block("invalid_augment")
		return false
	if not _state.can_rank(augment):
		_state.mark_block("rank_or_unique")
		return false
	var augment_id := str(augment.get("id"))
	_state.record_acquired(augment, owner)
	_owned_augments[augment_id] = augment
	_execute_for_signal("augment_acquired", {
		"signal_name": "augment_acquired",
		"trigger_id": "on_pick",
		"owner": owner,
		"augment_id": augment_id,
		"selection_state": context.duplicate(true)
	}, [augment])
	return true

func is_augment_owned(augment_id: String) -> bool:
	return _state.owned_ids.has(augment_id)

func get_owned_augment_rank(augment_id: String) -> int:
	return int(_state.ranks.get(augment_id, 0))

func get_route_count(route_id: String) -> int:
	return int(_state.route_counts.get(route_id, 0))

func get_owned_ids() -> Array[String]:
	var result: Array[String] = []
	for key in _state.owned_ids.keys():
		result.append(str(key))
	return result

func get_owned_tags() -> Array[String]:
	var result: Array[String] = []
	for key in _state.owned_tags.keys():
		result.append(str(key))
	return result

func get_runtime_snapshot() -> Dictionary:
	return _state.get_snapshot()

func cleanup_active_effects(now_seconds: float = -1.0) -> void:
	_state.cleanup_active(now_seconds)

func release_active_effect(kind: String, augment_id: String, count: int = 1) -> void:
	_state.release_active(kind, augment_id, count)

func is_augment_runtime_valid(augment: Resource) -> bool:
	if augment == null or not (augment is AugmentDataScript):
		return false
	var augment_id := str(augment.get("id"))
	if augment_id == "":
		return false
	var expected_path := _expected_resource_path(augment)
	if augment.has_method("validate"):
		var errors: Array = augment.call("validate", expected_path)
		if not errors.is_empty():
			return false
	return true

func can_select_augment(augment: Resource) -> bool:
	return is_augment_runtime_valid(augment) and _state.can_rank(augment)

func emit_synthetic_event(trigger_id: String, packet: Dictionary = {}, context: Dictionary = {}) -> void:
	var event_context := context.duplicate(true)
	event_context["signal_name"] = str(context.get("signal_name", trigger_id))
	event_context["trigger_id"] = trigger_id
	if not packet.is_empty():
		event_context["packet"] = packet.duplicate(true)
		if packet.has("owner"):
			event_context["owner"] = packet.get("owner")
		if packet.has("target"):
			event_context["target"] = packet.get("target")
	_execute_for_signal(str(event_context["signal_name"]), event_context)

func _connect_events() -> void:
	if is_instance_valid(GameEvents):
		_connect_signal("run_started", _on_run_started)
		_connect_signal("weapon_fired", _on_weapon_fired)
		_connect_signal("projectile_spawned", _on_projectile_spawned)
		_connect_signal("projectile_hit", _on_projectile_hit)
		_connect_signal("damage_roll_requested", _on_damage_roll_requested)
		_connect_signal("damage_applied_packet", _on_damage_applied_packet)
		_connect_signal("dot_tick", _on_dot_tick)
		_connect_signal("burn_stack_applied", _on_burn_stack_applied)
		_connect_signal("burn_stack_threshold", _on_burn_stack_threshold)
		_connect_signal("rift_chain_triggered", _on_rift_chain_triggered)
		_connect_signal("shield_gained", _on_shield_gained)
		_connect_signal("shield_broken", _on_shield_broken)
		_connect_signal("heal_received", _on_heal_received)
		_connect_signal("regen_tick", _on_regen_tick)
		_connect_signal("control_applied", _on_control_applied)
		_connect_signal("dash_started", _on_dash_started)
		_connect_signal("dash_finished", _on_dash_finished)
		_connect_signal("blink_used", _on_blink_used)
		_connect_signal("low_hp_entered", _on_low_hp_entered)
		_connect_signal("fatal_damage_received", _on_fatal_damage_received)
		_connect_signal("pickup_collected", _on_pickup_collected)
		_connect_signal("elite_killed", _on_elite_killed)
		_connect_signal("boss_damaged", _on_boss_damaged)
		_connect_signal("augment_periodic_tick", _on_augment_periodic_tick)
		_connect_signal("enemy_died", _on_enemy_died)
		_connect_signal("level_changed", _on_level_changed)
		_connect_signal("wave_phase_started", _on_wave_phase_started)

func _connect_signal(signal_name: String, callable: Callable) -> void:
	if GameEvents.has_signal(signal_name) and not GameEvents.is_connected(signal_name, callable):
		GameEvents.connect(signal_name, callable)

func _on_run_started() -> void:
	reset()

func _on_weapon_fired(player: Node, weapon: Resource, packet: Dictionary) -> void:
	_execute_for_signal("weapon_fired", _context_from_packet("weapon_fired", packet, {"owner": player, "weapon": weapon}))

func _on_projectile_spawned(projectile: Node, packet: Dictionary) -> void:
	_execute_for_signal("projectile_spawned", _context_from_packet("projectile_spawned", packet, {"projectile": projectile}))

func _on_projectile_hit(target: Node, packet: Dictionary) -> void:
	_execute_for_signal("projectile_hit", _context_from_packet("projectile_hit", packet, {"target": target}))

func _on_damage_roll_requested(packet: Dictionary) -> void:
	_execute_for_signal("damage_roll_requested", _context_from_packet("damage_roll_requested", packet))

func _on_damage_applied_packet(target: Node, packet: Dictionary) -> void:
	_execute_for_signal("damage_applied_packet", _context_from_packet("damage_applied_packet", packet, {"target": target}))

func _on_dot_tick(target: Node, packet: Dictionary) -> void:
	_execute_for_signal("dot_tick", _context_from_packet("dot_tick", packet, {"target": target}))

func _on_burn_stack_applied(target: Node, stacks_added: int, total_stacks: int, packet: Dictionary) -> void:
	var burn_packet := _event_packet(packet, ["burn"], {
		"target": target,
		"stacks_added": stacks_added,
		"total_stacks": total_stacks,
		"source_kind": "dot",
		"source_id": "burn_stack"
	})
	_execute_for_signal("burn_stack_applied", _context_from_packet("burn_stack_applied", burn_packet, {
		"target": target,
		"stacks_added": stacks_added,
		"total_stacks": total_stacks
	}))

func _on_burn_stack_threshold(target: Node, stacks: int, packet: Dictionary) -> void:
	var burn_packet := _event_packet(packet, ["burn"], {
		"target": target,
		"stacks_added": stacks,
		"total_stacks": stacks,
		"source_kind": "dot",
		"source_id": "burn_stack_threshold"
	})
	_execute_for_signal("burn_stack_threshold", _context_from_packet("burn_stack_threshold", burn_packet, {"target": target, "stacks": stacks}))
	_execute_for_signal("burn_stack_applied", _context_from_packet("burn_stack_applied", burn_packet, {
		"target": target,
		"stacks_added": stacks,
		"total_stacks": stacks
	}))

func _on_rift_chain_triggered(region_id: String, chain_count: int, packet: Dictionary) -> void:
	var rift_packet := _event_packet(packet, ["void", "rift"], {
		"region_id": region_id,
		"chain_count": chain_count,
		"source_kind": "augment",
		"source_id": "rift_chain"
	})
	_execute_for_signal("rift_chain_triggered", _context_from_packet("rift_chain_triggered", rift_packet, {
		"region_id": region_id,
		"chain_count": chain_count
	}))

func _on_shield_gained(target: Node, amount: float, packet: Dictionary) -> void:
	_execute_for_signal("shield_gained", _context_from_packet("shield_gained", packet, {"target": target, "amount": amount}))

func _on_shield_broken(target: Node, amount: float, packet: Dictionary) -> void:
	_execute_for_signal("shield_broken", _context_from_packet("shield_broken", packet, {"target": target, "amount": amount}))

func _on_heal_received(target: Node, amount: float, packet: Dictionary) -> void:
	_execute_for_signal("heal_received", _context_from_packet("heal_received", packet, {"target": target, "amount": amount}))

func _on_regen_tick(target: Node, amount: float, packet: Dictionary) -> void:
	_execute_for_signal("regen_tick", _context_from_packet("regen_tick", packet, {"target": target, "amount": amount}))

func _on_control_applied(target: Node, control_tag: String, packet: Dictionary) -> void:
	_execute_for_signal("control_applied", _context_from_packet("control_applied", packet, {"target": target, "control_tag": control_tag}))

func _on_dash_started(player: Node, packet: Dictionary) -> void:
	_execute_for_signal("dash_started", _context_from_packet("dash_started", packet, {"owner": player}))

func _on_dash_finished(player: Node, packet: Dictionary) -> void:
	_execute_for_signal("dash_finished", _context_from_packet("dash_finished", packet, {"owner": player}))

func _on_blink_used(player: Node, packet: Dictionary) -> void:
	_execute_for_signal("blink_used", _context_from_packet("blink_used", packet, {"owner": player}))

func _on_low_hp_entered(player: Node, ratio: float, packet: Dictionary) -> void:
	_execute_for_signal("low_hp_entered", _context_from_packet("low_hp_entered", packet, {"owner": player, "ratio": ratio}))

func _on_fatal_damage_received(player: Node, packet: Dictionary) -> void:
	_execute_for_signal("fatal_damage_received", _context_from_packet("fatal_damage_received", packet, {"owner": player}))

func _on_pickup_collected(pickup: Node, player: Node, packet: Dictionary) -> void:
	_execute_for_signal("pickup_collected", _context_from_packet("pickup_collected", packet, {"pickup": pickup, "owner": player}))

func _on_elite_killed(enemy: Node, packet: Dictionary) -> void:
	_execute_for_signal("elite_killed", _context_from_packet("elite_killed", packet, {"target": enemy, "target_class": "elite"}))

func _on_boss_damaged(enemy: Node, packet: Dictionary) -> void:
	_execute_for_signal("boss_damaged", _context_from_packet("boss_damaged", packet, {"target": enemy, "target_class": "boss"}))

func _on_augment_periodic_tick(elapsed_seconds: float) -> void:
	_execute_for_signal("augment_periodic_tick", {"signal_name": "augment_periodic_tick", "elapsed_seconds": elapsed_seconds})

func _on_enemy_died(enemy: Node, experience_value: int) -> void:
	_execute_for_signal("enemy_died", {"signal_name": "enemy_died", "target": enemy, "experience_value": experience_value})

func _on_level_changed(level: int) -> void:
	var packet := _event_packet({}, ["level"], {
		"level": level,
		"wave_phase_id": "level_%d" % level,
		"source_kind": "progression",
		"source_id": "level_changed"
	})
	_execute_for_signal("level_changed", _context_from_packet("level_changed", packet, {"level": level, "wave_phase_id": "level_%d" % level}))

func _on_wave_phase_started(wave_phase_id: String, level: int, packet: Dictionary) -> void:
	var wave_packet := _event_packet(packet, ["wave"], {
		"level": level,
		"wave_phase_id": wave_phase_id,
		"source_kind": "wave",
		"source_id": "wave_phase_started"
	})
	_execute_for_signal("wave_phase_started", _context_from_packet("wave_phase_started", wave_packet, {"level": level, "wave_phase_id": wave_phase_id}))

func _context_from_packet(signal_name: String, packet: Dictionary, extras: Dictionary = {}) -> Dictionary:
	var context := extras.duplicate(true)
	context["signal_name"] = signal_name
	context["packet"] = packet.duplicate(true)
	if packet.has("owner") and not context.has("owner"):
		context["owner"] = packet.get("owner")
	if packet.has("target") and not context.has("target"):
		context["target"] = packet.get("target")
	if packet.has("target_class") and not context.has("target_class"):
		context["target_class"] = packet.get("target_class")
	return context

func _event_packet(packet: Dictionary, tags: Array, defaults: Dictionary) -> Dictionary:
	var merged := packet.duplicate(true)
	for key in defaults.keys():
		if not merged.has(key):
			merged[key] = defaults[key]
	if not merged.has("hit_position"):
		merged["hit_position"] = Vector2.ZERO
	return DamageSystem.make_packet(float(merged.get("amount", 0.0)), _to_string_array(merged.get("tags", tags)), merged)

func _execute_for_signal(signal_name: String, event_context: Dictionary, augment_filter: Array = []) -> void:
	var augments := augment_filter if not augment_filter.is_empty() else _owned_augments.values()
	for augment_value in augments:
		var augment := augment_value as Resource
		if augment == null or not _trigger_matches(augment, signal_name, event_context):
			continue
		var context := event_context.duplicate(true)
		context["trigger_id"] = _trigger_id(augment)
		var augment_id := str(augment.get("id"))
		if not context.has("owner") and _state.owners.has(augment_id):
			context["owner"] = _state.owners[augment_id]
		for effect_value in augment.get("effects"):
			var effect := effect_value as Resource
			if effect == null:
				continue
			AugmentEffectRunner.call("execute_effect", augment, effect, context, _state)

func _trigger_matches(augment: Resource, signal_name: String, event_context: Dictionary) -> bool:
	var trigger = augment.get("trigger")
	var trigger_id := _trigger_id(augment)
	var signals: Array[String] = []
	if trigger != null:
		signals = _to_string_array(trigger.get("signal_names"))
	if signals.has(signal_name):
		return _required_values_match(trigger, event_context)
	return _trigger_alias_matches(trigger_id, signal_name, event_context)

func _trigger_alias_matches(trigger_id: String, signal_name: String, event_context: Dictionary) -> bool:
	if trigger_id == "on_pick" and signal_name == "augment_acquired":
		return true
	if trigger_id.begins_with("passive") and signal_name == "augment_acquired":
		return true
	if trigger_id == "on_attack_fire" and signal_name == "weapon_fired":
		return true
	if trigger_id in ["on_hit", "on_damage_dealt", "on_projectile_hit"] and signal_name in ["projectile_hit", "damage_applied_packet"]:
		return true
	if trigger_id == "on_level_up_or_wave_start" and signal_name in ["level_changed", "wave_phase_started", "on_level_up_or_wave_start"]:
		return true
	if trigger_id == "on_apply_burn" and signal_name in ["burn_stack_applied", "burn_stack_threshold", "on_apply_burn"]:
		return true
	if trigger_id == "on_rift_chain_count" and signal_name in ["rift_chain_triggered", "on_rift_chain_count"]:
		return true
	if trigger_id == "on_crit" and signal_name == "damage_applied_packet":
		var packet: Dictionary = event_context.get("packet", {})
		return bool(packet.get("is_crit", false))
	if trigger_id == "on_skill_hit" and signal_name == "damage_applied_packet":
		var packet: Dictionary = event_context.get("packet", {})
		return _to_string_array(packet.get("tags", [])).has("skill") or str(packet.get("source_kind", "")) in ["skill", "rune", "zone", "orbit"]
	if trigger_id == "on_damage_roll" and signal_name == "damage_roll_requested":
		return true
	if trigger_id.contains("periodic") and signal_name == "augment_periodic_tick":
		return true
	if trigger_id.contains("low_hp") and signal_name in ["low_hp_entered", "fatal_damage_received", "control_applied"]:
		return true
	if trigger_id.contains("fatal") and signal_name == "fatal_damage_received":
		return true
	if trigger_id.contains("shield") and signal_name in ["shield_gained", "shield_broken", "damage_applied_packet"]:
		return true
	if trigger_id.contains("heal") and signal_name in ["heal_received", "regen_tick", "shield_gained"]:
		return true
	if trigger_id.contains("control") and signal_name == "control_applied":
		return true
	if trigger_id.contains("dash") and signal_name in ["dash_started", "dash_finished", "blink_used"]:
		return true
	if trigger_id.contains("blink") and signal_name in ["blink_used", "low_hp_entered"]:
		return true
	if trigger_id.contains("elite") and signal_name in ["elite_killed", "damage_applied_packet", "boss_damaged"]:
		return true
	if trigger_id.contains("boss") and signal_name in ["boss_damaged", "damage_applied_packet"]:
		return true
	if trigger_id.contains("kill") and signal_name in ["enemy_died", "elite_killed"]:
		return true
	if trigger_id.contains("pickup") and signal_name in ["pickup_collected", "augment_periodic_tick"]:
		return true
	if trigger_id.contains("quest") and signal_name in ["enemy_died", "elite_killed", "weapon_fired"]:
		return true
	return false

func _required_values_match(trigger: Resource, event_context: Dictionary) -> bool:
	if trigger == null:
		return true
	var values: Dictionary = trigger.get("required_packet_values")
	if values.is_empty():
		return true
	var packet: Dictionary = event_context.get("packet", {})
	for key in values.keys():
		var expected := str(values[key])
		var actual := str(packet.get(key, event_context.get(key, "")))
		if expected.contains("|"):
			var allowed := expected.split("|", false)
			if not allowed.has(actual):
				return false
		elif actual != expected:
			return false
	return true

func _trigger_id(augment: Resource) -> String:
	var trigger = augment.get("trigger")
	if trigger != null:
		var value: Variant = trigger.get("trigger_id")
		if typeof(value) != TYPE_NIL and str(value) != "":
			return str(value)
	return str(augment.get("source_trigger"))

func _expected_resource_path(augment: Resource) -> String:
	var declared := str(augment.get("manifest_resource_path"))
	if declared != "":
		return declared
	var native_path := str(augment.resource_path)
	if native_path != "":
		return native_path.trim_prefix("res://")
	var route_id := str(augment.get("route_id"))
	var augment_id := str(augment.get("id"))
	if route_id != "" and augment_id != "":
		return "data/content/augments/%s/%s.tres" % [route_id, augment_id]
	return ""

func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is PackedStringArray:
		for item in value:
			result.append(str(item))
	elif value is Array:
		for item in value:
			result.append(str(item))
	elif value is String and str(value) != "":
		for part in str(value).split(",", false):
			result.append(part.strip_edges())
	return result
