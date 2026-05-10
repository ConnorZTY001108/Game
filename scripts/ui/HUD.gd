class_name HUD
extends Control

const PlayerScript := preload("res://scripts/player/Player.gd")
const RunTimerSystemScript := preload("res://scripts/systems/RunTimerSystem.gd")

@onready var health_label: Label = $Panel/Margin/Stats/HealthLabel
@onready var level_label: Label = $Panel/Margin/Stats/LevelLabel
@onready var experience_label: Label = $Panel/Margin/Stats/ExperienceLabel
@onready var timer_label: Label = $Panel/Margin/Stats/TimerLabel
@onready var kill_label: Label = $Panel/Margin/Stats/KillLabel

var kills: int = 0

func _ready() -> void:
	GameEvents.enemy_died.connect(_on_enemy_died)
	GameEvents.level_changed.connect(_on_level_changed)
	GameEvents.experience_collected.connect(_on_experience_collected)
	GameEvents.run_finished.connect(_on_run_finished)
	_on_level_changed(1)
	_on_experience_collected(0)
	_update_timer(0.0)
	kill_label.text = "击杀: 0"

func bind_player(player: PlayerScript) -> void:
	player.health_component.health_changed.connect(_on_health_changed)
	_on_health_changed(player.health_component.current_health, player.health_component.max_health)

func bind_timer(timer: RunTimerSystemScript) -> void:
	timer.time_changed.connect(_update_timer)

func _on_health_changed(current: float, maximum: float) -> void:
	health_label.text = "生命: %d/%d" % [int(current), int(maximum)]

func _on_level_changed(level: int) -> void:
	level_label.text = "等级: %d" % level

func _on_experience_collected(amount: int) -> void:
	experience_label.text = "经验: %d" % amount

func _on_enemy_died(_enemy: Node, _experience_value: int) -> void:
	kills += 1
	kill_label.text = "击杀: %d" % kills

func _update_timer(seconds: float) -> void:
	var minutes := int(seconds) / 60
	var remainder := int(seconds) % 60
	timer_label.text = "时间: %02d:%02d" % [minutes, remainder]

func _on_run_finished(result: String) -> void:
	var localized_result := "胜利" if result == "victory" else "失败"
	timer_label.text = "本局结束：%s" % localized_result
