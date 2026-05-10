extends SceneTree

const REQUIRED_PATHS: Array[String] = [
	"res://scenes/Main.tscn",
	"res://scenes/run/GameRoot.tscn",
	"res://scenes/run/RunScene.tscn",
	"res://data/content/characters/wasteland_walker.tres",
	"res://data/content/weapons/rune_bolt.tres",
	"res://data/content/runes/scorch_mark.tres",
	"res://data/content/enemies/dust_thrall.tres",
	"res://data/content/waves/m0_wave.tres"
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
		print("PASS: core scenes, resources, and M0 visual contract loaded")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _validate_visual_contract(failures: Array[String]) -> void:
	var run_scene := _instantiate_scene("res://scenes/run/RunScene.tscn", failures)
	if run_scene != null:
		_require_node(run_scene, "World/Ground", "ColorRect", failures)
		_require_node(run_scene, "CanvasLayer/HUD/Panel/Margin/Stats", "HBoxContainer", failures)
		_require_node(run_scene, "CanvasLayer/DebugOverlay/Panel/Margin/DebugLabel", "Label", failures)
		var debug_panel := run_scene.get_node_or_null("CanvasLayer/DebugOverlay/Panel") as PanelContainer
		if debug_panel == null:
			failures.append("DebugOverlay must use a compact PanelContainer")
		elif debug_panel.custom_minimum_size.x > 260.0 or debug_panel.custom_minimum_size.y > 140.0:
			failures.append("DebugOverlay panel is too large: %s" % debug_panel.custom_minimum_size)
		run_scene.free()

	for scene_path in [
		"res://scenes/player/Player.tscn",
		"res://scenes/enemies/Enemy.tscn",
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

func _instantiate_scene(path: String, failures: Array[String]) -> Node:
	var packed := load(path) as PackedScene
	if packed == null:
		failures.append("Failed to load scene for visual contract: %s" % path)
		return null
	var instance := packed.instantiate()
	if instance == null:
		failures.append("Failed to instantiate scene for visual contract: %s" % path)
	return instance

func _require_node(root_node: Node, path: NodePath, type_name: String, failures: Array[String]) -> void:
	var node := root_node.get_node_or_null(path)
	if node == null:
		failures.append("Missing visual contract node: %s" % path)
	elif node.get_class() != type_name and not node.is_class(type_name):
		failures.append("Visual contract node %s was %s, expected %s" % [path, node.get_class(), type_name])
