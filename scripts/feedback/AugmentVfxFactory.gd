class_name AugmentVfxFactory
extends RefCounted

const PrimitiveScript := preload("res://scripts/feedback/AugmentVfxPrimitive.gd")

func create_vfx(augment_id: String, spec: Dictionary, trigger_event: String, world_position: Vector2) -> Node:
	if str(spec.get("target_layer", "world")) == "hud":
		return _create_hud_vfx(augment_id, spec, trigger_event)
	return _create_world_vfx(augment_id, spec, trigger_event, world_position)

func _create_world_vfx(augment_id: String, spec: Dictionary, trigger_event: String, world_position: Vector2) -> Node2D:
	var root := Node2D.new()
	root.name = _node_name(augment_id, trigger_event)
	root.position = world_position
	root.scale = Vector2.ONE * float(spec.get("scale", 1.0))
	root.set_script(PrimitiveScript)
	root.set("lifetime_seconds", float(spec.get("lifetime", 0.75)))
	root.set("motion", str(spec.get("motion", "pulse")))
	_apply_required_metadata(root, augment_id, spec, trigger_event)

	var color: Color = spec.get("color", Color.WHITE)
	var shape := str(spec.get("shape", "projectile_arrow"))
	_add_line_primitive(root, shape, color, str(spec.get("line_style", "")))
	_add_polygon_primitive(root, shape, color)
	_add_particles(root, color, str(spec.get("particle_style", "sparks")))
	return root

func _create_hud_vfx(augment_id: String, spec: Dictionary, trigger_event: String) -> Control:
	var root := Control.new()
	root.name = _node_name(augment_id, trigger_event)
	root.custom_minimum_size = Vector2(138.0, 34.0)
	root.position = Vector2(22.0, 126.0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_script(PrimitiveScript)
	root.set("lifetime_seconds", float(spec.get("lifetime", 0.75)))
	root.set("motion", str(spec.get("motion", "card_flip")))
	_apply_required_metadata(root, augment_id, spec, trigger_event)

	var color: Color = spec.get("color", Color.WHITE)
	var panel := Panel.new()
	panel.custom_minimum_size = root.custom_minimum_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.22)
	style.border_color = color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)

	var glyph := ColorRect.new()
	glyph.color = color
	glyph.custom_minimum_size = Vector2(18.0, 18.0)
	glyph.position = Vector2(9.0, 8.0)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(glyph)

	var line := Line2D.new()
	line.default_color = color
	line.width = 2.0
	line.points = PackedVector2Array([Vector2(35.0, 10.0), Vector2(126.0, 10.0), Vector2(104.0, 24.0)])
	root.add_child(line)
	return root

func _apply_required_metadata(node: Node, augment_id: String, spec: Dictionary, trigger_event: String) -> void:
	node.add_to_group("augment_vfx")
	node.set_meta("augment_id", augment_id)
	node.set_meta("visual_signature", str(spec.get("visual_signature", "")))
	node.set_meta("trigger_event", trigger_event)

func _add_line_primitive(root: Node2D, shape: String, color: Color, line_style: String) -> void:
	var line := Line2D.new()
	line.default_color = color
	line.width = 3.0 if line_style.contains("wide") else 2.0
	if line_style.contains("dotted"):
		line.width = 1.0
	if shape.contains("bolt") or shape.contains("zap") or shape.contains("storm"):
		line.points = PackedVector2Array([Vector2(-26.0, -4.0), Vector2(-6.0, -18.0), Vector2(2.0, 0.0), Vector2(24.0, -12.0)])
	elif shape.contains("trail") or shape.contains("trajectory") or shape.contains("dash"):
		line.points = PackedVector2Array([Vector2(-42.0, 0.0), Vector2(-10.0, -6.0), Vector2(30.0, 0.0)])
	elif shape.contains("link") or shape.contains("chain"):
		line.points = PackedVector2Array([Vector2(-28.0, -10.0), Vector2(0.0, 10.0), Vector2(28.0, -10.0)])
	else:
		line.points = PackedVector2Array([Vector2(-20.0, 0.0), Vector2(0.0, -18.0), Vector2(20.0, 0.0)])
	root.add_child(line)

func _add_polygon_primitive(root: Node2D, shape: String, color: Color) -> void:
	var polygon := Polygon2D.new()
	polygon.color = Color(color.r, color.g, color.b, 0.55)
	polygon.polygon = _polygon_points(shape)
	root.add_child(polygon)

func _polygon_points(shape: String) -> PackedVector2Array:
	if shape.contains("ring") or shape.contains("orbit") or shape.contains("clock"):
		return PackedVector2Array([Vector2(-18.0, -18.0), Vector2(18.0, -18.0), Vector2(24.0, 0.0), Vector2(18.0, 18.0), Vector2(-18.0, 18.0), Vector2(-24.0, 0.0)])
	if shape.contains("shard") or shape.contains("arrow") or shape.contains("claw"):
		return PackedVector2Array([Vector2(-22.0, -8.0), Vector2(8.0, -14.0), Vector2(26.0, 0.0), Vector2(8.0, 14.0), Vector2(-22.0, 8.0)])
	if shape.contains("star") or shape.contains("burst"):
		return PackedVector2Array([Vector2(0.0, -24.0), Vector2(7.0, -7.0), Vector2(24.0, 0.0), Vector2(7.0, 7.0), Vector2(0.0, 24.0), Vector2(-7.0, 7.0), Vector2(-24.0, 0.0), Vector2(-7.0, -7.0)])
	if shape.contains("wall") or shape.contains("card") or shape.contains("stamp"):
		return PackedVector2Array([Vector2(-26.0, -15.0), Vector2(26.0, -15.0), Vector2(26.0, 15.0), Vector2(-26.0, 15.0)])
	return PackedVector2Array([Vector2(0.0, -24.0), Vector2(22.0, 0.0), Vector2(0.0, 24.0), Vector2(-22.0, 0.0)])

func _add_particles(root: Node2D, color: Color, particle_style: String) -> void:
	var particles := CPUParticles2D.new()
	particles.amount = 10
	particles.lifetime = 0.45
	particles.one_shot = true
	particles.emitting = true
	particles.explosiveness = 0.85
	particles.spread = 65.0
	particles.initial_velocity_min = 24.0 if particle_style.contains("burst") else 10.0
	particles.initial_velocity_max = 68.0 if particle_style.contains("burst") else 34.0
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.2
	particles.color = color
	root.add_child(particles)

func _node_name(augment_id: String, trigger_event: String) -> String:
	return "AugmentVFX_%s_%s" % [augment_id, trigger_event]
