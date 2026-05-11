extends Node

enum RunState { BOOT, PLAYING, PAUSED, LEVEL_UP, GAME_OVER, VICTORY }

var state: RunState = RunState.BOOT
var elapsed_seconds: float = 0.0
@export var state_logging_enabled: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if state != RunState.PLAYING:
		return
	elapsed_seconds += delta
	GameEvents.augment_periodic_tick.emit(elapsed_seconds)

func start_run() -> void:
	elapsed_seconds = 0.0
	state = RunState.PLAYING
	get_tree().paused = false
	log_state("run_started")
	GameEvents.run_started.emit()
	GameEvents.augment_periodic_tick.emit(elapsed_seconds)

func reset_to_boot() -> void:
	elapsed_seconds = 0.0
	state = RunState.BOOT
	get_tree().paused = false
	log_state("boot_reset")

func set_paused(is_paused: bool) -> void:
	if state == RunState.GAME_OVER or state == RunState.VICTORY:
		return
	state = RunState.PAUSED if is_paused else RunState.PLAYING
	get_tree().paused = is_paused
	log_state("run_pause_changed", {"is_paused": is_paused})
	GameEvents.run_paused.emit(is_paused)

func enter_level_up() -> void:
	if state != RunState.PLAYING:
		return
	state = RunState.LEVEL_UP
	get_tree().paused = true
	log_state("level_up_entered")

func resume_from_level_up() -> void:
	if state != RunState.LEVEL_UP:
		return
	state = RunState.PLAYING
	get_tree().paused = false
	log_state("level_up_resumed")

func finish_run(result: String) -> void:
	if state == RunState.GAME_OVER or state == RunState.VICTORY:
		return
	if result == "victory":
		state = RunState.VICTORY
	else:
		state = RunState.GAME_OVER
	get_tree().paused = true
	log_state("run_finished", {"result": result})
	GameEvents.run_finished.emit(result)

func log_state(event_name: String, payload: Dictionary = {}) -> void:
	if state_logging_enabled == false:
		return
	var tree := get_tree()
	var is_tree_paused := false
	if tree != null:
		is_tree_paused = tree.paused
	print("[GameState] event=%s state=%s elapsed=%.2f paused=%s payload=%s" % [
		event_name,
		get_state_name(),
		elapsed_seconds,
		str(is_tree_paused),
		str(payload)
	])

func get_state_name() -> String:
	match state:
		RunState.BOOT:
			return "BOOT"
		RunState.PLAYING:
			return "PLAYING"
		RunState.PAUSED:
			return "PAUSED"
		RunState.LEVEL_UP:
			return "LEVEL_UP"
		RunState.GAME_OVER:
			return "GAME_OVER"
		RunState.VICTORY:
			return "VICTORY"
		_:
			return "UNKNOWN"
