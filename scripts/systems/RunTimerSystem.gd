class_name RunTimerSystem
extends Node

signal time_changed(elapsed_seconds: float)

@export var run_duration_seconds: float = 180.0
var elapsed_seconds: float = 0.0

func _process(delta: float) -> void:
	if GameRuntime.state != GameRuntime.RunState.PLAYING:
		return
	elapsed_seconds += delta
	GameRuntime.elapsed_seconds = elapsed_seconds
	time_changed.emit(elapsed_seconds)
	if elapsed_seconds >= run_duration_seconds:
		GameRuntime.finish_run("victory")
