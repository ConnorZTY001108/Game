class_name ExperiencePickup
extends Area2D

const PlayerScript := preload("res://scripts/player/Player.gd")

@export var amount: int = 1
@export var magnet_speed: float = 420.0

var player: PlayerScript

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func configure_player(new_player: PlayerScript) -> void:
	player = new_player

func _process(delta: float) -> void:
	if player == null:
		return
	var distance := global_position.distance_to(player.global_position)
	if distance <= player.pickup_radius:
		global_position = global_position.move_toward(player.global_position, magnet_speed * delta)

func _on_area_entered(area: Area2D) -> void:
	if area.get_parent() == player:
		GameEvents.experience_collected.emit(amount)
		queue_free()
