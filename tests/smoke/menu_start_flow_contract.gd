extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	if ProjectSettings.get_setting("application/run/main_scene") != MAIN_SCENE_PATH:
		failures.append("project.godot main scene must stay %s" % MAIN_SCENE_PATH)

	var main_scene := load(MAIN_SCENE_PATH) as PackedScene
	if main_scene == null:
		_fail(["Failed to load Main scene"])
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame

	var game_runtime := root.get_node_or_null("GameRuntime")
	var game_root := main.get_node_or_null("GameRoot")
	var main_menu := main.get_node_or_null("MainMenu")
	if game_runtime == null:
		failures.append("GameRuntime autoload is missing")
	if game_root == null:
		failures.append("Main is missing GameRoot")
	if main_menu == null:
		failures.append("Main must show MainMenu on boot")

	if game_runtime != null:
		if int(game_runtime.get("state")) != 0:
			failures.append("GameRuntime should boot in BOOT before Start Game, got state %d" % int(game_runtime.get("state")))
		if paused:
			failures.append("Tree should be unpaused on boot menu")

	if game_root != null and _count_run_scenes(game_root) != 0:
		failures.append("GameRoot must not instance RunScene before Start Game")

	if main_menu != null:
		if main_menu.process_mode != Node.PROCESS_MODE_ALWAYS:
			failures.append("MainMenu must process while the tree is paused")
		var start_button := _find_button(main_menu, "StartButton")
		var quit_button := _find_button(main_menu, "QuitButton")
		if start_button == null:
			failures.append("MainMenu is missing StartButton")
		elif start_button.text != "Start Game":
			failures.append("StartButton text must be 'Start Game', got '%s'" % start_button.text)
		if quit_button == null:
			failures.append("MainMenu is missing QuitButton")
		elif quit_button.text != "Quit":
			failures.append("QuitButton text must be 'Quit', got '%s'" % quit_button.text)

		if start_button != null and game_root != null and game_runtime != null:
			start_button.emit_signal("pressed")
			await process_frame
			await process_frame
			if main_menu.visible:
				failures.append("MainMenu should hide after Start Game")
			if _count_run_scenes(game_root) != 1:
				failures.append("GameRoot should create exactly one RunScene after Start Game, found %d" % _count_run_scenes(game_root))
			if int(game_runtime.get("state")) != 1:
				failures.append("GameRuntime should be PLAYING after Start Game, got state %d" % int(game_runtime.get("state")))
			if paused:
				failures.append("Tree should be unpaused after Start Game")

			var first_run := game_root.call("get_current_run") as Node
			var game_events := root.get_node("GameEvents")
			game_events.emit_signal("restart_run_requested")
			await process_frame
			await process_frame
			var restarted_run := game_root.call("get_current_run") as Node
			if restarted_run == null:
				failures.append("restart_run_requested should create a new RunScene")
			elif restarted_run == first_run:
				failures.append("restart_run_requested should replace the previous RunScene")
			if _count_run_scenes(game_root) != 1:
				failures.append("GameRoot should keep exactly one RunScene after restart, found %d" % _count_run_scenes(game_root))
			if int(game_runtime.get("state")) != 1:
				failures.append("GameRuntime should be PLAYING after restart, got state %d" % int(game_runtime.get("state")))

			game_events.emit_signal("return_to_menu_requested")
			await process_frame
			await process_frame
			if main_menu.visible == false:
				failures.append("MainMenu should be visible after return_to_menu_requested")
			if _count_run_scenes(game_root) != 0:
				failures.append("GameRoot should clear RunScene after return_to_menu_requested")
			if int(game_runtime.get("state")) != 0:
				failures.append("GameRuntime should reset to BOOT after return_to_menu_requested, got state %d" % int(game_runtime.get("state")))

	if failures.is_empty():
		print("PASS: menu start flow contract")
		quit(0)
	else:
		_fail(failures)

func _find_button(parent: Node, node_name: String) -> Button:
	return parent.find_child(node_name, true, false) as Button

func _count_run_scenes(parent: Node) -> int:
	var count := 0
	for child in parent.get_children():
		var script := child.get_script() as Script
		var script_path := "" if script == null else script.resource_path
		if child.name == "RunScene" or script_path == "res://scripts/run/RunScene.gd":
			count += 1
	return count

func _fail(failures: Array[String]) -> void:
	for failure in failures:
		push_error(failure)
	quit(1)
