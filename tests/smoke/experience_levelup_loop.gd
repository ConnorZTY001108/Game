extends SceneTree

const UpgradeDataScript := preload("res://data/resources/upgrade_data.gd")
const DAMAGE_FOCUS_PATH := "res://data/content/upgrades/damage_focus.tres"
const COOLDOWN_FOCUS_PATH := "res://data/content/upgrades/cooldown_focus.tres"
const PICKUP_FOCUS_PATH := "res://data/content/upgrades/pickup_focus.tres"
const SCORCH_MARK_PICK_PATH := "res://data/content/upgrades/scorch_mark_pick.tres"

class UpgradeSelectedRecorder:
	extends Node

	var count: int = 0

	func _on_upgrade_selected(_upgrade: Resource) -> void:
		count += 1

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
		"res://autoload/ExperienceSystem.gd",
		"res://autoload/UpgradeSystem.gd",
		"res://scripts/systems/DropSystem.gd",
		"res://scripts/pickups/ExperiencePickup.gd",
		"res://scripts/ui/LevelUpPanel.gd"
	]:
		if ResourceLoader.exists(script_path) == false:
			push_error("Missing Task 9 script: %s" % script_path)
			quit(1)
			return

	var run_scene_packed := load("res://scenes/run/RunScene.tscn") as PackedScene
	if run_scene_packed == null:
		push_error("Failed to load RunScene")
		quit(1)
		return

	var run_scene := run_scene_packed.instantiate()
	root.add_child(run_scene)

	var player: Variant = run_scene.get_node("World/Player")
	var pickups := run_scene.get_node("World/Pickups")
	var drop_system := run_scene.get_node("Systems/DropSystem")
	var level_panel: Variant = run_scene.get_node("CanvasLayer/LevelUpPanel")
	if player == null or pickups == null or drop_system == null or level_panel == null:
		push_error("RunScene is missing Task 9 nodes")
		quit(1)
		return
	if drop_system.get_script() == null:
		push_error("DropSystem has no script")
		quit(1)
		return

	var game_runtime := root.get_node("GameRuntime")
	var game_events := root.get_node("GameEvents")
	var experience_system := root.get_node("ExperienceSystem")
	var upgrade_system := root.get_node("UpgradeSystem")

	if int(experience_system.get("level")) != 1 or int(experience_system.get("experience")) != 0:
		push_error("ExperienceSystem did not reset at run start")
		quit(1)
		return

	var enemy := Node2D.new()
	enemy.global_position = Vector2(120.0, 24.0)
	root.add_child(enemy)
	game_events.emit_signal("enemy_died", enemy, 5)

	if pickups.get_child_count() != 1:
		push_error("DropSystem spawned %d pickups, expected 1" % pickups.get_child_count())
		quit(1)
		return

	var pickup: Variant = pickups.get_child(0)
	if pickup == null or pickup.amount != 5 or pickup.player != player:
		push_error("ExperiencePickup was not configured from enemy death")
		quit(1)
		return

	player.pickup_radius = 200.0
	var before_move: Vector2 = pickup.global_position
	pickup._process(0.1)
	if pickup.global_position.distance_to(player.global_position) >= before_move.distance_to(player.global_position):
		push_error("ExperiencePickup did not move toward player inside pickup radius")
		quit(1)
		return

	pickup._on_area_entered(player.get_node("PickupArea") as Area2D)
	await process_frame

	if int(experience_system.get("level")) != 2:
		push_error("ExperienceSystem level is %d, expected 2" % int(experience_system.get("level")))
		quit(1)
		return
	if int(game_runtime.get("state")) != 3:
		push_error("GameRuntime did not enter LEVEL_UP")
		quit(1)
		return
	if level_panel.visible == false or level_panel.current_options.size() != 3:
		push_error("LevelUpPanel did not show three options")
		quit(1)
		return

	var generated_options := _collect_generated_options(upgrade_system, 8)
	for path in [DAMAGE_FOCUS_PATH, COOLDOWN_FOCUS_PATH, PICKUP_FOCUS_PATH, SCORCH_MARK_PICK_PATH]:
		if not generated_options.has(path):
			push_error("UpgradeSystem never generated %s" % path)
			quit(1)
			return

	var rune_system := root.get_node("RuneSystem")
	var base_damage: float = player.damage_multiplier
	var base_cooldown: float = player.cooldown_multiplier
	var base_pickup_radius: float = player.pickup_radius
	upgrade_system.call("apply_upgrade", generated_options[DAMAGE_FOCUS_PATH], player)
	if player.damage_multiplier <= base_damage:
		push_error("Damage upgrade did not increase damage_multiplier")
		quit(1)
		return
	if int(game_runtime.get("state")) != 1 or paused:
		push_error("Gameplay did not resume after damage upgrade")
		quit(1)
		return

	game_runtime.call("enter_level_up")
	upgrade_system.call("apply_upgrade", generated_options[COOLDOWN_FOCUS_PATH], player)
	if player.cooldown_multiplier >= base_cooldown:
		push_error("Cooldown upgrade did not reduce cooldown_multiplier")
		quit(1)
		return

	game_runtime.call("enter_level_up")
	upgrade_system.call("apply_upgrade", generated_options[PICKUP_FOCUS_PATH], player)
	if player.pickup_radius <= base_pickup_radius:
		push_error("Pickup upgrade did not increase pickup_radius")
		quit(1)
		return

	game_runtime.call("enter_level_up")
	var base_rune_count: int = rune_system.get("equipped_runes").size()
	upgrade_system.call("apply_upgrade", generated_options[SCORCH_MARK_PICK_PATH], player)
	if rune_system.get("equipped_runes").size() != base_rune_count + 1:
		push_error("Rune upgrade did not equip Scorch Mark")
		quit(1)
		return

	var pickups_before_bad_config := pickups.get_child_count()
	drop_system.pickup_scene = null
	game_events.emit_signal("enemy_died", enemy, 1)
	if pickups.get_child_count() != pickups_before_bad_config:
		push_error("DropSystem spawned a pickup with null pickup_scene")
		quit(1)
		return

	var wrong_scene := PackedScene.new()
	var wrong_node := Node2D.new()
	wrong_node.name = "WrongPickup"
	if wrong_scene.pack(wrong_node) != OK:
		push_error("Failed to pack wrong pickup scene")
		quit(1)
		return
	wrong_node.free()
	drop_system.pickup_scene = wrong_scene
	game_events.emit_signal("enemy_died", enemy, 1)
	if pickups.get_child_count() != pickups_before_bad_config:
		push_error("DropSystem spawned a pickup from the wrong scene type")
		quit(1)
		return

	var recorder := UpgradeSelectedRecorder.new()
	root.add_child(recorder)
	game_events.connect("upgrade_selected", recorder._on_upgrade_selected)
	game_runtime.call("enter_level_up")
	var invalid_result: bool = upgrade_system.call("apply_upgrade", null, player)
	if invalid_result or recorder.count != 0 or int(game_runtime.get("state")) != 3:
		push_error("Null upgrade was treated as selected")
		quit(1)
		return

	var unknown_upgrade := UpgradeDataScript.new()
	unknown_upgrade.upgrade_type = "unknown"
	invalid_result = upgrade_system.call("apply_upgrade", unknown_upgrade, player)
	if invalid_result or recorder.count != 0 or int(game_runtime.get("state")) != 3:
		push_error("Unknown upgrade type was treated as selected")
		quit(1)
		return

	invalid_result = upgrade_system.call("apply_upgrade", generated_options[DAMAGE_FOCUS_PATH], null)
	if invalid_result or recorder.count != 0 or int(game_runtime.get("state")) != 3:
		push_error("Null player was treated as selected")
		quit(1)
		return

	game_runtime.call("resume_from_level_up")
	experience_system.call("reset")
	game_runtime.call("start_run")
	experience_system.call("add_experience", 15)
	if int(experience_system.get("level")) != 3:
		push_error("Large XP grant level is %d, expected 3" % int(experience_system.get("level")))
		quit(1)
		return
	if int(game_runtime.get("state")) != 3 or level_panel.visible == false or level_panel.current_options.size() != 3:
		push_error("First pending level-up choice was not shown")
		quit(1)
		return

	level_panel.call("_select_option", level_panel.current_options[0])
	if int(game_runtime.get("state")) != 3 or level_panel.visible == false or level_panel.current_options.size() != 3:
		push_error("Second pending level-up choice was lost after first selection")
		quit(1)
		return

	level_panel.call("_select_option", level_panel.current_options[0])
	if int(game_runtime.get("state")) != 1 or paused or level_panel.visible:
		push_error("Gameplay did not resume after all pending level-ups were selected")
		quit(1)
		return

	print("PASS: experience drop, pickup collection, level-up choices")
	quit(0)
