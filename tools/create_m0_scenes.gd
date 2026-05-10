extends SceneTree

# M0-only bootstrap generator.
# Do not run this against M1+ work unless you intend to recreate the original
# M0 scene wiring; it binds RunScene SpawnSystem back to m0_wave.tres.

func _init() -> void:
	_make_dirs()
	_save_scene(_weapon_controller(), "res://scenes/weapons/WeaponController.tscn")
	_save_scene(_projectile(), "res://scenes/projectiles/Projectile.tscn")
	_save_scene(_experience_pickup(), "res://scenes/pickups/ExperiencePickup.tscn")
	_save_scene(_player(), "res://scenes/player/Player.tscn")
	_save_scene(_enemy(), "res://scenes/enemies/Enemy.tscn")
	_save_scene(_hud(), "res://scenes/ui/HUD.tscn")
	_save_scene(_level_up_panel(), "res://scenes/ui/LevelUpPanel.tscn")
	_save_scene(_debug_overlay(), "res://scenes/ui/DebugOverlay.tscn")
	_save_scene(_run_scene(), "res://scenes/run/RunScene.tscn")
	_save_scene(_game_root(), "res://scenes/run/GameRoot.tscn")
	_save_scene(_main(), "res://scenes/Main.tscn")
	_bind_generated_scene_scripts()
	print("PASS: M0 scenes created")
	quit(0)

func _make_dirs() -> void:
	for path in ["res://scenes/run", "res://scenes/player", "res://scenes/enemies", "res://scenes/projectiles", "res://scenes/pickups", "res://scenes/weapons", "res://scenes/ui"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))

func _main() -> Node:
	var root := Node.new()
	root.name = "Main"
	_add_instance(root, "GameRoot", "res://scenes/run/GameRoot.tscn")
	return root

func _game_root() -> Node:
	var root := Node.new()
	root.name = "GameRoot"
	_add_instance(root, "RunScene", "res://scenes/run/RunScene.tscn")
	return root

func _run_scene() -> Node2D:
	var root := Node2D.new()
	root.name = "RunScene"
	var world := Node2D.new()
	world.name = "World"
	root.add_child(world)
	var ground := ColorRect.new()
	ground.name = "Ground"
	ground.position = Vector2(-2000.0, -1200.0)
	ground.size = Vector2(4000.0, 2400.0)
	ground.color = Color(0.28, 0.25, 0.18)
	ground.z_index = -100
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(ground)
	var bounds := Node2D.new()
	bounds.name = "Bounds"
	world.add_child(bounds)
	var spawn := Marker2D.new()
	spawn.name = "PlayerSpawn"
	world.add_child(spawn)
	_add_instance(world, "Player", "res://scenes/player/Player.tscn")
	for name in ["Enemies", "Projectiles", "Pickups"]:
		var container := Node2D.new()
		container.name = name
		world.add_child(container)
	var systems := Node.new()
	systems.name = "Systems"
	root.add_child(systems)
	for name in ["RunTimerSystem", "SpawnSystem", "DropSystem"]:
		var system := Node.new()
		system.name = name
		systems.add_child(system)
	var layer := CanvasLayer.new()
	layer.name = "CanvasLayer"
	root.add_child(layer)
	_add_instance(layer, "HUD", "res://scenes/ui/HUD.tscn")
	_add_instance(layer, "LevelUpPanel", "res://scenes/ui/LevelUpPanel.tscn")
	_add_instance(layer, "DebugOverlay", "res://scenes/ui/DebugOverlay.tscn")
	_set_owner_recursive(root, root)
	return root

func _player() -> CharacterBody2D:
	var root := CharacterBody2D.new()
	root.name = "Player"
	_add_polygon_visual(root, [Vector2(0, -18), Vector2(16, 12), Vector2(0, 20), Vector2(-16, 12)], Color(0.05, 0.08, 0.08), Color(0.15, 0.9, 1.0), 1.2)
	var health_component := _named_node("HealthComponent")
	root.add_child(health_component)
	var pickup := Area2D.new()
	pickup.name = "PickupArea"
	pickup.add_child(_circle_shape(72.0))
	root.add_child(pickup)
	var mount := Node2D.new()
	mount.name = "WeaponMount"
	root.add_child(mount)
	_set_owner_recursive(root, root)
	return root

func _enemy() -> CharacterBody2D:
	var root := CharacterBody2D.new()
	root.name = "Enemy"
	_add_polygon_visual(root, [Vector2(0, -17), Vector2(17, 0), Vector2(0, 17), Vector2(-17, 0)], Color(0.08, 0.03, 0.02), Color(0.95, 0.27, 0.16), 1.18)
	root.add_child(_named_node("HealthComponent"))
	var hitbox := Area2D.new()
	hitbox.name = "HitboxComponent"
	hitbox.collision_layer = 2
	hitbox.collision_mask = 0
	hitbox.monitorable = true
	hitbox.add_child(_circle_shape(14.0))
	root.add_child(hitbox)
	var contact := Area2D.new()
	contact.name = "ContactArea"
	contact.add_child(_circle_shape(18.0))
	root.add_child(contact)
	root.add_child(_named_node("DropComponent"))
	root.add_child(_named_node("StatusReceiver"))
	_set_owner_recursive(root, root)
	return root

func _projectile() -> Area2D:
	var root := Area2D.new()
	root.name = "Projectile"
	root.collision_layer = 0
	root.collision_mask = 2
	root.monitoring = true
	_add_polygon_visual(root, [Vector2(0, -8), Vector2(10, 0), Vector2(0, 8), Vector2(-10, 0)], Color(0.02, 0.06, 0.08), Color(0.7, 1.0, 1.0), 1.25)
	root.add_child(_circle_shape(6.0))
	_set_owner_recursive(root, root)
	return root

func _experience_pickup() -> Area2D:
	var root := Area2D.new()
	root.name = "ExperiencePickup"
	_add_polygon_visual(root, [Vector2(0, -9), Vector2(8, -3), Vector2(5, 8), Vector2(-5, 8), Vector2(-8, -3)], Color(0.02, 0.08, 0.03), Color(0.35, 1.0, 0.25), 1.25)
	root.add_child(_circle_shape(8.0))
	_set_owner_recursive(root, root)
	return root

func _weapon_controller() -> Node2D:
	var root := Node2D.new()
	root.name = "WeaponController"
	return root

func _hud() -> Control:
	var root := Control.new()
	root.name = "HUD"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.position = Vector2(16.0, 16.0)
	panel.custom_minimum_size = Vector2(510.0, 44.0)
	root.add_child(panel)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var stats := HBoxContainer.new()
	stats.name = "Stats"
	stats.add_theme_constant_override("separation", 18)
	margin.add_child(stats)
	var default_labels := {
		"HealthLabel": "生命: 0/0",
		"LevelLabel": "等级: 1",
		"ExperienceLabel": "经验: 0",
		"TimerLabel": "时间: 00:00",
		"KillLabel": "击杀: 0"
	}
	for name in ["HealthLabel", "LevelLabel", "ExperienceLabel", "TimerLabel", "KillLabel"]:
		var label := Label.new()
		label.name = name
		label.text = default_labels[name]
		label.custom_minimum_size = Vector2(76.0, 24.0)
		stats.add_child(label)
	_set_owner_recursive(root, root)
	return root

func _level_up_panel() -> Control:
	var root := Control.new()
	root.name = "LevelUpPanel"
	root.visible = false
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -240.0
	panel.offset_top = -150.0
	panel.offset_right = 240.0
	panel.offset_bottom = 150.0
	root.add_child(panel)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "选择符文铭刻"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var options := VBoxContainer.new()
	options.name = "Options"
	options.add_theme_constant_override("separation", 10)
	content.add_child(options)
	_set_owner_recursive(root, root)
	return root

func _debug_overlay() -> Control:
	var root := Control.new()
	root.name = "DebugOverlay"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -224.0
	panel.offset_top = 16.0
	panel.offset_right = -16.0
	panel.offset_bottom = 116.0
	panel.custom_minimum_size = Vector2(208.0, 100.0)
	root.add_child(panel)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var label := Label.new()
	label.name = "DebugLabel"
	label.text = "帧率: 0"
	margin.add_child(label)
	_set_owner_recursive(root, root)
	return root

func _add_instance(parent: Node, name: String, path: String) -> void:
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("Failed to load scene: %s" % path)
		quit(1)
	var child := scene.instantiate()
	child.name = name
	child.scene_file_path = path
	parent.add_child(child)

func _named_node(name: String) -> Node:
	var node := Node.new()
	node.name = name
	return node

func _bind_generated_scene_scripts() -> void:
	_bind_scene_script("res://scenes/weapons/WeaponController.tscn", "1_weapon_controller", "res://scripts/weapons/WeaponController.gd", "[node name=\"WeaponController\" type=\"Node2D\"")
	_bind_scene_script("res://scenes/projectiles/Projectile.tscn", "1_projectile", "res://scripts/projectiles/Projectile.gd", "[node name=\"Projectile\" type=\"Area2D\"")
	_bind_scene_script("res://scenes/pickups/ExperiencePickup.tscn", "1_pickup", "res://scripts/pickups/ExperiencePickup.gd", "[node name=\"ExperiencePickup\" type=\"Area2D\"")
	_bind_scene_script("res://scenes/player/Player.tscn", "1_player", "res://scripts/player/Player.gd", "[node name=\"Player\" type=\"CharacterBody2D\"")
	_bind_scene_script("res://scenes/player/Player.tscn", "2_health", "res://scripts/components/HealthComponent.gd", "[node name=\"HealthComponent\" type=\"Node\" parent=\".\"")
	_bind_scene_script("res://scenes/enemies/Enemy.tscn", "3_enemy", "res://scripts/enemies/Enemy.gd", "[node name=\"Enemy\" type=\"CharacterBody2D\"")
	_bind_scene_script("res://scenes/enemies/Enemy.tscn", "4_enemy_health", "res://scripts/components/HealthComponent.gd", "[node name=\"HealthComponent\" type=\"Node\" parent=\".\"")
	_bind_scene_script("res://scenes/enemies/Enemy.tscn", "11_status_receiver", "res://scripts/components/StatusReceiver.gd", "[node name=\"StatusReceiver\" type=\"Node\" parent=\".\"")
	_bind_scene_script("res://scenes/run/RunScene.tscn", "5_run_scene", "res://scripts/run/RunScene.gd", "[node name=\"RunScene\" type=\"Node2D\"")
	_bind_scene_script("res://scenes/run/RunScene.tscn", "6_run_timer", "res://scripts/systems/RunTimerSystem.gd", "[node name=\"RunTimerSystem\" type=\"Node\" parent=\"Systems\"")
	_bind_scene_script("res://scenes/run/RunScene.tscn", "7_spawn_system", "res://scripts/systems/SpawnSystem.gd", "[node name=\"SpawnSystem\" type=\"Node\" parent=\"Systems\"")
	_bind_scene_script("res://scenes/run/RunScene.tscn", "10_drop_system", "res://scripts/systems/DropSystem.gd", "[node name=\"DropSystem\" type=\"Node\" parent=\"Systems\"")
	_bind_spawn_system_config()
	_bind_task9_scene_config()
	_bind_task11_scene_config()
	_bind_scene_script("res://scenes/ui/HUD.tscn", "1_hud", "res://scripts/ui/HUD.gd", "[node name=\"HUD\" type=\"Control\"")
	_bind_scene_script("res://scenes/ui/LevelUpPanel.tscn", "1_level_up", "res://scripts/ui/LevelUpPanel.gd", "[node name=\"LevelUpPanel\" type=\"Control\"")
	_bind_scene_script("res://scenes/ui/DebugOverlay.tscn", "1_debug", "res://scripts/ui/DebugOverlay.gd", "[node name=\"DebugOverlay\" type=\"Control\"")

func _bind_spawn_system_config() -> void:
	# M0-only: this deliberately preserves the original baseline m0_wave.tres.
	# M1+ scenes should be edited directly or by a dedicated migration, not this generator.
	var scene_path := "res://scenes/run/RunScene.tscn"
	var absolute_path := ProjectSettings.globalize_path(scene_path)
	var file := FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		push_error("Failed to read scene: %s" % scene_path)
		quit(1)
	var text := file.get_as_text()
	file.close()

	text = _ensure_ext_resource(text, "Resource", "res://data/content/waves/m0_wave.tres", "8_m0_wave")
	text = _ensure_ext_resource(text, "PackedScene", "res://scenes/enemies/Enemy.tscn", "9_enemy_scene")
	text = _ensure_node_property(text, "[node name=\"SpawnSystem\" type=\"Node\" parent=\"Systems\"", "wave_data", "ExtResource(\"8_m0_wave\")")
	text = _ensure_node_property(text, "[node name=\"SpawnSystem\" type=\"Node\" parent=\"Systems\"", "enemy_scene", "ExtResource(\"9_enemy_scene\")")
	text = _ensure_node_property(text, "[node name=\"SpawnSystem\" type=\"Node\" parent=\"Systems\"", "enemies_path", "NodePath(\"../../World/Enemies\")")
	text = _ensure_node_property(text, "[node name=\"SpawnSystem\" type=\"Node\" parent=\"Systems\"", "player_path", "NodePath(\"../../World/Player\")")

	file = FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write scene: %s" % scene_path)
		quit(1)
	file.store_string(text)
	file.close()

func _bind_task9_scene_config() -> void:
	var scene_path := "res://scenes/run/RunScene.tscn"
	var absolute_path := ProjectSettings.globalize_path(scene_path)
	var file := FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		push_error("Failed to read scene: %s" % scene_path)
		quit(1)
	var text := file.get_as_text()
	file.close()

	text = _ensure_node_property(text, "[node name=\"DropSystem\" type=\"Node\" parent=\"Systems\"", "pickups_path", "NodePath(\"../../World/Pickups\")")
	text = _ensure_node_property(text, "[node name=\"DropSystem\" type=\"Node\" parent=\"Systems\"", "player_path", "NodePath(\"../../World/Player\")")
	text = _ensure_node_property(text, "[node name=\"LevelUpPanel\" type=\"Control\" parent=\"CanvasLayer\"", "player_path", "NodePath(\"../../World/Player\")")

	file = FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write scene: %s" % scene_path)
		quit(1)
	file.store_string(text)
	file.close()

func _bind_task11_scene_config() -> void:
	var scene_path := "res://scenes/enemies/Enemy.tscn"
	var absolute_path := ProjectSettings.globalize_path(scene_path)
	var file := FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		push_error("Failed to read scene: %s" % scene_path)
		quit(1)
	var text := file.get_as_text()
	file.close()

	text = _ensure_connection(text, "body_entered", "ContactArea", ".", "_on_contact_area_body_entered")
	text = _ensure_connection(text, "body_exited", "ContactArea", ".", "_on_contact_area_body_exited")

	file = FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write scene: %s" % scene_path)
		quit(1)
	file.store_string(text)
	file.close()

func _ensure_ext_resource(text: String, type_name: String, path: String, id: String) -> String:
	var ext_line := "[ext_resource type=\"%s\" path=\"%s\" id=\"%s\"]" % [type_name, path, id]
	if text.contains(ext_line):
		return text
	var scene_header_end := text.find("\n")
	return text.substr(0, scene_header_end + 1) + "\n" + ext_line + text.substr(scene_header_end + 1)

func _ensure_connection(text: String, signal_name: String, from_path: String, to_path: String, method_name: String) -> String:
	var connection_line := "[connection signal=\"%s\" from=\"%s\" to=\"%s\" method=\"%s\"]" % [signal_name, from_path, to_path, method_name]
	if text.contains(connection_line):
		return text
	return text.rstrip("\n") + "\n\n" + connection_line + "\n"

func _ensure_node_property(text: String, node_prefix: String, property_name: String, property_value: String) -> String:
	var node_index := text.find(node_prefix)
	if node_index == -1:
		push_error("Missing node while setting property: %s" % node_prefix)
		quit(1)
	var header_end := text.find("\n", node_index)
	var next_node := text.find("\n[node ", header_end)
	var block_end := next_node if next_node != -1 else text.length()
	var block := text.substr(header_end + 1, block_end - header_end - 1)
	var property_prefix := property_name + " = "
	if block.contains(property_prefix):
		return text
	return text.substr(0, block_end) + "\n%s = %s" % [property_name, property_value] + text.substr(block_end)

func _bind_scene_script(scene_path: String, id: String, script_path: String, node_prefix: String) -> void:
	if ResourceLoader.exists(script_path) == false:
		push_error("Missing script: %s" % script_path)
		quit(1)
	var absolute_path := ProjectSettings.globalize_path(scene_path)
	var file := FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		push_error("Failed to read scene: %s" % scene_path)
		quit(1)
	var text := file.get_as_text()
	file.close()

	var ext_line := "[ext_resource type=\"Script\" path=\"%s\" id=\"%s\"]" % [script_path, id]
	if text.contains(ext_line) == false:
		var scene_header_end := text.find("\n")
		text = text.substr(0, scene_header_end + 1) + "\n" + ext_line + text.substr(scene_header_end + 1)

	var node_index := text.find(node_prefix)
	if node_index == -1:
		push_error("Missing node in %s: %s" % [scene_path, node_prefix])
		quit(1)
	var header_end := text.find("\n", node_index)
	var next_node := text.find("\n[node ", header_end)
	var block_end := next_node if next_node != -1 else text.length()
	var block := text.substr(header_end + 1, block_end - header_end - 1)
	if block.contains("script = ExtResource(") == false:
		text = text.substr(0, header_end + 1) + "script = ExtResource(\"%s\")\n" % id + text.substr(header_end + 1)

	file = FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write scene: %s" % scene_path)
		quit(1)
	file.store_string(text)
	file.close()

func _add_polygon_visual(parent: Node, points: Array[Vector2], outline_color: Color, fill_color: Color, outline_scale: float) -> void:
	var outline := Polygon2D.new()
	outline.name = "Outline"
	outline.polygon = PackedVector2Array(points.map(func(point: Vector2) -> Vector2: return point * outline_scale))
	outline.color = outline_color
	parent.add_child(outline)
	var visual := Polygon2D.new()
	visual.name = "Visual"
	visual.polygon = PackedVector2Array(points)
	visual.color = fill_color
	parent.add_child(visual)

func _circle_shape(radius: float) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	return shape

func _set_owner_recursive(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		if child.scene_file_path.is_empty():
			_set_owner_recursive(child, root)

func _save_scene(root: Node, path: String) -> void:
	_set_owner_recursive(root, root)
	var scene := PackedScene.new()
	var pack_error := scene.pack(root)
	if pack_error != OK:
		push_error("Failed to pack %s: %s" % [path, pack_error])
		quit(1)
	var save_error := ResourceSaver.save(scene, path)
	if save_error != OK:
		push_error("Failed to save %s: %s" % [path, save_error])
		quit(1)
