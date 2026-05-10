class_name AugmentEffectSpec
extends Resource

const KNOWN_EFFECT_TYPES: Array[String] = [
	"activate_cooldown_mode",
	"add_burn_stack",
	"add_dot",
	"add_stack_on_crit",
	"add_true_damage",
	"add_true_damage_to_all_damage",
	"apply_control",
	"apply_damage_and_vulnerability",
	"apply_on_hit_package",
	"apply_shield",
	"apply_state_at_threshold",
	"auto_blink",
	"below_half_regen",
	"boost_heal_conversion",
	"bounce_projectile_or_rift",
	"burn_threshold_explosion",
	"charge_on_hit",
	"cleanse_control",
	"collision_explosion",
	"contact_effect_while_invulnerable",
	"control_grants_resists",
	"control_grants_shield",
	"control_spawn_delayed_strike",
	"control_stack_resists",
	"control_to_burn",
	"convert_heal_to_damage",
	"convert_overflow_stat",
	"convert_shield_heal_to_burn",
	"convert_stat",
	"convert_unbroken_shield_to_pickup_radius",
	"counter_on_event",
	"damage_scale_by_speed_delta",
	"dash_blink_end_explosion",
	"dash_or_blink",
	"dash_path_execute",
	"dash_speed_burst",
	"dash_toward_mark_on_movement",
	"dot_splash",
	"drop_pickup",
	"drop_pickup_on_damage",
	"dual_stack",
	"elite_kill_stealth",
	"enable_crit_sources",
	"enable_dot_crit",
	"enable_heal_shield_crit",
	"enter_stasis",
	"execute_low_hp",
	"explode_absorbed_damage",
	"grant_blink_charge",
	"grant_currency",
	"grant_currency_or_progress_on_aura_death",
	"grant_forge_choice",
	"grant_next_choice_refresh",
	"grant_omnivamp",
	"grant_random_augment",
	"grant_random_augments",
	"grant_stored_shield",
	"heal_player",
	"long_range_bonus_projectile",
	"low_hp_defense_burst",
	"manual_blink",
	"max_hp_damage",
	"missing_hp_scaling",
	"mixed_damage_burst",
	"modify_adaptive_force",
	"modify_aura_radius",
	"modify_body_scale",
	"modify_damage",
	"modify_damage_healing",
	"modify_damage_vs_status",
	"modify_damage_while_shielded",
	"modify_incoming_hit_profile",
	"modify_max_health",
	"modify_mobility_cooldowns",
	"modify_next_option_count",
	"modify_pickup_healing",
	"modify_stat",
	"open_gold_window_on_elite_boss_hit",
	"periodic_aura",
	"periodic_auto_mark",
	"periodic_boomerang",
	"periodic_cluster_strike",
	"periodic_homing_projectiles",
	"periodic_invulnerability_star",
	"periodic_laser",
	"periodic_pickup_spawn",
	"periodic_self_drain",
	"periodic_slash",
	"periodic_taunt_pulse",
	"permanent_max_health_on_control",
	"prevent_fatal_damage",
	"progress_on_control_normal",
	"progress_quest",
	"protection_pulse",
	"quest_progress",
	"refund_cooldown",
	"refund_cooldown_on_dot",
	"refund_mobility_cooldown_on_xp",
	"refund_self_cooldown_on_elite_kill",
	"regional_counter",
	"replace_every_nth_on_class",
	"reroll_augment",
	"reroll_owned_augment",
	"rift_pair_explosion",
	"roll_crit",
	"scale_summons",
	"self_damage_on_cast",
	"set_pending_next_hit",
	"shield_end_explosion",
	"skill_hit_speed_buff",
	"spawn_delayed_strike",
	"spawn_healing_wave_on_crit",
	"spawn_projectile",
	"spawn_projectile_at_full_charge",
	"spawn_rift",
	"spawn_shockwave",
	"spawn_summon",
	"spawn_zone",
	"split_projectile",
	"stack_on_target",
	"stack_resistance_shred",
	"stack_while_shielded_or_recent_heal",
	"summon_on_elite_kill_or_pickup",
	"temporary_damage_reduction",
	"temporary_mode",
	"temporary_resists_on_protection"
]

@export var effect_type: String = ""
@export var effect_family: String = ""
@export var params: Dictionary = {}
@export var tags: Array[String] = []
@export var source_cooldown: float = 0.0
@export var per_target_cooldown: float = 0.0
@export var max_proc_depth: int = 2
@export var blocks_same_family_recursion: bool = true

func get_effect_family() -> String:
	return effect_family if effect_family != "" else effect_type

func validate() -> Array[String]:
	var errors: Array[String] = []
	if effect_type == "":
		errors.append("effect_missing_type")
	elif not KNOWN_EFFECT_TYPES.has(effect_type):
		errors.append("effect_unknown_type:%s" % effect_type)
	if not params is Dictionary:
		errors.append("effect_params_not_dictionary")
	if source_cooldown < 0.0:
		errors.append("effect_negative_source_cooldown")
	if per_target_cooldown < 0.0:
		errors.append("effect_negative_per_target_cooldown")
	if max_proc_depth < 0:
		errors.append("effect_negative_max_proc_depth")
	return errors

func to_runtime_metadata() -> Dictionary:
	return {
		"effect_type": effect_type,
		"effect_family": get_effect_family(),
		"params": params.duplicate(true),
		"tags": tags.duplicate(),
		"source_cooldown": source_cooldown,
		"per_target_cooldown": per_target_cooldown,
		"max_proc_depth": max_proc_depth,
		"blocks_same_family_recursion": blocks_same_family_recursion
	}

func apply_blueprint(blueprint: Dictionary) -> void:
	effect_type = str(blueprint.get("effect_type", ""))
	effect_family = str(blueprint.get("effect_family", effect_type))
	var next_params = blueprint.get("params", {})
	params = next_params.duplicate(true) if next_params is Dictionary else {}
	tags = _to_string_array(blueprint.get("tags", []))
	source_cooldown = max(0.0, float(blueprint.get("source_cooldown", params.get("source_cooldown", 0.0))))
	per_target_cooldown = max(0.0, float(blueprint.get("per_target_cooldown", params.get("per_target_cooldown", 0.0))))
	max_proc_depth = max(0, int(blueprint.get("max_proc_depth", params.get("max_proc_depth", 2))))
	blocks_same_family_recursion = bool(blueprint.get("blocks_same_family_recursion", true))

func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result
