extends SceneTree

const RUN_SCENE_PATH := "res://scenes/run/RunScene.tscn"
const ENEMY_SCENE_PATH := "res://scenes/enemies/Enemy.tscn"
const DAMAGE_UPGRADE_PATH := "res://data/content/upgrades/damage_focus.tres"

class RunFinishedRecorder:
	extends Node

	var results: Array[String] = []

	func _on_run_finished(result: String) -> void:
		results.append(result)

func _initialize() -> void:
	_run()

func _run() -> void:
	var run_scene_packed := load(RUN_SCENE_PATH) as PackedScene
	var enemy_scene := load(ENEMY_SCENE_PATH) as PackedScene
	var damage_upgrade := load(DAMAGE_UPGRADE_PATH) as Resource
	if run_scene_packed == null or enemy_scene == null or damage_upgrade == null:
		push_error("Failed to load feedback settlement smoke resources")
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
	var hud: Variant = run_scene.get_node("CanvasLayer/HUD")
	var settlement: Variant = run_scene.get_node("CanvasLayer/SettlementPanel")
	var player: Variant = run_scene.get_node("World/Player")
	var enemies := run_scene.get_node("World/Enemies")
	if hud == null or settlement == null or player == null or enemies == null:
		push_error("RunScene is missing feedback or settlement nodes")
		quit(1)
		return
	if settlement.visible:
		push_error("SettlementPanel should be hidden at run start")
		quit(1)
		return

	player.health_component.configure(20.0)
	player.take_contact_damage(3.0)
	if not _feedback_contains(hud, "受击"):
		push_error("Player damage feedback was not rendered")
		quit(1)
		return

	var enemy: Variant = enemy_scene.instantiate()
	enemies.add_child(enemy)
	enemy.global_position = Vector2(160.0, 40.0)
	enemy.health_component.configure(12.0)
	var projectile_tags: Array[String] = ["projectile"]
	enemy.apply_damage(4.0, projectile_tags)
	if not _feedback_contains(hud, "-4"):
		push_error("Damage number feedback was not rendered")
		quit(1)
		return

	enemy.apply_damage(30.0, projectile_tags)
	if not _feedback_contains(hud, "KILL"):
		push_error("Kill feedback was not rendered")
		quit(1)
		return

	game_events.emit_signal("upgrade_selected", damage_upgrade)
	game_events.emit_signal("rune_triggered", "scorch_mark", player, {"route_label": "Scorch Route"})
	if not _feedback_contains(hud, "升级："):
		push_error("Upgrade feedback was not rendered")
		quit(1)
		return
	if not _feedback_contains(hud, "符文触发："):
		push_error("Rune trigger feedback was not rendered")
		quit(1)
		return

	run_scene.run_timer.elapsed_seconds = 91.0
	game_runtime.call("finish_run", "victory")
	if settlement.visible == false or not settlement.get_summary_text().contains("胜利"):
		push_error("Victory settlement was not visible/readable")
		quit(1)
		return
	if not settlement.get_summary_text().contains("存活时间：01:31"):
		push_error("Settlement survival time was not rendered: %s" % settlement.get_summary_text())
		quit(1)
		return
	if not settlement.get_summary_text().contains("击杀：1"):
		push_error("Settlement kill count was not rendered: %s" % settlement.get_summary_text())
		quit(1)
		return
	if not settlement.get_summary_text().contains("本局选择："):
		push_error("Settlement route summary was not rendered: %s" % settlement.get_summary_text())
		quit(1)
		return
	if recorder.results != ["victory"]:
		push_error("Victory run_finished results were %s" % [recorder.results])
		quit(1)
		return

	game_runtime.call("finish_run", "defeat")
	if recorder.results != ["victory"]:
		push_error("Mixed finish_run after victory emitted results %s" % [recorder.results])
		quit(1)
		return
	if not settlement.get_summary_text().contains("胜利") or settlement.get_summary_text().contains("失败"):
		push_error("Defeat overwrote victory settlement: %s" % settlement.get_summary_text())
		quit(1)
		return

	game_runtime.call("start_run")
	if settlement.visible:
		push_error("SettlementPanel did not hide on run restart")
		quit(1)
		return
	if _feedback_contains(hud, "KILL") or _feedback_contains(hud, "升级：") or _feedback_contains(hud, "符文触发："):
		push_error("HUD feedback messages were not cleared on run restart: %s" % [hud.call("get_feedback_texts")])
		quit(1)
		return
	game_runtime.call("finish_run", "defeat")
	if settlement.visible == false or not settlement.get_summary_text().contains("失败"):
		push_error("Defeat settlement was not visible/readable")
		quit(1)
		return
	if not settlement.get_summary_text().contains("存活时间：00:00"):
		push_error("Immediate defeat carried stale time: %s" % settlement.get_summary_text())
		quit(1)
		return
	if not settlement.get_summary_text().contains("击杀：0"):
		push_error("Immediate defeat carried stale kills: %s" % settlement.get_summary_text())
		quit(1)
		return
	if recorder.results != ["victory", "defeat"]:
		push_error("Defeat run_finished results after restart were %s" % [recorder.results])
		quit(1)
		return

	game_runtime.call("finish_run", "victory")
	if recorder.results != ["victory", "defeat"]:
		push_error("Mixed finish_run after defeat emitted results %s" % [recorder.results])
		quit(1)
		return
	if not settlement.get_summary_text().contains("失败") or settlement.get_summary_text().contains("胜利"):
		push_error("Victory overwrote defeat settlement: %s" % settlement.get_summary_text())
		quit(1)
		return

	print("PASS: M1 feedback and settlement loop")
	quit(0)

func _feedback_contains(hud: Node, fragment: String) -> bool:
	var texts: Array = hud.call("get_feedback_texts")
	for text in texts:
		if str(text).contains(fragment):
			return true
	return false
