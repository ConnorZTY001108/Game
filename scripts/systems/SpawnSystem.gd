class_name SpawnSystem
extends Node

const WaveDataScript := preload("res://data/resources/wave_data.gd")
const EnemyDataScript := preload("res://data/resources/enemy_data.gd")
const EnemyScript := preload("res://scripts/enemies/Enemy.gd")

@export var wave_data: WaveDataScript = preload("res://data/content/waves/m0_wave.tres")
@export var enemy_scene: PackedScene = preload("res://scenes/enemies/Enemy.tscn")
@export var enemies_path: NodePath
@export var player_path: NodePath

var spawn_timer: float = 0.0

func _process(delta: float) -> void:
	if GameRuntime.state != GameRuntime.RunState.PLAYING:
		return
	var enemies := get_node_or_null(enemies_path)
	var player := get_node_or_null(player_path) as Node2D
	if enemies == null or player == null:
		return
	if enemies.get_child_count() >= wave_data.max_alive:
		return
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = wave_data.spawn_interval
		_spawn_enemy(enemies, player)

func _spawn_enemy(enemies: Node, player: Node2D) -> void:
	var enemy := enemy_scene.instantiate() as EnemyScript
	var angle := randf() * TAU
	enemy.global_position = player.global_position + Vector2.RIGHT.rotated(angle) * wave_data.spawn_radius
	enemy.configure(wave_data.enemy_data as EnemyDataScript, player)
	enemies.add_child(enemy)
