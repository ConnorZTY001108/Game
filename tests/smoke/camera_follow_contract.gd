extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var run_scene_packed := load("res://scenes/run/RunScene.tscn") as PackedScene
	if run_scene_packed == null:
		push_error("Failed to load RunScene")
		quit(1)
		return

	var run_scene := run_scene_packed.instantiate()
	root.add_child(run_scene)
	await process_frame

	var camera_node := run_scene.get_node_or_null("World/Player/Camera2D")
	if camera_node == null:
		push_error("RunScene is missing World/Player/Camera2D")
		quit(1)
		return

	var camera := camera_node as Camera2D
	if camera == null:
		push_error("World/Player/Camera2D is %s, expected Camera2D" % camera_node.get_class())
		quit(1)
		return
	if camera.enabled == false:
		push_error("World/Player/Camera2D is not enabled")
		quit(1)
		return
	if camera.is_current() == false:
		push_error("World/Player/Camera2D is not the current camera")
		quit(1)
		return
	if camera.get_parent() != run_scene.get_node("World/Player"):
		push_error("World/Player/Camera2D is not parented under World/Player")
		quit(1)
		return

	var canvas_layer := run_scene.get_node_or_null("CanvasLayer") as CanvasLayer
	if canvas_layer == null:
		push_error("RunScene is missing root CanvasLayer")
		quit(1)
		return
	for ui_name in ["HUD", "LevelUpPanel", "DebugOverlay"]:
		if _require_canvas_layer_ui(run_scene, canvas_layer, ui_name) == false:
			quit(1)
			return

	print("PASS: RunScene player-follow camera and CanvasLayer contract")
	quit(0)

func _require_canvas_layer_ui(run_scene: Node, canvas_layer: CanvasLayer, ui_name: String) -> bool:
	var ui_node := run_scene.get_node_or_null("CanvasLayer/%s" % ui_name)
	if ui_node == null:
		push_error("RunScene is missing CanvasLayer/%s" % ui_name)
		return false
	if ui_node.get_parent() != canvas_layer:
		push_error("%s is not parented directly under CanvasLayer" % ui_name)
		return false
	if run_scene.get_node_or_null("World/Player/%s" % ui_name) != null:
		push_error("%s must not be parented under World/Player" % ui_name)
		return false
	if run_scene.get_node_or_null("World/Player/Camera2D/%s" % ui_name) != null:
		push_error("%s must not be parented under World/Player/Camera2D" % ui_name)
		return false
	return true
