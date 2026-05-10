extends Node

signal run_started
signal run_paused(is_paused: bool)
signal run_finished(result: String)
signal player_died
signal enemy_died(enemy: Node, experience_value: int)
signal damage_applied(target: Node, amount: float, tags: Array[String])
signal weapon_hit(target: Node, payload: Dictionary)
signal weapon_fired(player: Node, weapon: Resource, packet: Dictionary)
signal projectile_spawned(projectile: Node, packet: Dictionary)
signal projectile_hit(target: Node, packet: Dictionary)
signal damage_roll_requested(packet: Dictionary)
signal damage_applied_packet(target: Node, packet: Dictionary)
signal dot_tick(target: Node, packet: Dictionary)
signal burn_stack_applied(target: Node, stacks_added: int, total_stacks: int, packet: Dictionary)
signal burn_stack_threshold(target: Node, stacks: int, packet: Dictionary)
signal rift_chain_triggered(region_id: String, chain_count: int, packet: Dictionary)
signal shield_gained(target: Node, amount: float, packet: Dictionary)
signal shield_broken(target: Node, amount: float, packet: Dictionary)
signal heal_received(target: Node, amount: float, packet: Dictionary)
signal regen_tick(target: Node, amount: float, packet: Dictionary)
signal control_applied(target: Node, control_tag: String, packet: Dictionary)
signal dash_started(player: Node, packet: Dictionary)
signal dash_finished(player: Node, packet: Dictionary)
signal blink_used(player: Node, packet: Dictionary)
signal low_hp_entered(player: Node, ratio: float, packet: Dictionary)
signal fatal_damage_received(player: Node, packet: Dictionary)
signal pickup_collected(pickup: Node, player: Node, packet: Dictionary)
signal elite_killed(enemy: Node, packet: Dictionary)
signal boss_damaged(enemy: Node, packet: Dictionary)
signal augment_periodic_tick(elapsed_seconds: float)
signal augment_quest_progressed(augment_id: String, amount: int, total: int)
signal experience_collected(amount: int)
signal level_changed(level: int)
signal wave_phase_started(wave_phase_id: String, level: int, packet: Dictionary)
signal level_up_requested(options: Array[Resource])
signal upgrade_selected(upgrade: Resource)
signal rune_triggered(rune_id: String, target: Node, payload: Dictionary)
signal damage_number_requested(amount: float, world_position: Vector2, tags: Array[String])
signal feedback_requested(feedback_type: String, text: String, world_position: Vector2, payload: Dictionary)
signal settlement_requested(summary: Dictionary)
signal map_region_changed(region_id: String, display_name: String)
signal map_landmark_hint_changed(landmark_id: String, display_name: String, direction: Vector2)
signal map_objective_updated(active_count: int, total_count: int)
signal map_event_triggered(event_id: String, display_name: String)
signal map_reward_granted(reward_id: String, display_name: String)

var selected_upgrade_summaries: Array[String] = []
var activated_obelisk_count: int = 0
var total_obelisk_count: int = 0
var triggered_map_event_count: int = 0

func _ready() -> void:
	if run_started.is_connected(_on_run_started) == false:
		run_started.connect(_on_run_started)
	if upgrade_selected.is_connected(_on_upgrade_selected) == false:
		upgrade_selected.connect(_on_upgrade_selected)
	if rune_triggered.is_connected(_on_rune_triggered) == false:
		rune_triggered.connect(_on_rune_triggered)
	if player_died.is_connected(_on_player_died) == false:
		player_died.connect(_on_player_died)

func get_selected_upgrade_summaries() -> Array[String]:
	return selected_upgrade_summaries.duplicate()

func reset_map_objective_counters(new_total_obelisk_count: int = 0) -> void:
	activated_obelisk_count = 0
	total_obelisk_count = max(0, new_total_obelisk_count)
	triggered_map_event_count = 0
	map_objective_updated.emit(activated_obelisk_count, total_obelisk_count)

func set_total_obelisk_count(new_total_obelisk_count: int) -> void:
	total_obelisk_count = max(0, new_total_obelisk_count)
	activated_obelisk_count = min(activated_obelisk_count, total_obelisk_count)
	map_objective_updated.emit(activated_obelisk_count, total_obelisk_count)

func record_map_obelisk_activation() -> void:
	activated_obelisk_count = min(total_obelisk_count, activated_obelisk_count + 1)
	map_objective_updated.emit(activated_obelisk_count, total_obelisk_count)

func record_map_event_trigger(event_id: String, display_name: String) -> void:
	triggered_map_event_count += 1
	map_event_triggered.emit(event_id, display_name)

func get_map_objective_summary() -> Dictionary:
	return {
		"activated_obelisks": activated_obelisk_count,
		"total_obelisks": total_obelisk_count,
		"triggered_map_events": triggered_map_event_count,
		"all_obelisks_activated": total_obelisk_count > 0 and activated_obelisk_count >= total_obelisk_count
	}

func request_feedback(feedback_type: String, text: String, world_position: Vector2 = Vector2.ZERO, payload: Dictionary = {}) -> void:
	feedback_requested.emit(feedback_type, text, world_position, payload.duplicate(true))

func _on_run_started() -> void:
	selected_upgrade_summaries.clear()
	reset_map_objective_counters(total_obelisk_count)

func _on_upgrade_selected(upgrade: Resource) -> void:
	var display_name := _get_resource_string(upgrade, "display_name", _get_resource_string(upgrade, "id", "upgrade"))
	var route_label := _get_resource_string(upgrade, "route_label", "")
	var summary := display_name
	if route_label != "":
		summary = "%s (%s)" % [display_name, route_label]
	selected_upgrade_summaries.append(summary)
	feedback_requested.emit("upgrade", "升级：%s" % display_name, Vector2.ZERO, {
		"upgrade_id": _get_resource_string(upgrade, "id", ""),
		"route_label": route_label
	})

func _on_rune_triggered(rune_id: String, target: Node, payload: Dictionary) -> void:
	var label: String = str(payload.get("route_label", ""))
	if label == "":
		label = rune_id
	feedback_requested.emit("rune", "符文触发：%s" % label, _node_world_position(target), payload.duplicate(true))

func _on_player_died() -> void:
	feedback_requested.emit("player_death", "失败", Vector2.ZERO, {})

func _node_world_position(node: Node) -> Vector2:
	if node is Node2D:
		return (node as Node2D).global_position
	return Vector2.ZERO

func _get_resource_string(resource: Resource, key: String, fallback: String) -> String:
	if resource == null:
		return fallback
	var value: Variant = resource.get(key)
	if typeof(value) == TYPE_NIL:
		return fallback
	return str(value)
