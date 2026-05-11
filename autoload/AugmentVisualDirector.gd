extends Node

const AugmentVisualRegistryScript := preload("res://scripts/augment/AugmentVisualRegistry.gd")

var _visual_registry: Node
var _event_serial: int = 0

func _ready() -> void:
	_visual_registry = AugmentVisualRegistryScript.new()
	add_child(_visual_registry)
	call_deferred("_deferred_ready")

func get_visual_registry() -> Node:
	return _visual_registry

func rebuild() -> void:
	if _visual_registry != null and is_instance_valid(AugmentRegistry):
		_visual_registry.call("rebuild_from_augment_registry", AugmentRegistry)

func _deferred_ready() -> void:
	rebuild()
	if not is_instance_valid(GameEvents):
		return
	_connect_event("augment_acquired", _on_augment_acquired)
	_connect_event("augment_effect_triggered", _on_augment_effect_triggered)

func _connect_event(signal_name: String, callable: Callable) -> void:
	if GameEvents.has_signal(signal_name) and not GameEvents.is_connected(signal_name, callable):
		GameEvents.connect(signal_name, callable)

func _on_augment_acquired(augment_id: String, augment: Resource, owner: Node, snapshot: Dictionary) -> void:
	var payload := {
		"augment_id": augment_id,
		"effect_type": "augment_acquired",
		"effect_family": "acquire",
		"trigger_id": "on_pick",
		"signal_name": "augment_acquired",
		"world_position": _node_world_position(owner),
		"owner": owner,
		"snapshot": snapshot,
	}
	_play_from_payload(payload, "on_acquire", augment)

func _on_augment_effect_triggered(payload: Dictionary) -> void:
	_play_from_payload(payload, "on_effect")

func _play_from_payload(payload: Dictionary, timing: String, augment: Resource = null) -> void:
	if _visual_registry == null:
		return
	var augment_id := str(payload.get("augment_id", ""))
	if augment_id == "":
		return
	if not bool(_visual_registry.call("has_spec", augment_id)):
		rebuild()
	if not bool(_visual_registry.call("has_spec", augment_id)):
		return
	_event_serial += 1
	var spec: Dictionary = _visual_registry.call("get_spec", augment_id)
	var resolved_augment := augment
	if resolved_augment == null and is_instance_valid(AugmentRegistry):
		resolved_augment = AugmentRegistry.call("get_by_id", augment_id) as Resource
	var display_name := str(resolved_augment.get("display_name")) if resolved_augment != null else augment_id
	var world_position := _world_position_from_payload(payload)
	var visual_payload := payload.duplicate(true)
	visual_payload["visual_event_id"] = _event_serial
	visual_payload["display_name"] = display_name
	visual_payload["timing"] = timing
	visual_payload["visual_spec"] = spec.duplicate(true)
	visual_payload["world_position"] = world_position
	if is_instance_valid(AugmentSystem) and AugmentSystem.has_method("record_visual_event"):
		AugmentSystem.call("record_visual_event", visual_payload.duplicate(true))
	if is_instance_valid(GameEvents):
		if GameEvents.has_signal("augment_visual_played"):
			GameEvents.augment_visual_played.emit(visual_payload.duplicate(true))
		GameEvents.request_feedback("augment_visual", "强化触发：%s" % display_name, world_position, visual_payload.duplicate(true))
	_spawn_runtime_node(visual_payload)

func _spawn_runtime_node(visual_payload: Dictionary) -> void:
	var spec: Dictionary = visual_payload.get("visual_spec", {})
	var lifetime := maxf(0.05, float(spec.get("lifetime", 0.55)))
	var scale_value := maxf(0.1, float(spec.get("scale", 1.0)))
	var color: Color = spec.get("color", Color.WHITE)
	var accent: Color = spec.get("accent_color", color.lightened(0.25))
	var vfx := Node2D.new()
	vfx.name = "AugmentRuntimeVisual_%s_%d" % [str(visual_payload.get("augment_id", "augment")), int(visual_payload.get("visual_event_id", 0))]
	vfx.global_position = _world_position_from_payload(visual_payload)
	vfx.scale = Vector2.ONE * scale_value
	vfx.modulate = Color(1.0, 1.0, 1.0, 0.92)
	vfx.add_to_group("augment_runtime_visual")
	vfx.set_meta("augment_id", str(visual_payload.get("augment_id", "")))
	vfx.set_meta("visual_event_id", int(visual_payload.get("visual_event_id", 0)))
	vfx.set_meta("visual_signature", str(spec.get("visual_signature", "")))

	var polygon := Polygon2D.new()
	polygon.color = color
	polygon.polygon = _shape_points(str(spec.get("shape", "burst_star")), 18.0)
	vfx.add_child(polygon)

	var line := Line2D.new()
	line.default_color = accent
	line.width = 2.0 + scale_value
	line.points = _motion_points(str(spec.get("motion", "pulse")), 28.0)
	vfx.add_child(line)

	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	parent.add_child(vfx)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(vfx, "scale", Vector2.ONE * scale_value * 1.35, lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(vfx, "modulate:a", 0.0, lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(vfx, "rotation", vfx.rotation + _rotation_for_motion(str(spec.get("motion", ""))), lifetime)
	tween.finished.connect(func():
		if is_instance_valid(vfx):
			vfx.queue_free()
	)

func _world_position_from_payload(payload: Dictionary) -> Vector2:
	var value = payload.get("world_position", Vector2.ZERO)
	if value is Vector2:
		return value
	return Vector2.ZERO

func _node_world_position(node: Node) -> Vector2:
	if node is Node2D:
		return (node as Node2D).global_position
	return Vector2.ZERO

func _shape_points(shape: String, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var sides := 6
	if shape.contains("star") or shape.contains("crit") or shape.contains("flash"):
		sides = 10
	elif shape.contains("line") or shape.contains("lance") or shape.contains("laser"):
		points.append(Vector2(-radius * 1.4, -radius * 0.22))
		points.append(Vector2(radius * 1.4, -radius * 0.22))
		points.append(Vector2(radius * 1.4, radius * 0.22))
		points.append(Vector2(-radius * 1.4, radius * 0.22))
		return points
	elif shape.contains("triangle") or shape.contains("claw") or shape.contains("boot"):
		sides = 3
	elif shape.contains("ring") or shape.contains("halo") or shape.contains("aura"):
		sides = 14
	for i in range(sides):
		var phase := TAU * float(i) / float(sides)
		var point_radius := radius * (0.55 if sides == 10 and i % 2 == 1 else 1.0)
		points.append(Vector2(cos(phase), sin(phase)) * point_radius)
	return points

func _motion_points(motion: String, radius: float) -> PackedVector2Array:
	if motion.contains("fan") or motion.contains("split"):
		return PackedVector2Array([Vector2.ZERO, Vector2(radius, -radius * 0.55), Vector2.ZERO, Vector2(radius, radius * 0.55)])
	if motion.contains("pull") or motion.contains("drain"):
		return PackedVector2Array([Vector2(-radius, 0), Vector2.ZERO, Vector2(radius * 0.45, 0)])
	if motion.contains("orbit") or motion.contains("spin") or motion.contains("clock"):
		return PackedVector2Array([Vector2(radius, 0), Vector2(0, radius), Vector2(-radius, 0), Vector2(0, -radius), Vector2(radius, 0)])
	return PackedVector2Array([Vector2(-radius, 0), Vector2.ZERO, Vector2(radius, 0)])

func _rotation_for_motion(motion: String) -> float:
	if motion.contains("spin") or motion.contains("orbit") or motion.contains("clock"):
		return TAU
	if motion.contains("collapse") or motion.contains("inward"):
		return -PI
	return PI * 0.35
