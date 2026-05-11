class_name AugmentTestHarness
extends RefCounted

const VisualRegistryScript := preload("res://scripts/augment/AugmentVisualRegistry.gd")

const ALL_AUGMENT_SIGNALS: Array[String] = [
	"augment_acquired",
	"weapon_fired",
	"projectile_spawned",
	"projectile_hit",
	"damage_roll_requested",
	"damage_applied_packet",
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
	"rune_triggered",
]

const POSITIVE_SIGNAL_PRIORITY: Array[String] = [
	"damage_applied_packet",
	"projectile_hit",
	"weapon_fired",
	"damage_roll_requested",
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
	"rune_triggered",
	"augment_acquired",
]

const NEGATIVE_SIGNAL_PRIORITY: Array[String] = [
	"weapon_fired",
	"pickup_collected",
	"level_changed",
	"fatal_damage_received",
	"shield_gained",
	"control_applied",
	"augment_periodic_tick",
	"enemy_died",
	"damage_roll_requested",
	"projectile_hit",
	"damage_applied_packet",
	"burn_stack_applied",
	"rift_chain_triggered",
]

var tree: SceneTree
var root: Node
var registry: Node
var augment_system: Node
var effect_runner: Node
var damage_system: Node
var game_events: Node
var upgrade_system: Node
var visual_director: Node
var visual_registry: Node
var owner: Node2D
var target: Node2D
var second_target: Node2D
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var captured_effect_events: Array[Dictionary] = []
var captured_visual_events: Array[Dictionary] = []
var captured_feedback_events: Array[Dictionary] = []
var _owns_visual_registry: bool = false
var _connected: bool = false

func setup(scene_tree: SceneTree, deterministic_seed: int = 1337) -> Array[String]:
	tree = scene_tree
	root = tree.root
	rng.seed = deterministic_seed
	var failures: Array[String] = []
	registry = root.get_node_or_null("AugmentRegistry")
	augment_system = root.get_node_or_null("AugmentSystem")
	effect_runner = root.get_node_or_null("AugmentEffectRunner")
	damage_system = root.get_node_or_null("DamageSystem")
	game_events = root.get_node_or_null("GameEvents")
	upgrade_system = root.get_node_or_null("UpgradeSystem")
	visual_director = root.get_node_or_null("AugmentVisualDirector")
	if registry == null:
		failures.append("AugmentRegistry autoload missing")
	if augment_system == null:
		failures.append("AugmentSystem autoload missing")
	if effect_runner == null:
		failures.append("AugmentEffectRunner autoload missing")
	if damage_system == null:
		failures.append("DamageSystem autoload missing")
	if game_events == null:
		failures.append("GameEvents autoload missing")
	if not failures.is_empty():
		return failures

	registry.call("reload")
	if upgrade_system != null and upgrade_system.has_method("reset"):
		upgrade_system.call("reset")
	augment_system.call("reset")
	_prepare_visual_registry()

	owner = Node2D.new()
	owner.name = "AugmentHarnessOwner"
	owner.global_position = Vector2(4.0, 8.0)
	target = Node2D.new()
	target.name = "AugmentHarnessTarget"
	target.global_position = Vector2(32.0, 16.0)
	second_target = Node2D.new()
	second_target.name = "AugmentHarnessSecondTarget"
	second_target.global_position = Vector2(56.0, 24.0)
	root.add_child(owner)
	root.add_child(target)
	root.add_child(second_target)
	_connect_recorders()
	return failures

func cleanup() -> void:
	_disconnect_recorders()
	_free_node(owner)
	_free_node(target)
	_free_node(second_target)
	if _owns_visual_registry:
		_free_node(visual_registry)
	visual_registry = null
	visual_director = null

func reset_runtime() -> void:
	captured_effect_events.clear()
	captured_visual_events.clear()
	captured_feedback_events.clear()
	if upgrade_system != null and upgrade_system.has_method("reset"):
		upgrade_system.call("reset")
	if augment_system != null:
		augment_system.call("reset")
	if visual_director != null and visual_director.has_method("rebuild"):
		visual_director.call("rebuild")
	elif visual_registry != null and registry != null and visual_registry.has_method("rebuild_from_augment_registry"):
		visual_registry.call("rebuild_from_augment_registry", registry)

func get_augments() -> Array:
	if registry == null:
		return []
	return registry.call("get_all")

func get_augment(augment_id: String) -> Resource:
	if registry == null:
		return null
	return registry.call("get_by_id", augment_id) as Resource

func install_augment(augment: Resource, context: Dictionary = {}) -> bool:
	if augment_system == null or augment == null:
		return false
	return bool(augment_system.call("acquire_augment", augment, owner, context.duplicate(true)))

func get_snapshot() -> Dictionary:
	if augment_system == null:
		return {}
	return augment_system.call("get_runtime_snapshot") as Dictionary

func trigger_id(augment: Resource) -> String:
	var trigger: Resource = _trigger_resource(augment)
	if trigger != null:
		var value: Variant = trigger.get("trigger_id")
		if typeof(value) != TYPE_NIL and str(value) != "":
			return str(value)
	if augment != null:
		return str(augment.get("source_trigger"))
	return ""

func primary_signal_name(augment: Resource) -> String:
	var signals: Array[String] = signal_names_for_augment(augment)
	for preferred in POSITIVE_SIGNAL_PRIORITY:
		if signals.has(preferred):
			return preferred
	if not signals.is_empty():
		return signals[0]
	var aliases: Array[String] = trigger_alias_signals(trigger_id(augment))
	for preferred in POSITIVE_SIGNAL_PRIORITY:
		if aliases.has(preferred):
			return preferred
	if not aliases.is_empty():
		return aliases[0]
	return "augment_acquired"

func signal_names_for_augment(augment: Resource) -> Array[String]:
	var result: Array[String] = []
	var trigger: Resource = _trigger_resource(augment)
	if trigger != null:
		result = _to_string_array(trigger.get("signal_names"))
	if result.is_empty() and augment != null:
		var spec: Dictionary = augment.get("trigger_spec")
		result = _to_string_array(spec.get("signal_names", spec.get("signals", [])))
	if result.is_empty():
		result = trigger_alias_signals(trigger_id(augment))
	return result

func trigger_alias_signals(id: String) -> Array[String]:
	if id == "on_pick" or id.begins_with("passive"):
		return ["augment_acquired"]
	if id == "on_attack_fire":
		return ["weapon_fired"]
	if id in ["on_hit", "on_damage_dealt", "on_projectile_hit"]:
		return ["damage_applied_packet", "projectile_hit"]
	if id == "on_level_up_or_wave_start":
		return ["level_changed", "wave_phase_started"]
	if id == "on_apply_burn":
		return ["burn_stack_applied", "burn_stack_threshold"]
	if id == "on_rift_chain_count":
		return ["rift_chain_triggered"]
	if id == "on_crit":
		return ["damage_applied_packet"]
	if id in ["on_skill_hit", "on_skill_or_element_hit", "on_damage_to_low_hp"]:
		return ["damage_applied_packet", "rune_triggered"]
	if id == "on_damage_roll":
		return ["damage_roll_requested"]
	if id.contains("periodic"):
		return ["augment_periodic_tick"]
	if id.contains("low_hp"):
		return ["low_hp_entered", "fatal_damage_received", "control_applied"]
	if id.contains("fatal"):
		return ["fatal_damage_received"]
	if id.contains("shield"):
		return ["shield_gained", "shield_broken", "damage_applied_packet"]
	if id.contains("heal"):
		return ["heal_received", "regen_tick", "shield_gained"]
	if id.contains("control"):
		return ["control_applied"]
	if id.contains("dash"):
		return ["dash_started", "dash_finished", "blink_used"]
	if id.contains("blink"):
		return ["blink_used", "low_hp_entered"]
	if id.contains("elite"):
		return ["elite_killed", "damage_applied_packet", "boss_damaged"]
	if id.contains("boss"):
		return ["boss_damaged", "damage_applied_packet"]
	if id.contains("kill"):
		return ["enemy_died", "elite_killed"]
	if id.contains("pickup"):
		return ["pickup_collected", "augment_periodic_tick"]
	if id.contains("quest"):
		return ["enemy_died", "elite_killed", "weapon_fired"]
	return []

func negative_signal_for_augment(augment: Resource) -> String:
	var allowed: Array[String] = signal_names_for_augment(augment)
	allowed.append_array(trigger_alias_signals(trigger_id(augment)))
	for preferred in NEGATIVE_SIGNAL_PRIORITY:
		if not allowed.has(preferred):
			return preferred
	for signal_name in ALL_AUGMENT_SIGNALS:
		if signal_name != "augment_acquired" and not allowed.has(signal_name):
			return signal_name
	return "weapon_fired"

func make_packet_for_augment(augment: Resource, overrides: Dictionary = {}) -> Dictionary:
	var id: String = trigger_id(augment)
	var signal_name: String = str(overrides.get("signal_name", primary_signal_name(augment)))
	var tags: Array[String] = ["projectile", "weapon", "skill", "rune", "element", "fire", "burn", "dot", "void", "rift", "summon", "pickup", "control", "shield", "heal"]
	var source_kind: String = _source_kind_for_signal(signal_name)
	var augment_id: String = str(augment.get("id")) if augment != null else "augment"
	var payload: Dictionary = {
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
		"hit_position": target.global_position,
		"source_position": owner.global_position,
		"distance": 640.0,
		"parent_event_id": "%s_parent" % augment_id,
		"proc_chain_id": "%s_chain" % augment_id,
		"proc_flags": [],
		"proc_depth": 0,
		"on_hit_efficiency": 1.0,
		"can_crit": true,
		"crit_chance": 1.0,
		"crit_multiplier": 1.6,
		"is_crit": id == "on_crit",
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
		"spawn_position": owner.global_position,
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
		"trigger_id": id,
		"signal_name": signal_name,
	}
	var trigger: Resource = _trigger_resource(augment)
	if trigger != null:
		var required_values: Dictionary = trigger.get("required_packet_values")
		for key in required_values.keys():
			payload[str(key)] = _first_required_value(str(required_values[key]))
		for key in _to_string_array(trigger.get("required_packet_keys")):
			if not payload.has(key):
				payload[key] = _default_required_value(key)
	for key in overrides.keys():
		payload[key] = overrides[key]
	if damage_system != null and damage_system.has_method("make_packet"):
		var packet: Dictionary = damage_system.call("make_packet", float(payload.get("amount", 16.0)), tags, payload) as Dictionary
		for key in payload.keys():
			packet[key] = payload[key]
		return packet
	return payload

func emit_positive_trigger(augment: Resource, overrides: Dictionary = {}) -> String:
	var signal_name: String = str(overrides.get("signal_name", primary_signal_name(augment)))
	if signal_name == "augment_acquired":
		return signal_name
	var packet: Dictionary = make_packet_for_augment(augment, overrides)
	emit_signal_event(signal_name, trigger_id(augment), packet, {"owner": owner, "target": target})
	return signal_name

func emit_negative_trigger(augment: Resource, overrides: Dictionary = {}) -> String:
	var signal_name: String = str(overrides.get("signal_name", negative_signal_for_augment(augment)))
	var packet: Dictionary = make_packet_for_augment(augment, {"signal_name": signal_name})
	for key in overrides.keys():
		packet[key] = overrides[key]
	emit_signal_event(signal_name, trigger_id(augment), packet, {"owner": owner, "target": target})
	return signal_name

func emit_signal_event(signal_name: String, id: String, packet: Dictionary, context: Dictionary = {}) -> void:
	if game_events == null or augment_system == null:
		return
	match signal_name:
		"weapon_fired":
			game_events.emit_signal("weapon_fired", owner, null, packet)
		"projectile_spawned":
			var projectile: Node2D = Node2D.new()
			projectile.name = "HarnessProjectile"
			owner.add_child(projectile)
			game_events.emit_signal("projectile_spawned", projectile, packet)
			projectile.queue_free()
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
			game_events.emit_signal("rift_chain_triggered", str(packet.get("region_id", "harness_region")), int(packet.get("chain_count", 4)), packet)
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
			var pickup: Node2D = Node2D.new()
			pickup.name = "HarnessPickup"
			owner.add_child(pickup)
			game_events.emit_signal("pickup_collected", pickup, owner, packet)
			pickup.queue_free()
		"elite_killed":
			game_events.emit_signal("elite_killed", target, packet)
		"boss_damaged":
			game_events.emit_signal("boss_damaged", target, packet)
		"augment_periodic_tick":
			game_events.emit_signal("augment_periodic_tick", float(packet.get("elapsed_seconds", 30.0)))
		"enemy_died":
			game_events.emit_signal("enemy_died", target, int(packet.get("experience_value", 1)))
		"level_changed":
			game_events.emit_signal("level_changed", int(packet.get("level", 2)))
		"wave_phase_started":
			game_events.emit_signal("wave_phase_started", str(packet.get("wave_phase_id", "harness_wave")), int(packet.get("level", 2)), packet)
		"rune_triggered":
			game_events.emit_signal("rune_triggered", str(packet.get("rune_id", "harness_rune")), target, packet)
		_:
			var event_context: Dictionary = context.duplicate(true)
			event_context["signal_name"] = signal_name
			event_context["owner"] = owner
			event_context["target"] = target
			augment_system.call("emit_synthetic_event", id, packet, event_context)

func proc_delta(augment_id: String, before: Dictionary, after: Dictionary) -> int:
	var before_counts: Dictionary = before.get("augment_proc_counts", {})
	var after_counts: Dictionary = after.get("augment_proc_counts", {})
	return int(after_counts.get(augment_id, 0)) - int(before_counts.get(augment_id, 0))

func effect_count_delta(effect_type: String, before: Dictionary, after: Dictionary) -> int:
	var before_counts: Dictionary = before.get("effect_counts", {})
	var after_counts: Dictionary = after.get("effect_counts", {})
	return int(after_counts.get(effect_type, 0)) - int(before_counts.get(effect_type, 0))

func expected_effect_counts(augment: Resource) -> Dictionary:
	var expected: Dictionary = {}
	for effect_value in augment.get("effects"):
		var effect: Resource = effect_value as Resource
		if effect == null:
			continue
		var effect_type: String = str(effect.get("effect_type"))
		expected[effect_type] = int(expected.get(effect_type, 0)) + 1
	return expected

func any_runtime_artifact_delta(augment: Resource, before: Dictionary, after: Dictionary) -> bool:
	for effect_value in augment.get("effects"):
		var effect: Resource = effect_value as Resource
		if effect != null and any_snapshot_key_changed(before, after, artifact_keys_for_effect(str(effect.get("effect_type")))):
			return true
	return false

func any_snapshot_key_changed(before: Dictionary, after: Dictionary, keys: Array[String]) -> bool:
	for key in keys:
		var fallback: Variant = [] if key == "generated_packets" or key == "visual_events" else {}
		var before_value: Variant = before.get(key, fallback)
		var after_value: Variant = after.get(key, fallback)
		if before_value is Array and after_value is Array:
			if (after_value as Array).size() > (before_value as Array).size():
				return true
		elif before_value is Dictionary and after_value is Dictionary:
			if _dictionary_score(after_value as Dictionary) > _dictionary_score(before_value as Dictionary):
				return true
		elif str(after_value) != str(before_value):
			return true
	return false

func artifact_keys_for_effect(effect_type: String) -> Array[String]:
	if effect_type == "periodic_taunt_pulse":
		return ["controls", "mobility", "safe_states"]
	if effect_type.contains("cooldown") or effect_type.begins_with("refund_"):
		if effect_type == "activate_cooldown_mode":
			return ["modes", "cooldown_refunds"]
		return ["cooldown_refunds"]
	if effect_type == "set_pending_next_hit" or effect_type == "apply_on_hit_package":
		return ["pending_effects"]
	if is_counter_effect(effect_type):
		return ["counters"]
	if effect_type.begins_with("convert_"):
		return ["derived_stat_rules"]
	if is_stat_effect(effect_type):
		return ["stat_modifiers", "derived_stat_rules"]
	if is_projectile_effect(effect_type):
		return ["generated_packets", "active_counts"]
	if is_dot_effect(effect_type):
		return ["generated_packets"]
	if is_zone_effect(effect_type):
		return ["generated_packets", "active_counts"]
	if is_delayed_effect(effect_type):
		return ["generated_packets", "active_counts"]
	if is_summon_effect(effect_type):
		return ["generated_packets", "active_counts"]
	if is_mode_effect(effect_type):
		return ["modes", "safe_states"]
	if is_shield_heal_effect(effect_type):
		if effect_type == "grant_stored_shield":
			return ["shields", "derived_stat_rules"]
		return ["shields", "heals", "safe_states", "mobility", "controls"]
	if is_safe_state_effect(effect_type):
		return ["safe_states", "shields", "controls"]
	if is_damage_effect(effect_type):
		return ["generated_packets"]
	if is_control_mobility_effect(effect_type):
		return ["controls", "mobility", "safe_states"]
	if is_choice_effect(effect_type):
		return ["choice_state", "rewards"]
	if is_quest_effect(effect_type):
		return ["quest_progress"]
	return []

func build_machine_spec(augment: Resource) -> Dictionary:
	var parsed_claims: Array[Dictionary] = parsed_claims_for_augment(augment)
	return {
		"augment_id": str(augment.get("id")),
		"display_name": str(augment.get("display_name")),
		"description_text": description_text(augment),
		"parsed_claims": parsed_claims,
		"assertion_refs": assertion_refs_for_augment(augment, parsed_claims),
		"trigger_spec": trigger_spec_dictionary(augment),
		"effect_spec": effect_spec_array(augment),
		"visual_spec": visual_signature_for_augment(augment),
		"negative_cases": negative_cases_for_augment(augment),
		"regression_risks": regression_risks_for_augment(augment),
	}

func description_text(augment: Resource) -> String:
	var parts: Array[String] = []
	for field in ["description", "source_condition", "effect", "combo_value", "fit", "risk"]:
		var value: String = str(augment.get(field)).strip_edges()
		if value != "" and not parts.has(value):
			parts.append(value)
	var manifest: Dictionary = augment.get("manifest_fields")
	for field in ["condition", "effect", "value", "combo_value", "fit", "risk"]:
		var value: String = str(manifest.get(field, "")).strip_edges()
		if value != "" and not parts.has(value):
			parts.append(value)
	return "\n".join(parts)

func trigger_spec_dictionary(augment: Resource) -> Dictionary:
	var trigger: Resource = _trigger_resource(augment)
	if trigger != null and trigger.has_method("to_runtime_metadata"):
		return trigger.call("to_runtime_metadata") as Dictionary
	var spec: Dictionary = augment.get("trigger_spec")
	return spec.duplicate(true)

func effect_spec_array(augment: Resource) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for effect_value in augment.get("effects"):
		var effect: Resource = effect_value as Resource
		if effect == null:
			continue
		if effect.has_method("to_runtime_metadata"):
			result.append(effect.call("to_runtime_metadata") as Dictionary)
		else:
			var params: Variant = effect.get("params")
			result.append({
				"effect_type": str(effect.get("effect_type")),
				"effect_family": str(effect.get("effect_family")),
				"params": params.duplicate(true) if params is Dictionary else {},
				"source_cooldown": float(effect.get("source_cooldown")),
				"per_target_cooldown": float(effect.get("per_target_cooldown")),
			})
	if result.is_empty():
		var blueprint: Array = augment.get("effect_spec_blueprint")
		for entry in blueprint:
			if entry is Dictionary:
				result.append((entry as Dictionary).duplicate(true))
	return result

func parsed_claims_for_augment(augment: Resource) -> Array[Dictionary]:
	var text: String = description_text(augment)
	var claims: Array[Dictionary] = []
	var segments: Array[String] = _claim_segments(text)
	for segment in segments:
		var normalized: String = segment.strip_edges()
		if normalized == "":
			continue
		var claim_type: String = claim_type_for_text(normalized)
		claims.append({
			"claim_id": "%s_claim_%02d" % [str(augment.get("id")), claims.size() + 1],
			"text": normalized,
			"claim_type": claim_type,
			"numbers": _numbers_in_text(normalized),
			"keywords": _keywords_in_text(normalized),
			"verifiable": claim_type != "manual_review",
			"mapped_assertions": claim_assertions_for_text(augment, normalized, claim_type),
		})
	if claims.is_empty():
		claims.append({
			"claim_id": "%s_claim_01" % str(augment.get("id")),
			"text": "<missing description/effect text>",
			"claim_type": "manual_review",
			"numbers": [],
			"keywords": [],
			"verifiable": false,
			"mapped_assertions": [],
		})
	return claims

func claim_assertions_for_text(augment: Resource, text: String, claim_type: String) -> Array[String]:
	var lower: String = text.to_lower()
	var assertions: Array[String] = []
	var trigger_spec: Dictionary = trigger_spec_dictionary(augment)
	var effect_specs: Array[Dictionary] = effect_spec_array(augment)
	if claim_type == "trigger" or _mentions_any(lower, ["trigger", "when", "on_", "after", "hit", "crit", "kill", "pickup", "level", "wave", "low_hp", "first", "every"]):
		if not _to_string_array(trigger_spec.get("signal_names", [])).is_empty():
			assertions.append("positive_trigger:%s" % primary_signal_name(augment))
		assertions.append("negative_trigger:%s" % negative_signal_for_augment(augment))
		if _mentions_any(lower, ["every", "first", "per ", "stack", "counter"]):
			assertions.append("stateful_repeat_or_counter_guard")
	if claim_type == "effect" or _mentions_any(lower, ["damage", "heal", "shield", "summon", "dash", "blink", "cooldown", "gold", "choice", "projectile", "zone", "aura", "burn", "rift", "stack", "quest"]):
		for effect_spec in effect_specs:
			if _effect_matches_claim(effect_spec, lower):
				assertions.append("effect_artifact:%s" % str(effect_spec.get("effect_type", "")))
	if claim_type == "visual" or _mentions_any(lower, ["visual", "vfx", "color", "audio", "flash", "particle", "trail"]):
		var signature: Dictionary = visual_signature_for_augment(augment)
		if str(signature.get("missing_reason", "")) == "":
			assertions.append("visual_signature:%s" % str(signature.get("visual_signature", "")))
	if claim_type == "manual_review":
		return assertions
	return _unique_strings(assertions)

func assertion_refs_for_augment(augment: Resource, parsed_claims: Array[Dictionary]) -> Array[String]:
	var refs: Array[String] = []
	var augment_id: String = str(augment.get("id")) if augment != null else ""
	refs.append("tests/smoke/augment_logic_contract.gd::positive_trigger:%s" % primary_signal_name(augment))
	refs.append("tests/smoke/augment_logic_contract.gd::negative_trigger:%s" % negative_signal_for_augment(augment))
	refs.append("tests/smoke/augment_logic_contract.gd::visual_feedback:%s" % augment_id)
	refs.append("tests/smoke/augment_description_coverage.gd::parsed_claims:%s" % augment_id)
	refs.append("tests/smoke/augment_visual_differentiation.gd::visual_signature:%s" % augment_id)
	var trigger_spec: Dictionary = trigger_spec_dictionary(augment)
	var required_values: Dictionary = trigger_spec.get("required_packet_values", {})
	for key in required_values.keys():
		refs.append("tests/smoke/augment_logic_contract.gd::required_value_negative:%s" % str(key))
	if _has_cooldown_or_repeat_guard(augment):
		refs.append("tests/smoke/augment_logic_contract.gd::cooldown_or_repeat_guard:%s" % augment_id)
	for claim_value in parsed_claims:
		var claim := claim_value as Dictionary
		if claim == null:
			continue
		var claim_id: String = str(claim.get("claim_id", "claim"))
		for assertion in claim.get("mapped_assertions", []):
			refs.append("claim:%s:%s" % [claim_id, str(assertion)])
	return _unique_strings(refs)

func undocumented_behaviors(augment: Resource) -> Array[String]:
	var lower: String = description_text(augment).to_lower()
	var result: Array[String] = []
	for effect_spec in effect_spec_array(augment):
		var effect_type: String = str(effect_spec.get("effect_type", ""))
		var category: String = effect_claim_category(effect_type)
		if category != "" and not _description_mentions_effect_category(lower, category, effect_type):
			result.append("%s:%s" % [effect_type, category])
	return result

func negative_cases_for_augment(augment: Resource) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	cases.append({
		"case_id": "%s_wrong_signal" % str(augment.get("id")),
		"signal_name": negative_signal_for_augment(augment),
		"expect_proc_delta": 0,
	})
	var trigger: Resource = _trigger_resource(augment)
	if trigger != null:
		var required_values: Dictionary = trigger.get("required_packet_values")
		for key in required_values.keys():
			cases.append({
				"case_id": "%s_wrong_%s" % [str(augment.get("id")), str(key)],
				"signal_name": primary_signal_name(augment),
				"override": {str(key): "__negative_contract_value__"},
				"expect_proc_delta": 0,
			})
	return cases

func regression_risks_for_augment(augment: Resource) -> Array[String]:
	var risks: Array[String] = []
	var id: String = trigger_id(augment)
	if id in ["on_hit", "on_damage_dealt", "on_projectile_hit"]:
		risks.append("hit-family triggers can be confused between projectile_hit and damage_applied_packet")
	if id == "on_crit":
		risks.append("crit trigger must not fire on non-crit damage packets")
	if id.contains("low_hp"):
		risks.append("low-health threshold must use packet health ratio, not owner rank/global state")
	if id.contains("kill") or id.contains("elite") or id.contains("boss"):
		risks.append("target class and kill/boss event bridges are easy to mix")
	for effect_spec in effect_spec_array(augment):
		var effect_type: String = str(effect_spec.get("effect_type", ""))
		if _effect_generates_packet(effect_type):
			risks.append("packet-producing effect must carry proc_depth/proc_flags/augment_id")
		var source_cd: float = float(effect_spec.get("source_cooldown", 0.0))
		var per_target_cd: float = float(effect_spec.get("per_target_cooldown", 0.0))
		var params: Dictionary = effect_spec.get("params", {})
		if source_cd > 0.0 or per_target_cd > 0.0 or float(params.get("source_cooldown", 0.0)) > 0.0 or float(params.get("per_target_cooldown", 0.0)) > 0.0:
			risks.append("cooldown guard can regress under repeated identical source/target events")
	return _unique_strings(risks)

func _has_cooldown_or_repeat_guard(augment: Resource) -> bool:
	var trigger_spec: Dictionary = trigger_spec_dictionary(augment)
	if float(trigger_spec.get("source_cooldown", 0.0)) > 0.0 or float(trigger_spec.get("per_target_cooldown", 0.0)) > 0.0:
		return true
	for effect_spec in effect_spec_array(augment):
		var params: Dictionary = effect_spec.get("params", {})
		if float(effect_spec.get("source_cooldown", 0.0)) > 0.0 or float(effect_spec.get("per_target_cooldown", 0.0)) > 0.0:
			return true
		if float(params.get("source_cooldown", 0.0)) > 0.0 or float(params.get("per_target_cooldown", 0.0)) > 0.0:
			return true
	return false

func visual_registry_spec(augment_id: String) -> Dictionary:
	_prepare_visual_registry()
	if visual_registry == null:
		return {}
	if visual_registry.has_method("has_spec") and not bool(visual_registry.call("has_spec", augment_id)):
		if visual_registry.has_method("rebuild_from_augment_registry") and registry != null:
			visual_registry.call("rebuild_from_augment_registry", registry)
	if visual_registry.has_method("has_spec") and not bool(visual_registry.call("has_spec", augment_id)):
		return {}
	if visual_registry.has_method("get_spec"):
		return visual_registry.call("get_spec", augment_id) as Dictionary
	return {}

func visual_signature_for_augment(augment: Resource) -> Dictionary:
	var augment_id: String = str(augment.get("id"))
	var spec: Dictionary = visual_registry_spec(augment_id)
	if spec.is_empty():
		return {
			"visual_signature": "missing:%s" % augment_id,
			"primary_color": "none",
			"secondary_color": "none",
			"shape_family": "none",
			"animation_type": "none",
			"spawn_anchor": "none",
			"duration_bucket": "none",
			"scale_bucket": "none",
			"particle_or_trail_usage": "none",
			"screen_feedback_usage": "none",
			"audio_feedback_key": "none",
			"missing_reason": "no AugmentVisualRegistry spec",
			"raw_spec": {},
		}
	var lifetime: float = float(spec.get("lifetime", 0.0))
	var scale_value: float = float(spec.get("scale", 1.0))
	return {
		"visual_signature": str(spec.get("visual_signature", "%s:%s:%s" % [augment_id, str(spec.get("shape", "")), str(spec.get("motion", ""))])),
		"visual_recipe_key": str(spec.get("visual_recipe_key", "")),
		"primary_color": _color_bucket(spec.get("color", Color.WHITE)),
		"secondary_color": _color_bucket(spec.get("accent_color", Color.WHITE)),
		"shape_family": _shape_family(str(spec.get("shape", "none"))),
		"animation_type": _animation_family(str(spec.get("motion", "none"))),
		"spawn_anchor": str(spec.get("spawn_anchor", "none")),
		"duration_bucket": _duration_bucket(lifetime),
		"scale_bucket": _scale_bucket(scale_value),
		"particle_or_trail_usage": _particle_usage(str(spec.get("particle_style", "")), str(spec.get("lifecycle", "")), str(spec.get("motion", ""))),
		"screen_feedback_usage": _screen_feedback_usage(spec),
		"audio_feedback_key": str(spec.get("audio_feedback_key", "none")) if str(spec.get("audio_feedback_key", "")) != "" else "none",
		"missing_reason": "",
		"raw_spec": _visual_spec_to_serializable(spec),
	}

func visual_similarity(left: Dictionary, right: Dictionary) -> float:
	var fields: Array[Dictionary] = [
		{"key": "primary_color", "weight": 0.14},
		{"key": "secondary_color", "weight": 0.10},
		{"key": "shape_family", "weight": 0.17},
		{"key": "animation_type", "weight": 0.16},
		{"key": "spawn_anchor", "weight": 0.11},
		{"key": "duration_bucket", "weight": 0.08},
		{"key": "scale_bucket", "weight": 0.06},
		{"key": "particle_or_trail_usage", "weight": 0.11},
		{"key": "screen_feedback_usage", "weight": 0.04},
		{"key": "audio_feedback_key", "weight": 0.03},
	]
	var total: float = 0.0
	var score: float = 0.0
	for entry in fields:
		var key: String = str(entry["key"])
		var weight: float = float(entry["weight"])
		total += weight
		if str(left.get(key, "")) != "" and str(left.get(key, "")) == str(right.get(key, "")):
			score += weight
	return score / maxf(total, 0.001)

func visual_collision_pairs(augments: Array, threshold: float = 0.88) -> Array[Dictionary]:
	var signatures: Dictionary = {}
	for augment_value in augments:
		var augment: Resource = augment_value as Resource
		if augment != null:
			signatures[str(augment.get("id"))] = visual_signature_for_augment(augment)
	var ids: Array = signatures.keys()
	ids.sort()
	var result: Array[Dictionary] = []
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			var left_id: String = str(ids[i])
			var right_id: String = str(ids[j])
			var similarity: float = visual_similarity(signatures[left_id], signatures[right_id])
			if similarity >= threshold:
				result.append({
					"left": left_id,
					"right": right_id,
					"similarity": similarity,
					"left_signature": signatures[left_id],
					"right_signature": signatures[right_id],
				})
	return result

func visual_missing_identities(augments: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for augment_value in augments:
		var augment: Resource = augment_value as Resource
		if augment == null:
			continue
		var signature: Dictionary = visual_signature_for_augment(augment)
		if str(signature.get("missing_reason", "")) != "":
			result.append({"augment_id": str(augment.get("id")), "reason": str(signature.get("missing_reason", "")), "signature": signature})
		elif str(signature.get("shape_family", "none")) == "none" or str(signature.get("animation_type", "none")) == "none" or str(signature.get("primary_color", "none")) == "none":
			result.append({"augment_id": str(augment.get("id")), "reason": "generic or incomplete signature", "signature": signature})
	return result

func visual_homogenized_clusters(augments: Array, min_size: int = 5) -> Array[Dictionary]:
	var groups: Dictionary = {}
	for augment_value in augments:
		var augment: Resource = augment_value as Resource
		if augment == null:
			continue
		var signature: Dictionary = visual_signature_for_augment(augment)
		var route_id: String = str(augment.get("route_id"))
		var rarity: String = str(augment.get("rarity"))
		var template_key: String = "%s|%s|%s|%s|%s" % [
			str(signature.get("shape_family", "")),
			str(signature.get("animation_type", "")),
			str(signature.get("particle_or_trail_usage", "")),
			str(signature.get("duration_bucket", "")),
			str(signature.get("scale_bucket", "")),
		]
		for scope_key in ["route:%s:%s" % [route_id, template_key], "rarity:%s:%s" % [rarity, template_key], "route_rarity:%s:%s:%s" % [route_id, rarity, template_key]]:
			if not groups.has(scope_key):
				groups[scope_key] = []
			(groups[scope_key] as Array).append(str(augment.get("id")))
	var result: Array[Dictionary] = []
	for key in groups.keys():
		var ids: Array = groups[key]
		if ids.size() >= min_size:
			result.append({"cluster_key": str(key), "augment_ids": ids.duplicate(), "size": ids.size()})
	return result

func write_json_file(path: String, value: Variant) -> void:
	_ensure_parent_dir(path)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_json_safe_value(value), "\t"))
		file.close()

func write_markdown_file(path: String, lines: Array[String]) -> void:
	write_text_file(path, "\n".join(lines) + "\n")

func write_text_file(path: String, text: String) -> void:
	_ensure_parent_dir(path)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()

func _prepare_visual_registry() -> void:
	if visual_director == null and root != null:
		visual_director = root.get_node_or_null("AugmentVisualDirector")
	if visual_director != null:
		if visual_director.has_method("_deferred_ready"):
			visual_director.call("_deferred_ready")
		if visual_director.has_method("rebuild"):
			visual_director.call("rebuild")
		if visual_director.has_method("get_visual_registry"):
			visual_registry = visual_director.call("get_visual_registry") as Node
	if visual_registry == null:
		visual_registry = VisualRegistryScript.new()
		_owns_visual_registry = true
		if root != null:
			root.add_child(visual_registry)
	if visual_registry != null and visual_registry.has_method("rebuild_from_augment_registry") and registry != null:
		visual_registry.call("rebuild_from_augment_registry", registry)

func _connect_recorders() -> void:
	if _connected or game_events == null:
		return
	if game_events.has_signal("augment_effect_triggered") and not game_events.is_connected("augment_effect_triggered", _on_augment_effect_triggered):
		game_events.connect("augment_effect_triggered", _on_augment_effect_triggered)
	if game_events.has_signal("augment_visual_played") and not game_events.is_connected("augment_visual_played", _on_augment_visual_played):
		game_events.connect("augment_visual_played", _on_augment_visual_played)
	if game_events.has_signal("feedback_requested") and not game_events.is_connected("feedback_requested", _on_feedback_requested):
		game_events.connect("feedback_requested", _on_feedback_requested)
	_connected = true

func _disconnect_recorders() -> void:
	if game_events == null or not is_instance_valid(game_events):
		return
	if game_events.has_signal("augment_effect_triggered") and game_events.is_connected("augment_effect_triggered", _on_augment_effect_triggered):
		game_events.disconnect("augment_effect_triggered", _on_augment_effect_triggered)
	if game_events.has_signal("augment_visual_played") and game_events.is_connected("augment_visual_played", _on_augment_visual_played):
		game_events.disconnect("augment_visual_played", _on_augment_visual_played)
	if game_events.has_signal("feedback_requested") and game_events.is_connected("feedback_requested", _on_feedback_requested):
		game_events.disconnect("feedback_requested", _on_feedback_requested)
	_connected = false

func _on_augment_effect_triggered(payload: Dictionary) -> void:
	captured_effect_events.append(payload.duplicate(true))

func _on_augment_visual_played(payload: Dictionary) -> void:
	captured_visual_events.append(payload.duplicate(true))

func _on_feedback_requested(feedback_type: String, text: String, world_position: Vector2, payload: Dictionary) -> void:
	captured_feedback_events.append({
		"feedback_type": feedback_type,
		"text": text,
		"world_position": world_position,
		"payload": payload.duplicate(true),
	})

func _trigger_resource(augment: Resource) -> Resource:
	if augment == null:
		return null
	return augment.get("trigger") as Resource

func _source_kind_for_signal(signal_name: String) -> String:
	if signal_name == "weapon_fired":
		return "weapon"
	if signal_name in ["projectile_hit", "projectile_spawned"]:
		return "projectile"
	if signal_name in ["dot_tick", "burn_stack_applied", "burn_stack_threshold"]:
		return "dot"
	if signal_name in ["shield_gained", "shield_broken"]:
		return "shield"
	if signal_name in ["heal_received", "regen_tick"]:
		return "heal"
	if signal_name == "control_applied":
		return "control"
	if signal_name == "pickup_collected":
		return "pickup"
	if signal_name == "rune_triggered":
		return "rune"
	return "skill"

func _first_required_value(value: String) -> String:
	if value.contains("|"):
		return value.split("|", false)[0]
	return value

func _default_required_value(key: String) -> Variant:
	if key.contains("crit"):
		return true
	if key.contains("ratio"):
		return 0.25
	if key.contains("count") or key.contains("stacks") or key.contains("level"):
		return 4
	if key.contains("target_class") or key.contains("enemy_class"):
		return "elite"
	return "%s_value" % key

func _dictionary_score(value: Dictionary) -> int:
	var score: int = value.size()
	for key in value.keys():
		var entry: Variant = value[key]
		if entry is Dictionary:
			score += int((entry as Dictionary).get("amount", 0))
			score += int((entry as Dictionary).get("total", 0))
			score += int((entry as Dictionary).get("complete", false))
		elif entry is int or entry is float:
			score += int(entry)
	return score

func _claim_segments(text: String) -> Array[String]:
	var normalized: String = text.replace("\r", "\n")
	for separator in [";", ".", ",", "\n", " and ", " + ", " / "]:
		normalized = normalized.replace(separator, "|")
	var result: Array[String] = []
	for segment in normalized.split("|", false):
		var clean: String = segment.strip_edges()
		if clean != "" and not result.has(clean):
			result.append(clean)
	return result

func claim_type_for_text(text: String) -> String:
	var lower: String = text.to_lower()
	if _mentions_any(lower, ["trigger", "when", "after", "on_", "on ", "hit", "crit", "kill", "pickup", "level", "wave", "low_hp", "fatal", "shield_broken", "first", "every", "per ", "periodic"]):
		return "trigger"
	if _mentions_any(lower, ["damage", "heal", "regen", "shield", "barrier", "summon", "dash", "blink", "cooldown", "refund", "gold", "currency", "choice", "reroll", "projectile", "missile", "shard", "burn", "dot", "aura", "zone", "rift", "stat", "convert", "stack", "counter", "quest", "control", "slow", "stasis"]):
		return "effect"
	if _mentions_any(lower, ["visual", "vfx", "color", "audio", "flash", "particle", "trail", "shape", "motion"]):
		return "visual"
	if _numbers_in_text(text).size() > 0:
		return "effect"
	return "manual_review"

func _keywords_in_text(text: String) -> Array[String]:
	var lower: String = text.to_lower()
	var keys: Array[String] = []
	for keyword in ["damage", "heal", "regen", "shield", "burn", "dot", "crit", "kill", "pickup", "cooldown", "refund", "summon", "dash", "blink", "level", "wave", "visual", "projectile", "missile", "rift", "zone", "stack", "counter", "quest", "choice", "gold", "control"]:
		if lower.contains(keyword):
			keys.append(keyword)
	return keys

func _numbers_in_text(text: String) -> Array[String]:
	var result: Array[String] = []
	var regex: RegEx = RegEx.new()
	regex.compile("[0-9]+(?:\\.[0-9]+)?%?")
	for match_result in regex.search_all(text):
		result.append(match_result.get_string())
	return result

func _mentions_any(lower_text: String, needles: Array[String]) -> bool:
	for needle in needles:
		if lower_text.contains(needle):
			return true
	return false

func _effect_matches_claim(effect_spec: Dictionary, lower_text: String) -> bool:
	var effect_type: String = str(effect_spec.get("effect_type", ""))
	var category: String = effect_claim_category(effect_type)
	return _description_mentions_effect_category(lower_text, category, effect_type)

func _description_mentions_effect_category(lower_text: String, category: String, effect_type: String) -> bool:
	if category == "damage":
		return _mentions_any(lower_text, ["damage", "explode", "explosion", "execute", "true", "vulnerability", "slash", "collapse"])
	if category == "heal_shield":
		return _mentions_any(lower_text, ["heal", "regen", "shield", "barrier", "stasis", "protection"])
	if category == "stat":
		return _mentions_any(lower_text, ["stat", "force", "health", "crit", "speed", "convert", "scale", "attack_speed", "max_health"])
	if category == "projectile":
		return _mentions_any(lower_text, ["projectile", "missile", "shard", "split", "chain", "bolt", "boomerang"])
	if category == "dot_burn":
		return _mentions_any(lower_text, ["dot", "burn", "fire", "flame", "aura", "periodic", "immolate"])
	if category == "zone_delayed":
		return _mentions_any(lower_text, ["zone", "rift", "comet", "laser", "shockwave", "delayed", "orbital", "pulse"])
	if category == "summon":
		return _mentions_any(lower_text, ["summon", "minion", "poro", "companion", "soldier"])
	if category == "mobility_control":
		return _mentions_any(lower_text, ["dash", "blink", "mobility", "control", "slow", "taunt", "stasis", "knockback"])
	if category == "choice_reward":
		return _mentions_any(lower_text, ["choice", "reroll", "gold", "currency", "pickup", "random", "augment", "forge", "transmute"])
	if category == "counter_quest":
		return _mentions_any(lower_text, ["quest", "progress", "stack", "counter", "charge", "threshold", "every"])
	if category == "cooldown":
		return _mentions_any(lower_text, ["cooldown", "refund", "haste", "reset"])
	return lower_text.contains(effect_type.to_lower().replace("_", " "))

func effect_claim_category(effect_type: String) -> String:
	if is_damage_effect(effect_type):
		return "damage"
	if is_shield_heal_effect(effect_type):
		return "heal_shield"
	if is_stat_effect(effect_type) or effect_type.begins_with("convert_"):
		return "stat"
	if is_projectile_effect(effect_type):
		return "projectile"
	if is_dot_effect(effect_type):
		return "dot_burn"
	if is_zone_effect(effect_type) or is_delayed_effect(effect_type):
		return "zone_delayed"
	if is_summon_effect(effect_type):
		return "summon"
	if is_control_mobility_effect(effect_type) or is_mode_effect(effect_type) or is_safe_state_effect(effect_type):
		return "mobility_control"
	if is_choice_effect(effect_type):
		return "choice_reward"
	if is_counter_effect(effect_type) or is_quest_effect(effect_type):
		return "counter_quest"
	if effect_type.contains("cooldown") or effect_type.begins_with("refund_"):
		return "cooldown"
	return ""

func is_stat_effect(effect_type: String) -> bool:
	return effect_type.begins_with("modify_") or effect_type.begins_with("convert_") or effect_type in ["enable_crit_sources", "enable_dot_crit", "enable_heal_shield_crit", "scale_summons", "grant_omnivamp", "missing_hp_scaling", "boost_heal_conversion", "skill_hit_speed_buff", "damage_scale_by_speed_delta"]

func is_projectile_effect(effect_type: String) -> bool:
	return effect_type.contains("projectile") or effect_type.contains("missile") or effect_type.contains("boomerang") or effect_type.contains("foxfire") or effect_type.contains("shard") or effect_type == "chain_lightning"

func is_dot_effect(effect_type: String) -> bool:
	return effect_type.contains("dot") or effect_type.contains("burn") or effect_type.contains("aura") or effect_type == "periodic_self_drain"

func is_zone_effect(effect_type: String) -> bool:
	if effect_type == "periodic_taunt_pulse":
		return false
	return effect_type.contains("zone") or effect_type.contains("rift") or effect_type.contains("laser") or effect_type.contains("shockwave") or effect_type.contains("pulse")

func is_delayed_effect(effect_type: String) -> bool:
	return effect_type.contains("delayed") or effect_type.contains("comet") or effect_type.contains("cluster_strike") or effect_type.contains("orbital") or effect_type == "delayed_fire_beam" or effect_type == "replace_every_nth_on_class"

func is_summon_effect(effect_type: String) -> bool:
	return effect_type.contains("summon") or effect_type.contains("poro") or effect_type.contains("minion") or effect_type.contains("soldier")

func is_damage_effect(effect_type: String) -> bool:
	return effect_type.contains("damage") or effect_type.contains("execute") or effect_type.contains("explosion") or effect_type.contains("collapse") or effect_type.contains("slash") or effect_type.contains("true") or effect_type.contains("vulnerability") or effect_type == "max_hp_damage" or effect_type == "long_range_bonus_projectile" or effect_type == "mixed_damage_burst" or effect_type == "burn_threshold_explosion"

func is_shield_heal_effect(effect_type: String) -> bool:
	return effect_type.contains("shield") or effect_type.contains("heal") or effect_type.contains("regen") or effect_type == "prevent_fatal_damage" or effect_type == "enter_stasis" or effect_type == "low_hp_defense_burst"

func is_control_mobility_effect(effect_type: String) -> bool:
	return effect_type.contains("control") or effect_type.contains("dash") or effect_type.contains("blink") or effect_type.contains("slow") or effect_type.contains("stasis") or effect_type.contains("taunt") or effect_type == "periodic_taunt_pulse"

func is_choice_effect(effect_type: String) -> bool:
	return effect_type.contains("forge") or effect_type.contains("choice") or effect_type.contains("reroll") or effect_type.contains("random_augment") or effect_type.contains("option_count") or effect_type.contains("currency") or effect_type.contains("pickup") or effect_type == "open_gold_window_on_elite_boss_hit"

func is_quest_effect(effect_type: String) -> bool:
	return effect_type.contains("quest") or effect_type.contains("progress")

func is_counter_effect(effect_type: String) -> bool:
	return effect_type.contains("stack") or effect_type.contains("counter") or effect_type.contains("charge") or effect_type == "dual_stack" or effect_type == "regional_counter" or effect_type == "add_stack_on_crit" or effect_type == "periodic_auto_mark"

func is_mode_effect(effect_type: String) -> bool:
	return effect_type.contains("temporary") or effect_type.contains("mode") or effect_type.contains("invulnerable") or effect_type == "elite_kill_stealth" or effect_type == "contact_effect_while_invulnerable" or effect_type == "temporary_damage_reduction"

func is_safe_state_effect(effect_type: String) -> bool:
	return effect_type in ["apply_state_at_threshold", "cleanse_control", "control_grants_resists", "control_grants_shield", "grant_stored_shield", "permanent_max_health_on_control", "prevent_fatal_damage", "protection_pulse", "temporary_resists_on_protection"]

func _effect_generates_packet(effect_type: String) -> bool:
	return is_projectile_effect(effect_type) or is_dot_effect(effect_type) or is_zone_effect(effect_type) or is_delayed_effect(effect_type) or is_summon_effect(effect_type) or is_damage_effect(effect_type)

func _color_bucket(value: Variant) -> String:
	if not value is Color:
		return "none"
	var color: Color = value
	var max_channel: float = maxf(color.r, maxf(color.g, color.b))
	if max_channel <= 0.05:
		return "black"
	if color.r > 0.85 and color.g > 0.85 and color.b > 0.75:
		return "white_gold"
	if color.r >= color.g and color.r >= color.b:
		return "orange_gold" if color.g > 0.45 else "red"
	if color.g >= color.r and color.g >= color.b:
		return "teal" if color.b > 0.55 else "green"
	if color.b >= color.r and color.b >= color.g:
		return "violet" if color.r > 0.45 else "blue"
	return "mixed"

func _shape_family(shape: String) -> String:
	var lower: String = shape.to_lower()
	if lower == "" or lower == "none":
		return "none"
	if _mentions_any(lower, ["ring", "halo", "aura", "circle", "orb", "disk"]):
		return "ring_or_orb"
	if _mentions_any(lower, ["line", "lance", "laser", "beam", "wave"]):
		return "line_or_beam"
	if _mentions_any(lower, ["star", "crit", "flash", "sunburst", "comet"]):
		return "star_or_burst"
	if _mentions_any(lower, ["mark", "stamp", "sigil", "brand", "cross", "rune"]):
		return "mark_or_sigil"
	if _mentions_any(lower, ["claw", "boot", "blade", "slash", "scythe", "weapon"]):
		return "weapon_or_slash"
	if _mentions_any(lower, ["wall", "plate", "dome", "barrier", "shell"]):
		return "barrier"
	if _mentions_any(lower, ["poro", "minion", "summon", "crown"]):
		return "creature"
	return "other:%s" % lower

func _animation_family(motion: String) -> String:
	var lower: String = motion.to_lower()
	if lower == "" or lower == "none":
		return "none"
	if _mentions_any(lower, ["fan", "split", "spread"]):
		return "fan_spread"
	if _mentions_any(lower, ["arc", "homing", "flight", "missile", "bounce"]):
		return "flight_or_bounce"
	if _mentions_any(lower, ["pulse", "pop", "bloom", "burst", "explosion"]):
		return "pulse_burst"
	if _mentions_any(lower, ["orbit", "spin", "clock", "loop"]):
		return "orbit_spin"
	if _mentions_any(lower, ["trail", "dash", "afterimage", "streak", "slide"]):
		return "trail_dash"
	if _mentions_any(lower, ["pull", "drain", "suck", "collapse", "inward"]):
		return "pull_collapse"
	if _mentions_any(lower, ["beam", "laser", "line", "shockwave", "wave"]):
		return "beam_wave"
	return "other:%s" % lower

func _duration_bucket(lifetime: float) -> String:
	if lifetime <= 0.0:
		return "none"
	if lifetime < 0.45:
		return "snap"
	if lifetime < 0.70:
		return "short"
	if lifetime < 0.95:
		return "medium"
	return "long"

func _scale_bucket(scale_value: float) -> String:
	if scale_value < 0.95:
		return "small"
	if scale_value <= 1.10:
		return "medium"
	if scale_value <= 1.30:
		return "large"
	return "huge"

func _particle_usage(particle_style: String, lifecycle: String, motion: String) -> String:
	var lower: String = "%s %s %s" % [particle_style.to_lower(), lifecycle.to_lower(), motion.to_lower()]
	if lower.strip_edges() == "":
		return "none"
	if _mentions_any(lower, ["trail", "streak", "arc", "line"]):
		return "trail"
	if _mentions_any(lower, ["spark", "mote", "dust", "shard", "embers", "drops", "snow", "photons"]):
		return "particles"
	if _mentions_any(lower, ["hold", "aura", "loop"]):
		return "persistent_field"
	return "styled"

func _screen_feedback_usage(spec: Dictionary) -> String:
	if bool(spec.get("screen_shake", false)):
		return "screen_shake"
	if bool(spec.get("screen_flash", false)):
		return "screen_flash"
	if str(spec.get("target_layer", "")) == "screen" or str(spec.get("spawn_anchor", "")).contains("hud"):
		return "hud_or_screen"
	return "none"

func _visual_spec_to_serializable(spec: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in spec.keys():
		var value: Variant = spec[key]
		if value is Color:
			var color: Color = value
			result[key] = "Color(%.3f, %.3f, %.3f, %.3f)" % [color.r, color.g, color.b, color.a]
		elif value is Vector2:
			var vector: Vector2 = value
			result[key] = "Vector2(%.3f, %.3f)" % [vector.x, vector.y]
		else:
			result[key] = value
	return result

func _json_safe_value(value: Variant) -> Variant:
	if value is Dictionary:
		var safe_dict: Dictionary = {}
		for key in (value as Dictionary).keys():
			safe_dict[str(key)] = _json_safe_value((value as Dictionary)[key])
		return safe_dict
	if value is Array:
		var safe_array: Array = []
		for item in value:
			safe_array.append(_json_safe_value(item))
		return safe_array
	if value is String:
		return _json_safe_string(str(value))
	if value is StringName:
		return _json_safe_string(str(value))
	if value is Color:
		var color: Color = value
		return "Color(%.3f, %.3f, %.3f, %.3f)" % [color.r, color.g, color.b, color.a]
	if value is Vector2:
		var vector: Vector2 = value
		return "Vector2(%.3f, %.3f)" % [vector.x, vector.y]
	if value is Node:
		var node: Node = value
		return "Node:%s" % node.name
	if value == null or value is bool or value is int or value is float:
		return value
	return _json_safe_string(str(value))

func _json_safe_string(value: String) -> String:
	var normalized: String = value.replace("\r", " ").replace("\n", " ").replace("\t", " ")
	normalized = normalized.replace("\"", "'").replace("\\", "/")
	var result: String = ""
	for index in range(normalized.length()):
		var codepoint: int = normalized.unicode_at(index)
		if codepoint >= 32 and codepoint <= 126:
			result += char(codepoint)
		elif codepoint == 160:
			result += " "
		else:
			result += "?"
	return result

func _unique_strings(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		if value != "" and not result.has(value):
			result.append(value)
	return result

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

func _ensure_parent_dir(path: String) -> void:
	var dir_path: String = path.get_base_dir()
	if dir_path == "":
		return
	if dir_path.begins_with("res://"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	else:
		DirAccess.make_dir_recursive_absolute(dir_path)

func _free_node(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()
