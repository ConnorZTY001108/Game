class_name MainMenu
extends Control

signal start_game_requested

@onready var start_button: Button = $Panel/Margin/Content/Actions/StartButton
@onready var quit_button: Button = $Panel/Margin/Content/Actions/QuitButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	start_button.process_mode = Node.PROCESS_MODE_ALWAYS
	quit_button.process_mode = Node.PROCESS_MODE_ALWAYS
	if start_button.pressed.is_connected(_on_start_button_pressed) == false:
		start_button.pressed.connect(_on_start_button_pressed)
	if quit_button.pressed.is_connected(_on_quit_button_pressed) == false:
		quit_button.pressed.connect(_on_quit_button_pressed)

func _on_start_button_pressed() -> void:
	start_game_requested.emit()

func _on_quit_button_pressed() -> void:
	GameEvents.quit_game_requested.emit()
