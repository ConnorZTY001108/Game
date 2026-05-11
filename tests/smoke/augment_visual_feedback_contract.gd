extends SceneTree

const RUN_SCENE_PATH := "res://scenes/run/RunScene.tscn"
const VISUAL_REGISTRY_PATH := "res://scripts/augment/AugmentVisualRegistry.gd"
const FEEDBACK_DIRECTOR_PATH := "res://scripts/feedback/AugmentFeedbackDirector.gd"
const VFX_FACTORY_PATH := "res://scripts/feedback/AugmentVfxFactory.gd"

const REQUIRED_SPEC_FIELDS: Array[String] = [
	"visual_signature",
	"visual_recipe_key",
	"effect_family",
	"category",
	"color",
	"shape",
	"motion",
	"particle_style",
	"trigger_events",
]

const EXPECTED_EVENT_SIGNALS: Array[String] = [
	"weapon_fired",
	"projectile_spawned",
	"projectile_hit",
	"damage_roll_requested",
	"damage_applied_packet",
	"dot_tick",
	"burn_stack_applied",
	"burn_stack_threshold",
	"rift_chain_triggered",
	"shield_gained",
	"shield_broken",
	"heal_received",
	"regen_tick",
	"control_applied",
	"dash_started",
	"dash_finished",
	"blink_used",
	"low_hp_entered",
	"fatal_damage_received",
	"pickup_collected",
	"elite_killed",
	"boss_damaged",
	"augment_periodic_tick",
	"enemy_died",
	"level_changed",
	"wave_phase_started",
	"rune_triggered",
]

const CATEGORY_KEYWORDS: Dictionary = {
	"bullet": ["projectile", "trajectory", "split", "link"],
	"projectile": ["projectile", "trajectory", "split", "link"],
	"burn": ["burn", "flame", "ember", "detonation"],
	"void": ["void", "rift", "collapse", "chain"],
	"storm": ["storm", "lightning", "arc", "spark"],
	"shield": ["shield", "barrier", "aegis", "ring"],
	"summon": ["summon", "companion", "minion", "orbit"],
	"dash": ["dash", "blink", "trail", "afterimage"],
	"cooldown": ["cooldown", "clock", "refund", "pulse"],
	"crit": ["crit", "shard", "burst", "spark"],
	"lifesteal": ["lifesteal", "blood", "drain", "heal"],
	"forge": ["forge", "choice", "transmute", "card"],
	"choice": ["forge", "choice", "transmute", "card"],
}

const REQUIRED_CATEGORY_GROUPS: Array[Array] = [
	["projectile", "bullet"],
	["burn"],
	["void"],
	["storm"],
	["shield"],
	["summon"],
	["dash"],
	["cooldown"],
	["crit"],
	["lifesteal"],
	["forge", "choice"],
]

func _initialize() -> void:
	_run()

func _run() -> void:
	var failures: Array[String] = []
	var registry_script := load(VISUAL_REGISTRY_PATH) as GDScript
	var director_script := load(FEEDBACK_DIRECTOR_PATH) as GDScript
	var factory_script := load(VFX_FACTORY_PATH) as GDScript
	if registry_script == null:
		failures.append("Missing AugmentVisualRegistry.gd at %s" % VISUAL_REGISTRY_PATH)
	if director_script == null:
		failures.append("Missing AugmentFeedbackDirector.gd at %s" % FEEDBACK_DIRECTOR_PATH)
	if factory_script == null:
		failures.append("Missing AugmentVfxFactory.gd at %s" % VFX_FACTORY_PATH)
	if not failures.is_empty():
		_fail(failures)
		return

	var augment_registry := root.get_node_or_null("AugmentRegistry")
	var game_events := root.get_node_or_null("GameEvents")
	var augment_system := root.get_node_or_null("AugmentSystem")
	if augment_registry == null or game_events == null or augment_system == null:
		_fail(["Missing AugmentRegistry, GameEvents, or AugmentSystem autoload"])
		return
	if (augment_registry.get_all() as Array).is_empty():
		augment_registry.call("reload")

	var visual_registry: Node = registry_script.new()
	var registry_errors: Array = visual_registry.call("validate_against_augment_registry", augment_registry)
	for error in registry_errors:
		failures.append(str(error))
	_validate_visual_specs(visual_registry, augment_registry, failures)

	var run_scene: Node = null
	var run_scene_packed := load(RUN_SCENE_PATH) as PackedScene
	if run_scene_packed == null:
		failures.append("Failed to load RunScene")
	else:
		run_scene = run_scene_packed.instantiate()
		root.add_child(run_scene)
		await process_frame
		_validate_run_scene_contract(run_scene, failures)
		await _validate_spawn_contract(run_scene, game_events, augment_registry, visual_registry, failures)
		await _validate_vfx_cleanup(run_scene, failures)

	if run_scene != null:
		run_scene.queue_free()
		await process_frame
		await process_frame
	if is_instance_valid(visual_registry):
		visual_registry.free()

	if failures.is_empty():
		print("PASS: augment visual feedback contract")
		quit(0)
	else:
		_fail(failures)

func _validate_visual_specs(visual_registry: Node, augment_registry: Node, failures: Array[String]) -> void:
	var seen_signatures: Dictionary = {}
	var seen_recipe_keys: Dictionary = {}
	var seen_categories: Dictionary = {}
	var all_augments: Array = augment_registry.call("get_all")
	if all_augments.is_empty():
		failures.append("AugmentRegistry returned no production Augments")
	for augment in all_augments:
		var augment_id := str(augment.get("id"))
		if not bool(visual_registry.call("has_spec", augment_id)):
			failures.append("Missing visual spec for %s" % augment_id)
			continue
		var spec: Dictionary = visual_registry.call("get_spec", augment_id)
		seen_categories[str(spec.get("category", ""))] = true
		for field in REQUIRED_SPEC_FIELDS:
			if not spec.has(field):
				failures.append("%s visual spec missing field %s" % [augment_id, field])
		var signature := str(spec.get("visual_signature", ""))
		if signature == "":
			failures.append("%s visual_signature is empty" % augment_id)
		elif seen_signatures.has(signature):
			failures.append("%s duplicates visual_signature with %s: %s" % [augment_id, seen_signatures[signature], signature])
		else:
			seen_signatures[signature] = augment_id
		var recipe_key := str(spec.get("visual_recipe_key", ""))
		if recipe_key == "":
			failures.append("%s visual_recipe_key is empty" % augment_id)
		elif recipe_key.contains(augment_id):
			failures.append("%s visual_recipe_key must not include augment_id: %s" % [augment_id, recipe_key])
		elif seen_recipe_keys.has(recipe_key):
			failures.append("%s duplicates visual_recipe_key with %s: %s" % [augment_id, seen_recipe_keys[recipe_key], recipe_key])
		else:
			seen_recipe_keys[recipe_key] = augment_id
		var triggers := _to_string_array(spec.get("trigger_events", []))
		if triggers.is_empty():
			failures.append("%s visual spec has no trigger_events" % augment_id)
		for trigger in triggers:
			if not EXPECTED_EVENT_SIGNALS.has(trigger) and trigger not in ["augment_acquired", "augment_effect_triggered", "level_up_requested", "upgrade_selected"]:
				failures.append("%s visual spec uses unsupported trigger_event %s" % [augment_id, trigger])
		_validate_category_keywords(augment_id, spec, failures)
	_validate_required_category_groups(seen_categories, failures)
	if seen_recipe_keys.size() < all_augments.size():
		failures.append("Visual recipe keys are not sufficiently distinct: %d recipes for %d augments" % [seen_recipe_keys.size(), all_augments.size()])

func _validate_required_category_groups(seen_categories: Dictionary, failures: Array[String]) -> void:
	for group in REQUIRED_CATEGORY_GROUPS:
		var represented := false
		for category in group:
			if seen_categories.has(str(category)):
				represented = true
				break
		if not represented:
			failures.append("Augment visual specs missing required category group: %s" % str(group))

func _validate_category_keywords(augment_id: String, spec: Dictionary, failures: Array[String]) -> void:
	var category := str(spec.get("category", ""))
	if not CATEGORY_KEYWORDS.has(category):
		return
	var haystack := "%s %s %s %s %s %s" % [
		str(spec.get("effect_family", "")),
		category,
		str(spec.get("shape", "")),
		str(spec.get("motion", "")),
		str(spec.get("particle_style", "")),
		str(spec.get("visual_signature", "")),
	]
	var matched := false
	for keyword in CATEGORY_KEYWORDS[category]:
		if haystack.contains(str(keyword)):
			matched = true
			break
	if not matched:
		failures.append("%s category %s lacks category-appropriate visual keywords: %s" % [augment_id, category, haystack])

func _validate_run_scene_contract(run_scene: Node, failures: Array[String]) -> void:
	var vfx_root := run_scene.get_node_or_null("World/VFXRoot2D")
	if vfx_root == null:
		failures.append("RunScene missing World/VFXRoot2D")
	elif not vfx_root is Node2D:
		failures.append("RunScene World/VFXRoot2D must be Node2D")
	var director := run_scene.get_node_or_null("World/Feedback/AugmentFeedbackDirector")
	if director == null:
		failures.append("RunScene missing World/Feedback/AugmentFeedbackDirector")
	elif director.get_script() == null or str(director.get_script().resource_path) != FEEDBACK_DIRECTOR_PATH:
		failures.append("AugmentFeedbackDirector node uses wrong script")
	else:
		if str(director.get("vfx_root_path")) != "World/VFXRoot2D" and str(director.get("vfx_root_path")) != "../../VFXRoot2D":
			failures.append("AugmentFeedbackDirector must target VFXRoot2D, got %s" % str(director.get("vfx_root_path")))

func _validate_spawn_contract(run_scene: Node, game_events: Node, augment_registry: Node, visual_registry: Node, failures: Array[String]) -> void:
	var vfx_root := run_scene.get_node_or_null("World/VFXRoot2D")
	var hud := run_scene.get_node_or_null("CanvasLayer/HUD")
	if vfx_root == null:
		return
	var before_spawn_index := _max_spawn_index(run_scene)
	var owner := run_scene.get_node_or_null("World/Player")
	var target := run_scene.get_node_or_null("World/Player")
	for augment in augment_registry.call("get_all"):
		var augment_id := str(augment.get("id"))
		var spec: Dictionary = visual_registry.call("get_spec", augment_id)
		var event_name := _first_trigger_event(spec)
		var payload := {
			"augment_id": augment_id,
			"effect_family": str(spec.get("effect_family", "")),
			"signal_name": event_name,
			"trigger_id": event_name,
			"world_position": Vector2(32.0, 48.0),
		}
		game_events.emit_signal("augment_effect_triggered", payload)
		await process_frame
		var node := _find_vfx_after(vfx_root, hud, before_spawn_index, augment_id, event_name)
		if node == null:
			failures.append("%s did not spawn augment_vfx for augment_effect_triggered" % augment_id)
		else:
			_validate_vfx_node(node, augment_id, str(spec.get("visual_signature", "")), event_name, failures)
		before_spawn_index = _max_spawn_index(run_scene)
		game_events.emit_signal("augment_acquired", augment_id, augment, owner, {})
		await process_frame
		node = _find_vfx_after(vfx_root, hud, before_spawn_index, augment_id, "augment_acquired")
		if node == null:
			failures.append("%s did not spawn augment_vfx for augment_acquired" % augment_id)
		else:
			_validate_vfx_node(node, augment_id, str(spec.get("visual_signature", "")), "augment_acquired", failures)
		before_spawn_index = _max_spawn_index(run_scene)
		for trigger in _to_string_array(spec.get("trigger_events", [])):
			if not EXPECTED_EVENT_SIGNALS.has(trigger):
				continue
			var runtime_packet := _runtime_packet(augment_id)
			_emit_runtime_event(game_events, str(trigger), owner, target, runtime_packet)
			await process_frame
			node = _find_vfx_after(vfx_root, hud, before_spawn_index, augment_id, str(trigger))
			if node == null:
				failures.append("%s did not spawn augment_vfx for runtime event %s" % [augment_id, trigger])
			else:
				_validate_vfx_node(node, augment_id, str(spec.get("visual_signature", "")), str(trigger), failures)
			before_spawn_index = _max_spawn_index(run_scene)

func _runtime_packet(augment_id: String) -> Dictionary:
	return {
		"augment_id": augment_id,
		"source_augment_id": augment_id,
		"source_kind": "augment",
		"source_id": augment_id,
		"amount": 1.0,
		"hit_position": Vector2(40.0, 52.0),
		"world_position": Vector2(40.0, 52.0),
	}

func _emit_runtime_event(game_events: Node, event_name: String, owner: Node, target: Node, packet: Dictionary) -> void:
	match event_name:
		"weapon_fired":
			game_events.emit_signal("weapon_fired", owner, null, packet)
		"projectile_spawned":
			game_events.emit_signal("projectile_spawned", owner, packet)
		"projectile_hit":
			game_events.emit_signal("projectile_hit", target, packet)
		"damage_roll_requested":
			game_events.emit_signal("damage_roll_requested", packet)
		"damage_applied_packet":
			game_events.emit_signal("damage_applied_packet", target, packet)
		"dot_tick":
			game_events.emit_signal("dot_tick", target, packet)
		"burn_stack_applied":
			game_events.emit_signal("burn_stack_applied", target, 1, 1, packet)
		"burn_stack_threshold":
			game_events.emit_signal("burn_stack_threshold", target, 3, packet)
		"rift_chain_triggered":
			game_events.emit_signal("rift_chain_triggered", "visual_contract_region", 1, packet)
		"shield_gained":
			game_events.emit_signal("shield_gained", owner, 1.0, packet)
		"shield_broken":
			game_events.emit_signal("shield_broken", owner, 1.0, packet)
		"heal_received":
			game_events.emit_signal("heal_received", owner, 1.0, packet)
		"regen_tick":
			game_events.emit_signal("regen_tick", owner, 1.0, packet)
		"control_applied":
			game_events.emit_signal("control_applied", target, "slow", packet)
		"dash_started":
			game_events.emit_signal("dash_started", owner, packet)
		"dash_finished":
			game_events.emit_signal("dash_finished", owner, packet)
		"blink_used":
			game_events.emit_signal("blink_used", owner, packet)
		"low_hp_entered":
			game_events.emit_signal("low_hp_entered", owner, 0.25, packet)
		"fatal_damage_received":
			game_events.emit_signal("fatal_damage_received", owner, packet)
		"pickup_collected":
			game_events.emit_signal("pickup_collected", target, owner, packet)
		"elite_killed":
			game_events.emit_signal("elite_killed", target, packet)
		"boss_damaged":
			game_events.emit_signal("boss_damaged", target, packet)
		"augment_periodic_tick":
			game_events.emit_signal("augment_periodic_tick", 10.0)
		"enemy_died":
			game_events.emit_signal("enemy_died", target, 1)
		"level_changed":
			game_events.emit_signal("level_changed", 2)
		"wave_phase_started":
			game_events.emit_signal("wave_phase_started", "visual_contract_wave", 2, packet)
		"rune_triggered":
			game_events.emit_signal("rune_triggered", "visual_contract_rune", target, packet)

func _validate_vfx_cleanup(run_scene: Node, failures: Array[String]) -> void:
	await create_timer(1.75, true).timeout
	await process_frame
	await process_frame
	var remaining := _count_all_augment_vfx(run_scene)
	if remaining > 0:
		failures.append("augment_vfx nodes did not clean up after lifetime: %d remaining" % remaining)

func _validate_vfx_node(node: Node, augment_id: String, visual_signature: String, trigger_event: String, failures: Array[String]) -> void:
	if not node.is_in_group("augment_vfx"):
		failures.append("%s spawned node is not in augment_vfx group" % augment_id)
	if str(node.get_meta("augment_id", "")) != augment_id:
		failures.append("%s spawned node missing augment_id meta" % augment_id)
	if str(node.get_meta("visual_signature", "")) != visual_signature:
		failures.append("%s spawned node missing visual_signature meta" % augment_id)
	if str(node.get_meta("trigger_event", "")) != trigger_event:
		failures.append("%s spawned node missing trigger_event meta" % augment_id)

func _first_trigger_event(spec: Dictionary) -> String:
	var triggers := _to_string_array(spec.get("trigger_events", []))
	for trigger in triggers:
		if trigger != "augment_acquired":
			return trigger
	return "augment_effect_triggered"

func _count_augment_vfx(root_node: Node) -> int:
	if root_node == null:
		return 0
	var count := 0
	for node in root_node.get_tree().get_nodes_in_group("augment_vfx"):
		if root_node.is_ancestor_of(node) or root_node == node:
			count += 1
	return count

func _find_vfx_after(vfx_root: Node, hud: Node, previous_spawn_index: int, augment_id: String, trigger_event: String) -> Node:
	var candidates: Array[Node] = []
	for node in root.get_tree().get_nodes_in_group("augment_vfx"):
		if (vfx_root != null and vfx_root.is_ancestor_of(node)) or (hud != null and hud.is_ancestor_of(node)):
			candidates.append(node)
	for node in candidates:
		if int(node.get_meta("spawn_index", -1)) > previous_spawn_index and str(node.get_meta("augment_id", "")) == augment_id and str(node.get_meta("trigger_event", "")) == trigger_event:
			return node
	return null

func _max_spawn_index(run_scene: Node) -> int:
	var result := -1
	if run_scene == null:
		return result
	for node in root.get_tree().get_nodes_in_group("augment_vfx"):
		if run_scene.is_ancestor_of(node):
			result = maxi(result, int(node.get_meta("spawn_index", -1)))
	return result

func _count_all_augment_vfx(run_scene: Node) -> int:
	if run_scene == null:
		return 0
	var count := 0
	for node in root.get_tree().get_nodes_in_group("augment_vfx"):
		if run_scene.is_ancestor_of(node):
			count += 1
	return count

func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is PackedStringArray:
		for item in value:
			result.append(str(item))
	elif value is Array:
		for item in value:
			result.append(str(item))
	elif value is String and str(value) != "":
		for part in str(value).split(",", false):
			result.append(part.strip_edges())
	return result

func _fail(failures: Array[String]) -> void:
	for failure in failures:
		push_error(failure)
	quit(1)
