extends SceneTree

class DamageTarget:
	extends Node2D

	var total_damage: float = 0.0
	var received_tags: Array[String] = []

	func apply_damage(amount: float, tags: Array[String]) -> void:
		total_damage += amount
		received_tags = tags.duplicate()

class HitRecorder:
	extends Node

	var count: int = 0
	var target: Node
	var payload: Dictionary = {}

	func _on_weapon_hit(new_target: Node, new_payload: Dictionary) -> void:
		count += 1
		target = new_target
		payload = new_payload.duplicate(true)

func _initialize() -> void:
	var weapon_scene := load("res://scenes/weapons/WeaponController.tscn") as PackedScene
	var rune_bolt := load("res://data/content/weapons/rune_bolt.tres") as Resource
	var sigil_orbit := load("res://data/content/weapons/sigil_orbit.tres") as Resource
	if weapon_scene == null or rune_bolt == null or sigil_orbit == null:
		push_error("Failed to load M1 weapon variety resources")
		quit(1)
		return

	if str(rune_bolt.get("attack_mode")) != "projectile":
		push_error("rune_bolt attack_mode was %s" % rune_bolt.get("attack_mode"))
		quit(1)
		return
	if str(sigil_orbit.get("attack_mode")) == "projectile":
		push_error("sigil_orbit must use a non-projectile attack_mode")
		quit(1)
		return

	get_root().get_node("GameRuntime").set("state", 1)

	var world := Node2D.new()
	root.add_child(world)

	var player := Node2D.new()
	player.name = "Player"
	player.set("damage_multiplier", 1.0)
	player.set("cooldown_multiplier", 1.0)
	world.add_child(player)

	var enemies := Node2D.new()
	enemies.name = "Enemies"
	world.add_child(enemies)

	var projectiles := Node2D.new()
	projectiles.name = "Projectiles"
	world.add_child(projectiles)

	var close_target := DamageTarget.new()
	close_target.name = "CloseTarget"
	close_target.global_position = Vector2(72.0, 0.0)
	enemies.add_child(close_target)

	var far_target := DamageTarget.new()
	far_target.name = "FarTarget"
	far_target.global_position = Vector2(420.0, 0.0)
	enemies.add_child(far_target)

	var projectile_weapon := weapon_scene.instantiate()
	player.add_child(projectile_weapon)
	projectile_weapon.projectiles_path = ^"../../Projectiles"
	projectile_weapon.enemies_path = ^"../../Enemies"
	projectile_weapon.configure(player, rune_bolt)
	projectile_weapon._process(1.0)

	if projectiles.get_child_count() != 1:
		push_error("projectile weapon should spawn one projectile, got %d" % projectiles.get_child_count())
		quit(1)
		return
	if close_target.total_damage != 0.0:
		push_error("projectile weapon should not apply direct area damage in this smoke")
		quit(1)
		return

	var hit_recorder := HitRecorder.new()
	root.add_child(hit_recorder)
	get_root().get_node("GameEvents").connect("weapon_hit", hit_recorder._on_weapon_hit)

	var pulse_weapon := weapon_scene.instantiate()
	player.add_child(pulse_weapon)
	pulse_weapon.projectiles_path = ^"../../Projectiles"
	pulse_weapon.enemies_path = ^"../../Enemies"
	pulse_weapon.configure(player, sigil_orbit)
	pulse_weapon._process(1.0)

	if projectiles.get_child_count() != 1:
		push_error("sigil_orbit should not spawn projectiles, got %d total projectiles" % projectiles.get_child_count())
		quit(1)
		return
	if close_target.total_damage <= 0.0:
		push_error("sigil_orbit did not damage the close target")
		quit(1)
		return
	if far_target.total_damage != 0.0:
		push_error("sigil_orbit damaged a target outside its local area")
		quit(1)
		return
	if hit_recorder.count != 1 or hit_recorder.target != close_target:
		push_error("sigil_orbit did not emit exactly one weapon_hit for the close target")
		quit(1)
		return
	if hit_recorder.payload.get("weapon_id", "") != "sigil_orbit":
		push_error("sigil_orbit payload weapon_id was %s" % hit_recorder.payload.get("weapon_id", ""))
		quit(1)
		return
	if not _arrays_equal(hit_recorder.payload.get("weapon_tags", []), ["area", "orbit", "rune"]):
		push_error("sigil_orbit payload weapon_tags were %s" % [hit_recorder.payload.get("weapon_tags", [])])
		quit(1)
		return
	if not _arrays_equal(hit_recorder.payload.get("element_tags", []), []):
		push_error("sigil_orbit payload element_tags were %s" % [hit_recorder.payload.get("element_tags", [])])
		quit(1)
		return

	var no_hit_enemies := Node2D.new()
	no_hit_enemies.name = "NoHitEnemies"
	world.add_child(no_hit_enemies)

	var no_hit_target := DamageTarget.new()
	no_hit_target.name = "NoHitTarget"
	no_hit_target.global_position = Vector2(420.0, 0.0)
	no_hit_enemies.add_child(no_hit_target)

	var no_hit_pulse_weapon := weapon_scene.instantiate()
	player.add_child(no_hit_pulse_weapon)
	no_hit_pulse_weapon.projectiles_path = ^"../../Projectiles"
	no_hit_pulse_weapon.enemies_path = ^"../../NoHitEnemies"
	no_hit_pulse_weapon.configure(player, sigil_orbit)
	var hit_count_before_no_hit := hit_recorder.count
	no_hit_pulse_weapon._process(1.0)

	if no_hit_target.total_damage != 0.0:
		push_error("no-hit pulse setup unexpectedly damaged the out-of-range target")
		quit(1)
		return
	if no_hit_pulse_weapon.cooldown <= 0.0:
		push_error("no-hit pulse attempt did not enter cooldown")
		quit(1)
		return

	no_hit_target.global_position = Vector2(72.0, 0.0)
	no_hit_pulse_weapon._process(0.0)

	if no_hit_target.total_damage != 0.0:
		push_error("no-hit pulse cooldown allowed an immediate repeat hit")
		quit(1)
		return
	if hit_recorder.count != hit_count_before_no_hit:
		push_error("no-hit pulse cooldown allowed an immediate repeat weapon_hit")
		quit(1)
		return

	print("PASS: M1 weapon variety projectile and orbit pulse loop")
	quit(0)

func _arrays_equal(left, right: Array) -> bool:
	if not left is Array:
		return false
	if left.size() != right.size():
		return false
	for index in right.size():
		if str(left[index]) != str(right[index]):
			return false
	return true
