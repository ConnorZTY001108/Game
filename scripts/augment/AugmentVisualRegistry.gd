class_name AugmentVisualRegistry
extends Node

const REQUIRED_FIELDS: Array[String] = [
	"visual_signature",
	"visual_recipe_key",
	"effect_family",
	"category",
	"color",
	"shape",
	"motion",
	"particle_style",
	"trigger_events",
]

const SUPPORTED_EVENTS: Array[String] = [
	"augment_acquired",
	"augment_effect_triggered",
	"weapon_fired",
	"projectile_spawned",
	"projectile_hit",
	"damage_applied_packet",
	"burn_stack_applied",
	"rift_chain_triggered",
	"shield_gained",
	"heal_received",
	"dash_started",
	"augment_periodic_tick",
]

const ROUTE_CATEGORY: Dictionary = {
	"inferno_conduit": "burn",
	"void_cascade": "void",
	"summon_engine": "summon",
	"snowstep_vanguard": "dash",
	"rune_volley": "projectile",
	"colossus_furnace": "shield",
	"aegis_transmutation": "shield",
	"quest_forge": "forge",
	"blood_reaver": "lifesteal",
}

const CATEGORY_FAMILY: Dictionary = {
	"bullet": "projectile_trajectory",
	"projectile": "projectile_trajectory",
	"burn": "burn_flame",
	"void": "void_rift",
	"storm": "storm_arc",
	"shield": "shield_barrier",
	"summon": "summon_companion",
	"dash": "dash_afterimage",
	"cooldown": "cooldown_clock",
	"crit": "crit_shard",
	"lifesteal": "lifesteal_blood_drain",
	"forge": "forge_choice_card",
	"choice": "forge_choice_card",
}

const CATEGORY_COLORS: Dictionary = {
	"bullet": Color(0.64, 0.84, 1.0, 0.95),
	"projectile": Color(0.50, 0.78, 1.0, 0.95),
	"burn": Color(1.0, 0.34, 0.12, 0.95),
	"void": Color(0.48, 0.30, 0.86, 0.95),
	"storm": Color(0.34, 0.92, 1.0, 0.95),
	"shield": Color(0.35, 0.95, 0.74, 0.95),
	"summon": Color(0.88, 0.82, 0.44, 0.95),
	"dash": Color(0.82, 0.92, 1.0, 0.95),
	"cooldown": Color(0.70, 0.76, 0.92, 0.95),
	"crit": Color(1.0, 0.92, 0.30, 0.95),
	"lifesteal": Color(0.98, 0.16, 0.28, 0.95),
	"forge": Color(1.0, 0.62, 0.18, 0.95),
	"choice": Color(1.0, 0.62, 0.18, 0.95),
}

const CATEGORY_SHAPES: Dictionary = {
	"bullet": ["projectile_arrow", "trajectory_dash", "split_prongs", "link_beam"],
	"projectile": ["projectile_arrow", "trajectory_dash", "split_prongs", "link_beam"],
	"burn": ["flame_diamond", "ember_ring", "detonation_star", "burn_wave"],
	"void": ["rift_ring", "void_diamond", "collapse_spiral", "chain_link"],
	"storm": ["lightning_bolt", "storm_arc", "spark_cross", "chain_zap"],
	"shield": ["barrier_ring", "aegis_hex", "shield_wall", "protection_pulse"],
	"summon": ["companion_orbit", "minion_badge", "summon_gate", "orbit_laser"],
	"dash": ["dash_trail", "blink_afterimage", "snowstep_streak", "dropkick_line"],
	"cooldown": ["cooldown_clock", "refund_loop", "timer_pulse", "reset_tick"],
	"crit": ["crit_shard", "burst_star", "precision_cross", "gold_spark"],
	"lifesteal": ["blood_drain", "heal_drop", "reaver_claw", "vampiric_arc"],
	"forge": ["forge_card", "transmute_hex", "choice_sigil", "reward_stamp"],
	"choice": ["forge_card", "transmute_hex", "choice_sigil", "reward_stamp"],
}

const CATEGORY_MOTIONS: Dictionary = {
	"bullet": ["projectile_forward", "trajectory_sweep", "split_fan", "link_snap"],
	"projectile": ["projectile_forward", "trajectory_sweep", "split_fan", "link_snap"],
	"burn": ["ember_rise", "flame_pulse", "detonation_pop", "aura_flicker"],
	"void": ["rift_expand", "collapse_inward", "chain_step", "void_wobble"],
	"storm": ["arc_jump", "spark_burst", "zap_fork", "storm_spin"],
	"shield": ["barrier_expand", "aegis_lock", "ring_hold", "shield_breathe"],
	"summon": ["orbit_enter", "gate_open", "companion_pop", "laser_sweep"],
	"dash": ["trail_stretch", "afterimage_fade", "blink_flash", "dash_kick"],
	"cooldown": ["clock_spin", "refund_snap", "tick_pulse", "reset_wipe"],
	"crit": ["shard_burst", "precision_flash", "spark_scatter", "crit_pop"],
	"lifesteal": ["drain_pull", "blood_arc", "heal_return", "pact_pulse"],
	"forge": ["card_flip", "transmute_glow", "choice_slide", "reward_pop"],
	"choice": ["card_flip", "transmute_glow", "choice_slide", "reward_pop"],
}

const CATEGORY_PARTICLES: Dictionary = {
	"bullet": ["projectile_sparks", "trajectory_dust", "split_fragments", "link_motes"],
	"projectile": ["projectile_sparks", "trajectory_dust", "split_fragments", "link_motes"],
	"burn": ["embers", "flame_lift", "ash_burst", "heat_sparks"],
	"void": ["rift_motes", "void_shards", "collapse_dust", "chain_stars"],
	"storm": ["electric_sparks", "arc_motes", "zap_shards", "storm_static"],
	"shield": ["barrier_motes", "aegis_sparks", "shield_runes", "protection_dust"],
	"summon": ["summon_motes", "companion_sparks", "gate_stars", "orbit_dust"],
	"dash": ["trail_motes", "afterimage_sparks", "snow_dust", "blink_stars"],
	"cooldown": ["clock_ticks", "refund_sparks", "timer_motes", "reset_dust"],
	"crit": ["crit_sparks", "shard_motes", "gold_burst", "precision_glints"],
	"lifesteal": ["blood_motes", "drain_sparks", "heal_stars", "pact_dust"],
	"forge": ["forge_sparks", "choice_glints", "transmute_dust", "reward_motes"],
	"choice": ["forge_sparks", "choice_glints", "transmute_dust", "reward_motes"],
}

var _specs: Dictionary = {}

func rebuild_from_augment_registry(augment_registry: Node) -> void:
	_specs.clear()
	if augment_registry == null:
		return
	var all_augments: Array = augment_registry.call("get_all")
	for index in range(all_augments.size()):
		var augment := all_augments[index] as Resource
		if augment == null:
			continue
		var augment_id := str(augment.get("id"))
		if augment_id == "":
			continue
		_specs[augment_id] = _build_spec(augment, index)

func validate_against_augment_registry(augment_registry: Node) -> Array[String]:
	rebuild_from_augment_registry(augment_registry)
	var errors: Array[String] = []
	if augment_registry == null:
		return ["AugmentVisualRegistry missing AugmentRegistry"]
	var seen_signatures: Dictionary = {}
	for augment in augment_registry.call("get_all"):
		var augment_id := str(augment.get("id"))
		if not _specs.has(augment_id):
			errors.append("missing_visual_spec:%s" % augment_id)
			continue
		var spec: Dictionary = _specs[augment_id]
		for field in REQUIRED_FIELDS:
			if not spec.has(field):
				errors.append("%s:missing_visual_field:%s" % [augment_id, field])
		var signature := str(spec.get("visual_signature", ""))
		var recipe_key := str(spec.get("visual_recipe_key", ""))
		if signature == "":
			errors.append("%s:empty_visual_signature" % augment_id)
		elif seen_signatures.has(signature):
			errors.append("%s:duplicate_visual_signature:%s" % [augment_id, signature])
		else:
			seen_signatures[signature] = augment_id
		if recipe_key == "" or recipe_key.contains(augment_id):
			errors.append("%s:invalid_visual_recipe_key:%s" % [augment_id, recipe_key])
		var triggers := _to_string_array(spec.get("trigger_events", []))
		if triggers.is_empty():
			errors.append("%s:missing_trigger_events" % augment_id)
		for trigger in triggers:
			if not SUPPORTED_EVENTS.has(trigger):
				errors.append("%s:unsupported_trigger_event:%s" % [augment_id, trigger])
	return errors

func has_spec(augment_id: String) -> bool:
	return _specs.has(augment_id)

func get_spec(augment_id: String) -> Dictionary:
	if not _specs.has(augment_id):
		return {}
	return (_specs[augment_id] as Dictionary).duplicate(true)

func get_all_specs() -> Dictionary:
	return _specs.duplicate(true)

func _build_spec(augment: Resource, index: int) -> Dictionary:
	var augment_id := str(augment.get("id"))
	var route_id := str(augment.get("route_id"))
	var text := _augment_search_text(augment)
	var category := _infer_category(route_id, text)
	var family := str(CATEGORY_FAMILY.get(category, category))
	var variant := _stable_variant(augment_id, index)
	var color := _variant_color(CATEGORY_COLORS.get(category, Color.WHITE), variant)
	var shape := _pick(CATEGORY_SHAPES.get(category, ["projectile_arrow"]), variant)
	var motion := _pick(CATEGORY_MOTIONS.get(category, ["projectile_forward"]), variant / 3)
	var particle_style := _pick(CATEGORY_PARTICLES.get(category, ["projectile_sparks"]), variant / 7)
	var trigger_events := _trigger_events_for(augment, category)
	var line_style := _line_style_for(category, variant)
	var target_layer := "hud" if category in ["forge", "choice"] else "world"
	var scale := 0.85 + float(variant % 5) * 0.12
	var lifetime := 0.55 + float(variant % 6) * 0.07
	var recipe_key := _visual_recipe_key(family, category, color, shape, motion, particle_style, line_style, target_layer, scale, lifetime, variant)
	return {
		"augment_id": augment_id,
		"visual_signature": recipe_key,
		"visual_recipe_key": recipe_key,
		"effect_family": family,
		"category": category,
		"color": color,
		"shape": shape,
		"motion": motion,
		"particle_style": particle_style,
		"line_style": line_style,
		"trigger_events": trigger_events,
		"target_layer": target_layer,
		"scale": scale,
		"lifetime": lifetime,
	}

func _infer_category(route_id: String, text: String) -> String:
	if text.contains("cooldown") or text.contains("refund") or text.contains("reset"):
		return "cooldown"
	if text.contains("crit") or text.contains("critical") or text.contains("precision"):
		return "crit"
	if text.contains("lifesteal") or text.contains("vampir") or text.contains("blood") or text.contains("drain"):
		return "lifesteal"
	if text.contains("storm") or text.contains("lightning") or text.contains("typhoon") or text.contains("chain_lightning"):
		return "storm"
	if text.contains("burn") or text.contains("flame") or text.contains("fire") or text.contains("infernal") or text.contains("immolate"):
		return "burn"
	if text.contains("void") or text.contains("rift") or text.contains("collapse"):
		return "void"
	if text.contains("shield") or text.contains("barrier") or text.contains("aegis") or text.contains("protection"):
		return "shield"
	if text.contains("dash") or text.contains("blink") or text.contains("snowstep") or text.contains("afterimage"):
		return "dash"
	if text.contains("forge") or text.contains("choice") or text.contains("transmute") or text.contains("pandora") or text.contains("gold"):
		return "forge"
	if text.contains("summon") or text.contains("minion") or text.contains("poro") or text.contains("companion"):
		return "summon"
	if text.contains("projectile") or text.contains("missile") or text.contains("boomerang") or text.contains("shard") or text.contains("volley"):
		return "projectile"
	return str(ROUTE_CATEGORY.get(route_id, "projectile"))

func _trigger_events_for(augment: Resource, category: String) -> Array[String]:
	var result: Array[String] = ["augment_acquired", "augment_effect_triggered"]
	var trigger = augment.get("trigger")
	if trigger != null:
		for signal_name in _to_string_array(trigger.get("signal_names")):
			var mapped := _map_supported_event(signal_name)
			if mapped != "" and not result.has(mapped):
				result.append(mapped)
	var trigger_id := ""
	if trigger != null:
		trigger_id = str(trigger.get("trigger_id"))
	if trigger_id == "":
		trigger_id = str(augment.get("source_trigger"))
	for event_name in _events_for_trigger_or_category(trigger_id, category):
		if not result.has(event_name):
			result.append(event_name)
	return result

func _events_for_trigger_or_category(trigger_id: String, category: String) -> Array[String]:
	var trigger_text := trigger_id.to_lower()
	if trigger_text.contains("attack") or trigger_text.contains("fire"):
		return ["weapon_fired", "projectile_spawned"]
	if trigger_text.contains("projectile"):
		return ["projectile_spawned", "projectile_hit"]
	if trigger_text.contains("hit") or trigger_text.contains("damage") or trigger_text.contains("crit") or trigger_text.contains("skill"):
		return ["damage_applied_packet", "projectile_hit"]
	if trigger_text.contains("burn"):
		return ["burn_stack_applied"]
	if trigger_text.contains("rift"):
		return ["rift_chain_triggered"]
	if trigger_text.contains("shield"):
		return ["shield_gained"]
	if trigger_text.contains("heal") or trigger_text.contains("regen"):
		return ["heal_received"]
	if trigger_text.contains("dash") or trigger_text.contains("blink"):
		return ["dash_started"]
	if trigger_text.contains("periodic") or trigger_text.contains("aura") or trigger_text.contains("pickup"):
		return ["augment_periodic_tick"]
	if category in ["bullet", "projectile", "storm"]:
		return ["projectile_spawned", "projectile_hit"]
	if category == "burn":
		return ["burn_stack_applied", "damage_applied_packet"]
	if category == "void":
		return ["rift_chain_triggered", "damage_applied_packet"]
	if category == "shield":
		return ["shield_gained", "damage_applied_packet"]
	if category == "lifesteal":
		return ["heal_received", "damage_applied_packet"]
	if category == "dash":
		return ["dash_started"]
	if category in ["forge", "choice", "cooldown", "summon"]:
		return ["augment_periodic_tick"]
	return ["damage_applied_packet"]

func _map_supported_event(signal_name: String) -> String:
	if SUPPORTED_EVENTS.has(signal_name):
		return signal_name
	if signal_name in ["damage_roll_requested", "dot_tick", "burn_stack_threshold", "control_applied", "shield_broken", "regen_tick", "enemy_died", "elite_killed", "boss_damaged"]:
		return "damage_applied_packet"
	if signal_name in ["dash_finished", "blink_used"]:
		return "dash_started"
	if signal_name in ["pickup_collected", "level_changed", "wave_phase_started"]:
		return "augment_periodic_tick"
	return ""

func _augment_search_text(augment: Resource) -> String:
	var parts: Array[String] = [
		str(augment.get("id")),
		str(augment.get("route_id")),
		str(augment.get("source_trigger")),
		str(augment.get("effect")),
		str(augment.get("description")),
	]
	var trigger = augment.get("trigger")
	if trigger != null:
		parts.append(str(trigger.get("trigger_id")))
		parts.append(str(trigger.get("signal_names")))
	for effect in augment.get("effects"):
		if effect == null:
			continue
		parts.append(str(effect.get("effect_type")))
		if effect.has_method("get_effect_family"):
			parts.append(str(effect.call("get_effect_family")))
		parts.append(str(effect.get("params")))
	return " ".join(parts).to_lower()

func _variant_color(base_color: Color, variant: int) -> Color:
	var hue_shift := float(variant % 9) * 0.018
	var saturation_delta := float((variant / 3) % 4) * 0.035
	var value_delta := float((variant / 5) % 4) * 0.04
	return Color.from_hsv(
		fposmod(base_color.h + hue_shift, 1.0),
		clampf(base_color.s + saturation_delta, 0.35, 1.0),
		clampf(base_color.v + value_delta, 0.45, 1.0),
		base_color.a
	)

func _line_style_for(category: String, variant: int) -> String:
	var suffixes: Array[String] = ["solid", "double", "dotted", "wide"]
	return "%s_%s" % [category, suffixes[variant % suffixes.size()]]

func _visual_recipe_key(family: String, category: String, color: Color, shape: String, motion: String, particle_style: String, line_style: String, target_layer: String, scale: float, lifetime: float, variant: int) -> String:
	return "%s|%s|%s|%s|%s|%s|%s|%s|s%.2f|t%.2f|phase%03d" % [
		family,
		category,
		shape,
		motion,
		particle_style,
		line_style,
		target_layer,
		_color_key(color),
		scale,
		lifetime,
		variant % 997,
	]

func _color_key(color: Color) -> String:
	return "%02x%02x%02x%02x" % [
		int(round(color.r * 255.0)),
		int(round(color.g * 255.0)),
		int(round(color.b * 255.0)),
		int(round(color.a * 255.0)),
	]

func _pick(values: Array, variant: int) -> String:
	if values.is_empty():
		return ""
	return str(values[abs(variant) % values.size()])

func _stable_variant(augment_id: String, index: int) -> int:
	return abs(augment_id.hash() + index * 31)

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
