extends SceneTree

const RUN_SCENE_PATH := "res://scenes/run/RunScene.tscn"

const FORBIDDEN_DEBUG_LABELS: Array[String] = ["Tags:", "Source:", "Effect:", "Condition:", "Fit:", "Risk:"]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var registry := root.get_node_or_null("AugmentRegistry")
	if registry == null:
		_finish(["AugmentRegistry autoload missing"])
		return
	registry.call("reload")

	var run_scene_packed := load(RUN_SCENE_PATH) as PackedScene
	if run_scene_packed == null:
		_finish(["failed to load RunScene"])
		return
	var run_scene := run_scene_packed.instantiate()
	root.add_child(run_scene)
	await process_frame

	var level_panel: Variant = run_scene.get_node_or_null("CanvasLayer/LevelUpPanel")
	if level_panel == null:
		_finish(["RunScene missing LevelUpPanel"])
		return

	for augment_id in ["aug_stats_forge", "aug_rune_dual_wield"]:
		var augment := registry.call("get_by_id", augment_id) as Resource
		if augment == null:
			failures.append("missing augment fixture: %s" % augment_id)
			continue
		level_panel.call("_show_options", _resource_array([augment]))
		var button_text := _first_button_text(level_panel)
		_assert_augment_copy(button_text, augment, failures)

	run_scene.free()
	_finish(failures)

func _assert_augment_copy(text: String, augment: Resource, failures: Array[String]) -> void:
	var augment_id := str(augment.get("id"))
	for forbidden in FORBIDDEN_DEBUG_LABELS:
		if text.contains(forbidden):
			failures.append("%s player-facing copy still contains debug label %s: %s" % [augment_id, forbidden, text])
	var lines := text.split("\n", false)
	if lines.size() != 4:
		failures.append("%s option copy should be exactly 4 lines, got %d: %s" % [augment_id, lines.size(), text])
		return
	if lines[0] != str(augment.get("display_name")):
		failures.append("%s line 1 should be display name only: %s" % [augment_id, lines[0]])
	if not lines[1].contains(str(augment.get("route_id"))) and not lines[1].contains(str(augment.get("route_label"))):
		failures.append("%s line 2 should show type/route: %s" % [augment_id, lines[1]])
	if _first_non_empty([str(augment.get("effect")), str(augment.get("description"))]) != "" and not lines[2].contains(_first_non_empty([str(augment.get("effect")), str(augment.get("description"))]).substr(0, 8)):
		failures.append("%s line 3 should show direct effect: %s" % [augment_id, lines[2]])
	var condition_or_fit := _first_non_empty([str(augment.get("source_condition")), str(augment.get("fit"))])
	if condition_or_fit != "" and not lines[3].contains(condition_or_fit.substr(0, 8)):
		failures.append("%s line 4 should show trigger condition or suitable route: %s" % [augment_id, lines[3]])

func _first_button_text(level_panel: Node) -> String:
	var options_container: Node = level_panel.get_node("Panel/Margin/Content/Options")
	if options_container.get_child_count() <= 0:
		return ""
	var button := options_container.get_child(0) as Button
	return button.text if button != null else ""

func _first_non_empty(values: Array[String]) -> String:
	for value in values:
		if value.strip_edges() != "":
			return value
	return ""

func _resource_array(values: Array) -> Array[Resource]:
	var result: Array[Resource] = []
	for value in values:
		result.append(value as Resource)
	return result

func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("PASS: LevelUpPanel augment copy is four-line player-facing text")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
