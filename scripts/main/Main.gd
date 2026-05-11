extends Node

@onready var main_menu: Node = $MainMenu
@onready var game_root: Node = $GameRoot

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if main_menu.start_game_requested.is_connected(_on_start_game_requested) == false:
		main_menu.start_game_requested.connect(_on_start_game_requested)
	if GameEvents.restart_run_requested.is_connected(_on_restart_run_requested) == false:
		GameEvents.restart_run_requested.connect(_on_restart_run_requested)
	if GameEvents.return_to_menu_requested.is_connected(_on_return_to_menu_requested) == false:
		GameEvents.return_to_menu_requested.connect(_on_return_to_menu_requested)
	if GameEvents.quit_game_requested.is_connected(_on_quit_game_requested) == false:
		GameEvents.quit_game_requested.connect(_on_quit_game_requested)
	show_menu()

func show_menu() -> void:
	game_root.clear_run()
	GameRuntime.reset_to_boot()
	main_menu.visible = true

func _on_start_game_requested() -> void:
	main_menu.visible = false
	game_root.start_new_run()

func _on_restart_run_requested() -> void:
	main_menu.visible = false
	game_root.restart_run()

func _on_return_to_menu_requested() -> void:
	show_menu()

func _on_quit_game_requested() -> void:
	get_tree().quit()
