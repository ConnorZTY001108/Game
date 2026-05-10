extends SceneTree

const SCORCH_MARK_PICK_PATH := "res://data/content/upgrades/scorch_mark_pick.tres"

class DamageTarget:
	extends Node2D

	var total_damage: float = 0.0
	var received_tags: Array[String] = []

	func apply_damage(amount: float, tags: Array[String]) -> void:
		total_damage += amount
		received_tags = tags.duplicate()

class RuneTriggeredRecorder:
	extends Node

	var count: int = 0
	var rune_id: String = ""
	var target: Node
	var payload: Dictionary = {}

	func _on_rune_triggered(new_rune_id: String, new_target: Node, new_payload: Dictionary) -> void:
		count += 1
		rune_id = new_rune_id
		target = new_target
		payload = new_payload.duplicate(true)

func _initialize() -> void:
	call_deferred("_run")

func _collect_generated_options(upgrade_system: Node, attempts: int) -> Dictionary:
	var generated := {}
	for _index in range(attempts):
		var options: Array = upgrade_system.call("generate_options")
		if options.size() != 3:
			push_error("UpgradeSystem generated %d options, expected 3" % options.size())
			return {}
		for option in options:
			var resource := option as Resource
			if resource == null:
				continue
			generated[resource.resource_path] = resource
	return generated

func _run() -> void:
	for script_path in [
		"res://autoload/ElementStatusSystem.gd",
		"res://autoload/RuneSystem.gd",
		"res://scripts/components/StatusReceiver.gd"
	]:
		if ResourceLoader.exists(script_path) == false:
			push_error("Missing Task 10 script: %s" % script_path)
			quit(1)
			return

	var rune_system := root.get_node_or_null("RuneSystem")
	var element_status_system := root.get_node_or_null("ElementStatusSystem")
	var upgrade_system := root.get_node_or_null("UpgradeSystem")
	var game_events := root.get_node_or_null("GameEvents")
	if rune_system == null or element_status_system == null or upgrade_system == null or game_events == null:
		push_error("Task 10 autoloads are not registered")
		quit(1)
		return

	rune_system.call("reset")
	element_status_system.set("stacks_by_target", {})

	var generated_options := _collect_generated_options(upgrade_system, 8)
	if not generated_options.has(SCORCH_MARK_PICK_PATH):
		push_error("UpgradeSystem never generated scorch_mark_pick.tres")
		quit(1)
		return

	var player_scene := load("res://scenes/player/Player.tscn") as PackedScene
	if player_scene == null:
		push_error("Failed to load Player scene")
		quit(1)
		return
	var player := player_scene.instantiate()
	root.add_child(player)

	var upgrade_data_script := load("res://data/resources/upgrade_data.gd")
	var invalid_rune_upgrade = upgrade_data_script.new()
	invalid_rune_upgrade.upgrade_type = "rune"
	invalid_rune_upgrade.rune = Resource.new()
	var invalid_result: bool = upgrade_system.call("apply_upgrade", invalid_rune_upgrade, player)
	if invalid_result or rune_system.get("equipped_runes").size() != 0:
		push_error("Invalid rune resource was treated as selected")
		quit(1)
		return

	var apply_result: bool = upgrade_system.call("apply_upgrade", generated_options[SCORCH_MARK_PICK_PATH], player)
	if apply_result == false:
		push_error("Rune upgrade was not applied successfully")
		quit(1)
		return
	if rune_system.get("equipped_runes").size() != 1:
		push_error("RuneSystem equipped %d runes, expected 1" % rune_system.get("equipped_runes").size())
		quit(1)
		return

	var enemy_scene := load("res://scenes/enemies/Enemy.tscn") as PackedScene
	var enemy := enemy_scene.instantiate() if enemy_scene != null else null
	if enemy == null:
		push_error("Failed to load Enemy scene")
		quit(1)
		return
	var status_receiver := enemy.get_node_or_null("StatusReceiver")
	if status_receiver == null or status_receiver.get_script() == null:
		push_error("Enemy StatusReceiver is missing StatusReceiver.gd")
		quit(1)
		return
	if status_receiver.call("get_status_owner") != enemy:
		push_error("StatusReceiver did not return its parent owner")
		quit(1)
		return

	var target := DamageTarget.new()
	root.add_child(target)

	var recorder := RuneTriggeredRecorder.new()
	root.add_child(recorder)
	game_events.connect("rune_triggered", recorder._on_rune_triggered)

	var payload := {
		"weapon_id": "rune_bolt",
		"weapon_tags": ["projectile", "rune"],
		"element_tags": []
	}
	for _index in range(3):
		game_events.emit_signal("weapon_hit", target, payload)
		rune_system.call("_process", 0.25)

	if not is_equal_approx(target.total_damage, 12.0):
		push_error("Rune bonus damage was %.2f, expected 12.00" % target.total_damage)
		quit(1)
		return
	if target.received_tags != ["scorch", "rune_bonus"]:
		push_error("Rune bonus damage tags were %s" % [target.received_tags])
		quit(1)
		return
	if recorder.count != 1 or recorder.rune_id != "scorch_mark" or recorder.target != target:
		push_error("Rune triggered event was not emitted with the expected target and rune id")
		quit(1)
		return
	if recorder.payload.get("element", "") != "scorch" or int(recorder.payload.get("stacks", 0)) != 3:
		push_error("Rune triggered payload was %s" % [recorder.payload])
		quit(1)
		return
	if recorder.payload.get("route_id", "") != "scorch_projectile" or recorder.payload.get("source_weapon_id", "") != "rune_bolt":
		push_error("Scorch route payload was not readable: %s" % [recorder.payload])
		quit(1)
		return
	var stacks_by_target: Dictionary = element_status_system.get("stacks_by_target")
	if stacks_by_target.has(target) and (stacks_by_target[target] as Dictionary).has("scorch"):
		push_error("ElementStatusSystem did not clear scorch stacks after trigger")
		quit(1)
		return

	rune_system.call("reset")
	if rune_system.get("equipped_runes").size() != 0 or (rune_system.get("cooldowns") as Dictionary).size() != 0:
		push_error("RuneSystem reset did not clear runes and cooldowns")
		quit(1)
		return

	player.free()
	enemy.free()
	target.free()
	recorder.free()
	print("PASS: rune upgrade and element trigger loop")
	quit(0)
