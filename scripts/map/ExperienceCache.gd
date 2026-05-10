class_name ExperienceCache
extends Area2D

const ExperiencePickupScene := preload("res://scenes/pickups/ExperiencePickup.tscn")

@export var cache_id: String = ""
@export var display_name: String = ""
@export var pickup_count: int = 6
@export var spread_radius: float = 90.0
@export var experience_value: int = 1
@export var objective_system_path: NodePath

var triggered: bool = false

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func try_trigger(player: Node) -> bool:
	if triggered or player == null:
		return false
	triggered = true
	var pickups_root := _find_world_child("Pickups")
	if pickups_root != null:
		_spawn_pickups(pickups_root, player)
	var objective_system := _get_objective_system()
	if objective_system != null and objective_system.has_method("record_map_event"):
		objective_system.call("record_map_event", cache_id, display_name)
	_update_visual_state()
	return true

func _spawn_pickups(pickups_root: Node, player: Node) -> void:
	var count: int = maxi(1, pickup_count)
	for index in range(count):
		var pickup := ExperiencePickupScene.instantiate() as Node2D
		var angle := TAU * float(index) / float(count)
		var offset := Vector2(cos(angle), sin(angle)) * spread_radius
		pickup.global_position = global_position + offset
		pickup.set("amount", experience_value)
		if pickup.has_method("configure_player"):
			pickup.call("configure_player", player)
		pickups_root.add_child(pickup)

func _find_world_child(child_name: String) -> Node:
	var current: Node = self
	while current != null:
		if current.name == "World":
			return current.get_node_or_null(child_name)
		current = current.get_parent()
	return null

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
		try_trigger(player)

func _on_body_entered(body: Node2D) -> void:
	try_trigger(body)

func _update_visual_state() -> void:
	modulate = Color(0.55, 0.55, 0.55, 0.65)
