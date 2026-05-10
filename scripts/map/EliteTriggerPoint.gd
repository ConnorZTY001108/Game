class_name EliteTriggerPoint
extends Area2D

@export var trigger_id: String = ""
@export var display_name: String = ""
@export var enemies_path: NodePath
@export var player_path: NodePath
@export var enemy_scene: PackedScene
@export var dust_thrall_data: Resource
@export var ash_runner_data: Resource
@export var bone_brute_data: Resource
@export var objective_system_path: NodePath

var triggered: bool = false

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func try_trigger(player: Node) -> bool:
	if triggered or player == null or enemy_scene == null:
		return false
	var enemies := _resolve_enemies_root()
	if enemies == null:
		return false
	triggered = true
	_spawn_pack(enemies, player as Node2D)
	var objective_system := _get_objective_system()
	if objective_system != null and objective_system.has_method("record_map_event"):
		objective_system.call("record_map_event", trigger_id, display_name)
	_update_visual_state()
	return true

func _spawn_pack(enemies: Node, player: Node2D) -> void:
	var spawn_items: Array[Resource] = []
	for _index in range(4):
		spawn_items.append(dust_thrall_data)
	for _index in range(2):
		spawn_items.append(ash_runner_data)
	spawn_items.append(bone_brute_data)

	for index in range(spawn_items.size()):
		var data: Resource = spawn_items[index]
		var enemy := enemy_scene.instantiate() as Node2D
		enemy.global_position = _spawn_position_for_index(index, player)
		if enemy.has_method("configure"):
			enemy.call("configure", data, player)
		enemies.add_child(enemy)

func _spawn_position_for_index(index: int, player: Node2D) -> Vector2:
	var player_position: Vector2 = global_position
	if player != null:
		player_position = player.global_position
	var base_radius := 190.0
	var angle := TAU * float(index) / 7.0
	var candidate := global_position + Vector2(cos(angle), sin(angle)) * base_radius
	if candidate.distance_to(player_position) < 160.0:
		candidate = player_position + player_position.direction_to(candidate).normalized() * 170.0
	return candidate

func _resolve_enemies_root() -> Node:
	var enemies := get_node_or_null(enemies_path)
	if enemies != null:
		return enemies
	var current: Node = self
	while current != null:
		if current.name == "World":
			return current.get_node_or_null("Enemies")
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
	modulate = Color(0.7, 0.7, 0.7, 0.6)
