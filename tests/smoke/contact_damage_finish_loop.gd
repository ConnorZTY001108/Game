extends SceneTree

class RunFinishedRecorder:
	extends Node

	var results: Array[String] = []

	func _on_run_finished(result: String) -> void:
		results.append(result)

func _initialize() -> void:
	_run()

func _run() -> void:
	var run_scene_packed := load("res://scenes/run/RunScene.tscn") as PackedScene
	var enemy_scene := load("res://scenes/enemies/Enemy.tscn") as PackedScene
	if run_scene_packed == null or enemy_scene == null:
		push_error("Failed to load contact damage smoke resources")
		quit(1)
		return

	var run_scene := run_scene_packed.instantiate()
	root.add_child(run_scene)
	await process_frame
	run_scene.call("begin_run")

	var game_runtime := root.get_node("GameRuntime")
	var game_events := root.get_node("GameEvents")
	var recorder := RunFinishedRecorder.new()
	root.add_child(recorder)
	game_events.connect("run_finished", recorder._on_run_finished)

	var player: Variant = run_scene.get_node("World/Player")
	var enemies := run_scene.get_node("World/Enemies")
	var hud: Variant = run_scene.get_node("CanvasLayer/HUD")
	var settlement: Variant = run_scene.get_node("CanvasLayer/SettlementPanel")
	var enemy: Variant = enemy_scene.instantiate()
	enemies.add_child(enemy)

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

	player.health_component.configure(16.0)
	enemy.target = player
	enemy.contact_interval = 0.6
	enemy.contact_cooldown = 0.0
	enemy.global_position = player.global_position

	var real_contact_targets: Array = enemy.get("contact_targets")
	for frame_index in 3:
		if not real_contact_targets.is_empty():
			break
		await physics_frame
		real_contact_targets = enemy.get("contact_targets")
	if real_contact_targets.is_empty():
		push_error("Real ContactArea overlap did not register the player body")
		quit(1)
		return

	enemy.call("_physics_process", 0.1)
	if not is_equal_approx(player.health_component.current_health, 8.0):
		push_error("Real contact overlap left HP at %.2f, expected 8.00" % player.health_component.current_health)
		quit(1)
		return

	player.health_component.configure(16.0)
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
	if not str(hud.timer_label.text).contains("失败"):
		push_error("HUD defeat text was '%s'" % hud.timer_label.text)
		quit(1)
		return
	if settlement.visible == false or not settlement.get_summary_text().contains("失败"):
		push_error("Settlement defeat text was '%s'" % settlement.get_summary_text())
		quit(1)
		return

	game_runtime.call("start_run")
	run_scene.run_timer.elapsed_seconds = 47.0
	game_runtime.call("finish_run", "victory")
	if recorder.results.back() != "victory":
		push_error("Victory run_finished result was %s" % recorder.results.back())
		quit(1)
		return
	if int(game_runtime.get("state")) != 5 or paused == false:
		push_error("Victory did not enter VICTORY and pause the tree")
		quit(1)
		return
	if not str(hud.timer_label.text).contains("胜利"):
		push_error("HUD victory text was '%s'" % hud.timer_label.text)
		quit(1)
		return
	if settlement.visible == false or not settlement.get_summary_text().contains("胜利"):
		push_error("Settlement victory text was '%s'" % settlement.get_summary_text())
		quit(1)
		return
	if not settlement.get_summary_text().contains("存活时间：00:47"):
		push_error("Settlement victory time was '%s'" % settlement.get_summary_text())
		quit(1)
		return

	print("PASS: contact damage defeat and settlement loop")
	quit(0)
