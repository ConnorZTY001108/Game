extends SceneTree

const RUN_SCENE_PATH := "res://scenes/run/RunScene.tscn"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var registry := root.get_node_or_null("AugmentRegistry")
	var augment_system := root.get_node_or_null("AugmentSystem")
	var game_events := root.get_node_or_null("GameEvents")
	var damage_system := root.get_node_or_null("DamageSystem")
	if registry == null or augment_system == null or game_events == null or damage_system == null:
		_finish(["required autoload missing for augment HUD contract"])
		return
	registry.call("reload")
	augment_system.call("reset")

	var run_scene_packed := load(RUN_SCENE_PATH) as PackedScene
	if run_scene_packed == null:
		_finish(["failed to load RunScene"])
		return
	var run_scene := run_scene_packed.instantiate()
	root.add_child(run_scene)
	await process_frame

	var hud: Variant = run_scene.get_node_or_null("CanvasLayer/HUD")
	var player: Variant = run_scene.get_node_or_null("World/Player")
	if hud == null or player == null:
		_finish(["RunScene missing HUD or Player"])
		return
	if not player.has_method("get_stat_snapshot"):
		failures.append("Player missing get_stat_snapshot()")
	else:
		var stats: Dictionary = player.call("get_stat_snapshot")
		for key in ["damage_multiplier", "cooldown_multiplier", "pickup_radius", "health", "max_health", "move_speed"]:
			if not stats.has(key):
				failures.append("Player stat snapshot missing %s: %s" % [key, stats])

	if not augment_system.has_method("get_hud_snapshot"):
		failures.append("AugmentSystem missing get_hud_snapshot()")
	else:
		var empty_snapshot: Dictionary = augment_system.call("get_hud_snapshot", player)
		for key in ["owned_augments", "route_counts", "proc_counts", "quest_progress", "forge_progress", "stat_snapshot", "last_triggers"]:
			if not empty_snapshot.has(key):
				failures.append("HUD snapshot missing %s: %s" % [key, empty_snapshot])

	var status_panel: Node = hud.get_node_or_null("AugmentStatusPanel")
	if status_panel == null:
		failures.append("HUD missing AugmentStatusPanel")
	else:
		for child_name in ["RouteSummaryLabel", "StatDeltaLabel", "OwnedAugmentsLabel", "ProcCountersLabel", "ProgressLabel"]:
			if status_panel.get_node_or_null(child_name) == null:
				failures.append("AugmentStatusPanel missing %s" % child_name)

	var forge := registry.call("get_by_id", "aug_stats_forge") as Resource
	var dual := registry.call("get_by_id", "aug_rune_dual_wield") as Resource
	if forge == null or dual == null:
		failures.append("missing HUD augment fixtures")
	else:
		game_events.emit_signal("run_started")
		await process_frame
		augment_system.call("acquire_augment", forge, player)
		await process_frame
		augment_system.call("acquire_augment", dual, player)
		var tags: Array[String] = ["projectile", "weapon"]
		var weapon_tags: Array[String] = ["projectile"]
		var packet: Dictionary = damage_system.call("make_packet", 10.0, tags, {
			"owner": player,
			"weapon_id": "rune_bolt",
			"weapon_tags": weapon_tags,
			"cooldown_source_id": "hud_contract",
			"hit_position": Vector2(4.0, 5.0)
		})
		augment_system.call("emit_synthetic_event", "on_attack_fire", packet, {"signal_name": "weapon_fired", "owner": player})
		await process_frame
		game_events.emit_signal("upgrade_selected", forge)
		await process_frame

		if augment_system.has_method("get_hud_snapshot"):
			var snapshot: Dictionary = augment_system.call("get_hud_snapshot", player)
			if int((snapshot.get("route_counts", {}) as Dictionary).get("quest_forge", 0)) < 1:
				failures.append("HUD snapshot did not include quest_forge route count: %s" % snapshot)
			if int((snapshot.get("proc_counts", {}) as Dictionary).get("aug_rune_dual_wield", 0)) < 1:
				failures.append("HUD snapshot did not include aug_rune_dual_wield proc count: %s" % snapshot)
			if (snapshot.get("owned_augments", []) as Array).is_empty():
				failures.append("HUD snapshot did not include owned augments: %s" % snapshot)

		if status_panel != null:
			var panel_text := _combined_panel_text(status_panel)
			for required in ["aug_stats_forge", "aug_rune_dual_wield", "quest_forge"]:
				if not panel_text.contains(required):
					failures.append("AugmentStatusPanel text missing %s: %s" % [required, panel_text])

	run_scene.free()
	_finish(failures)

func _combined_panel_text(panel: Node) -> String:
	var parts: Array[String] = []
	for child in panel.get_children():
		var label := child as Label
		if label != null:
			parts.append(label.text)
	return "\n".join(parts)

func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("PASS: augment HUD state snapshot and panel contract")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
