extends SceneTree

class DamageTarget:
	extends Node2D

	var total_damage: float = 0.0
	var received_tags: Array[String] = []

	func apply_damage(amount: float, tags: Array[String]) -> void:
		total_damage += amount
		received_tags = tags.duplicate()

class DeathRecorder:
	extends Node

	var count: int = 0

	func _on_enemy_died(_enemy: Node, _experience_value: int) -> void:
		count += 1

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
	var weapon_data := load("res://data/content/weapons/rune_bolt.tres") as Resource
	var enemy_scene := load("res://scenes/enemies/Enemy.tscn") as PackedScene
	if weapon_scene == null or weapon_data == null or enemy_scene == null:
		push_error("Failed to load weapon smoke resources")
		quit(1)
		return

	get_root().get_node("GameRuntime").set("state", 1)

	var world := Node2D.new()
	root.add_child(world)

	var player := Node2D.new()
	player.name = "Player"
	world.add_child(player)

	var enemies := Node2D.new()
	enemies.name = "Enemies"
	world.add_child(enemies)

	var projectiles := Node2D.new()
	projectiles.name = "Projectiles"
	world.add_child(projectiles)

	var target := DamageTarget.new()
	target.name = "DamageTarget"
	target.global_position = Vector2(120.0, 0.0)
	var hitbox := Area2D.new()
	hitbox.name = "HitboxComponent"
	target.add_child(hitbox)
	enemies.add_child(target)

	var weapon := weapon_scene.instantiate()
	player.add_child(weapon)
	weapon.projectiles_path = ^"../../Projectiles"
	weapon.enemies_path = ^"../../Enemies"
	weapon.configure(player, weapon_data)
	weapon._process(1.0)

	var hit_recorder := HitRecorder.new()
	root.add_child(hit_recorder)
	get_root().get_node("GameEvents").connect("weapon_hit", hit_recorder._on_weapon_hit)

	if projectiles.get_child_count() != 1:
		push_error("WeaponController did not spawn a projectile")
		quit(1)
		return

	var projectile := projectiles.get_child(0)
	projectile._on_area_entered(hitbox)

	if not is_equal_approx(target.total_damage, 12.0):
		push_error("Projectile dealt %.2f damage, expected 12.00" % target.total_damage)
		quit(1)
		return
	if target.received_tags != ["projectile", "rune"]:
		push_error("Projectile tags were %s" % [target.received_tags])
		quit(1)
		return
	if hit_recorder.count != 1 or hit_recorder.target != target:
		push_error("GameEvents.weapon_hit was not emitted for the damage target")
		quit(1)
		return
	if hit_recorder.payload.get("weapon_id", "") != "rune_bolt":
		push_error("weapon_hit payload weapon_id was %s" % hit_recorder.payload.get("weapon_id", ""))
		quit(1)
		return
	if hit_recorder.payload.has("tags"):
		push_error("weapon_hit payload still contains legacy tags key")
		quit(1)
		return
	if not _arrays_equal(hit_recorder.payload.get("weapon_tags", []), ["projectile", "rune"]):
		push_error("weapon_hit payload weapon_tags were %s" % [hit_recorder.payload.get("weapon_tags", [])])
		quit(1)
		return
	if not _arrays_equal(hit_recorder.payload.get("element_tags", []), []):
		push_error("weapon_hit payload element_tags were %s" % [hit_recorder.payload.get("element_tags", [])])
		quit(1)
		return

	var recorder := DeathRecorder.new()
	root.add_child(recorder)
	get_root().get_node("GameEvents").connect("enemy_died", recorder._on_enemy_died)

	var enemy := enemy_scene.instantiate()
	if enemy.has_method("apply_damage") == false:
		push_error("Enemy.tscn instance is missing apply_damage")
		quit(1)
		return
	var health_component = enemy.get_node("HealthComponent")
	if health_component.get_script() == null or health_component.get_script().resource_path != "res://scripts/components/HealthComponent.gd":
		push_error("Enemy HealthComponent is missing HealthComponent.gd")
		quit(1)
		return
	var enemy_hitbox := enemy.get_node("HitboxComponent") as Area2D
	if enemy_hitbox == null or enemy_hitbox.collision_layer != 2 or enemy_hitbox.collision_mask != 0:
		push_error("Enemy HitboxComponent collision settings were not preserved")
		quit(1)
		return
	enemy.health_component = health_component
	enemy.drop_component = enemy.get_node("DropComponent")
	health_component.configure(enemy.enemy_data.max_health)
	health_component.died.connect(enemy._on_died)

	projectile = load("res://scenes/projectiles/Projectile.tscn").instantiate()
	var kill_tags: Array[String] = ["projectile"]
	projectile.configure(Vector2.RIGHT, 0.0, 40.0, 1.0, 0, kill_tags, {})
	projectile._on_area_entered(enemy_hitbox)

	if recorder.count != 1:
		push_error("Enemy death event count was %d, expected 1" % recorder.count)
		quit(1)
		return

	print("PASS: weapon projectile damage and enemy death loop")
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
