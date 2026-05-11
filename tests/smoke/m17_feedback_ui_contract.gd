extends SceneTree

const RUN_SCENE_PATH := "res://scenes/run/RunScene.tscn"
const ENEMY_SCENE_PATH := "res://scenes/enemies/Enemy.tscn"
const DAMAGE_UPGRADE_PATH := "res://data/content/upgrades/damage_focus.tres"

func _initialize() -> void:
	_run()

func _run() -> void:
	var failures: Array[String] = []
	var run_scene_packed := load(RUN_SCENE_PATH) as PackedScene
	var enemy_scene := load(ENEMY_SCENE_PATH) as PackedScene
	var damage_upgrade := load(DAMAGE_UPGRADE_PATH) as Resource
	if run_scene_packed == null or enemy_scene == null or damage_upgrade == null:
		_fail(["Failed to load M1.7 smoke resources"])
		return

	var run_scene := run_scene_packed.instantiate()
	root.add_child(run_scene)
	await process_frame
	run_scene.call("begin_run")

	var game_runtime := root.get_node_or_null("GameRuntime")
	var game_events := root.get_node_or_null("GameEvents")
	var hud := run_scene.get_node_or_null("CanvasLayer/HUD")
	var settlement := run_scene.get_node_or_null("CanvasLayer/SettlementPanel")
	var level_panel := run_scene.get_node_or_null("CanvasLayer/LevelUpPanel")
	var debug_overlay := run_scene.get_node_or_null("CanvasLayer/DebugOverlay")
	var player: Variant = run_scene.get_node_or_null("World/Player")
	var enemies := run_scene.get_node_or_null("World/Enemies")
	if game_runtime == null or game_events == null or hud == null or settlement == null or level_panel == null or player == null or enemies == null:
		_fail(["RunScene is missing required M1.7 nodes"])
		return

	if debug_overlay == null:
		failures.append("RunScene/CanvasLayer/DebugOverlay is missing")
	elif debug_overlay.visible:
		failures.append("DebugOverlay must be hidden by default")

	game_events.emit_signal("upgrade_selected", damage_upgrade)
	game_events.emit_signal("rune_triggered", "scorch_mark", player, {"route_label": "灼痕弹链"})
	if not _feedback_contains(hud, "升级："):
		failures.append("Upgrade feedback did not use Chinese prefix")
	if not _feedback_contains(hud, "符文触发："):
		failures.append("Rune feedback did not use Chinese prefix")

	var cap_tags: Array[String] = ["m17_cap"]
	for index in range(30):
		game_events.emit_signal("damage_number_requested", 1.0, Vector2(24.0 + index, 24.0), cap_tags)
	var feedback_layer := hud.get_node_or_null("FeedbackLayer")
	if feedback_layer == null:
		failures.append("HUD is missing FeedbackLayer")
	elif feedback_layer.get_child_count() > 18:
		failures.append("HUD visible feedback cap exceeded: %d labels" % feedback_layer.get_child_count())

	game_events.emit_signal("map_event_triggered", "m17_event", "测试地图事件")
	var map_prompt_label := hud.get_node_or_null("MapPromptLabel") as Label
	if map_prompt_label == null:
		failures.append("HUD is missing separate MapPromptLabel")
	elif map_prompt_label.text.contains("地图事件：测试地图事件") == false:
		failures.append("Map event prompt was not rendered separately: %s" % map_prompt_label.text)

	var enemy: Variant = enemy_scene.instantiate()
	enemies.add_child(enemy)
	enemy.health_component.configure(20.0)
	var hit_tags: Array[String] = ["m17_hit_flash"]
	enemy.apply_damage(1.0, hit_tags)
	if enemy.has_method("is_hit_flash_active") == false:
		failures.append("Enemy is missing is_hit_flash_active()")
	elif enemy.call("is_hit_flash_active") == false:
		failures.append("Enemy hit flash was not active after damage")

	player.health_component.configure(20.0)
	player.take_contact_damage(1.0)
	if player.has_method("is_damage_blink_active") == false:
		failures.append("Player is missing is_damage_blink_active()")
	elif player.call("is_damage_blink_active") == false:
		failures.append("Player damage blink was not active after health decrease")

	var test_options: Array[Resource] = [damage_upgrade, damage_upgrade, damage_upgrade]
	game_events.emit_signal("level_up_requested", test_options)
	if level_panel.visible == false:
		failures.append("LevelUpPanel did not show test options")
	else:
		var options := level_panel.get_node_or_null("Panel/Margin/Content/Options")
		if options == null:
			failures.append("LevelUpPanel is missing Options container")
		elif options.get_child_count() != 3:
			failures.append("LevelUpPanel rendered %d options, expected 3" % options.get_child_count())
		else:
			for child in options.get_children():
				var button := child as Button
				if button == null:
					failures.append("LevelUpPanel option is not a Button")
				elif button.text.split("\n", false).size() != 3:
					failures.append("LevelUpPanel option is not exactly 3 readable lines: %s" % button.text)
				elif button.autowrap_mode == TextServer.AUTOWRAP_OFF:
					failures.append("LevelUpPanel option wrapping is disabled")

	level_panel.visible = false
	game_runtime.call("start_run")
	game_events.call("reset_map_objective_counters", 3)
	game_events.call("record_map_obelisk_activation")
	game_events.call("record_map_obelisk_activation")
	game_events.call("record_map_event_trigger", "m17_cache", "测试地图事件")
	run_scene.run_timer.elapsed_seconds = 91.0
	game_runtime.call("finish_run", "victory")
	var victory_text := str(settlement.call("get_summary_text"))
	for required in ["胜利", "存活时间", "击杀", "等级", "本局选择", "符文碑", "地图事件", "地图目标"]:
		if victory_text.contains(required) == false:
			failures.append("Victory settlement missing '%s': %s" % [required, victory_text])

	game_runtime.call("start_run")
	player.health_component.configure(1.0)
	player.take_contact_damage(2.0)
	var defeat_text := str(settlement.call("get_summary_text"))
	if defeat_text.contains("失败") == false:
		failures.append("Defeat settlement missing Chinese defeat text: %s" % defeat_text)
	if not _feedback_contains(hud, "失败"):
		failures.append("Defeat feedback did not use Chinese text")

	if failures.is_empty():
		print("PASS: M1.7 feedback and UI contract")
		quit(0)
	else:
		_fail(failures)

func _feedback_contains(hud: Node, fragment: String) -> bool:
	var texts: Array = hud.call("get_feedback_texts")
	for text in texts:
		if str(text).contains(fragment):
			return true
	return false

func _fail(failures: Array[String]) -> void:
	for failure in failures:
		push_error(failure)
	quit(1)
