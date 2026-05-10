extends SceneTree

const RUN_SCENE_PATH := "res://scenes/run/RunScene.tscn"
const M1_WAVE_PATH := "res://data/content/waves/m1_wave.tres"
const DUST_THRALL_PATH := "res://data/content/enemies/dust_thrall.tres"
const ASH_RUNNER_PATH := "res://data/content/enemies/ash_runner.tres"
const BONE_BRUTE_PATH := "res://data/content/enemies/bone_brute.tres"
const SPAWN_SYSTEM_SCRIPT := "res://scripts/systems/SpawnSystem.gd"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var enemies := _load_enemy_resources(failures)
	var wave := _load_m1_wave(failures)
	if wave != null:
		_validate_wave_phases(wave, failures)
	_validate_run_scene_spawn_contract(wave, failures)
	_validate_null_wave_safety(failures)

	if failures.is_empty():
		print("PASS: M1 wave phase selection, off-screen spawning, and max_alive contract")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _load_enemy_resources(failures: Array[String]) -> Dictionary:
	var resources := {
		"dust_thrall": load(DUST_THRALL_PATH),
		"ash_runner": load(ASH_RUNNER_PATH),
		"bone_brute": load(BONE_BRUTE_PATH)
	}
	for expected_id in resources.keys():
		var data = resources[expected_id]
		if data == null:
			failures.append("Failed to load enemy resource: %s" % expected_id)
			continue
		if data.get("id") != expected_id:
			failures.append("Enemy id for %s was %s" % [expected_id, data.get("id")])

	var dust = resources.get("dust_thrall")
	var runner = resources.get("ash_runner")
	var brute = resources.get("bone_brute")
	if dust != null and runner != null:
		if float(runner.get("max_health")) >= float(dust.get("max_health")):
			failures.append("ash_runner must have lower health than dust_thrall")
		if float(runner.get("move_speed")) <= float(dust.get("move_speed")):
			failures.append("ash_runner must move faster than dust_thrall")
	if dust != null and brute != null:
		if float(brute.get("max_health")) <= float(dust.get("max_health")):
			failures.append("bone_brute must have higher health than dust_thrall")
		if float(brute.get("move_speed")) >= float(dust.get("move_speed")):
			failures.append("bone_brute must move slower than dust_thrall")
		if int(brute.get("experience_value")) <= int(dust.get("experience_value")):
			failures.append("bone_brute must award more XP than dust_thrall")
	return resources

func _load_m1_wave(failures: Array[String]) -> Resource:
	var wave := load(M1_WAVE_PATH) as Resource
	if wave == null:
		failures.append("Failed to load M1 wave resource")
		return null
	if float(wave.get("duration_seconds")) < 300.0 or float(wave.get("duration_seconds")) > 480.0:
		failures.append("M1 wave duration must be 300-480 seconds")
	if not wave.has_method("get_phase_at_time"):
		failures.append("WaveData must expose get_phase_at_time")
	return wave

func _validate_wave_phases(wave: Resource, failures: Array[String]) -> void:
	if not wave.has_method("get_phase_at_time"):
		return
	var early := wave.call("get_phase_at_time", 5.0) as Dictionary
	var mid := wave.call("get_phase_at_time", 150.0) as Dictionary
	var late := wave.call("get_phase_at_time", 300.0) as Dictionary
	_validate_phase("early", early, ["dust_thrall"], failures)
	_validate_phase("mid", mid, ["dust_thrall", "ash_runner"], failures)
	_validate_phase("late", late, ["dust_thrall", "ash_runner", "bone_brute"], failures)
	if float(early.get("spawn_interval", 0.0)) <= float(late.get("spawn_interval", 0.0)):
		failures.append("late phase should spawn faster than early phase")
	if int(early.get("max_alive", 0)) >= int(late.get("max_alive", 0)):
		failures.append("late phase should allow more alive enemies than early phase")

func _validate_phase(label: String, phase: Dictionary, expected_ids: Array[String], failures: Array[String]) -> void:
	for key in ["start_time", "duration", "spawn_interval", "max_alive", "spawn_radius", "enemy_pool"]:
		if phase.has(key) == false:
			failures.append("%s phase missing %s" % [label, key])
	var pool = phase.get("enemy_pool", [])
	if not pool is Array:
		failures.append("%s enemy_pool must be an Array" % label)
		return
	var ids: Array[String] = []
	for item in pool:
		if item != null:
			ids.append(str(item.get("id")))
	for expected_id in expected_ids:
		if ids.has(expected_id) == false:
			failures.append("%s enemy_pool missing %s, got %s" % [label, expected_id, ids])

func _validate_run_scene_spawn_contract(wave: Resource, failures: Array[String]) -> void:
	var packed := load(RUN_SCENE_PATH) as PackedScene
	if packed == null:
		failures.append("Failed to load RunScene")
		return
	var run_scene := packed.instantiate()
	root.add_child(run_scene)
	await process_frame

	var run_timer := run_scene.get_node_or_null("Systems/RunTimerSystem")
	if run_timer == null:
		failures.append("RunScene missing RunTimerSystem")
	elif float(run_timer.get("run_duration_seconds")) < 300.0 or float(run_timer.get("run_duration_seconds")) > 480.0:
		failures.append("RunTimerSystem duration must be 300-480 seconds")

	var spawn_system := run_scene.get_node_or_null("Systems/SpawnSystem")
	var player := run_scene.get_node_or_null("World/Player") as Node2D
	var enemy_root := run_scene.get_node_or_null("World/Enemies")
	if spawn_system == null or player == null or enemy_root == null:
		failures.append("RunScene missing SpawnSystem, Player, or Enemies")
		run_scene.queue_free()
		return
	if spawn_system.get("wave_data") == null or spawn_system.get("wave_data").get("id") != "m1_wave":
		failures.append("RunScene SpawnSystem must use m1_wave.tres")
	if not spawn_system.has_method("get_camera_view_rect"):
		failures.append("SpawnSystem must expose get_camera_view_rect")
	if not spawn_system.has_method("get_spawn_position"):
		failures.append("SpawnSystem must expose get_spawn_position")
	if not spawn_system.has_method("get_active_phase"):
		failures.append("SpawnSystem must expose get_active_phase")
	if not spawn_system.has_method("select_enemy_data"):
		failures.append("SpawnSystem must expose select_enemy_data")
	if failures.size() > 0:
		run_scene.queue_free()
		return

	var late := wave.call("get_phase_at_time", 300.0) as Dictionary
	var camera_rect := spawn_system.call("get_camera_view_rect", player) as Rect2
	for index in 16:
		var spawn_position := spawn_system.call("get_spawn_position", player, late) as Vector2
		if camera_rect.has_point(spawn_position):
			failures.append("Spawn position %s was inside camera rect %s" % [spawn_position, camera_rect])
			break

	for index in int(late.get("max_alive", 0)):
		enemy_root.add_child(Node2D.new())
	var before_count := enemy_root.get_child_count()
	root.get_node("GameRuntime").set("elapsed_seconds", 300.0)
	root.get_node("GameRuntime").set("state", 1)
	spawn_system.set("spawn_timer", 0.0)
	spawn_system.call("_process", 1.0)
	if enemy_root.get_child_count() != before_count:
		failures.append("SpawnSystem ignored phase max_alive")

	var selected = spawn_system.call("select_enemy_data", late)
	if selected == null or str(selected.get("id")) == "":
		failures.append("SpawnSystem failed to select enemy data from phase pool")

	run_scene.queue_free()

func _validate_null_wave_safety(failures: Array[String]) -> void:
	var spawn_script := load(SPAWN_SYSTEM_SCRIPT) as Script
	if spawn_script == null:
		failures.append("Failed to load SpawnSystem script")
		return

	var world := Node2D.new()
	root.add_child(world)
	var player := Node2D.new()
	player.name = "Player"
	world.add_child(player)
	var enemy_root := Node2D.new()
	enemy_root.name = "Enemies"
	world.add_child(enemy_root)
	var spawn_system = spawn_script.new()
	spawn_system.name = "SpawnSystem"
	world.add_child(spawn_system)
	spawn_system.set("wave_data", null)
	spawn_system.set("enemies_path", ^"../Enemies")
	spawn_system.set("player_path", ^"../Player")
	spawn_system.set("spawn_timer", 0.0)

	root.get_node("GameRuntime").set("state", 1)
	var phase := spawn_system.call("get_active_phase") as Dictionary
	if phase.is_empty() == false:
		failures.append("Null wave get_active_phase should return an empty phase")
	var selected = spawn_system.call("select_enemy_data", phase)
	if selected != null:
		failures.append("Null wave select_enemy_data should return null")
	var spawn_position := spawn_system.call("get_spawn_position", player, phase) as Vector2
	if not is_finite(spawn_position.x) or not is_finite(spawn_position.y):
		failures.append("Null wave get_spawn_position should return finite fallback coordinates")
	spawn_system.call("_process", 1.0)
	if enemy_root.get_child_count() != 0:
		failures.append("Null wave SpawnSystem should not spawn enemies")

	world.queue_free()
