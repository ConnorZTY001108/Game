class_name SpawnSystem
extends Node

const WaveDataScript := preload("res://data/resources/wave_data.gd")
const EnemyDataScript := preload("res://data/resources/enemy_data.gd")
const EnemyScript := preload("res://scripts/enemies/Enemy.gd")
const DEFAULT_SPAWN_RADIUS := 760.0

@export var wave_data: WaveDataScript = preload("res://data/content/waves/m0_wave.tres")
@export var enemy_scene: PackedScene = preload("res://scenes/enemies/Enemy.tscn")
@export var enemies_path: NodePath
@export var player_path: NodePath

var spawn_timer: float = 0.0

func _process(delta: float) -> void:
	if GameRuntime.state != GameRuntime.RunState.PLAYING:
		return
	if wave_data == null:
		return
	var enemies := get_node_or_null(enemies_path)
	var player := get_node_or_null(player_path) as Node2D
	if enemies == null or player == null:
		return
	var phase := get_active_phase()
	if enemies.get_child_count() >= int(phase.get("max_alive", wave_data.max_alive)):
		return
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = float(phase.get("spawn_interval", wave_data.spawn_interval))
		_spawn_enemy(enemies, player, phase)

func get_active_phase() -> Dictionary:
	if wave_data == null:
		return {}
	if wave_data.has_method("get_phase_at_time"):
		return wave_data.get_phase_at_time(_get_elapsed_seconds())
	return {
		"start_time": 0.0,
		"duration": wave_data.duration_seconds,
		"spawn_interval": wave_data.spawn_interval,
		"max_alive": wave_data.max_alive,
		"spawn_radius": wave_data.spawn_radius,
		"enemy_pool": [wave_data.enemy_data]
	}

func select_enemy_data(phase: Dictionary) -> EnemyDataScript:
	var pool = phase.get("enemy_pool", [])
	if pool is Array and not pool.is_empty():
		var selected = pool[randi() % pool.size()]
		return selected as EnemyDataScript
	if wave_data == null:
		return null
	return wave_data.enemy_data as EnemyDataScript

func get_camera_view_rect(player: Node2D) -> Rect2:
	var viewport_size := Vector2(1280.0, 720.0)
	if is_inside_tree() and get_viewport() != null:
		var visible_rect := get_viewport().get_visible_rect()
		if visible_rect.size.x > 0.0 and visible_rect.size.y > 0.0:
			viewport_size = visible_rect.size

	var center := player.global_position if player != null else Vector2.ZERO
	if is_inside_tree() and get_viewport() != null:
		var camera := get_viewport().get_camera_2d()
		if camera != null:
			center = camera.get_screen_center_position()
			viewport_size.x /= maxf(camera.zoom.x, 0.001)
			viewport_size.y /= maxf(camera.zoom.y, 0.001)
	return Rect2(center - viewport_size * 0.5, viewport_size)

func get_spawn_position(player: Node2D, phase: Dictionary) -> Vector2:
	var camera_rect := get_camera_view_rect(player)
	var fallback_radius := DEFAULT_SPAWN_RADIUS if wave_data == null else wave_data.spawn_radius
	var spawn_radius_value := float(phase.get("spawn_radius", fallback_radius))
	var outside_offset := maxf(48.0, spawn_radius_value - maxf(camera_rect.size.x, camera_rect.size.y) * 0.5)
	var side := randi() % 4
	match side:
		0:
			return Vector2(
				camera_rect.position.x - outside_offset,
				randf_range(camera_rect.position.y - outside_offset, camera_rect.position.y + camera_rect.size.y + outside_offset)
			)
		1:
			return Vector2(
				camera_rect.position.x + camera_rect.size.x + outside_offset,
				randf_range(camera_rect.position.y - outside_offset, camera_rect.position.y + camera_rect.size.y + outside_offset)
			)
		2:
			return Vector2(
				randf_range(camera_rect.position.x - outside_offset, camera_rect.position.x + camera_rect.size.x + outside_offset),
				camera_rect.position.y - outside_offset
			)
		_:
			return Vector2(
				randf_range(camera_rect.position.x - outside_offset, camera_rect.position.x + camera_rect.size.x + outside_offset),
				camera_rect.position.y + camera_rect.size.y + outside_offset
			)

func _spawn_enemy(enemies: Node, player: Node2D, phase: Dictionary) -> void:
	var data := select_enemy_data(phase)
	if data == null:
		return
	var enemy := enemy_scene.instantiate() as EnemyScript
	enemy.global_position = get_spawn_position(player, phase)
	enemy.configure(data, player)
	enemies.add_child(enemy)

func _get_elapsed_seconds() -> float:
	var elapsed := float(GameRuntime.elapsed_seconds)
	var timer := get_node_or_null("../RunTimerSystem")
	if timer != null:
		elapsed = maxf(elapsed, float(timer.get("elapsed_seconds")))
	return elapsed
