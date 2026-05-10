class_name WeaponController
extends Node2D

@export var weapon_data: Resource
@export var projectile_scene: PackedScene = preload("res://scenes/projectiles/Projectile.tscn")
@export var projectiles_path: NodePath
@export var enemies_path: NodePath

var owner_player: Node2D
var cooldown: float = 0.0

func configure(player: Node2D, data: Resource) -> void:
	owner_player = player
	weapon_data = data
	cooldown = 0.0

func _process(delta: float) -> void:
	if GameRuntime.state != GameRuntime.RunState.PLAYING or weapon_data == null:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	var attack_mode := _get_string("attack_mode", "projectile")
	if attack_mode == "orbit_pulse" or attack_mode == "area_pulse":
		_pulse_nearby_enemies()
		cooldown = max(0.05, _get_float("tick_interval", _get_float("cooldown", 1.0)) * _get_owner_float("cooldown_multiplier", 1.0))
		return

	var target := _find_nearest_enemy()
	if target == null:
		return
	_fire_at(target)
	cooldown = max(0.05, _get_float("cooldown", 1.0) * _get_owner_float("cooldown_multiplier", 1.0))

func _find_nearest_enemy() -> Node2D:
	var enemies := get_node_or_null(enemies_path)
	if enemies == null:
		return null
	var max_range := _get_float("range", 600.0)
	var nearest: Node2D
	var nearest_distance := max_range
	for child in enemies.get_children():
		var enemy := child as Node2D
		if enemy == null:
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance <= nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest

func _fire_at(target: Node2D) -> void:
	var projectiles := get_node_or_null(projectiles_path)
	if projectiles == null or projectile_scene == null:
		return
	var projectile := projectile_scene.instantiate()
	projectiles.add_child(projectile)
	if projectile is Node2D:
		(projectile as Node2D).global_position = global_position

	var direction := global_position.direction_to(target.global_position)
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var weapon_tags := _get_string_array("tags")
	var element_tags := _get_string_array("element_tags")
	var combined_tags := weapon_tags.duplicate()
	combined_tags.append_array(element_tags)
	var payload := {
		"weapon_id": _get_string("id", ""),
		"weapon_tags": weapon_tags.duplicate(),
		"element_tags": element_tags.duplicate()
	}
	if projectile.has_method("configure"):
		projectile.configure(
			direction,
			_get_float("projectile_speed", 520.0),
			_get_float("damage", 10.0) * _get_owner_float("damage_multiplier", 1.0),
			_get_float("projectile_lifetime", 1.0),
			_get_int("pierce", 0),
			combined_tags,
			payload
		)

func _pulse_nearby_enemies() -> int:
	var enemies := get_node_or_null(enemies_path)
	if enemies == null:
		return 0
	var radius := _get_float("area_radius", 96.0)
	var damage := _get_float("damage", 10.0) * _get_owner_float("damage_multiplier", 1.0)
	var weapon_tags := _get_string_array("tags")
	var element_tags := _get_string_array("element_tags")
	var combined_tags := weapon_tags.duplicate()
	combined_tags.append_array(element_tags)
	var payload := {
		"weapon_id": _get_string("id", ""),
		"weapon_tags": weapon_tags.duplicate(),
		"element_tags": element_tags.duplicate()
	}
	var hit_count := 0
	for child in enemies.get_children():
		var enemy := child as Node2D
		if enemy == null:
			continue
		if not enemy.has_method("apply_damage"):
			continue
		if global_position.distance_to(enemy.global_position) > radius:
			continue
		DamageSystem.apply_damage(enemy, damage, combined_tags, payload)
		hit_count += 1
	return hit_count

func _get_float(key: String, fallback: float) -> float:
	var value = weapon_data.get(key)
	if typeof(value) == TYPE_NIL:
		return fallback
	return float(value)

func _get_int(key: String, fallback: int) -> int:
	var value = weapon_data.get(key)
	if typeof(value) == TYPE_NIL:
		return fallback
	return int(value)

func _get_string(key: String, fallback: String) -> String:
	var value = weapon_data.get(key)
	if typeof(value) == TYPE_NIL:
		return fallback
	return str(value)

func _get_string_array(key: String) -> Array[String]:
	var result: Array[String] = []
	var value = weapon_data.get(key)
	if value is Array:
		for item in value:
			result.append(str(item))
	return result

func _get_owner_float(key: String, fallback: float) -> float:
	if owner_player == null:
		return fallback
	var value = owner_player.get(key)
	if typeof(value) == TYPE_NIL:
		return fallback
	return float(value)
