extends Node

const AugmentEffectSpecScript := preload("res://data/resources/augment_effect_spec.gd")

const MAX_ACTIVE_ZONES_PER_AUGMENT := 12
const MAX_ACTIVE_SUMMONS_PER_AUGMENT := 16
const MAX_DELAYED_STRIKES_PER_AUGMENT := 10
const MAX_ACTIVE_PROJECTILES_PER_AUGMENT := 48
const BOSS_MAX_HP_DAMAGE_SCALAR := 0.30
const ELITE_MAX_HP_DAMAGE_SCALAR := 0.65
const DEFAULT_SOURCE_COOLDOWN := 0.0
const DEFAULT_PER_TARGET_COOLDOWN := 0.0

func is_effect_type_handled(effect_type: String) -> bool:
	return _effect_category(effect_type) != ""

func execute_effect(augment: Resource, effect: Resource, event_context: Dictionary, runtime_state: Variant) -> bool:
	if augment == null or effect == null or runtime_state == null:
		return false
	var augment_id := str(augment.get("id"))
	var effect_type := str(effect.get("effect_type"))
	var effect_family := str(effect.call("get_effect_family")) if effect.has_method("get_effect_family") else effect_type
	var packet: Dictionary = _packet_from_context(event_context)
	if not _passes_proc_guards(effect_family, packet, effect, runtime_state):
		return false
	if not _passes_cooldown_guards(augment_id, effect_family, effect, event_context, packet, runtime_state):
		return false
	if not _passes_once_guards(augment_id, effect_family, effect, packet, runtime_state):
		return false
	var params: Dictionary = effect.get("params")
	var executed := _execute_by_type(augment_id, effect_type, effect_family, params, packet, event_context, runtime_state)
	if executed:
		_start_cooldowns(augment_id, effect_family, effect, event_context, packet, runtime_state)
		var effect_payload := {
			"augment_id": augment_id,
			"effect_family": effect_family,
			"trigger_id": str(event_context.get("trigger_id", "")),
			"signal_name": str(event_context.get("signal_name", "")),
			"effect_type": effect_type,
			"world_position": _world_position_from_context(event_context, packet)
		}
		runtime_state.mark_effect(effect_type, effect_payload)
		if is_instance_valid(GameEvents):
			GameEvents.augment_effect_triggered.emit(effect_payload.duplicate(true))
			GameEvents.augment_state_changed.emit(runtime_state.get_snapshot())
	return executed

func _passes_proc_guards(effect_family: String, packet: Dictionary, effect: Resource, runtime_state: Variant) -> bool:
	if packet.is_empty():
		return true
	if not DamageSystem.can_trigger(effect_family, packet, effect):
		runtime_state.mark_block("recursion")
		return false
	return true

func _passes_cooldown_guards(augment_id: String, effect_family: String, effect: Resource, event_context: Dictionary, packet: Dictionary, runtime_state: Variant) -> bool:
	var now_seconds := float(Time.get_ticks_msec()) / 1000.0
	var source_cooldown := _effect_cooldown(effect, "source_cooldown", DEFAULT_SOURCE_COOLDOWN)
	var per_target_cooldown := _effect_cooldown(effect, "per_target_cooldown", DEFAULT_PER_TARGET_COOLDOWN)
	var source_key := _cooldown_key(augment_id, effect_family, event_context, packet)
	if not runtime_state.is_source_cooldown_ready(source_key, now_seconds, source_cooldown):
		runtime_state.mark_block("source_cooldown")
		return false
	var target := _target_from_context(event_context, packet)
	if not runtime_state.is_per_target_cooldown_ready(source_key, target, now_seconds, per_target_cooldown):
		runtime_state.mark_block("per_target_cooldown")
		return false
	return true

func _start_cooldowns(augment_id: String, effect_family: String, effect: Resource, event_context: Dictionary, packet: Dictionary, runtime_state: Variant) -> void:
	var now_seconds := float(Time.get_ticks_msec()) / 1000.0
	var source_cooldown := _effect_cooldown(effect, "source_cooldown", DEFAULT_SOURCE_COOLDOWN)
	var per_target_cooldown := _effect_cooldown(effect, "per_target_cooldown", DEFAULT_PER_TARGET_COOLDOWN)
	var source_key := _cooldown_key(augment_id, effect_family, event_context, packet)
	runtime_state.start_source_cooldown(source_key, now_seconds, source_cooldown)
	runtime_state.start_per_target_cooldown(source_key, _target_from_context(event_context, packet), now_seconds, per_target_cooldown)

func _passes_once_guards(augment_id: String, effect_family: String, effect: Resource, packet: Dictionary, runtime_state: Variant) -> bool:
	var params: Dictionary = effect.get("params")
	if not bool(params.get("once_per_parent", false)):
		return true
	var parent_id := str(packet.get("parent_event_id", packet.get("proc_chain_id", "")))
	var once_key := "%s:%s:%s" % [augment_id, effect_family, parent_id]
	if runtime_state.has_once_key(once_key):
		runtime_state.mark_block("once_per_parent")
		return false
	runtime_state.mark_once_key(once_key)
	return true

func _execute_by_type(augment_id: String, effect_type: String, effect_family: String, params: Dictionary, packet: Dictionary, event_context: Dictionary, runtime_state: Variant) -> bool:
	if effect_type == "":
		return false
	var category := _effect_category(effect_type)
	if category == "stat":
		_execute_stat_effect(augment_id, effect_type, params, runtime_state)
		return true
	if category == "projectile":
		return _execute_proc_packet_effect(augment_id, effect_type, effect_family, params, packet, runtime_state, "projectile", MAX_ACTIVE_PROJECTILES_PER_AUGMENT)
	if category == "dot":
		return _execute_proc_packet_effect(augment_id, effect_type, effect_family, params, packet, runtime_state, "dot", 0)
	if category == "zone":
		return _execute_proc_packet_effect(augment_id, effect_type, effect_family, params, packet, runtime_state, "zone", MAX_ACTIVE_ZONES_PER_AUGMENT)
	if category == "delayed":
		return _execute_proc_packet_effect(augment_id, effect_type, effect_family, params, packet, runtime_state, "delayed_strike", MAX_DELAYED_STRIKES_PER_AUGMENT)
	if category == "summon":
		return _execute_proc_packet_effect(augment_id, effect_type, effect_family, params, packet, runtime_state, "summon", MAX_ACTIVE_SUMMONS_PER_AUGMENT)
	if category == "damage":
		return _execute_damage_modifier(augment_id, effect_type, effect_family, params, packet, runtime_state)
	if category == "shield_heal":
		_execute_shield_heal(augment_id, effect_type, params, event_context, packet, runtime_state)
		return true
	if category == "control_mobility":
		_execute_control_mobility(augment_id, effect_type, params, event_context, packet, runtime_state)
		return true
	if category == "choice":
		_execute_choice_effect(augment_id, effect_type, params, runtime_state)
		return true
	if category == "quest":
		_execute_quest_effect(augment_id, params, runtime_state)
		return true
	if category == "cooldown":
		_execute_cooldown_effect(augment_id, effect_type, effect_family, params, packet, runtime_state)
		return true
	if category == "pending":
		_execute_pending_effect(augment_id, effect_type, effect_family, params, packet, runtime_state)
		return true
	if category == "counter":
		_execute_counter_effect(augment_id, effect_type, effect_family, params, packet, runtime_state)
		return true
	if category == "mode":
		_execute_mode_effect(augment_id, effect_type, params, runtime_state)
		return true
	if category == "safe_state":
		runtime_state.add_safe_state("%s:%s" % [augment_id, effect_type], {"effect_family": effect_family, "params": params.duplicate(true)})
		return true
	runtime_state.mark_block("unhandled_effect")
	runtime_state.record_log("unhandled_effect", augment_id, {"effect_type": effect_type, "effect_family": effect_family})
	return false

func _execute_stat_effect(augment_id: String, effect_type: String, params: Dictionary, runtime_state: Variant) -> void:
	var stat := str(params.get("stat", params.get("to_stat", params.get("from_stat", effect_type))))
	var op := str(params.get("op", "add_percent"))
	var value := _numeric_param(params, ["value", "ratio", "crit_chance_add", "vulnerability_percent"], 0.0)
	if value == 0.0 and effect_type.begins_with("modify_"):
		value = 1.0
	runtime_state.add_stat_modifier(stat, value, op, augment_id)

func _execute_proc_packet_effect(augment_id: String, effect_type: String, effect_family: String, params: Dictionary, packet: Dictionary, runtime_state: Variant, active_kind: String, cap: int) -> bool:
	if cap > 0 and not runtime_state.increment_active(active_kind, augment_id, int(params.get("max_active_per_owner", cap)), _active_ttl_seconds(active_kind, params)):
		return false
	var child := _child_packet_or_stub(packet, effect_family, augment_id, params)
	child["source_kind"] = _source_kind_for_active_kind(active_kind)
	child["augment_effect_type"] = effect_type
	child["boss_scalar"] = _boss_scalar_for_packet(child, params)
	runtime_state.record_generated_packet(child)
	return true

func _execute_damage_modifier(augment_id: String, effect_type: String, effect_family: String, params: Dictionary, packet: Dictionary, runtime_state: Variant) -> bool:
	var child := _child_packet_or_stub(packet, effect_family, augment_id, params)
	var multiplier := _numeric_param(params, ["damage_multiplier", "multiplier"], 1.0)
	var bonus := _numeric_param(params, ["amount", "damage", "bonus_damage"], 0.0)
	child["amount"] = max(0.0, float(child.get("amount", 0.0)) * multiplier + bonus)
	child["damage_type"] = str(params.get("damage_type", child.get("damage_type", "adaptive")))
	child["boss_scalar"] = _boss_scalar_for_packet(child, params)
	child["augment_effect_type"] = effect_type
	runtime_state.record_generated_packet(child)
	return true

func _execute_shield_heal(augment_id: String, effect_type: String, params: Dictionary, event_context: Dictionary, packet: Dictionary, runtime_state: Variant) -> void:
	var amount := _numeric_param(params, ["amount", "shield", "heal_amount"], 1.0)
	var owner_key := _owner_key(event_context, packet)
	if effect_type == "low_hp_defense_burst":
		runtime_state.shields[owner_key] = float(runtime_state.shields.get(owner_key, 0.0)) + amount
		runtime_state.mobility[owner_key] = int(runtime_state.mobility.get(owner_key, 0)) + 1
		runtime_state.controls["knockback"] = int(runtime_state.controls.get("knockback", 0)) + 1
		runtime_state.add_safe_state("%s:%s:%s" % [augment_id, effect_type, owner_key], {
			"effect_type": effect_type,
			"params": params.duplicate(true),
			"health_ratio": float(packet.get("health_ratio", event_context.get("ratio", 0.0)))
		})
		return
	if effect_type.contains("shield") or effect_type == "prevent_fatal_damage" or effect_type == "enter_stasis":
		runtime_state.shields[owner_key] = float(runtime_state.shields.get(owner_key, 0.0)) + amount
	if effect_type.contains("heal") or effect_type == "below_half_regen" or effect_type == "enter_stasis":
		runtime_state.heals[owner_key] = float(runtime_state.heals.get(owner_key, 0.0)) + amount

func _execute_control_mobility(augment_id: String, effect_type: String, params: Dictionary, event_context: Dictionary, packet: Dictionary, runtime_state: Variant) -> void:
	var owner_key := _owner_key(event_context, packet)
	if effect_type.contains("dash") or effect_type.contains("blink") or effect_type.contains("stasis"):
		runtime_state.mobility[owner_key] = int(runtime_state.mobility.get(owner_key, 0)) + 1
	if effect_type.contains("control") or effect_type.contains("slow") or effect_type.contains("charm") or effect_type.contains("taunt"):
		var control_tag := str(params.get("control_tag", params.get("tag", effect_type)))
		runtime_state.controls[control_tag] = int(runtime_state.controls.get(control_tag, 0)) + 1

func _execute_choice_effect(augment_id: String, effect_type: String, params: Dictionary, runtime_state: Variant) -> void:
	if effect_type == "grant_forge_choice":
		runtime_state.add_choice_count("forge_choices_pending", int(params.get("choice_count", 1)))
	elif effect_type == "grant_next_choice_refresh":
		var refresh := int(params.get("refresh_per_slot", 1))
		runtime_state.add_choice_count("next_choice_refresh_per_slot", refresh)
		if is_instance_valid(UpgradeSystem):
			UpgradeSystem.set_next_choice_refresh_per_slot(refresh)
	elif effect_type == "modify_next_option_count":
		runtime_state.add_choice_count("next_option_count_delta", int(params.get("delta", 0)))
	elif effect_type.contains("currency") or effect_type.contains("pickup") or effect_type == "open_gold_window_on_elite_boss_hit":
		runtime_state.add_reward(effect_type, int(params.get("count", params.get("amount", 1))))
	else:
		runtime_state.add_choice_count(effect_type, int(params.get("count", 1)))

func _execute_cooldown_effect(augment_id: String, effect_type: String, effect_family: String, params: Dictionary, packet: Dictionary, runtime_state: Variant) -> void:
	var key := "%s:%s:%s" % [augment_id, effect_family, str(packet.get("cooldown_source_id", packet.get("source_id", effect_type)))]
	var amount := _numeric_param(params, ["amount", "refund", "seconds", "value"], 1.0)
	runtime_state.add_cooldown_refund(key, amount)
	if effect_type == "activate_cooldown_mode":
		runtime_state.add_mode("%s:%s" % [augment_id, str(params.get("mode", "cooldown_mode"))], params)

func _execute_pending_effect(augment_id: String, effect_type: String, effect_family: String, params: Dictionary, packet: Dictionary, runtime_state: Variant) -> void:
	var key := "%s:%s:%s" % [augment_id, effect_family, str(packet.get("proc_chain_id", packet.get("cooldown_source_id", effect_type)))]
	runtime_state.set_pending_effect(key, {"effect_type": effect_type, "effect_family": effect_family, "params": params.duplicate(true)})

func _execute_counter_effect(augment_id: String, effect_type: String, effect_family: String, params: Dictionary, packet: Dictionary, runtime_state: Variant) -> void:
	var target_key := _node_key(packet.get("target", null))
	var key := "%s:%s:%s:%s" % [augment_id, effect_family, str(params.get("stack_tag", effect_type)), target_key]
	runtime_state.add_counter(key, int(params.get("stacks", params.get("amount", 1))), int(params.get("threshold", params.get("total", 0))))

func _execute_mode_effect(augment_id: String, effect_type: String, params: Dictionary, runtime_state: Variant) -> void:
	var mode := str(params.get("mode", effect_type))
	runtime_state.add_mode("%s:%s" % [augment_id, mode], {"effect_type": effect_type, "params": params.duplicate(true)})

func _execute_quest_effect(augment_id: String, params: Dictionary, runtime_state: Variant) -> void:
	var amount := int(params.get("amount", params.get("progress", 1)))
	var total := int(params.get("total", params.get("normal_kills_required", params.get("elite_kills_required", 1))))
	var entry: Dictionary = runtime_state.add_quest_progress(augment_id, amount, total)
	if is_instance_valid(GameEvents):
		GameEvents.augment_quest_progressed.emit(augment_id, int(entry.get("amount", 0)), int(entry.get("total", total)))

func _child_packet_or_stub(packet: Dictionary, effect_family: String, augment_id: String, params: Dictionary) -> Dictionary:
	var packet_params := {
		"amount": _numeric_param(params, ["amount", "damage"], float(packet.get("amount", 1.0))),
		"source_kind": str(params.get("source_kind", "augment")),
		"source_id": str(params.get("source_id", effect_family)),
		"on_hit_efficiency": _numeric_param(params, ["on_hit_efficiency"], 1.0)
	}
	if packet.is_empty():
		packet = DamageSystem.make_packet(float(packet_params["amount"]), _to_string_array(params.get("tags", [])), {
			"source_kind": "augment",
			"source_id": effect_family,
			"augment_id": augment_id
		})
	return DamageSystem.child_proc_packet(packet, effect_family, augment_id, packet_params)

func _packet_from_context(event_context: Dictionary) -> Dictionary:
	var packet = event_context.get("packet", {})
	if packet is Dictionary:
		return (packet as Dictionary).duplicate(true)
	return {}

func _target_from_context(event_context: Dictionary, packet: Dictionary) -> Node:
	var target = event_context.get("target", packet.get("target", null))
	return target as Node

func _world_position_from_context(event_context: Dictionary, packet: Dictionary) -> Vector2:
	var position = packet.get("hit_position", event_context.get("world_position", Vector2.ZERO))
	if position is Vector2:
		return position
	var target := _target_from_context(event_context, packet)
	if target is Node2D:
		return (target as Node2D).global_position
	var owner = event_context.get("owner", packet.get("owner", null))
	if owner is Node2D:
		return (owner as Node2D).global_position
	return Vector2.ZERO

func _cooldown_key(augment_id: String, effect_family: String, event_context: Dictionary, packet: Dictionary) -> String:
	var source_id := str(packet.get("cooldown_source_id", packet.get("source_id", event_context.get("signal_name", ""))))
	return "%s:%s:%s" % [augment_id, effect_family, source_id]

func _owner_key(event_context: Dictionary, packet: Dictionary) -> String:
	var owner = event_context.get("owner", packet.get("owner", null))
	if owner is Node:
		return "%s:%d" % [(owner as Node).name, (owner as Node).get_instance_id()]
	return "owner:none"

func _node_key(value: Variant) -> String:
	var node := value as Node
	if node == null:
		return "none"
	return "%s:%d" % [node.name, node.get_instance_id()]

func _source_kind_for_active_kind(active_kind: String) -> String:
	if active_kind == "dot":
		return "dot"
	if active_kind == "zone":
		return "zone"
	if active_kind == "summon":
		return "summon"
	if active_kind == "delayed_strike":
		return "delayed_strike"
	return "augment"

func _active_ttl_seconds(active_kind: String, params: Dictionary) -> float:
	if params.has("active_ttl_seconds"):
		return maxf(0.0, float(params.get("active_ttl_seconds")))
	if params.has("duration"):
		return maxf(0.0, float(params.get("duration")))
	if params.has("lifetime"):
		return maxf(0.0, float(params.get("lifetime")))
	if active_kind == "delayed_strike":
		return maxf(0.1, float(params.get("delay", 0.0)) + 0.25)
	if active_kind == "projectile":
		return 0.75
	if active_kind == "zone":
		return 4.0
	if active_kind == "summon":
		return 8.0
	return 1.0

func _boss_scalar_for_packet(packet: Dictionary, params: Dictionary) -> float:
	if params.has("boss_scalar"):
		return clampf(float(params.get("boss_scalar")), 0.0, 1.0)
	var target_class := str(packet.get("target_class", ""))
	if target_class == "boss":
		return BOSS_MAX_HP_DAMAGE_SCALAR
	if target_class == "elite":
		return ELITE_MAX_HP_DAMAGE_SCALAR
	return max(0.0, float(packet.get("boss_scalar", 1.0)))

func _effect_cooldown(effect: Resource, key: String, fallback: float) -> float:
	var value: Variant = effect.get(key)
	if typeof(value) != TYPE_NIL and float(value) > 0.0:
		return float(value)
	var params: Dictionary = effect.get("params")
	return max(0.0, float(params.get(key, fallback)))

func _numeric_param(params: Dictionary, keys: Array[String], fallback: float) -> float:
	for key in keys:
		if params.has(key):
			var value = params[key]
			if value is int or value is float:
				return float(value)
	return fallback

func _effect_category(effect_type: String) -> String:
	if _is_cooldown_effect(effect_type):
		return "cooldown"
	if effect_type == "set_pending_next_hit" or effect_type == "apply_on_hit_package":
		return "pending"
	if _is_counter_effect(effect_type):
		return "counter"
	if _is_stat_effect(effect_type):
		return "stat"
	if _is_projectile_effect(effect_type):
		return "projectile"
	if _is_dot_effect(effect_type):
		return "dot"
	if _is_zone_effect(effect_type):
		return "zone"
	if _is_delayed_effect(effect_type):
		return "delayed"
	if _is_summon_effect(effect_type):
		return "summon"
	if _is_damage_effect(effect_type):
		return "damage"
	if _is_shield_heal_effect(effect_type):
		return "shield_heal"
	if _is_control_mobility_effect(effect_type):
		return "control_mobility"
	if _is_choice_effect(effect_type):
		return "choice"
	if _is_quest_effect(effect_type):
		return "quest"
	if _is_mode_effect(effect_type):
		return "mode"
	if _is_safe_state_effect(effect_type):
		return "safe_state"
	return ""

func _is_stat_effect(effect_type: String) -> bool:
	return effect_type.begins_with("modify_") or effect_type.begins_with("convert_") or effect_type in ["enable_crit_sources", "enable_dot_crit", "enable_heal_shield_crit", "scale_summons", "grant_omnivamp", "missing_hp_scaling", "boost_heal_conversion", "skill_hit_speed_buff", "damage_scale_by_speed_delta"]

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

func _is_shield_heal_effect(effect_type: String) -> bool:
	return effect_type.contains("shield") or effect_type.contains("heal") or effect_type.contains("regen") or effect_type == "prevent_fatal_damage" or effect_type == "enter_stasis" or effect_type == "low_hp_defense_burst"

func _is_control_mobility_effect(effect_type: String) -> bool:
	return effect_type.contains("control") or effect_type.contains("dash") or effect_type.contains("blink") or effect_type.contains("slow") or effect_type.contains("stasis") or effect_type.contains("taunt")

func _is_choice_effect(effect_type: String) -> bool:
	return effect_type.contains("forge") or effect_type.contains("choice") or effect_type.contains("reroll") or effect_type.contains("random_augment") or effect_type.contains("option_count") or effect_type.contains("currency") or effect_type.contains("pickup") or effect_type == "open_gold_window_on_elite_boss_hit"

func _is_quest_effect(effect_type: String) -> bool:
	return effect_type.contains("quest") or effect_type.contains("progress")

func _is_cooldown_effect(effect_type: String) -> bool:
	return effect_type.contains("cooldown") or effect_type.begins_with("refund_") or effect_type == "activate_cooldown_mode"

func _is_counter_effect(effect_type: String) -> bool:
	return effect_type.contains("stack") or effect_type.contains("counter") or effect_type.contains("charge") or effect_type == "dual_stack" or effect_type == "regional_counter" or effect_type == "add_stack_on_crit" or effect_type == "periodic_auto_mark"

func _is_mode_effect(effect_type: String) -> bool:
	return effect_type.contains("temporary") or effect_type.contains("mode") or effect_type.contains("invulnerable") or effect_type == "elite_kill_stealth" or effect_type == "contact_effect_while_invulnerable"

func _is_safe_state_effect(effect_type: String) -> bool:
	return effect_type in ["apply_state_at_threshold", "cleanse_control", "control_grants_resists", "control_grants_shield", "grant_stored_shield", "permanent_max_health_on_control", "prevent_fatal_damage", "protection_pulse", "temporary_resists_on_protection"]

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
