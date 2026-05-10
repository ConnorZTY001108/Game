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
	if current_health <= 0.0:
		is_dead = true
		died.emit()
