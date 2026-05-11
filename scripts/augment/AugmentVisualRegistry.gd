class_name AugmentVisualRegistry
extends Node

const REQUIRED_FIELDS: Array[String] = [
	"visual_signature",
	"visual_recipe_key",
	"effect_family",
	"category",
	"color",
	"accent_color",
	"shape",
	"motion",
	"particle_style",
	"spawn_anchor",
	"trigger_timing",
	"lifecycle",
	"trigger_events",
	"target_layer",
	"scale",
	"lifetime",
]

const SUPPORTED_EVENTS: Array[String] = [
	"augment_acquired",
	"augment_effect_triggered",
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

const AUGMENT_VISUAL_OVERRIDES: Dictionary = {
	"aug_rune_dual_wield": {"category": "projectile", "effect_family": "offhand_rune", "color": Color(0.30, 0.78, 1.00, 0.96), "accent_color": Color(1.00, 0.90, 0.35, 0.92), "shape": "paired_rune_blades", "motion": "dual_muzzle_fan", "particle_style": "blue_rune_sparks", "spawn_anchor": "muzzle", "trigger_timing": "on_weapon_fired", "lifecycle": "short_trail", "scale": 1.00, "lifetime": 0.42},
	"aug_typhoon_split": {"category": "storm", "effect_family": "split_projectile", "color": Color(0.46, 0.92, 1.00, 0.94), "accent_color": Color(0.95, 1.00, 1.00, 0.90), "shape": "forked_arrow_fan", "motion": "split_after_hit", "particle_style": "wind_splinters", "spawn_anchor": "hit_target", "trigger_timing": "after_projectile_hit", "lifecycle": "fan_pop", "scale": 0.95, "lifetime": 0.48},
	"aug_jeweled_rune": {"category": "crit", "effect_family": "crit_converter", "color": Color(1.00, 0.86, 0.32, 0.95), "accent_color": Color(0.72, 0.96, 1.00, 0.90), "shape": "jewel_crit_crown", "motion": "damage_roll_glint", "particle_style": "prism_dust", "spawn_anchor": "target_core", "trigger_timing": "on_damage_roll", "lifecycle": "single_glint", "scale": 0.90, "lifetime": 0.52},
	"aug_critical_shards": {"category": "crit", "effect_family": "crit_shard", "color": Color(1.00, 0.78, 0.18, 0.96), "accent_color": Color(1.00, 1.00, 0.68, 0.90), "shape": "golden_shard_burst", "motion": "homing_shard_spread", "particle_style": "crit_glints", "spawn_anchor": "crit_target", "trigger_timing": "on_crit", "lifecycle": "shard_flight", "scale": 1.05, "lifetime": 0.58},
	"aug_ethereal_weapon": {"category": "projectile", "effect_family": "ethereal_on_hit", "color": Color(0.66, 0.92, 1.00, 0.78), "accent_color": Color(0.90, 0.78, 1.00, 0.80), "shape": "ghost_weapon_overlay", "motion": "onhit_copy_echo", "particle_style": "pale_wisps", "spawn_anchor": "skill_hit_target", "trigger_timing": "on_skill_hit", "lifecycle": "ghost_echo", "scale": 0.96, "lifetime": 0.60},
	"aug_press_chain": {"category": "projectile", "effect_family": "press_chain", "color": Color(0.98, 0.66, 0.28, 0.95), "accent_color": Color(1.00, 0.25, 0.20, 0.90), "shape": "triple_ring_stamp", "motion": "three_hit_snap", "particle_style": "impact_ticks", "spawn_anchor": "target_feet", "trigger_timing": "third_hit", "lifecycle": "counter_stamp", "scale": 1.08, "lifetime": 0.46},
	"aug_crit_cast_engine": {"category": "cooldown", "effect_family": "crit_to_haste", "color": Color(0.94, 0.82, 1.00, 0.94), "accent_color": Color(1.00, 0.92, 0.30, 0.90), "shape": "crit_to_clock_sigil", "motion": "stat_conversion_spin", "particle_style": "clock_sparks", "spawn_anchor": "owner_hud", "trigger_timing": "passive_recalc", "lifecycle": "hud_spin", "scale": 0.92, "lifetime": 0.70},
	"aug_collector_mark": {"category": "projectile", "effect_family": "execute_low_hp", "color": Color(1.00, 0.82, 0.22, 0.96), "accent_color": Color(0.35, 0.20, 0.08, 0.90), "shape": "execute_cross_mark", "motion": "low_hp_cutdown", "particle_style": "coin_shards", "spawn_anchor": "target_head", "trigger_timing": "on_low_hp_damage", "lifecycle": "execute_flash", "scale": 1.10, "lifetime": 0.44},
	"aug_infernal_conduit": {"category": "burn", "effect_family": "rune_fire", "color": Color(1.00, 0.32, 0.08, 0.96), "accent_color": Color(1.00, 0.74, 0.18, 0.92), "shape": "rune_fire_lash", "motion": "burn_attach", "particle_style": "ember_stream", "spawn_anchor": "target_center", "trigger_timing": "skill_or_rune_hit", "lifecycle": "sticky_flame", "scale": 1.00, "lifetime": 0.66},
	"aug_firebrand_runes": {"category": "burn", "effect_family": "firebrand", "color": Color(1.00, 0.24, 0.06, 0.95), "accent_color": Color(0.35, 0.05, 0.02, 0.88), "shape": "branded_rune_stamp", "motion": "brand_pulse", "particle_style": "hot_cinders", "spawn_anchor": "target_chest", "trigger_timing": "on_burn_apply", "lifecycle": "brand_pulse", "scale": 0.94, "lifetime": 0.72},
	"aug_slow_cooker_aura": {"category": "burn", "effect_family": "simmer_aura", "color": Color(1.00, 0.46, 0.14, 0.72), "accent_color": Color(0.88, 0.22, 0.08, 0.62), "shape": "simmering_aura_ring", "motion": "slow_orbit_flicker", "particle_style": "heat_haze", "spawn_anchor": "owner_radius", "trigger_timing": "periodic_aura_tick", "lifecycle": "area_hold", "scale": 1.30, "lifetime": 0.95},
	"aug_chili_oil": {"category": "burn", "effect_family": "chili_oil", "color": Color(1.00, 0.18, 0.05, 0.96), "accent_color": Color(1.00, 0.92, 0.10, 0.90), "shape": "oil_slick_flare", "motion": "threshold_floor_bloom", "particle_style": "sizzling_drops", "spawn_anchor": "target_feet", "trigger_timing": "burn_stack_threshold", "lifecycle": "floor_flare", "scale": 1.18, "lifetime": 0.62},
	"aug_holy_fire_conversion": {"category": "burn", "effect_family": "holy_fire", "color": Color(1.00, 0.88, 0.55, 0.92), "accent_color": Color(1.00, 0.30, 0.10, 0.90), "shape": "white_flame_wing", "motion": "heal_to_flame_arc", "particle_style": "sacred_embers", "spawn_anchor": "owner_to_target", "trigger_timing": "shield_or_heal_conversion", "lifecycle": "arc_transfer", "scale": 1.00, "lifetime": 0.64},
	"aug_vulnerable_flame": {"category": "burn", "effect_family": "vulnerable_flame", "color": Color(1.00, 0.40, 0.09, 0.96), "accent_color": Color(0.10, 0.02, 0.02, 0.90), "shape": "cracked_fire_vuln", "motion": "armor_crack_pop", "particle_style": "black_ash", "spawn_anchor": "target_core", "trigger_timing": "burned_damage", "lifecycle": "crack_pop", "scale": 1.02, "lifetime": 0.50},
	"aug_tormentor_brand": {"category": "burn", "effect_family": "tormentor_brand", "color": Color(0.86, 0.08, 0.06, 0.96), "accent_color": Color(1.00, 0.48, 0.12, 0.90), "shape": "thorn_flame_brand", "motion": "control_burn_squeeze", "particle_style": "red_sparks", "spawn_anchor": "target_spine", "trigger_timing": "control_or_burn", "lifecycle": "squeeze_mark", "scale": 1.06, "lifetime": 0.68},
	"aug_infernal_detonation": {"category": "burn", "effect_family": "infernal_detonation", "color": Color(1.00, 0.52, 0.04, 0.98), "accent_color": Color(1.00, 1.00, 0.30, 0.92), "shape": "detonation_sunburst", "motion": "burn_stack_implode_then_pop", "particle_style": "ash_ring", "spawn_anchor": "target_center", "trigger_timing": "burn_detonate", "lifecycle": "implosion_explosion", "scale": 1.35, "lifetime": 0.55},
	"aug_void_rift": {"category": "void", "effect_family": "void_rift", "color": Color(0.50, 0.25, 0.95, 0.94), "accent_color": Color(0.08, 0.02, 0.18, 0.88), "shape": "violet_rift_ring", "motion": "rift_tear_open", "particle_style": "void_motes", "spawn_anchor": "hit_position", "trigger_timing": "on_hit", "lifecycle": "rift_open", "scale": 1.08, "lifetime": 0.78},
	"aug_magic_missile": {"category": "void", "effect_family": "magic_missile", "color": Color(0.66, 0.42, 1.00, 0.95), "accent_color": Color(0.36, 0.82, 1.00, 0.90), "shape": "arcane_missile_comet", "motion": "curved_homing_arc", "particle_style": "purple_trail", "spawn_anchor": "owner_to_target", "trigger_timing": "proc_projectile", "lifecycle": "missile_arc", "scale": 0.92, "lifetime": 0.62},
	"aug_trueshot_prod": {"category": "void", "effect_family": "trueshot_prod", "color": Color(0.38, 0.85, 1.00, 0.94), "accent_color": Color(0.76, 0.56, 1.00, 0.90), "shape": "longshot_lance_line", "motion": "distant_pierce_flash", "particle_style": "starlight_bits", "spawn_anchor": "projectile_tip", "trigger_timing": "long_range_hit", "lifecycle": "pierce_line", "scale": 1.12, "lifetime": 0.38},
	"aug_erosion_loop": {"category": "void", "effect_family": "erosion_loop", "color": Color(0.42, 0.16, 0.72, 0.92), "accent_color": Color(0.12, 0.90, 0.72, 0.84), "shape": "corrosion_spiral", "motion": "looping_decay_crawl", "particle_style": "void_dust", "spawn_anchor": "target_skin", "trigger_timing": "void_dot_tick", "lifecycle": "decay_loop", "scale": 0.98, "lifetime": 0.82},
	"aug_hextech_chain": {"category": "storm", "effect_family": "hextech_chain", "color": Color(0.32, 0.92, 1.00, 0.95), "accent_color": Color(0.70, 0.42, 1.00, 0.90), "shape": "hex_chain_link", "motion": "node_to_node_snap", "particle_style": "electric_hex_motes", "spawn_anchor": "chain_targets", "trigger_timing": "chain_step", "lifecycle": "link_snap", "scale": 1.05, "lifetime": 0.45},
	"aug_pinball_rift": {"category": "void", "effect_family": "pinball_rift", "color": Color(0.70, 0.36, 1.00, 0.95), "accent_color": Color(0.28, 0.05, 0.52, 0.88), "shape": "ricochet_rift_disk", "motion": "bounce_angle_pop", "particle_style": "rebound_stars", "spawn_anchor": "bounce_point", "trigger_timing": "rift_bounce", "lifecycle": "ricochet_pop", "scale": 0.96, "lifetime": 0.44},
	"aug_duality_charge": {"category": "void", "effect_family": "duality_charge", "color": Color(0.26, 0.18, 0.92, 0.93), "accent_color": Color(0.96, 0.92, 1.00, 0.90), "shape": "twin_orb_charge", "motion": "alternating_orbit_pulse", "particle_style": "dual_sparks", "spawn_anchor": "owner_sides", "trigger_timing": "dual_stack_ready", "lifecycle": "charge_orbit", "scale": 1.06, "lifetime": 0.74},
	"aug_void_collapse": {"category": "void", "effect_family": "void_collapse", "color": Color(0.20, 0.04, 0.34, 0.96), "accent_color": Color(0.88, 0.44, 1.00, 0.90), "shape": "collapse_black_sun", "motion": "inward_suck_then_strike", "particle_style": "gravity_dust", "spawn_anchor": "rift_region", "trigger_timing": "rift_chain_count", "lifecycle": "collapse_strike", "scale": 1.42, "lifetime": 0.72},
	"aug_shield_egg": {"category": "shield", "effect_family": "shield_egg", "color": Color(0.42, 1.00, 0.78, 0.90), "accent_color": Color(1.00, 0.95, 0.70, 0.88), "shape": "egg_barrier_shell", "motion": "shield_crack_hatch", "particle_style": "shell_sparks", "spawn_anchor": "owner_barrier", "trigger_timing": "shield_break_or_gain", "lifecycle": "shell_hatch", "scale": 1.18, "lifetime": 0.70},
	"aug_circle_of_death": {"category": "shield", "effect_family": "death_halo", "color": Color(0.80, 1.00, 0.86, 0.70), "accent_color": Color(0.92, 0.34, 0.62, 0.82), "shape": "death_halo_ring", "motion": "expanding_damage_circle", "particle_style": "pale_runes", "spawn_anchor": "owner_radius", "trigger_timing": "shield_or_heal_damage", "lifecycle": "expanding_ring", "scale": 1.45, "lifetime": 0.82},
	"aug_critical_healing": {"category": "crit", "effect_family": "critical_healing", "color": Color(1.00, 0.92, 0.42, 0.94), "accent_color": Color(0.42, 1.00, 0.72, 0.90), "shape": "heart_cross_shard", "motion": "crit_heal_bloom", "particle_style": "gold_heal_stars", "spawn_anchor": "healed_target", "trigger_timing": "crit_heal", "lifecycle": "heal_bloom", "scale": 1.00, "lifetime": 0.58},
	"aug_windspeaker": {"category": "shield", "effect_family": "windspeaker", "color": Color(0.56, 1.00, 0.86, 0.84), "accent_color": Color(0.70, 0.90, 1.00, 0.82), "shape": "wind_aegis_feather", "motion": "shield_breeze_wrap", "particle_style": "teal_feathers", "spawn_anchor": "ally_or_owner", "trigger_timing": "heal_or_shield", "lifecycle": "breeze_wrap", "scale": 1.04, "lifetime": 0.76},
	"aug_sonic_holy": {"category": "shield", "effect_family": "sonic_holy", "color": Color(0.90, 1.00, 0.82, 0.88), "accent_color": Color(0.64, 0.96, 1.00, 0.86), "shape": "sonic_holy_wave", "motion": "concentric_sound_pulse", "particle_style": "white_notes", "spawn_anchor": "owner_front", "trigger_timing": "protection_pulse", "lifecycle": "sound_pulse", "scale": 1.22, "lifetime": 0.56},
	"aug_big_brain_barrier": {"category": "shield", "effect_family": "stored_barrier", "color": Color(0.34, 1.00, 0.72, 0.88), "accent_color": Color(0.88, 0.72, 1.00, 0.82), "shape": "cerebral_hex_dome", "motion": "hex_grid_lock", "particle_style": "mint_glyphs", "spawn_anchor": "owner_head", "trigger_timing": "level_or_wave_start", "lifecycle": "barrier_hold", "scale": 1.15, "lifetime": 0.92},
	"aug_faith_shockwave": {"category": "shield", "effect_family": "faith_shockwave", "color": Color(1.00, 0.95, 0.62, 0.88), "accent_color": Color(0.42, 1.00, 0.78, 0.84), "shape": "faith_ground_cross", "motion": "forward_shockwave", "particle_style": "dust_halo", "spawn_anchor": "owner_feet", "trigger_timing": "protection_trigger", "lifecycle": "ground_wave", "scale": 1.30, "lifetime": 0.54},
	"aug_laser_heal_array": {"category": "shield", "effect_family": "heal_laser_array", "color": Color(0.34, 1.00, 0.58, 0.90), "accent_color": Color(0.74, 1.00, 0.96, 0.86), "shape": "healing_laser_lattice", "motion": "vertical_beam_array", "particle_style": "green_photons", "spawn_anchor": "target_column", "trigger_timing": "heal_array_tick", "lifecycle": "beam_hold", "scale": 1.12, "lifetime": 0.78},
	"aug_ominous_pact": {"category": "lifesteal", "effect_family": "ominous_pact", "color": Color(0.72, 0.02, 0.10, 0.96), "accent_color": Color(0.18, 0.00, 0.05, 0.90), "shape": "pact_sigil_bloodmoon", "motion": "contract_pulse", "particle_style": "dark_drops", "spawn_anchor": "owner_hud", "trigger_timing": "pact_tick", "lifecycle": "sigil_pulse", "scale": 1.05, "lifetime": 0.78},
	"aug_devil_shoulder": {"category": "lifesteal", "effect_family": "devil_shoulder", "color": Color(1.00, 0.12, 0.18, 0.95), "accent_color": Color(0.35, 0.02, 0.04, 0.88), "shape": "devil_claw_shoulder", "motion": "shoulder_flare_slash", "particle_style": "red_claw_sparks", "spawn_anchor": "owner_side", "trigger_timing": "cast_or_hit", "lifecycle": "claw_slash", "scale": 0.98, "lifetime": 0.46},
	"aug_vampirism": {"category": "lifesteal", "effect_family": "vampirism", "color": Color(0.95, 0.04, 0.18, 0.94), "accent_color": Color(1.00, 0.58, 0.68, 0.84), "shape": "blood_drain_tether", "motion": "target_to_owner_pull", "particle_style": "crimson_droplets", "spawn_anchor": "enemy_to_owner", "trigger_timing": "damage_heal_return", "lifecycle": "drain_return", "scale": 1.04, "lifetime": 0.68},
	"aug_escape_plan": {"category": "lifesteal", "effect_family": "escape_plan", "color": Color(1.00, 0.18, 0.26, 0.92), "accent_color": Color(1.00, 1.00, 1.00, 0.86), "shape": "panic_shield_burst", "motion": "low_hp_knockback_ring", "particle_style": "red_white_sparks", "spawn_anchor": "owner_center", "trigger_timing": "low_hp_entered", "lifecycle": "panic_burst", "scale": 1.28, "lifetime": 0.55},
	"aug_dawn_resolve": {"category": "lifesteal", "effect_family": "dawn_resolve", "color": Color(1.00, 0.45, 0.24, 0.90), "accent_color": Color(1.00, 0.88, 0.50, 0.86), "shape": "dawn_blood_cross", "motion": "low_hp_sunrise_pulse", "particle_style": "warm_heal_motes", "spawn_anchor": "owner_core", "trigger_timing": "below_half_regen", "lifecycle": "sunrise_pulse", "scale": 1.10, "lifetime": 0.82},
	"aug_blood_debt_execute": {"category": "lifesteal", "effect_family": "blood_debt_execute", "color": Color(0.82, 0.00, 0.06, 0.96), "accent_color": Color(1.00, 0.74, 0.20, 0.88), "shape": "debt_execution_scythe", "motion": "delayed_reaver_cut", "particle_style": "coin_blood_spray", "spawn_anchor": "target_head", "trigger_timing": "execute_window", "lifecycle": "scythe_cut", "scale": 1.18, "lifetime": 0.50},
	"aug_final_transit": {"category": "lifesteal", "effect_family": "final_transit", "color": Color(0.18, 0.00, 0.04, 0.94), "accent_color": Color(0.94, 0.04, 0.16, 0.90), "shape": "final_train_shadow", "motion": "fatal_phase_slide", "particle_style": "black_red_trails", "spawn_anchor": "owner_center", "trigger_timing": "fatal_damage_received", "lifecycle": "phase_slide", "scale": 1.22, "lifetime": 0.72},
	"aug_glass_cannon": {"category": "lifesteal", "effect_family": "glass_cannon", "color": Color(1.00, 0.24, 0.28, 0.88), "accent_color": Color(0.82, 0.96, 1.00, 0.84), "shape": "glass_red_cannon", "motion": "fragile_burst_recoil", "particle_style": "glass_shards", "spawn_anchor": "owner_weapon", "trigger_timing": "passive_damage_profile", "lifecycle": "glass_burst", "scale": 1.05, "lifetime": 0.48},
	"aug_holy_snowmark": {"category": "dash", "effect_family": "holy_snowmark", "color": Color(0.82, 0.96, 1.00, 0.92), "accent_color": Color(1.00, 0.94, 0.52, 0.84), "shape": "snow_cross_mark", "motion": "step_mark_flash", "particle_style": "snow_crystals", "spawn_anchor": "dash_path", "trigger_timing": "dash_or_control_mark", "lifecycle": "snow_mark", "scale": 0.98, "lifetime": 0.60},
	"aug_flash2": {"category": "dash", "effect_family": "double_blink", "color": Color(0.72, 0.90, 1.00, 0.88), "accent_color": Color(0.42, 0.58, 1.00, 0.82), "shape": "double_blink_ghost", "motion": "two_pop_afterimage", "particle_style": "blue_stars", "spawn_anchor": "blink_end", "trigger_timing": "blink_used", "lifecycle": "double_pop", "scale": 1.00, "lifetime": 0.38},
	"aug_flashbang": {"category": "dash", "effect_family": "flashbang", "color": Color(1.00, 1.00, 0.92, 0.96), "accent_color": Color(0.72, 0.92, 1.00, 0.86), "shape": "flash_grenade_star", "motion": "whiteout_pop", "particle_style": "blind_sparks", "spawn_anchor": "target_group", "trigger_timing": "blink_or_dash_end", "lifecycle": "whiteout", "scale": 1.20, "lifetime": 0.36},
	"aug_dashing_engine": {"category": "dash", "effect_family": "dashing_engine", "color": Color(0.60, 0.90, 1.00, 0.86), "accent_color": Color(0.92, 1.00, 1.00, 0.78), "shape": "engine_ice_trail", "motion": "accelerating_dash_lines", "particle_style": "frost_vapor", "spawn_anchor": "player_trail", "trigger_timing": "dash_started", "lifecycle": "dash_trail", "scale": 1.08, "lifetime": 0.44},
	"aug_shadow_runner": {"category": "dash", "effect_family": "shadow_runner", "color": Color(0.20, 0.20, 0.38, 0.88), "accent_color": Color(0.66, 0.86, 1.00, 0.78), "shape": "shadow_afterimage_chain", "motion": "fade_dash_clone", "particle_style": "dark_snow", "spawn_anchor": "player_trail", "trigger_timing": "dash_finished", "lifecycle": "afterimage_chain", "scale": 1.00, "lifetime": 0.62},
	"aug_poro_king_bounce": {"category": "dash", "effect_family": "poro_bounce", "color": Color(0.96, 0.92, 1.00, 0.92), "accent_color": Color(1.00, 0.82, 0.32, 0.86), "shape": "poro_crown_bounce", "motion": "squash_bounce_arc", "particle_style": "fluffy_snow", "spawn_anchor": "bounce_target", "trigger_timing": "bounce_trigger", "lifecycle": "bounce_arc", "scale": 1.04, "lifetime": 0.58},
	"aug_dropkick_dash": {"category": "dash", "effect_family": "dropkick_dash", "color": Color(0.90, 0.96, 1.00, 0.94), "accent_color": Color(1.00, 0.42, 0.22, 0.88), "shape": "boot_impact_line", "motion": "dash_kick_streak", "particle_style": "impact_snow", "spawn_anchor": "dash_end_target", "trigger_timing": "dash_hit", "lifecycle": "kick_impact", "scale": 1.16, "lifetime": 0.42},
	"aug_speed_demon": {"category": "dash", "effect_family": "speed_demon", "color": Color(0.26, 0.78, 1.00, 0.92), "accent_color": Color(1.00, 0.22, 0.16, 0.88), "shape": "speed_meter_flame", "motion": "velocity_warp", "particle_style": "blue_red_streaks", "spawn_anchor": "owner_feet", "trigger_timing": "speed_scaled_damage", "lifecycle": "warp_streak", "scale": 1.10, "lifetime": 0.50},
	"aug_colossus_courage": {"category": "shield", "effect_family": "colossus_courage", "color": Color(0.58, 0.72, 0.70, 0.92), "accent_color": Color(1.00, 0.54, 0.20, 0.84), "shape": "giant_guard_plate", "motion": "heavy_shield_thud", "particle_style": "metal_sparks", "spawn_anchor": "owner_front", "trigger_timing": "protection_trigger", "lifecycle": "heavy_thud", "scale": 1.26, "lifetime": 0.58},
	"aug_cruel_comet": {"category": "shield", "effect_family": "cruel_comet", "color": Color(0.86, 0.46, 0.24, 0.95), "accent_color": Color(1.00, 0.86, 0.32, 0.88), "shape": "cruel_comet_marker", "motion": "downward_comet_smash", "particle_style": "molten_rocks", "spawn_anchor": "target_ground", "trigger_timing": "control_delayed_strike", "lifecycle": "impact_marker", "scale": 1.30, "lifetime": 0.72},
	"aug_impassable": {"category": "shield", "effect_family": "impassable_wall", "color": Color(0.48, 0.62, 0.58, 0.94), "accent_color": Color(0.80, 1.00, 0.82, 0.84), "shape": "stone_wall_rise", "motion": "wall_lock", "particle_style": "granite_chips", "spawn_anchor": "owner_front", "trigger_timing": "control_or_shield", "lifecycle": "wall_hold", "scale": 1.18, "lifetime": 0.88},
	"aug_adamant_layers": {"category": "shield", "effect_family": "adamant_layers", "color": Color(0.62, 0.72, 0.84, 0.94), "accent_color": Color(0.92, 0.98, 1.00, 0.82), "shape": "layered_armor_hex", "motion": "plates_stack_click", "particle_style": "steel_dust", "spawn_anchor": "owner_body", "trigger_timing": "stack_resist", "lifecycle": "plate_stack", "scale": 1.08, "lifetime": 0.70},
	"aug_soul_eater": {"category": "lifesteal", "effect_family": "soul_eater", "color": Color(0.30, 0.88, 0.48, 0.86), "accent_color": Color(0.05, 0.12, 0.08, 0.90), "shape": "soul_orb_devour", "motion": "kill_soul_pull", "particle_style": "green_black_wisps", "spawn_anchor": "dead_enemy_to_owner", "trigger_timing": "kill_or_control", "lifecycle": "soul_pull", "scale": 1.06, "lifetime": 0.78},
	"aug_immolate_engine": {"category": "burn", "effect_family": "immolate_engine", "color": Color(1.00, 0.34, 0.08, 0.92), "accent_color": Color(0.28, 0.08, 0.02, 0.88), "shape": "furnace_core_flare", "motion": "self_drain_heatwave", "particle_style": "coal_sparks", "spawn_anchor": "owner_core", "trigger_timing": "periodic_self_drain", "lifecycle": "furnace_pulse", "scale": 1.22, "lifetime": 0.82},
	"aug_goliath": {"category": "shield", "effect_family": "goliath_growth", "color": Color(0.76, 0.74, 0.64, 0.92), "accent_color": Color(1.00, 0.58, 0.24, 0.84), "shape": "goliath_growth_ring", "motion": "body_scale_surge", "particle_style": "heavy_dust", "spawn_anchor": "owner_feet", "trigger_timing": "passive_growth", "lifecycle": "growth_surge", "scale": 1.34, "lifetime": 0.76},
	"aug_stuck_with_me": {"category": "shield", "effect_family": "taunt_chain", "color": Color(0.50, 0.54, 0.58, 0.94), "accent_color": Color(1.00, 0.26, 0.16, 0.86), "shape": "taunt_chain_anchor", "motion": "chain_pull_pulse", "particle_style": "iron_links", "spawn_anchor": "owner_radius", "trigger_timing": "taunt_pulse", "lifecycle": "chain_pulse", "scale": 1.24, "lifetime": 0.66},
	"aug_orbital_laser": {"category": "summon", "effect_family": "orbital_laser", "color": Color(0.38, 0.94, 1.00, 0.94), "accent_color": Color(1.00, 0.90, 0.34, 0.88), "shape": "orbital_target_reticle", "motion": "sky_laser_sweep", "particle_style": "beam_photons", "spawn_anchor": "target_column", "trigger_timing": "periodic_laser", "lifecycle": "beam_sweep", "scale": 1.28, "lifetime": 0.72},
	"aug_quantum_slash": {"category": "summon", "effect_family": "quantum_slash", "color": Color(0.46, 1.00, 0.92, 0.92), "accent_color": Color(0.72, 0.52, 1.00, 0.86), "shape": "quantum_blade_arc", "motion": "blink_slash_slice", "particle_style": "cyan_fragments", "spawn_anchor": "target_line", "trigger_timing": "periodic_slash", "lifecycle": "slash_slice", "scale": 1.10, "lifetime": 0.42},
	"aug_boomerang": {"category": "summon", "effect_family": "boomerang", "color": Color(0.98, 0.78, 0.32, 0.92), "accent_color": Color(0.42, 1.00, 0.86, 0.82), "shape": "returning_boomerang_path", "motion": "loop_out_return", "particle_style": "trail_dust", "spawn_anchor": "owner_orbit", "trigger_timing": "periodic_boomerang", "lifecycle": "return_path", "scale": 1.04, "lifetime": 0.76},
	"aug_firefox": {"category": "summon", "effect_family": "foxfire", "color": Color(1.00, 0.36, 0.10, 0.94), "accent_color": Color(1.00, 0.82, 0.24, 0.86), "shape": "foxfire_gate", "motion": "fox_pop_then_dash", "particle_style": "orange_wisps", "spawn_anchor": "summon_gate", "trigger_timing": "summon_or_foxfire", "lifecycle": "gate_dash", "scale": 1.02, "lifetime": 0.70},
	"aug_poro_blaster": {"category": "summon", "effect_family": "poro_blaster", "color": Color(0.90, 0.92, 1.00, 0.94), "accent_color": Color(1.00, 0.72, 0.28, 0.86), "shape": "poro_cannon_badge", "motion": "cannon_puff_projectile", "particle_style": "wool_sparks", "spawn_anchor": "summon_side", "trigger_timing": "summon_projectile", "lifecycle": "cannon_puff", "scale": 1.00, "lifetime": 0.58},
	"aug_minionmancer": {"category": "summon", "effect_family": "minionmancer", "color": Color(0.72, 0.86, 0.62, 0.92), "accent_color": Color(0.46, 0.30, 0.18, 0.86), "shape": "minion_portal_grid", "motion": "squad_spawn_pop", "particle_style": "tiny_stars", "spawn_anchor": "owner_front", "trigger_timing": "summon_spawn", "lifecycle": "squad_pop", "scale": 1.14, "lifetime": 0.76},
	"aug_hand_of_baron": {"category": "summon", "effect_family": "baron_hand", "color": Color(0.66, 0.34, 1.00, 0.94), "accent_color": Color(1.00, 0.84, 0.30, 0.88), "shape": "baron_hand_sigil", "motion": "giant_hand_bless", "particle_style": "purple_gold_motes", "spawn_anchor": "elite_or_pickup", "trigger_timing": "elite_kill_or_pickup", "lifecycle": "baron_bless", "scale": 1.30, "lifetime": 0.86},
	"aug_divine_intervention": {"category": "summon", "effect_family": "divine_intervention", "color": Color(1.00, 0.92, 0.54, 0.94), "accent_color": Color(0.78, 0.96, 1.00, 0.86), "shape": "divine_wing_gate", "motion": "rescue_beam_descend", "particle_style": "gold_feathers", "spawn_anchor": "owner_center", "trigger_timing": "fatal_or_low_hp", "lifecycle": "rescue_beam", "scale": 1.28, "lifetime": 0.90},
	"aug_stats_forge": {"category": "forge", "effect_family": "stats_forge", "color": Color(1.00, 0.56, 0.12, 0.94), "accent_color": Color(1.00, 0.88, 0.42, 0.88), "shape": "forge_anvil_card", "motion": "card_flip_sparks", "particle_style": "orange_sparks", "spawn_anchor": "hud_card", "trigger_timing": "on_pick", "lifecycle": "card_flip", "scale": 1.00, "lifetime": 0.80},
	"aug_stats_on_stats": {"category": "forge", "effect_family": "stats_on_stats", "color": Color(0.56, 0.78, 1.00, 0.92), "accent_color": Color(1.00, 0.78, 0.24, 0.86), "shape": "stat_abacus_sigil", "motion": "numbers_stack_spin", "particle_style": "blue_gold_digits", "spawn_anchor": "hud_panel", "trigger_timing": "passive_recalc", "lifecycle": "number_stack", "scale": 1.02, "lifetime": 0.76},
	"aug_red_envelope": {"category": "forge", "effect_family": "red_envelope", "color": Color(1.00, 0.08, 0.08, 0.94), "accent_color": Color(1.00, 0.84, 0.18, 0.90), "shape": "red_envelope_pop", "motion": "envelope_arc_open", "particle_style": "red_confetti", "spawn_anchor": "pickup_or_hud", "trigger_timing": "pickup_or_periodic", "lifecycle": "confetti_pop", "scale": 1.04, "lifetime": 0.64},
	"aug_goldrend": {"category": "forge", "effect_family": "goldrend", "color": Color(1.00, 0.74, 0.16, 0.96), "accent_color": Color(0.42, 0.20, 0.02, 0.88), "shape": "gold_claw_window", "motion": "elite_coin_slice", "particle_style": "gold_sparks", "spawn_anchor": "target_head", "trigger_timing": "elite_or_boss_hit", "lifecycle": "coin_slice", "scale": 1.10, "lifetime": 0.52},
	"aug_pandora_box": {"category": "forge", "effect_family": "pandora_box", "color": Color(0.84, 0.32, 1.00, 0.94), "accent_color": Color(0.32, 1.00, 0.82, 0.86), "shape": "pandora_cube_open", "motion": "chaotic_card_burst", "particle_style": "rainbow_dust", "spawn_anchor": "hud_center", "trigger_timing": "choice_or_pick", "lifecycle": "chaos_burst", "scale": 1.16, "lifetime": 0.92},
	"aug_transmute_chaos": {"category": "forge", "effect_family": "transmute_chaos", "color": Color(0.34, 1.00, 0.70, 0.92), "accent_color": Color(1.00, 0.42, 0.96, 0.86), "shape": "transmute_hex_swirl", "motion": "hex_shuffle", "particle_style": "alchemy_dust", "spawn_anchor": "hud_card", "trigger_timing": "reroll_or_transmute", "lifecycle": "hex_shuffle", "scale": 1.05, "lifetime": 0.78},
	"aug_urf_champion": {"category": "cooldown", "effect_family": "urf_champion", "color": Color(0.28, 0.74, 1.00, 0.94), "accent_color": Color(1.00, 0.92, 0.26, 0.88), "shape": "urf_clock_rocket", "motion": "cooldown_clock_rush", "particle_style": "blue_timer_sparks", "spawn_anchor": "owner_hud", "trigger_timing": "cooldown_mode", "lifecycle": "clock_rush", "scale": 1.10, "lifetime": 0.66},
	"aug_mobile_zhonya": {"category": "forge", "effect_family": "mobile_stasis", "color": Color(1.00, 0.84, 0.26, 0.94), "accent_color": Color(0.96, 0.96, 0.78, 0.86), "shape": "mobile_stasis_hourglass", "motion": "moving_gold_freeze", "particle_style": "gold_sand", "spawn_anchor": "owner_center", "trigger_timing": "low_hp_or_fatal", "lifecycle": "stasis_freeze", "scale": 1.20, "lifetime": 0.86},
}

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
		if not AUGMENT_VISUAL_OVERRIDES.has(augment_id):
			errors.append("%s:missing_visual_override" % augment_id)
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
	var override: Dictionary = AUGMENT_VISUAL_OVERRIDES.get(augment_id, {})
	if not override.is_empty():
		category = str(override.get("category", category))
		family = str(override.get("effect_family", CATEGORY_FAMILY.get(category, category)))
		color = override.get("color", color)
		shape = str(override.get("shape", shape))
		motion = str(override.get("motion", motion))
		particle_style = str(override.get("particle_style", particle_style))
		line_style = str(override.get("line_style", _line_style_for(category, variant)))
		target_layer = str(override.get("target_layer", "hud" if category in ["forge", "choice", "cooldown"] else "world"))
		scale = float(override.get("scale", scale))
		lifetime = float(override.get("lifetime", lifetime))
	var recipe_key := _visual_recipe_key(family, category, color, shape, motion, particle_style, line_style, target_layer, scale, lifetime, variant)
	var spec := {
		"augment_id": augment_id,
		"visual_signature": recipe_key,
		"visual_recipe_key": recipe_key,
		"effect_family": family,
		"category": category,
		"color": color,
		"accent_color": override.get("accent_color", color.lightened(0.25)) if not override.is_empty() else color.lightened(0.25),
		"shape": shape,
		"motion": motion,
		"particle_style": particle_style,
		"line_style": line_style,
		"trigger_events": trigger_events,
		"target_layer": target_layer,
		"spawn_anchor": str(override.get("spawn_anchor", "world_position")) if not override.is_empty() else "world_position",
		"trigger_timing": str(override.get("trigger_timing", "augment_effect_triggered")) if not override.is_empty() else "augment_effect_triggered",
		"lifecycle": str(override.get("lifecycle", "single_burst")) if not override.is_empty() else "single_burst",
		"scale": scale,
		"lifetime": lifetime,
	}
	if not override.is_empty():
		for key in override.keys():
			spec[key] = override[key]
		spec["visual_recipe_key"] = recipe_key
		spec["visual_signature"] = _signature_for_spec(spec, variant)
	return spec

func _signature_for_spec(spec: Dictionary, variant: int) -> String:
	return "%s|%s|%s|%s|%s|%s|%s|v%03d" % [
		str(spec.get("effect_family", "")),
		str(spec.get("category", "")),
		str(spec.get("shape", "")),
		str(spec.get("motion", "")),
		str(spec.get("particle_style", "")),
		str(spec.get("spawn_anchor", "")),
		str(spec.get("trigger_timing", "")),
		variant % 997,
	]

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
	if trigger_text.contains("rune"):
		return ["rune_triggered"]
	if trigger_text.contains("attack") or trigger_text.contains("fire"):
		return ["weapon_fired", "projectile_spawned"]
	if trigger_text.contains("projectile"):
		return ["projectile_spawned", "projectile_hit"]
	if trigger_text.contains("roll"):
		return ["damage_roll_requested"]
	if trigger_text.contains("hit") or trigger_text.contains("damage") or trigger_text.contains("crit") or trigger_text.contains("skill"):
		return ["damage_applied_packet", "projectile_hit"]
	if trigger_text.contains("burn"):
		return ["burn_stack_applied", "burn_stack_threshold"]
	if trigger_text.contains("rift"):
		return ["rift_chain_triggered"]
	if trigger_text.contains("shield"):
		return ["shield_gained", "shield_broken"]
	if trigger_text.contains("heal") or trigger_text.contains("regen"):
		return ["heal_received", "regen_tick"]
	if trigger_text.contains("dash") or trigger_text.contains("blink"):
		return ["dash_started", "dash_finished", "blink_used"]
	if trigger_text.contains("fatal"):
		return ["fatal_damage_received"]
	if trigger_text.contains("low_hp"):
		return ["low_hp_entered", "damage_applied_packet"]
	if trigger_text.contains("control") or trigger_text.contains("taunt"):
		return ["control_applied"]
	if trigger_text.contains("elite") or trigger_text.contains("boss"):
		return ["elite_killed", "boss_damaged"]
	if trigger_text.contains("periodic") or trigger_text.contains("aura") or trigger_text.contains("pickup"):
		return ["augment_periodic_tick", "pickup_collected"]
	if category in ["bullet", "projectile", "storm"]:
		return ["projectile_spawned", "projectile_hit"]
	if category == "burn":
		return ["burn_stack_applied", "damage_applied_packet"]
	if category == "void":
		return ["rift_chain_triggered", "damage_applied_packet"]
	if category == "shield":
		return ["shield_gained", "damage_applied_packet"]
	if category == "lifesteal":
		return ["heal_received", "damage_applied_packet", "low_hp_entered"]
	if category == "dash":
		return ["dash_started", "dash_finished", "blink_used"]
	if category in ["forge", "choice", "cooldown", "summon"]:
		return ["augment_periodic_tick"]
	return ["damage_applied_packet"]

func _map_supported_event(signal_name: String) -> String:
	if SUPPORTED_EVENTS.has(signal_name):
		return signal_name
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
