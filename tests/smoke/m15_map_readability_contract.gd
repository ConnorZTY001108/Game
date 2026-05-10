extends SceneTree

const RUN_SCENE_PATH := "res://scenes/run/RunScene.tscn"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var run_scene_packed := load(RUN_SCENE_PATH) as PackedScene
	if run_scene_packed == null:
		_fail(["Failed to load %s" % RUN_SCENE_PATH])
		return

	var run_scene := run_scene_packed.instantiate()
	root.add_child(run_scene)
	await process_frame

	_validate_run_scene_map(run_scene, failures)
	_validate_region_tracking(run_scene, failures)
	_validate_map_events(failures)
	_validate_hud_region_prompt(run_scene, failures)

	if failures.is_empty():
		print("PASS: M1.5 map readability contract")
		quit(0)
	else:
		_fail(failures)

func _validate_run_scene_map(run_scene: Node, failures: Array[String]) -> void:
	var map_director := run_scene.get_node_or_null("World/Map/MapDirector")
	if map_director == null:
		failures.append("RunScene is missing World/Map/MapDirector")
		return

	var player := run_scene.get_node_or_null("World/Player") as Node2D
	if player == null:
		failures.append("RunScene is missing World/Player")
		return

	if int(map_director.call("get_landmark_count")) != 4:
		failures.append("MapDirector expected exactly 4 landmarks, got %d" % int(map_director.call("get_landmark_count")))
	if int(map_director.call("get_region_count")) < 3:
		failures.append("MapDirector expected at least 3 regions, got %d" % int(map_director.call("get_region_count")))

	for landmark_id in ["spawn_altar", "broken_tower", "glowing_rift_landmark", "ruin_gate"]:
		if _has_landmark_id(map_director, landmark_id) == false:
			failures.append("Missing landmark id: %s" % landmark_id)

	_assert_region_at(map_director, player.global_position, "altar_region", "player start", failures)
	_assert_region_at(map_director, Vector2(1350.0, -200.0), "ash_region", "ash test position", failures)
	_assert_region_at(map_director, Vector2(-1300.0, 350.0), "stone_region", "stone test position", failures)
	_assert_region_at(map_director, Vector2(500.0, -100.0), "ash_region", "overlap priority position", failures)

func _validate_region_tracking(run_scene: Node, failures: Array[String]) -> void:
	var map_director := run_scene.get_node_or_null("World/Map/MapDirector")
	var player := run_scene.get_node_or_null("World/Player") as Node2D
	if map_director == null or player == null:
		return

	player.global_position = Vector2.ZERO
	map_director.call("_update_active_region")
	_assert_active_region(map_director, "altar_region", "active region at spawn", failures)

	player.global_position = Vector2(500.0, -100.0)
	map_director.call("_update_active_region")
	_assert_active_region(map_director, "ash_region", "active region in overlap should use priority", failures)

	player.global_position = Vector2(5000.0, 5000.0)
	map_director.call("_update_active_region")
	_assert_active_region(map_director, "ash_region", "active region outside known regions should be retained", failures)

	player.global_position = Vector2(-1300.0, 350.0)
	map_director.call("_update_active_region")
	_assert_active_region(map_director, "stone_region", "active region after entering stone region", failures)

func _validate_map_events(failures: Array[String]) -> void:
	var game_events := root.get_node_or_null("GameEvents")
	if game_events == null:
		failures.append("GameEvents autoload is missing")
		return
	if game_events.has_signal("map_region_changed") == false:
		failures.append("GameEvents is missing map_region_changed")
	if game_events.has_signal("map_landmark_hint_changed") == false:
		failures.append("GameEvents is missing map_landmark_hint_changed")

func _validate_hud_region_prompt(run_scene: Node, failures: Array[String]) -> void:
	var hud := run_scene.get_node_or_null("CanvasLayer/HUD")
	if hud == null:
		failures.append("RunScene is missing CanvasLayer/HUD")
		return
	var prompt := hud.get_node_or_null("RegionPromptLabel") as Label
	if prompt == null:
		failures.append("HUD is missing RegionPromptLabel")
		return

	var game_events := root.get_node_or_null("GameEvents")
	if game_events == null:
		failures.append("GameEvents autoload is missing")
		return
	game_events.emit_signal("map_region_changed", "contract_region", "测试区域")

	if prompt.text == "":
		failures.append("HUD RegionPromptLabel did not receive region display text")
	if prompt.visible == false:
		failures.append("HUD RegionPromptLabel did not become visible after map_region_changed")

func _assert_region_at(map_director: Node, world_position: Vector2, expected_region_id: String, label: String, failures: Array[String]) -> void:
	if map_director.has_method("get_region_id_for_world_position") == false:
		failures.append("MapDirector is missing get_region_id_for_world_position for direct region queries")
		return
	var region_id := str(map_director.call("get_region_id_for_world_position", world_position))
	if region_id != expected_region_id:
		failures.append("%s resolved to %s, expected %s" % [label, region_id, expected_region_id])

func _assert_active_region(map_director: Node, expected_region_id: String, label: String, failures: Array[String]) -> void:
	var region_id := str(map_director.call("get_active_region_id"))
	if region_id != expected_region_id:
		failures.append("%s was %s, expected %s" % [label, region_id, expected_region_id])

func _has_landmark_id(map_director: Node, landmark_id: String) -> bool:
	if map_director.has_method("has_landmark_id"):
		return bool(map_director.call("has_landmark_id", landmark_id))
	return false

func _fail(failures: Array[String]) -> void:
	for failure in failures:
		push_error(failure)
	quit(1)
