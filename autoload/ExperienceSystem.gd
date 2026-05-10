extends Node

var level: int = 1
var experience: int = 0
var next_level_experience: int = 5
var pending_level_ups: int = 0

func _ready() -> void:
	GameEvents.experience_collected.connect(add_experience)

func reset() -> void:
	level = 1
	experience = 0
	next_level_experience = 5
	pending_level_ups = 0
	GameEvents.level_changed.emit(level)

func add_experience(amount: int) -> void:
	experience += amount
	while experience >= next_level_experience:
		experience -= next_level_experience
		level += 1
		next_level_experience += 5
		pending_level_ups += 1
		GameEvents.level_changed.emit(level)
	_request_next_level_up()

func complete_level_up_selection() -> void:
	if pending_level_ups > 0:
		pending_level_ups -= 1
		GameEvents.level_up_requested.emit(UpgradeSystem.generate_level_up_options({"level": level}))
		return
	GameRuntime.resume_from_level_up()

func _request_next_level_up() -> void:
	if pending_level_ups <= 0:
		return
	if GameRuntime.state != GameRuntime.RunState.PLAYING:
		return
	pending_level_ups -= 1
	GameRuntime.enter_level_up()
	if GameRuntime.state == GameRuntime.RunState.LEVEL_UP:
		GameEvents.level_up_requested.emit(UpgradeSystem.generate_level_up_options({"level": level}))
