extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var registry := root.get_node_or_null("AugmentRegistry")
	var augment_system := root.get_node_or_null("AugmentSystem")
	var director := root.get_node_or_null("AugmentVisualDirector")
	var game_events := root.get_node_or_null("GameEvents")
	if registry == null:
		failures.append("AugmentRegistry missing")
	if augment_system == null:
		failures.append("AugmentSystem missing")
	if director == null:
		failures.append("AugmentVisualDirector missing")
	if game_events == null or not game_events.has_signal("augment_visual_played"):
		failures.append("GameEvents.augment_visual_played missing")
	if not failures.is_empty():
		_finish(failures)
		return

	registry.call("reload")
	director.call("rebuild")
	await process_frame
	var visual_registry := director.call("get_visual_registry") as Node
	if visual_registry == null:
		failures.append("AugmentVisualDirector did not expose registry")
		_finish(failures)
		return
	for error in visual_registry.call("validate_against_augment_registry", registry):
		failures.append(str(error))
	_assert_route_visuals_are_distinct(registry, visual_registry, failures)
	_assert_effect_signal_plays_visual(registry, augment_system, game_events, failures)
	_finish(failures)

func _assert_route_visuals_are_distinct(registry: Node, visual_registry: Node, failures: Array[String]) -> void:
	var signatures: Dictionary = {}
	var fingerprints_by_route: Dictionary = {}
	var all_augments: Array = registry.call("get_all")
	if all_augments.size() != 72:
		failures.append("expected 72 production augments, got %d" % all_augments.size())
	for augment in all_augments:
		var resource := augment as Resource
		if resource == null:
			continue
		var augment_id := str(resource.get("id"))
		var route_id := str(resource.get("route_id"))
		if not bool(visual_registry.call("has_spec", augment_id)):
			failures.append("missing visual spec for %s" % augment_id)
			continue
		var spec: Dictionary = visual_registry.call("get_spec", augment_id)
		var signature := str(spec.get("visual_signature", ""))
		if signature == "":
			failures.append("%s has empty visual_signature" % augment_id)
		elif signatures.has(signature):
			failures.append("%s duplicates visual_signature with %s" % [augment_id, str(signatures[signature])])
		else:
			signatures[signature] = augment_id
		var fingerprint := "%s|%s|%s|%s|%s|%s" % [
			str(spec.get("shape", "")),
			str(spec.get("motion", "")),
			str(spec.get("particle_style", "")),
			str(spec.get("spawn_anchor", "")),
			str(spec.get("trigger_timing", "")),
			str(spec.get("lifecycle", "")),
		]
		var route_seen: Dictionary = fingerprints_by_route.get(route_id, {})
		if route_seen.has(fingerprint):
			failures.append("route %s has duplicate visual fingerprint: %s and %s" % [route_id, str(route_seen[fingerprint]), augment_id])
		else:
			route_seen[fingerprint] = augment_id
		fingerprints_by_route[route_id] = route_seen

func _assert_effect_signal_plays_visual(registry: Node, augment_system: Node, game_events: Node, failures: Array[String]) -> void:
	augment_system.call("reset")
	var owner := Node2D.new()
	root.add_child(owner)
	var recorder := _VisualRecorder.new()
	root.add_child(recorder)
	game_events.connect("augment_visual_played", recorder._on_visual_played)
	var augment := registry.call("get_by_id", "aug_rune_dual_wield") as Resource
	if augment == null:
		failures.append("missing aug_rune_dual_wield")
	else:
		augment_system.call("acquire_augment", augment, owner)
		var before_count := recorder.count
		var tags: Array[String] = ["projectile", "weapon"]
		var weapon_tags: Array[String] = ["projectile"]
		var packet: Dictionary = root.get_node("DamageSystem").call("make_packet", 10.0, tags, {
			"owner": owner,
			"weapon_id": "visual_contract_bolt",
			"weapon_tags": weapon_tags,
			"cooldown_source_id": "visual_contract_bolt",
			"hit_position": Vector2(10.0, 5.0)
		})
		augment_system.call("emit_synthetic_event", "on_attack_fire", packet, {"signal_name": "weapon_fired", "owner": owner})
		if recorder.count <= before_count:
			failures.append("executed augment effect did not produce augment_visual_played")
		elif str(recorder.last_payload.get("augment_id", "")) != "aug_rune_dual_wield":
			failures.append("visual payload wrong augment_id: %s" % [recorder.last_payload])
		var snapshot: Dictionary = augment_system.call("get_runtime_snapshot")
		if (snapshot.get("visual_events", []) as Array).is_empty():
			failures.append("AugmentRuntimeState did not record visual_events")
	owner.free()
	recorder.free()

func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("PASS: augment visual runtime contract")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

class _VisualRecorder:
	extends Node
	var count: int = 0
	var last_payload: Dictionary = {}

	func _on_visual_played(payload: Dictionary) -> void:
		count += 1
		last_payload = payload.duplicate(true)
