class_name HealthComponent
extends Node

signal health_changed(current: float, maximum: float)
signal died

@export var max_health: float = 100.0
var current_health: float = 100.0
var is_dead: bool = false

func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)

func configure(new_max_health: float) -> void:
	max_health = new_max_health
	current_health = max_health
	is_dead = false
	health_changed.emit(current_health, max_health)

func apply_damage(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current_health = max(0.0, current_health - amount)
	health_changed.emit(current_health, max_health)
	_emit_player_damage_feedback(amount)
	if current_health <= 0.0:
		is_dead = true
		died.emit()

func _emit_player_damage_feedback(amount: float) -> void:
	var owner_node := get_parent()
	if owner_node == null or owner_node.has_method("take_contact_damage") == false:
		return
	var world_position := Vector2.ZERO
	if owner_node is Node2D:
		world_position = (owner_node as Node2D).global_position
	GameEvents.feedback_requested.emit("player_damage", "受击：-%d" % int(amount), world_position, {
		"amount": amount,
		"current_health": current_health,
		"max_health": max_health
	})
