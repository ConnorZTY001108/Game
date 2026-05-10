class_name RuneObelisk
extends Area2D

@export var obelisk_id: String = ""
@export var display_name: String = ""
@export var reward_type: String = "experience"
@export var reward_value: float = 10.0
@export var activation_radius: float = 96.0
@export var pickup_bonus_duration_seconds: float = 20.0
@export var objective_system_path: NodePath

var activated: bool = false

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func try_activate(player: Node) -> bool:
	if activated or player == null:
		return false
	if player is Node2D and global_position.distance_to((player as Node2D).global_position) > activation_radius:
		return false
	activated = true
	_apply_reward(player)
	GameEvents.map_reward_granted.emit(reward_type, _reward_display_text())
	var objective_system := _get_objective_system()
	if objective_system != null and objective_system.has_method("record_obelisk_activated"):
		objective_system.call("record_obelisk_activated", obelisk_id, display_name)
	_update_visual_state()
	return true

func _apply_reward(player: Node) -> void:
	if reward_type == "experience":
		ExperienceSystem.add_experience(int(reward_value))
	elif reward_type == "heal":
		_heal_player(player, reward_value)
	elif reward_type == "pickup_bonus" and player.has_method("apply_temporary_pickup_radius_bonus"):
		player.call("apply_temporary_pickup_radius_bonus", reward_value, pickup_bonus_duration_seconds)

func _heal_player(player: Node, amount: float) -> void:
	var health_component := player.get_node_or_null("HealthComponent")
	if health_component == null:
		return
	var maximum := float(health_component.get("max_health"))
	var current := float(health_component.get("current_health"))
	var healed: float = minf(maximum, current + amount)
	health_component.set("current_health", healed)
	health_component.emit_signal("health_changed", healed, maximum)

func _reward_display_text() -> String:
	if reward_type == "experience":
		return "%s：经验 +%d" % [display_name, int(reward_value)]
	if reward_type == "heal":
		return "%s：恢复 +%d" % [display_name, int(reward_value)]
	if reward_type == "pickup_bonus":
		return "%s：拾取范围 +%d" % [display_name, int(reward_value)]
	return display_name

func _get_objective_system() -> Node:
	var node := get_node_or_null(objective_system_path)
	if node != null:
		return node
	var current := get_parent()
	while current != null:
		var candidate := current.get_node_or_null("ObjectiveSystem")
		if candidate != null:
			return candidate
		current = current.get_parent()
	return null

func _on_area_entered(area: Area2D) -> void:
	var player := area.get_parent()
	if player != null:
		try_activate(player)

func _on_body_entered(body: Node2D) -> void:
	try_activate(body)

func _update_visual_state() -> void:
	modulate = Color(0.55, 1.0, 0.78, 1.0)
