extends SceneTree

const SETTLEMENT_SCENE_PATH := "res://scenes/ui/SettlementPanel.tscn"

class SignalRecorder:
	extends Node

	var restart_count := 0
	var return_menu_count := 0
	var quit_count := 0

	func _on_restart_run_requested() -> void:
		restart_count += 1

	func _on_return_to_menu_requested() -> void:
		return_menu_count += 1

	func _on_quit_game_requested() -> void:
		quit_count += 1

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var game_events := root.get_node_or_null("GameEvents")
	if game_events == null:
		_fail(["GameEvents autoload is missing"])
		return

	for signal_name in ["restart_run_requested", "return_to_menu_requested", "quit_game_requested"]:
		if game_events.has_signal(signal_name) == false:
			failures.append("GameEvents is missing %s signal" % signal_name)

	var settlement_scene := load(SETTLEMENT_SCENE_PATH) as PackedScene
	if settlement_scene == null:
		_fail(["Failed to load SettlementPanel scene"])
		return

	var settlement := settlement_scene.instantiate()
	root.add_child(settlement)
	await process_frame

	if settlement.process_mode != Node.PROCESS_MODE_ALWAYS:
		failures.append("SettlementPanel must process while the tree is paused")

	var restart_button := _find_button(settlement, "RestartButton")
	var return_menu_button := _find_button(settlement, "ReturnMenuButton")
	var quit_button := _find_button(settlement, "QuitButton")
	for button_info in [
		{"name": "RestartButton", "node": restart_button, "text": "Restart"},
		{"name": "ReturnMenuButton", "node": return_menu_button, "text": "Return Menu"},
		{"name": "QuitButton", "node": quit_button, "text": "Quit"}
	]:
		var button := button_info["node"] as Button
		if button == null:
			failures.append("SettlementPanel is missing %s" % button_info["name"])
			continue
		if button.text != button_info["text"]:
			failures.append("%s text must be '%s', got '%s'" % [button_info["name"], button_info["text"], button.text])
		if button.process_mode != Node.PROCESS_MODE_ALWAYS:
			failures.append("%s must process while the tree is paused" % button_info["name"])

	if failures.is_empty():
		var recorder := SignalRecorder.new()
		root.add_child(recorder)
		game_events.connect("restart_run_requested", recorder._on_restart_run_requested)
		game_events.connect("return_to_menu_requested", recorder._on_return_to_menu_requested)
		game_events.connect("quit_game_requested", recorder._on_quit_game_requested)

		paused = true
		restart_button.emit_signal("pressed")
		return_menu_button.emit_signal("pressed")
		quit_button.emit_signal("pressed")
		await process_frame
		paused = false

		if recorder.restart_count != 1:
			failures.append("RestartButton emitted restart_run_requested %d times" % recorder.restart_count)
		if recorder.return_menu_count != 1:
			failures.append("ReturnMenuButton emitted return_to_menu_requested %d times" % recorder.return_menu_count)
		if recorder.quit_count != 1:
			failures.append("QuitButton emitted quit_game_requested %d times" % recorder.quit_count)

	if failures.is_empty():
		print("PASS: settlement actions contract")
		quit(0)
	else:
		_fail(failures)

func _find_button(parent: Node, node_name: String) -> Button:
	return parent.find_child(node_name, true, false) as Button

func _fail(failures: Array[String]) -> void:
	for failure in failures:
		push_error(failure)
	quit(1)
