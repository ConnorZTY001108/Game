class_name RunTimerSystem
extends Node

signal time_changed(elapsed_seconds: float)

@export var run_duration_seconds: float = 360.0
var elapsed_seconds: float = 0.0

func _ready() -> void:
	if GameEvents.run_started.is_connected(_on_run_started) == false:
		GameEvents.run_started.connect(_on_run_started)

func _process(delta: float) -> void:
	if GameRuntime.state != GameRuntime.RunState.PLAYING:
		return
	elapsed_seconds += delta
	GameRuntime.elapsed_seconds = elapsed_seconds
	time_changed.emit(elapsed_seconds)
	if elapsed_seconds >= run_duration_seconds:
		GameRuntime.finish_run("victory")

func _on_run_started() -> void:
	elapsed_seconds = 0.0
	time_changed.emit(elapsed_seconds)
