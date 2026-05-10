extends SceneTree

const ENEMY_CASES: Array[Dictionary] = [
	{
		"data_path": "res://data/content/enemies/dust_thrall.tres",
		"visual_path": "res://assets/enemies/dust_thrall.png"
	},
	{
		"data_path": "res://data/content/enemies/ash_runner.tres",
		"visual_path": "res://assets/enemies/ash_runner.png"
	},
	{
		"data_path": "res://data/content/enemies/bone_brute.tres",
		"visual_path": "res://assets/enemies/bone_brute.png"
	}
]

func _initialize() -> void:
	var failures: Array[String] = []
	_validate_player_visual(failures)
	_validate_enemy_visuals(failures)
	if failures.is_empty():
		print("PASS: M1 visual asset replacement contract")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _validate_player_visual(failures: Array[String]) -> void:
	_require_resource("res://assets/characters/player_wasteland_walker.png", failures)
	var player := _instantiate_scene("res://scenes/player/Player.tscn", failures)
	if player == null:
		return
	_require_sprite_visual(player, "res://scenes/player/Player.tscn", "res://assets/characters/player_wasteland_walker.png", failures)
	_require_node(player, "HealthComponent", failures)
	_require_node(player, "PickupArea", failures)
	_require_node(player, "PickupArea/CollisionShape2D", failures)
	_require_node(player, "WeaponMount", failures)
	player.free()

func _validate_enemy_visuals(failures: Array[String]) -> void:
	var enemy_scene := load("res://scenes/enemies/Enemy.tscn") as PackedScene
	if enemy_scene == null:
		failures.append("Failed to load enemy scene")
		return

	var seen_visual_paths: Array[String] = []
	for enemy_case in ENEMY_CASES:
		var data_path := str(enemy_case["data_path"])
		var visual_path := str(enemy_case["visual_path"])
		_require_resource(visual_path, failures)
		var enemy_data := load(data_path) as Resource
		if enemy_data == null:
			failures.append("Failed to load enemy data: %s" % data_path)
			continue
		var visual_texture := enemy_data.get("visual_texture") as Texture2D
		if visual_texture == null:
			failures.append("%s is missing visual_texture" % data_path)
			continue
		if visual_texture.resource_path != visual_path:
			failures.append("%s visual_texture was %s, expected %s" % [data_path, visual_texture.resource_path, visual_path])
		if seen_visual_paths.has(visual_texture.resource_path):
			failures.append("Enemy visual texture path is duplicated: %s" % visual_texture.resource_path)
		seen_visual_paths.append(visual_texture.resource_path)

		var enemy := enemy_scene.instantiate()
		if enemy == null:
			failures.append("Failed to instantiate Enemy.tscn for %s" % data_path)
			continue
		var target := Node2D.new()
		enemy.health_component = enemy.get_node_or_null("HealthComponent")
		enemy.drop_component = enemy.get_node_or_null("DropComponent")
		enemy.status_receiver = enemy.get_node_or_null("StatusReceiver")
		enemy.visual = enemy.get_node_or_null("Visual")
		enemy.enemy_data = enemy_data
		if enemy.has_method("configure"):
			enemy.configure(enemy_data, target)
		enemy._ready()
		_require_sprite_visual(enemy, "res://scenes/enemies/Enemy.tscn:%s" % data_path, visual_path, failures)
		_require_enemy_runtime_nodes(enemy, data_path, failures)
		if enemy.has_method("apply_damage"):
			var damage_tags: Array[String] = ["visual_contract"]
			enemy.apply_damage(1.0, damage_tags)
		else:
			failures.append("%s enemy instance is missing apply_damage" % data_path)
		enemy.free()
		target.free()

func _require_sprite_visual(root_node: Node, label: String, expected_path: String, failures: Array[String]) -> void:
	var visual_node := root_node.get_node_or_null("Visual")
	if visual_node == null:
		failures.append("%s is missing Visual node" % label)
		return
	if visual_node is Polygon2D:
		failures.append("%s Visual must not be Polygon2D" % label)
		return
	var sprite := visual_node as Sprite2D
	if sprite == null:
		failures.append("%s Visual must be Sprite2D" % label)
		return
	if sprite.texture == null:
		failures.append("%s Sprite2D is missing texture" % label)
	elif sprite.texture.resource_path != expected_path:
		failures.append("%s texture was %s, expected %s" % [label, sprite.texture.resource_path, expected_path])

func _require_enemy_runtime_nodes(enemy: Node, data_path: String, failures: Array[String]) -> void:
	_require_node(enemy, "HealthComponent", failures)
	_require_node(enemy, "HitboxComponent", failures)
	_require_node(enemy, "HitboxComponent/CollisionShape2D", failures)
	_require_node(enemy, "ContactArea", failures)
	_require_node(enemy, "ContactArea/CollisionShape2D", failures)
	_require_node(enemy, "DropComponent", failures)
	_require_node(enemy, "StatusReceiver", failures)
	var hitbox := enemy.get_node_or_null("HitboxComponent") as Area2D
	if hitbox == null:
		failures.append("%s HitboxComponent must remain Area2D" % data_path)
	elif hitbox.collision_layer != 2 or hitbox.collision_mask != 0:
		failures.append("%s HitboxComponent collision settings changed" % data_path)

func _require_resource(path: String, failures: Array[String]) -> void:
	if ResourceLoader.exists(path) == false:
		failures.append("Missing resource: %s" % path)
	elif load(path) == null:
		failures.append("Failed to load resource: %s" % path)

func _instantiate_scene(path: String, failures: Array[String]) -> Node:
	var packed := load(path) as PackedScene
	if packed == null:
		failures.append("Failed to load scene: %s" % path)
		return null
	var instance := packed.instantiate()
	if instance == null:
		failures.append("Failed to instantiate scene: %s" % path)
	return instance

func _require_node(root_node: Node, path: NodePath, failures: Array[String]) -> void:
	if root_node.get_node_or_null(path) == null:
		failures.append("Missing required node: %s/%s" % [root_node.name, path])
