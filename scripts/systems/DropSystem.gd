class_name DropSystem
extends Node

const ExperiencePickupScript := preload("res://scripts/pickups/ExperiencePickup.gd")
const PlayerScript := preload("res://scripts/player/Player.gd")

@export var pickup_scene: PackedScene = preload("res://scenes/pickups/ExperiencePickup.tscn")
@export var pickups_path: NodePath
@export var player_path: NodePath

func _ready() -> void:
	GameEvents.enemy_died.connect(_on_enemy_died)

func _on_enemy_died(enemy: Node, experience_value: int) -> void:
	var pickups := get_node_or_null(pickups_path)
	var player := get_node_or_null(player_path) as PlayerScript
	var enemy_2d := enemy as Node2D
	if pickups == null or player == null or enemy_2d == null or pickup_scene == null:
		return
	var pickup_instance := pickup_scene.instantiate()
	var pickup := pickup_instance as ExperiencePickupScript
	if pickup == null:
		if pickup_instance != null:
			pickup_instance.free()
		return
	pickup.global_position = enemy_2d.global_position
	pickup.amount = experience_value
	pickup.configure_player(player)
	pickups.add_child(pickup)
