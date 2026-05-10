extends SceneTree

const REQUIRED_PATHS: Array[String] = [
	"res://scenes/Main.tscn",
	"res://scenes/run/GameRoot.tscn",
	"res://scenes/run/RunScene.tscn",
	"res://data/content/characters/wasteland_walker.tres",
	"res://data/content/weapons/rune_bolt.tres",
	"res://data/content/runes/scorch_mark.tres",
	"res://data/content/enemies/dust_thrall.tres",
	"res://data/content/enemies/ash_runner.tres",
	"res://data/content/enemies/bone_brute.tres",
	"res://data/content/waves/m0_wave.tres",
	"res://data/content/waves/m1_wave.tres"
]

func _initialize() -> void:
	var failures: Array[String] = []
	for path in REQUIRED_PATHS:
		if ResourceLoader.exists(path) == false:
			failures.append("Missing resource: %s" % path)
			continue
		if load(path) == null:
			failures.append("Failed to load: %s" % path)
	_validate_visual_contract(failures)
	if failures.is_empty():
		print("PASS: core scenes, resources, and M1 visual contract loaded")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _validate_visual_contract(failures: Array[String]) -> void:
	var run_scene := _instantiate_scene("res://scenes/run/RunScene.tscn", failures)
	if run_scene != null:
		_require_node(run_scene, "World/Ground", "ColorRect", failures)
		_require_node(run_scene, "World/Player/Camera2D", "Camera2D", failures)
		_require_node(run_scene, "CanvasLayer/HUD/Panel/Margin/Stats", "HBoxContainer", failures)
		_require_node(run_scene, "CanvasLayer/DebugOverlay/Panel/Margin/DebugLabel", "Label", failures)
		var camera := run_scene.get_node_or_null("World/Player/Camera2D") as Camera2D
		if camera != null and camera.enabled == false:
			failures.append("Player follow camera must be enabled")
		for ui_name in ["HUD", "LevelUpPanel", "DebugOverlay"]:
			_require_canvas_layer_ui(run_scene, ui_name, failures)
		var debug_panel := run_scene.get_node_or_null("CanvasLayer/DebugOverlay/Panel") as PanelContainer
		if debug_panel == null:
			failures.append("DebugOverlay must use a compact PanelContainer")
		elif debug_panel.custom_minimum_size.x > 260.0 or debug_panel.custom_minimum_size.y > 140.0:
			failures.append("DebugOverlay panel is too large: %s" % debug_panel.custom_minimum_size)
		run_scene.free()

	for scene_path in [
		"res://scenes/player/Player.tscn",
		"res://scenes/enemies/Enemy.tscn"
	]:
		_validate_sprite_visual(scene_path, failures)

	for scene_path in [
		"res://scenes/projectiles/Projectile.tscn",
		"res://scenes/pickups/ExperiencePickup.tscn"
	]:
		var scene_root := _instantiate_scene(scene_path, failures)
		if scene_root == null:
			continue
		var outline := scene_root.get_node_or_null("Outline") as Polygon2D
		var visual := scene_root.get_node_or_null("Visual") as Polygon2D
		if outline == null:
			failures.append("%s is missing Polygon2D Outline" % scene_path)
		if visual == null:
			failures.append("%s is missing Polygon2D Visual" % scene_path)
		elif visual.polygon.size() < 3:
			failures.append("%s Visual polygon is not drawable" % scene_path)
		scene_root.free()

func _validate_sprite_visual(scene_path: String, failures: Array[String]) -> void:
	var scene_root := _instantiate_scene(scene_path, failures)
	if scene_root == null:
		return
	var visual_node := scene_root.get_node_or_null("Visual")
	if visual_node == null:
		failures.append("%s is missing Visual node" % scene_path)
	elif visual_node is Polygon2D:
		failures.append("%s Visual must use a 2D texture asset, not Polygon2D" % scene_path)
	else:
		var sprite := visual_node as Sprite2D
		if sprite == null:
			failures.append("%s Visual must be a Sprite2D texture asset node" % scene_path)
		elif sprite.texture == null:
			failures.append("%s Visual Sprite2D is missing texture" % scene_path)
	scene_root.free()

func _instantiate_scene(path: String, failures: Array[String]) -> Node:
	var packed := load(path) as PackedScene
	if packed == null:
		failures.append("Failed to load scene for visual contract: %s" % path)
		return null
	var instance := packed.instantiate()
	if instance == null:
		failures.append("Failed to instantiate scene for visual contract: %s" % path)
	return instance

func _require_canvas_layer_ui(root_node: Node, ui_name: String, failures: Array[String]) -> void:
	var canvas_layer := root_node.get_node_or_null("CanvasLayer") as CanvasLayer
	if canvas_layer == null:
		failures.append("RunScene CanvasLayer must remain a CanvasLayer")
		return
	var ui_node := root_node.get_node_or_null("CanvasLayer/%s" % ui_name)
	if ui_node == null:
		failures.append("RunScene %s must remain under CanvasLayer" % ui_name)
	elif ui_node.get_parent() != canvas_layer:
		failures.append("RunScene %s must be parented directly under CanvasLayer" % ui_name)
	if root_node.get_node_or_null("World/Player/%s" % ui_name) != null:
		failures.append("RunScene %s must not be parented under World/Player" % ui_name)
	if root_node.get_node_or_null("World/Player/Camera2D/%s" % ui_name) != null:
		failures.append("RunScene %s must not be parented under World/Player/Camera2D" % ui_name)

func _require_node(root_node: Node, path: NodePath, type_name: String, failures: Array[String]) -> void:
	var node := root_node.get_node_or_null(path)
	if node == null:
		failures.append("Missing visual contract node: %s" % path)
	elif node.get_class() != type_name and not node.is_class(type_name):
		failures.append("Visual contract node %s was %s, expected %s" % [path, node.get_class(), type_name])
