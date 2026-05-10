extends Node

enum RunState { BOOT, PLAYING, PAUSED, LEVEL_UP, GAME_OVER, VICTORY }

var state: RunState = RunState.BOOT
var elapsed_seconds: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func start_run() -> void:
	elapsed_seconds = 0.0
	state = RunState.PLAYING
	get_tree().paused = false
	GameEvents.run_started.emit()

func set_paused(is_paused: bool) -> void:
	if state == RunState.GAME_OVER or state == RunState.VICTORY:
		return
	state = RunState.PAUSED if is_paused else RunState.PLAYING
	get_tree().paused = is_paused
	GameEvents.run_paused.emit(is_paused)

func enter_level_up() -> void:
	if state != RunState.PLAYING:
		return
	state = RunState.LEVEL_UP
	get_tree().paused = true

func resume_from_level_up() -> void:
	if state != RunState.LEVEL_UP:
		return
	state = RunState.PLAYING
	get_tree().paused = false

func finish_run(result: String) -> void:
	if result == "victory":
		state = RunState.VICTORY
	else:
		state = RunState.GAME_OVER
	get_tree().paused = true
	GameEvents.run_finished.emit(result)
