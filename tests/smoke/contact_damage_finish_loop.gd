extends SceneTree

class RunFinishedRecorder:
	extends Node

	var results: Array[String] = []

	func _on_run_finished(result: String) -> void:
		results.append(result)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var player_scene := load("res://scenes/player/Player.tscn") as PackedScene
	var enemy_scene := load("res://scenes/enemies/Enemy.tscn") as PackedScene
	var hud_scene := load("res://scenes/ui/HUD.tscn") as PackedScene
	if player_scene == null or enemy_scene == null or hud_scene == null:
		push_error("Failed to load contact damage smoke resources")
		quit(1)
		return

	var game_runtime := root.get_node("GameRuntime")
	var game_events := root.get_node("GameEvents")
	game_runtime.call("start_run")

	var recorder := RunFinishedRecorder.new()
	root.add_child(recorder)
	game_events.connect("run_finished", recorder._on_run_finished)

	var world := Node2D.new()
	root.add_child(world)
	var player: Variant = player_scene.instantiate()
	var enemy: Variant = enemy_scene.instantiate()
	var hud: Variant = hud_scene.instantiate()
	world.add_child(player)
	world.add_child(enemy)
	root.add_child(hud)
	await process_frame

	if enemy.has_method("_on_contact_area_body_entered") == false or enemy.has_method("_on_contact_area_body_exited") == false:
		push_error("Enemy is missing ContactArea body callbacks")
		quit(1)
		return

	var contact_area := enemy.get_node_or_null("ContactArea") as Area2D
	if contact_area == null:
		push_error("Enemy is missing ContactArea")
		quit(1)
		return
	if contact_area.is_connected("body_entered", Callable(enemy, "_on_contact_area_body_entered")) == false:
		push_error("ContactArea body_entered is not connected to Enemy")
		quit(1)
		return
	if contact_area.is_connected("body_exited", Callable(enemy, "_on_contact_area_body_exited")) == false:
		push_error("ContactArea body_exited is not connected to Enemy")
		quit(1)
		return

	hud.call("bind_player", player)
	player.health_component.configure(16.0)
	enemy.target = player
	enemy.contact_interval = 0.6
	enemy.contact_cooldown = 0.0

	contact_area.emit_signal("body_entered", player)
	enemy.call("_physics_process", 0.1)
	if not is_equal_approx(player.health_component.current_health, 8.0):
		push_error("First contact tick left HP at %.2f, expected 8.00" % player.health_component.current_health)
		quit(1)
		return

	enemy.call("_physics_process", 0.3)
	if not is_equal_approx(player.health_component.current_health, 8.0):
		push_error("Contact damage ignored cooldown")
		quit(1)
		return

	enemy.call("_physics_process", 0.3)
	if recorder.results != ["defeat"]:
		push_error("Defeat run_finished results were %s" % [recorder.results])
		quit(1)
		return
	if int(game_runtime.get("state")) != 4 or paused == false:
		push_error("Defeat did not enter GAME_OVER and pause the tree")
		quit(1)
		return
	if hud.timer_label.text != "本局结束：失败":
		push_error("HUD defeat text was '%s'" % hud.timer_label.text)
		quit(1)
		return

	game_runtime.call("start_run")
	game_runtime.call("finish_run", "victory")
	if recorder.results.back() != "victory":
		push_error("Victory run_finished result was %s" % recorder.results.back())
		quit(1)
		return
	if int(game_runtime.get("state")) != 5 or paused == false:
		push_error("Victory did not enter VICTORY and pause the tree")
		quit(1)
		return
	if hud.timer_label.text != "本局结束：胜利":
		push_error("HUD victory text was '%s'" % hud.timer_label.text)
		quit(1)
		return

	print("PASS: contact damage defeat and run-finished HUD loop")
	quit(0)
