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

	var player := run_scene.get_node_or_null("World/Player") as Node2D
	var map_director := run_scene.get_node_or_null("World/Map/MapDirector")
	var pickups := run_scene.get_node_or_null("World/Pickups")
	var enemies := run_scene.get_node_or_null("World/Enemies")
	var hud := run_scene.get_node_or_null("CanvasLayer/HUD")
	var settlement := run_scene.get_node_or_null("CanvasLayer/SettlementPanel")
	if player == null or map_director == null or pickups == null or enemies == null or hud == null or settlement == null:
		_fail(["RunScene is missing required M1.6 nodes"])
		return

	var obelisks := _collect_nodes_by_property(map_director, "obelisk_id")
	if obelisks.size() != 3:
		failures.append("Expected 3 rune obelisks, got %d" % obelisks.size())
	for required_id in ["obelisk_altar", "obelisk_ash", "obelisk_stone"]:
		if _find_node_by_property(map_director, "obelisk_id", required_id) == null:
			failures.append("Missing rune obelisk %s" % required_id)

	for obelisk in obelisks:
		if obelisk.has_method("try_activate") == false:
			failures.append("%s is missing try_activate(player)" % obelisk.name)
			continue
		player.global_position = (obelisk as Node2D).global_position
		obelisk.call("try_activate", player)
	if not obelisks.is_empty():
		player.global_position = (obelisks[0] as Node2D).global_position
		obelisks[0].call("try_activate", player)

	var game_events := root.get_node_or_null("GameEvents")
	if game_events == null or game_events.has_method("get_map_objective_summary") == false:
		failures.append("GameEvents is missing get_map_objective_summary()")
	else:
		var summary: Dictionary = game_events.call("get_map_objective_summary")
		if int(summary.get("activated_obelisks", -1)) != 3:
			failures.append("Activated obelisk summary was %s, expected 3" % str(summary.get("activated_obelisks")))
		if int(summary.get("total_obelisks", -1)) != 3:
			failures.append("Total obelisk summary was %s, expected 3" % str(summary.get("total_obelisks")))
		if bool(summary.get("all_obelisks_activated", false)) == false:
			failures.append("Map summary did not mark all obelisks activated")

	var objective_label := hud.get_node_or_null("ObjectiveLabel") as Label
	if objective_label == null:
		failures.append("HUD is missing ObjectiveLabel")
	elif objective_label.text.contains("全部激活") == false and objective_label.text.contains("3/3") == false:
		failures.append("HUD objective text did not reach completion: %s" % objective_label.text)

	var cache := _find_node_by_property(map_director, "cache_id", "xp_cache_north")
	if cache == null:
		failures.append("Missing xp_cache_north")
	elif cache.has_method("try_trigger") == false:
		failures.append("xp_cache_north is missing try_trigger(player)")
	else:
		var before_pickups := pickups.get_child_count()
		player.global_position = (cache as Node2D).global_position
		cache.call("try_trigger", player)
		if pickups.get_child_count() <= before_pickups:
			failures.append("XP cache did not add pickup children")
		var after_pickups := pickups.get_child_count()
		cache.call("try_trigger", player)
		if pickups.get_child_count() != after_pickups:
			failures.append("XP cache triggered more than once")

	var rift := _find_node_by_property(map_director, "rift_id", "rift_ash_01")
	if rift == null:
		failures.append("Missing rift_ash_01")
	elif rift.has_method("force_active_for_test") == false:
		failures.append("rift_ash_01 is missing force_active_for_test(player)")
	else:
		var health_component := player.get_node_or_null("HealthComponent")
		var before_health := float(health_component.get("current_health")) if health_component != null else -1.0
		player.global_position = (rift as Node2D).global_position
		rift.call("force_active_for_test", player)
		var after_health := float(health_component.get("current_health")) if health_component != null else before_health
		if not after_health < before_health:
			failures.append("Hazard rift did not damage player once when forced active")
		if rift.has_method("_damage_player_once"):
			rift.call("_damage_player_once", player)
			var after_second_hit := float(health_component.get("current_health")) if health_component != null else after_health
			if after_second_hit != after_health:
				failures.append("Hazard rift damaged player twice in one active window")

	var ambush := _find_node_by_property(map_director, "trigger_id", "ruin_gate_ambush")
	if ambush == null:
		failures.append("Missing ruin_gate_ambush")
	elif ambush.has_method("try_trigger") == false:
		failures.append("ruin_gate_ambush is missing try_trigger(player)")
	else:
		var before_enemies := enemies.get_child_count()
		player.global_position = (ambush as Node2D).global_position
		ambush.call("try_trigger", player)
		var spawned_count := enemies.get_child_count() - before_enemies
		if spawned_count != 7:
			failures.append("Ambush spawned %d enemies, expected 7" % spawned_count)
		ambush.call("try_trigger", player)
		if enemies.get_child_count() - before_enemies != 7:
			failures.append("Ambush triggered more than once")
		for index in range(before_enemies, enemies.get_child_count()):
			var enemy := enemies.get_child(index) as Node2D
			if enemy != null and enemy.global_position.distance_to(player.global_position) < 160.0:
				failures.append("Ambush enemy spawned too close to player: %.1f px" % enemy.global_position.distance_to(player.global_position))

	if game_events != null and game_events.has_method("get_map_objective_summary"):
		var final_map_summary: Dictionary = game_events.call("get_map_objective_summary")
		if int(final_map_summary.get("triggered_map_events", -1)) != 2:
			failures.append("Triggered map event count was %s, expected 2" % str(final_map_summary.get("triggered_map_events")))

	var game_runtime := root.get_node_or_null("GameRuntime")
	if game_runtime != null:
		game_runtime.call("finish_run", "victory")
	if settlement.has_method("get_summary_text") == false:
		failures.append("SettlementPanel is missing get_summary_text()")
	else:
		var settlement_text := str(settlement.call("get_summary_text"))
		if settlement_text.contains("符文碑：3/3") == false:
			failures.append("Settlement text missing map objective summary: %s" % settlement_text)

	if failures.is_empty():
		print("PASS: M1.6 map objectives loop")
		quit(0)
	else:
		_fail(failures)

func _collect_nodes_by_property(root_node: Node, property_name: String) -> Array[Node]:
	var result: Array[Node] = []
	_collect_nodes_by_property_recursive(root_node, property_name, result)
	return result

func _collect_nodes_by_property_recursive(node: Node, property_name: String, result: Array[Node]) -> void:
	var value: Variant = node.get(property_name)
	if typeof(value) != TYPE_NIL and str(value) != "":
		result.append(node)
	for child in node.get_children():
		_collect_nodes_by_property_recursive(child, property_name, result)

func _find_node_by_property(root_node: Node, property_name: String, expected_value: String) -> Node:
	var nodes := _collect_nodes_by_property(root_node, property_name)
	for node in nodes:
		if str(node.get(property_name)) == expected_value:
			return node
	return null

func _fail(failures: Array[String]) -> void:
	for failure in failures:
		push_error(failure)
	quit(1)
