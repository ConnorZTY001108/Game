extends SceneTree

const SCORCH_MARK_PICK_PATH := "res://data/content/upgrades/scorch_mark_pick.tres"
const STORM_ORBIT_PICK_PATH := "res://data/content/upgrades/storm_orbit_pick.tres"
const WEAPON_SIGIL_ORBIT_PICK_PATH := "res://data/content/upgrades/weapon_sigil_orbit_pick.tres"

class DamageTarget:
	extends Node2D

	var total_damage: float = 0.0
	var received_tags: Array[String] = []

	func apply_damage(amount: float, tags: Array[String]) -> void:
		total_damage += amount
		received_tags = tags.duplicate()

class RuneTriggeredRecorder:
	extends Node

	var events: Array[Dictionary] = []

	func _on_rune_triggered(rune_id: String, target: Node, payload: Dictionary) -> void:
		events.append({
			"rune_id": rune_id,
			"target": target,
			"payload": payload.duplicate(true)
		})

func _initialize() -> void:
	call_deferred("_run")

func _collect_generated_options(upgrade_system: Node, attempts: int) -> Dictionary:
	var generated := {}
	for _index in range(attempts):
		var options: Array = upgrade_system.call("generate_options")
		if options.size() != 3:
			push_error("UpgradeSystem generated %d options, expected 3" % options.size())
			return {}
		var routes := {}
		var unique_ids := {}
		for option in options:
			var resource := option as Resource
			if resource == null:
				continue
			var route_id := str(resource.get("route_id"))
			if route_id != "":
				routes[route_id] = true
			if bool(resource.get("unique")):
				var upgrade_id := str(resource.get("id"))
				if unique_ids.has(upgrade_id):
					push_error("UpgradeSystem generated duplicate unique upgrade on one screen: %s" % upgrade_id)
					return {}
				unique_ids[upgrade_id] = true
			generated[resource.resource_path] = resource
		if routes.size() < 2:
			push_error("UpgradeSystem generated a single-route option screen: %s" % [options.map(func(item): return item.get("id"))])
			return {}
	return generated

func _run() -> void:
	for resource_path in [
		SCORCH_MARK_PICK_PATH,
		STORM_ORBIT_PICK_PATH,
		WEAPON_SIGIL_ORBIT_PICK_PATH,
		"res://data/content/weapons/sigil_orbit.tres"
	]:
		if ResourceLoader.exists(resource_path) == false:
			push_error("Missing M1 route resource: %s" % resource_path)
			quit(1)
			return

	var upgrade_system := root.get_node_or_null("UpgradeSystem")
	var rune_system := root.get_node_or_null("RuneSystem")
	var game_events := root.get_node_or_null("GameEvents")
	var game_runtime := root.get_node_or_null("GameRuntime")
	if upgrade_system == null or rune_system == null or game_events == null or game_runtime == null:
		push_error("Required autoloads are not registered")
		quit(1)
		return

	if upgrade_system.has_method("reset"):
		upgrade_system.call("reset")
	rune_system.call("reset")

	var generated_options := _collect_generated_options(upgrade_system, 10)
	for path in [SCORCH_MARK_PICK_PATH, STORM_ORBIT_PICK_PATH, WEAPON_SIGIL_ORBIT_PICK_PATH]:
		if not generated_options.has(path):
			push_error("UpgradeSystem never generated %s" % path)
			quit(1)
			return

	var scorch_upgrade := generated_options[SCORCH_MARK_PICK_PATH] as Resource
	var storm_upgrade := generated_options[STORM_ORBIT_PICK_PATH] as Resource
	var weapon_upgrade := generated_options[WEAPON_SIGIL_ORBIT_PICK_PATH] as Resource
	if str(scorch_upgrade.get("route_id")) != "scorch_projectile" or str(storm_upgrade.get("route_id")) != "storm_orbit":
		push_error("Rune route ids were not readable/distinct")
		quit(1)
		return
	if str(storm_upgrade.get("summary")) == "" or str(storm_upgrade.get("details")) == "":
		push_error("Storm route upgrade is missing readable summary/details")
		quit(1)
		return
	if weapon_upgrade.get("weapon") == null:
		push_error("weapon_sigil_orbit_pick.tres must reference its WeaponData resource")
		quit(1)
		return

	var player_scene := load("res://scenes/player/Player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	await process_frame

	var weapon_mount := player.get_node_or_null("WeaponMount")
	if weapon_mount == null:
		push_error("Player is missing WeaponMount")
		quit(1)
		return
	var base_weapon_count := weapon_mount.get_child_count()
	var weapon_pick_result: bool = upgrade_system.call("apply_upgrade", weapon_upgrade, player)
	if weapon_pick_result == false or weapon_mount.get_child_count() != base_weapon_count + 1:
		push_error("weapon_pick did not add sigil_orbit as the second weapon")
		quit(1)
		return
	var duplicate_weapon_result: bool = upgrade_system.call("apply_upgrade", weapon_upgrade, player)
	if duplicate_weapon_result or weapon_mount.get_child_count() != base_weapon_count + 1:
		push_error("unique weapon_pick was applied more than once")
		quit(1)
		return
	var post_pick_options: Array = upgrade_system.call("generate_options")
	for option in post_pick_options:
		if option.resource_path == WEAPON_SIGIL_ORBIT_PICK_PATH:
			push_error("unique weapon_pick reappeared after being applied")
			quit(1)
			return

	if upgrade_system.has_method("reset"):
		upgrade_system.call("reset")
	var scorch_result: bool = upgrade_system.call("apply_upgrade", scorch_upgrade, player)
	var storm_result: bool = upgrade_system.call("apply_upgrade", storm_upgrade, player)
	if scorch_result == false or storm_result == false:
		push_error("Both rune route upgrades must apply successfully")
		quit(1)
		return
	if rune_system.get("equipped_runes").size() != 2:
		push_error("RuneSystem equipped %d runes, expected 2" % rune_system.get("equipped_runes").size())
		quit(1)
		return

	var recorder := RuneTriggeredRecorder.new()
	root.add_child(recorder)
	game_events.connect("rune_triggered", recorder._on_rune_triggered)

	var scorch_target := DamageTarget.new()
	root.add_child(scorch_target)
	var scorch_payload := {
		"weapon_id": "rune_bolt",
		"weapon_tags": ["projectile", "rune"],
		"element_tags": []
	}
	for _index in range(3):
		game_events.emit_signal("weapon_hit", scorch_target, scorch_payload)
		rune_system.call("_process", 0.25)

	var storm_target := DamageTarget.new()
	root.add_child(storm_target)
	var storm_payload := {
		"weapon_id": "sigil_orbit",
		"weapon_tags": ["area", "orbit", "rune"],
		"element_tags": []
	}
	for _index in range(2):
		game_events.emit_signal("weapon_hit", storm_target, storm_payload)
		rune_system.call("_process", 0.25)

	if recorder.events.size() != 2:
		push_error("Expected two distinct rune trigger events, got %d" % recorder.events.size())
		quit(1)
		return
	var scorch_event := _find_event(recorder.events, "scorch_mark")
	var storm_event := _find_event(recorder.events, "storm_orbit")
	if scorch_event.is_empty() or storm_event.is_empty():
		push_error("Missing scorch_mark or storm_orbit trigger event: %s" % [recorder.events])
		quit(1)
		return
	if scorch_event["payload"].get("route_id", "") != "scorch_projectile" or scorch_event["payload"].get("element", "") != "scorch":
		push_error("Scorch payload was not route-readable: %s" % [scorch_event["payload"]])
		quit(1)
		return
	if storm_event["payload"].get("route_id", "") != "storm_orbit" or storm_event["payload"].get("element", "") != "storm":
		push_error("Storm payload was not route-readable: %s" % [storm_event["payload"]])
		quit(1)
		return
	if storm_event["payload"].get("source_weapon_id", "") != "sigil_orbit":
		push_error("Storm payload did not preserve source weapon identity: %s" % [storm_event["payload"]])
		quit(1)
		return
	if not scorch_target.received_tags.has("scorch") or not storm_target.received_tags.has("storm"):
		push_error("Rune damage tags did not distinguish route effects")
		quit(1)
		return

	print("PASS: M1 rune routes, readable options, and orbit weapon pick")
	quit(0)

func _find_event(events: Array[Dictionary], rune_id: String) -> Dictionary:
	for event in events:
		if event.get("rune_id", "") == rune_id:
			return event
	return {}
