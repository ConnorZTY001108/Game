class_name HUD
extends Control

const PlayerScript := preload("res://scripts/player/Player.gd")
const RunTimerSystemScript := preload("res://scripts/systems/RunTimerSystem.gd")
const MAX_FEEDBACK_MESSAGES := 64
const MAX_VISIBLE_FEEDBACK_LABELS := 18
const REGION_PROMPT_LIFETIME := 1.5
const REGION_PROMPT_FADE_SECONDS := 0.35
const MAP_EVENT_PROMPT_LIFETIME := 2.0
const MAP_REWARD_PROMPT_LIFETIME := 1.5
const MAP_PROMPT_FADE_SECONDS := 0.3

@onready var health_label: Label = $Panel/Margin/Stats/HealthLabel
@onready var level_label: Label = $Panel/Margin/Stats/LevelLabel
@onready var experience_label: Label = $Panel/Margin/Stats/ExperienceLabel
@onready var timer_label: Label = $Panel/Margin/Stats/TimerLabel
@onready var kill_label: Label = $Panel/Margin/Stats/KillLabel

var kills: int = 0
var feedback_layer: Control
var flash_rect: ColorRect
var feedback_entries: Array[Dictionary] = []
var feedback_messages: Array[String] = []
var feedback_sequence: int = 0
var region_prompt_label: Label
var objective_label: Label
var map_prompt_label: Label
var augment_status_panel: VBoxContainer
var augment_route_label: Label
var augment_stat_label: Label
var augment_owned_label: Label
var augment_proc_label: Label
var augment_progress_label: Label
var bound_player: PlayerScript
var region_prompt_remaining: float = 0.0
var map_prompt_remaining: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_feedback_nodes()
	_ensure_region_prompt_node()
	_ensure_objective_node()
	_ensure_map_prompt_node()
	_ensure_augment_status_panel()
	GameEvents.enemy_died.connect(_on_enemy_died)
	GameEvents.level_changed.connect(_on_level_changed)
	GameEvents.experience_collected.connect(_on_experience_collected)
	GameEvents.run_started.connect(_on_run_started)
	GameEvents.run_finished.connect(_on_run_finished)
	GameEvents.augment_acquired.connect(_on_augment_acquired)
	GameEvents.augment_effect_triggered.connect(_on_augment_effect_triggered)
	GameEvents.augment_state_changed.connect(_on_augment_state_changed)
	GameEvents.upgrade_selected.connect(_on_upgrade_selected)
	GameEvents.damage_number_requested.connect(_on_damage_number_requested)
	GameEvents.feedback_requested.connect(_on_feedback_requested)
	GameEvents.map_region_changed.connect(_on_map_region_changed)
	GameEvents.map_objective_updated.connect(_on_map_objective_updated)
	GameEvents.map_event_triggered.connect(_on_map_event_triggered)
	GameEvents.map_reward_granted.connect(_on_map_reward_granted)
	_on_level_changed(1)
	_on_experience_collected(0)
	_on_map_objective_updated(GameEvents.activated_obelisk_count, GameEvents.total_obelisk_count)
	_refresh_augment_status()
	_update_timer(0.0)
	kill_label.text = "击杀: 0"

func _process(delta: float) -> void:
	_update_feedback_entries(delta)
	_update_flash(delta)
	_update_region_prompt(delta)
	_update_map_prompt(delta)

func bind_player(player: PlayerScript) -> void:
	bound_player = player
	player.health_component.health_changed.connect(_on_health_changed)
	_on_health_changed(player.health_component.current_health, player.health_component.max_health)
	_refresh_augment_status()

func bind_timer(timer: RunTimerSystemScript) -> void:
	timer.time_changed.connect(_update_timer)

func get_feedback_texts() -> Array[String]:
	return feedback_messages.duplicate()

func _on_health_changed(current: float, maximum: float) -> void:
	health_label.text = "生命: %d/%d" % [int(current), int(maximum)]

func _on_level_changed(level: int) -> void:
	level_label.text = "等级: %d" % level

func _on_experience_collected(amount: int) -> void:
	experience_label.text = "经验: %d" % amount

func _on_enemy_died(_enemy: Node, _experience_value: int) -> void:
	kills += 1
	kill_label.text = "击杀: %d" % kills

func _on_run_started() -> void:
	kills = 0
	feedback_messages.clear()
	feedback_sequence = 0
	feedback_entries.clear()
	kill_label.text = "击杀: 0"
	if flash_rect != null:
		flash_rect.visible = false
	if feedback_layer != null:
		for child in feedback_layer.get_children():
			child.queue_free()
	if region_prompt_label != null:
		region_prompt_label.visible = false
		region_prompt_remaining = 0.0
	if map_prompt_label != null:
		map_prompt_label.visible = false
		map_prompt_remaining = 0.0
	_on_map_objective_updated(0, GameEvents.total_obelisk_count)
	_refresh_augment_status()
	_update_timer(0.0)

func _update_timer(seconds: float) -> void:
	var minutes := int(seconds) / 60
	var remainder := int(seconds) % 60
	timer_label.text = "时间: %02d:%02d" % [minutes, remainder]

func _on_run_finished(result: String) -> void:
	var label := "胜利" if result == "victory" else "失败"
	timer_label.text = "本局结束：%s" % label

func _on_damage_number_requested(amount: float, world_position: Vector2, tags: Array[String]) -> void:
	_spawn_feedback_label("damage", "-%d" % int(round(amount)), world_position, {
		"tags": tags.duplicate()
	})

func _on_feedback_requested(feedback_type: String, text: String, world_position: Vector2, payload: Dictionary) -> void:
	var message := text if text != "" else feedback_type.to_upper()
	_spawn_feedback_label(feedback_type, message, world_position, payload)
	if feedback_type == "player_damage":
		_flash(Color(1.0, 0.15, 0.1, 0.34))

func _on_augment_acquired(_augment_id: String, _augment: Resource, _owner: Node, _snapshot: Dictionary) -> void:
	_refresh_augment_status()

func _on_augment_effect_triggered(_payload: Dictionary) -> void:
	_refresh_augment_status()

func _on_augment_state_changed(_snapshot: Dictionary) -> void:
	_refresh_augment_status()

func _on_upgrade_selected(_upgrade: Resource) -> void:
	_refresh_augment_status()

func _on_map_region_changed(_region_id: String, display_name: String) -> void:
	if region_prompt_label == null:
		_ensure_region_prompt_node()
	if region_prompt_label == null:
		return
	region_prompt_label.text = display_name
	region_prompt_label.visible = display_name != ""
	region_prompt_label.modulate = Color(0.94, 0.9, 0.74, 1.0)
	region_prompt_remaining = REGION_PROMPT_LIFETIME

func _on_map_objective_updated(activated: int, total: int) -> void:
	if objective_label == null:
		_ensure_objective_node()
	if objective_label == null:
		return
	if total > 0 and activated >= total:
		objective_label.text = "目标：符文碑已全部激活"
	else:
		objective_label.text = "目标：激活符文碑 %d/%d" % [activated, total]

func _on_map_event_triggered(_event_id: String, display_name: String) -> void:
	_show_map_prompt("地图事件：%s" % display_name, MAP_EVENT_PROMPT_LIFETIME, Color(1.0, 0.72, 0.36, 1.0))

func _on_map_reward_granted(_reward_id: String, display_name: String) -> void:
	_show_map_prompt("奖励：%s" % display_name, MAP_REWARD_PROMPT_LIFETIME, Color(0.64, 1.0, 0.82, 1.0))

func _ensure_feedback_nodes() -> void:
	flash_rect = ColorRect.new()
	flash_rect.name = "DamageFlash"
	flash_rect.visible = false
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1.0, 0.0, 0.0, 0.0)
	add_child(flash_rect)

	feedback_layer = Control.new()
	feedback_layer.name = "FeedbackLayer"
	feedback_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(feedback_layer)

func _ensure_region_prompt_node() -> void:
	region_prompt_label = get_node_or_null("RegionPromptLabel") as Label
	if region_prompt_label != null:
		return
	region_prompt_label = Label.new()
	region_prompt_label.name = "RegionPromptLabel"
	region_prompt_label.visible = false
	region_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	region_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	region_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	region_prompt_label.custom_minimum_size = Vector2(440.0, 34.0)
	region_prompt_label.anchor_left = 0.5
	region_prompt_label.anchor_right = 0.5
	region_prompt_label.anchor_top = 0.0
	region_prompt_label.anchor_bottom = 0.0
	region_prompt_label.offset_left = -220.0
	region_prompt_label.offset_top = 72.0
	region_prompt_label.offset_right = 220.0
	region_prompt_label.offset_bottom = 106.0
	add_child(region_prompt_label)

func _ensure_objective_node() -> void:
	objective_label = get_node_or_null("ObjectiveLabel") as Label
	if objective_label != null:
		return
	objective_label = Label.new()
	objective_label.name = "ObjectiveLabel"
	objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	objective_label.custom_minimum_size = Vector2(360.0, 28.0)
	objective_label.anchor_left = 0.0
	objective_label.anchor_right = 0.0
	objective_label.anchor_top = 0.0
	objective_label.anchor_bottom = 0.0
	objective_label.offset_left = 18.0
	objective_label.offset_top = 112.0
	objective_label.offset_right = 378.0
	objective_label.offset_bottom = 140.0
	objective_label.modulate = Color(0.9, 0.95, 0.82, 1.0)
	add_child(objective_label)

func _ensure_map_prompt_node() -> void:
	map_prompt_label = get_node_or_null("MapPromptLabel") as Label
	if map_prompt_label != null:
		return
	map_prompt_label = Label.new()
	map_prompt_label.name = "MapPromptLabel"
	map_prompt_label.visible = false
	map_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	map_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_prompt_label.custom_minimum_size = Vector2(520.0, 34.0)
	map_prompt_label.anchor_left = 0.5
	map_prompt_label.anchor_right = 0.5
	map_prompt_label.anchor_top = 0.0
	map_prompt_label.anchor_bottom = 0.0
	map_prompt_label.offset_left = -260.0
	map_prompt_label.offset_top = 114.0
	map_prompt_label.offset_right = 260.0
	map_prompt_label.offset_bottom = 148.0
	add_child(map_prompt_label)

func _ensure_augment_status_panel() -> void:
	augment_status_panel = get_node_or_null("AugmentStatusPanel") as VBoxContainer
	if augment_status_panel == null:
		augment_status_panel = VBoxContainer.new()
		augment_status_panel.name = "AugmentStatusPanel"
		augment_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		augment_status_panel.custom_minimum_size = Vector2(360.0, 132.0)
		augment_status_panel.anchor_left = 1.0
		augment_status_panel.anchor_right = 1.0
		augment_status_panel.anchor_top = 0.0
		augment_status_panel.anchor_bottom = 0.0
		augment_status_panel.offset_left = -376.0
		augment_status_panel.offset_top = 16.0
		augment_status_panel.offset_right = -16.0
		augment_status_panel.offset_bottom = 148.0
		augment_status_panel.add_theme_constant_override("separation", 2)
		add_child(augment_status_panel)
	augment_route_label = _ensure_augment_label("RouteSummaryLabel")
	augment_stat_label = _ensure_augment_label("StatDeltaLabel")
	augment_owned_label = _ensure_augment_label("OwnedAugmentsLabel")
	augment_proc_label = _ensure_augment_label("ProcCountersLabel")
	augment_progress_label = _ensure_augment_label("ProgressLabel")

func _ensure_augment_label(label_name: String) -> Label:
	var label := augment_status_panel.get_node_or_null(label_name) as Label
	if label != null:
		return label
	label = Label.new()
	label.name = label_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(360.0, 22.0)
	augment_status_panel.add_child(label)
	return label

func _refresh_augment_status() -> void:
	if augment_status_panel == null:
		_ensure_augment_status_panel()
	if not is_instance_valid(AugmentSystem) or not AugmentSystem.has_method("get_hud_snapshot"):
		return
	var snapshot: Dictionary = AugmentSystem.call("get_hud_snapshot", bound_player)
	augment_route_label.text = "路线：%s" % _format_count_dictionary(snapshot.get("route_counts", {}), "无")
	augment_stat_label.text = "属性：%s" % _format_stat_line(snapshot)
	augment_owned_label.text = "已拥有：%s" % _format_owned_augments(snapshot.get("owned_augments", []))
	augment_proc_label.text = "触发：%s" % _format_count_dictionary(snapshot.get("proc_counts", {}), "暂无")
	augment_progress_label.text = "进度：%s" % _format_progress_line(snapshot)

func _format_owned_augments(value: Variant) -> String:
	if not value is Array:
		return "无"
	var names: Array[String] = []
	for item in value:
		if item is Dictionary:
			var entry := item as Dictionary
			var augment_id := str(entry.get("id", ""))
			var rank := int(entry.get("rank", 0))
			if augment_id != "":
				names.append("%s x%d" % [augment_id, rank])
	if names.is_empty():
		return "无"
	return ", ".join(names)

func _format_count_dictionary(value: Variant, empty_text: String) -> String:
	if not value is Dictionary:
		return empty_text
	var dictionary := value as Dictionary
	if dictionary.is_empty():
		return empty_text
	var parts: Array[String] = []
	for key in dictionary.keys():
		parts.append("%s x%s" % [str(key), str(dictionary[key])])
	return ", ".join(parts)

func _format_stat_line(snapshot: Dictionary) -> String:
	var stat_modifiers: Dictionary = snapshot.get("stat_modifiers", {})
	if not stat_modifiers.is_empty():
		var parts: Array[String] = []
		for stat in stat_modifiers.keys():
			var entry: Dictionary = stat_modifiers.get(stat, {})
			var total := float(entry.get("flat", 0.0)) + float(entry.get("percent", 0.0))
			parts.append("%s %+0.2f" % [str(stat), total])
		return ", ".join(parts)
	var stats: Dictionary = snapshot.get("stat_snapshot", {})
	if stats.is_empty():
		return "暂无变化"
	return "伤害 %.2f / 冷却 %.2f / 拾取 %.0f / 移速 %.0f" % [
		float(stats.get("damage_multiplier", 1.0)),
		float(stats.get("cooldown_multiplier", 1.0)),
		float(stats.get("pickup_radius", 0.0)),
		float(stats.get("move_speed", 0.0))
	]

func _format_progress_line(snapshot: Dictionary) -> String:
	var parts: Array[String] = []
	var quest_progress: Dictionary = snapshot.get("quest_progress", {})
	for key in quest_progress.keys():
		var entry: Dictionary = quest_progress.get(key, {})
		parts.append("%s %d/%d" % [str(key), int(entry.get("amount", 0)), int(entry.get("total", 0))])
	var forge_progress: Dictionary = snapshot.get("forge_progress", {})
	var choice_state: Dictionary = forge_progress.get("choice_state", {})
	for key in choice_state.keys():
		parts.append("%s %s" % [str(key), str(choice_state[key])])
	if parts.is_empty():
		return "暂无任务/锻造"
	return ", ".join(parts)

func _spawn_feedback_label(feedback_type: String, text: String, world_position: Vector2, payload: Dictionary) -> void:
	if feedback_layer == null:
		return
	feedback_sequence += 1
	feedback_messages.append(text)
	if feedback_messages.size() > MAX_FEEDBACK_MESSAGES:
		feedback_messages.remove_at(0)
	var label := Label.new()
	label.name = "Feedback_%s_%d" % [feedback_type, feedback_sequence]
	label.text = text
	label.modulate = _feedback_color(feedback_type)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(180.0, 24.0)
	label.position = _feedback_position(feedback_type, world_position) + _feedback_offset(feedback_sequence)
	feedback_layer.add_child(label)
	feedback_entries.append({
		"label": label,
		"age": 0.0,
		"lifetime": float(payload.get("lifetime", 0.9)),
		"velocity": _feedback_velocity(feedback_type)
	})
	_trim_visible_feedback_labels()

func _update_feedback_entries(delta: float) -> void:
	for index in range(feedback_entries.size() - 1, -1, -1):
		var entry: Dictionary = feedback_entries[index]
		var label: Label = entry.get("label") as Label
		if label == null or not is_instance_valid(label):
			feedback_entries.remove_at(index)
			continue
		var age: float = float(entry.get("age", 0.0)) + delta
		var lifetime: float = float(entry.get("lifetime", 0.9))
		var velocity: Vector2 = entry.get("velocity", Vector2.ZERO) as Vector2
		label.position += velocity * delta
		var color: Color = label.modulate
		color.a = clamp(1.0 - (age / max(lifetime, 0.01)), 0.0, 1.0)
		label.modulate = color
		entry["age"] = age
		feedback_entries[index] = entry
		if age >= lifetime:
			label.queue_free()
			feedback_entries.remove_at(index)

func _update_flash(delta: float) -> void:
	if flash_rect == null or flash_rect.visible == false:
		return
	var color: Color = flash_rect.color
	color.a = max(0.0, color.a - (delta * 1.8))
	flash_rect.color = color
	if color.a <= 0.01:
		flash_rect.visible = false

func _flash(color: Color) -> void:
	if flash_rect == null:
		return
	flash_rect.color = color
	flash_rect.visible = true

func _show_map_prompt(text: String, lifetime: float, color: Color) -> void:
	if map_prompt_label == null:
		_ensure_map_prompt_node()
	if map_prompt_label == null:
		return
	map_prompt_label.text = text
	map_prompt_label.modulate = color
	map_prompt_label.visible = text != ""
	map_prompt_remaining = lifetime

func _update_region_prompt(delta: float) -> void:
	if region_prompt_label == null or region_prompt_label.visible == false:
		return
	region_prompt_remaining = max(0.0, region_prompt_remaining - delta)
	var color: Color = region_prompt_label.modulate
	if region_prompt_remaining <= REGION_PROMPT_FADE_SECONDS:
		color.a = clamp(region_prompt_remaining / REGION_PROMPT_FADE_SECONDS, 0.0, 1.0)
	else:
		color.a = 1.0
	region_prompt_label.modulate = color
	if region_prompt_remaining <= 0.0:
		region_prompt_label.visible = false

func _update_map_prompt(delta: float) -> void:
	if map_prompt_label == null or map_prompt_label.visible == false:
		return
	map_prompt_remaining = max(0.0, map_prompt_remaining - delta)
	var color: Color = map_prompt_label.modulate
	if map_prompt_remaining <= MAP_PROMPT_FADE_SECONDS:
		color.a = clamp(map_prompt_remaining / MAP_PROMPT_FADE_SECONDS, 0.0, 1.0)
	else:
		color.a = 1.0
	map_prompt_label.modulate = color
	if map_prompt_remaining <= 0.0:
		map_prompt_label.visible = false

func _trim_visible_feedback_labels() -> void:
	while feedback_entries.size() > MAX_VISIBLE_FEEDBACK_LABELS:
		var entry: Dictionary = feedback_entries.pop_front()
		var label: Label = entry.get("label") as Label
		if label != null and is_instance_valid(label):
			if label.get_parent() == feedback_layer:
				feedback_layer.remove_child(label)
			label.queue_free()

func _feedback_position(feedback_type: String, world_position: Vector2) -> Vector2:
	if feedback_type == "upgrade":
		return Vector2(get_viewport_rect().size.x * 0.5 - 90.0, 86.0)
	if feedback_type == "map_event" or feedback_type == "map_reward" or feedback_type == "map_objective":
		return Vector2(get_viewport_rect().size.x * 0.5 - 90.0, 122.0)
	if feedback_type == "player_death":
		return Vector2(get_viewport_rect().size.x * 0.5 - 90.0, get_viewport_rect().size.y * 0.42)
	return _screen_position_from_world(world_position)

func _screen_position_from_world(world_position: Vector2) -> Vector2:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		return world_position
	var viewport_size: Vector2 = get_viewport_rect().size
	return (world_position - camera.get_screen_center_position()) * camera.zoom + (viewport_size * 0.5)

func _feedback_offset(sequence: int) -> Vector2:
	var horizontal: float = float((sequence % 5) - 2) * 18.0
	var vertical: float = float(sequence % 3) * 10.0
	return Vector2(horizontal, vertical)

func _feedback_velocity(feedback_type: String) -> Vector2:
	if feedback_type == "upgrade":
		return Vector2(0.0, 10.0)
	return Vector2(0.0, -42.0)

func _feedback_color(feedback_type: String) -> Color:
	if feedback_type == "damage":
		return Color(1.0, 0.85, 0.35, 1.0)
	if feedback_type == "kill":
		return Color(0.85, 1.0, 0.45, 1.0)
	if feedback_type == "rune":
		return Color(0.55, 0.9, 1.0, 1.0)
	if feedback_type == "upgrade":
		return Color(0.75, 0.95, 0.65, 1.0)
	if feedback_type == "map_event":
		return Color(1.0, 0.72, 0.36, 1.0)
	if feedback_type == "map_reward" or feedback_type == "map_objective":
		return Color(0.64, 1.0, 0.82, 1.0)
	if feedback_type == "player_damage" or feedback_type == "player_death":
		return Color(1.0, 0.35, 0.28, 1.0)
	return Color.WHITE
