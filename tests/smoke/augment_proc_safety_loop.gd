extends SceneTree

class DamageTarget:
	extends Node2D

	var total_damage: float = 0.0
	var received_tags: Array[String] = []

	func apply_damage(amount: float, tags: Array[String]) -> void:
		total_damage += amount
		received_tags = tags.duplicate()

class PacketRecorder:
	extends Node

	var weapon_hit_count: int = 0
	var damage_packet_count: int = 0
	var projectile_hit_count: int = 0
	var weapon_payload: Dictionary = {}
	var damage_packet: Dictionary = {}
	var projectile_packet: Dictionary = {}

	func _on_weapon_hit(_target: Node, payload: Dictionary) -> void:
		weapon_hit_count += 1
		weapon_payload = payload.duplicate(true)

	func _on_damage_applied_packet(_target: Node, packet: Dictionary) -> void:
		damage_packet_count += 1
		damage_packet = packet.duplicate(true)

	func _on_projectile_hit(_target: Node, packet: Dictionary) -> void:
		projectile_hit_count += 1
		projectile_packet = packet.duplicate(true)

func _initialize() -> void:
	var damage_system := root.get_node_or_null("DamageSystem")
	var game_events := root.get_node_or_null("GameEvents")
	if damage_system == null or game_events == null:
		push_error("DamageSystem/GameEvents autoloads are required")
		quit(1)
		return

	for method_name in ["make_packet", "normalize_packet", "validate_packet", "child_proc_packet", "can_trigger"]:
		if damage_system.has_method(method_name) == false:
			push_error("DamageSystem is missing %s" % method_name)
			quit(1)
			return

	var target := DamageTarget.new()
	root.add_child(target)

	var recorder := PacketRecorder.new()
	root.add_child(recorder)
	game_events.connect("weapon_hit", recorder._on_weapon_hit)
	game_events.connect("damage_applied_packet", recorder._on_damage_applied_packet)
	game_events.connect("projectile_hit", recorder._on_projectile_hit)

	var tags: Array[String] = ["projectile", "rune"]
	var legacy_payload := {
		"weapon_id": "rune_bolt",
		"weapon_tags": ["projectile", "rune"],
		"element_tags": [],
		"owner": root,
		"hit_position": Vector2(12.0, 8.0),
		"on_hit_efficiency": 0.75
	}
	var normalized: Dictionary = damage_system.call("normalize_packet", target, 7.0, tags, legacy_payload)
	var validation: Array = damage_system.call("validate_packet", normalized)
	if not validation.is_empty():
		push_error("Legacy packet normalization failed: %s" % [validation])
		quit(1)
		return
	if not _assert_packet_core(normalized, 7.0, tags, "rune_bolt"):
		quit(1)
		return
	if str(normalized.get("proc_chain_id", "")) == "":
		push_error("normalize_packet did not create proc_chain_id")
		quit(1)
		return
	if not is_equal_approx(float(normalized.get("on_hit_efficiency", 0.0)), 0.75):
		push_error("normalize_packet did not preserve on_hit_efficiency")
		quit(1)
		return

	damage_system.call("apply_damage", target, 7.0, tags, legacy_payload)
	if not is_equal_approx(target.total_damage, 7.0):
		push_error("Legacy apply_damage wrapper dealt %.2f damage" % target.total_damage)
		quit(1)
		return
	if target.received_tags != tags:
		push_error("Legacy apply_damage wrapper tags were %s" % [target.received_tags])
		quit(1)
		return
	if recorder.weapon_hit_count != 1 or recorder.damage_packet_count != 1 or recorder.projectile_hit_count != 1:
		push_error("Expected weapon_hit, damage_applied_packet, and projectile_hit once; got %d/%d/%d" % [recorder.weapon_hit_count, recorder.damage_packet_count, recorder.projectile_hit_count])
		quit(1)
		return
	if recorder.weapon_payload.has("tags"):
		push_error("Legacy weapon_hit payload exposed packet tags directly")
		quit(1)
		return
	if not recorder.weapon_payload.has("damage_packet"):
		push_error("Legacy weapon_hit payload did not include damage_packet bridge")
		quit(1)
		return
	if not _assert_packet_core(recorder.damage_packet, 7.0, tags, "rune_bolt"):
		quit(1)
		return
	if not _assert_packet_core(recorder.projectile_packet, 7.0, tags, "rune_bolt"):
		quit(1)
		return

	var child: Dictionary = damage_system.call("child_proc_packet", recorder.damage_packet, "split_projectile", "aug_typhoon_split", {
		"amount": 3.5,
		"source_kind": "augment",
		"on_hit_efficiency": 0.5
	})
	validation = damage_system.call("validate_packet", child)
	if not validation.is_empty():
		push_error("Child proc packet validation failed: %s" % [validation])
		quit(1)
		return
	if child.get("proc_chain_id", "") != recorder.damage_packet.get("proc_chain_id", ""):
		push_error("child_proc_packet did not inherit proc_chain_id")
		quit(1)
		return
	if int(child.get("proc_depth", -1)) != 1:
		push_error("child_proc_packet proc_depth was %s" % child.get("proc_depth", null))
		quit(1)
		return
	if not (child.get("proc_flags", []) as Array).has("split_projectile"):
		push_error("child_proc_packet did not append effect family flag")
		quit(1)
		return
	if str(child.get("augment_id", "")) != "aug_typhoon_split" or str(child.get("source_kind", "")) != "augment":
		push_error("child_proc_packet source fields were wrong: %s" % [child])
		quit(1)
		return
	if not is_equal_approx(float(child.get("on_hit_efficiency", 0.0)), 0.375):
		push_error("child_proc_packet efficiency was %.3f" % float(child.get("on_hit_efficiency", 0.0)))
		quit(1)
		return

	var spec := {"max_proc_depth": 2, "blocks_same_family_recursion": true}
	if damage_system.call("can_trigger", "split_projectile", recorder.damage_packet, spec) == false:
		push_error("can_trigger blocked first split_projectile trigger")
		quit(1)
		return
	if damage_system.call("can_trigger", "split_projectile", child, spec):
		push_error("can_trigger allowed same-family recursion in one proc chain")
		quit(1)
		return

	var too_deep := child.duplicate(true)
	too_deep["proc_depth"] = 3
	if damage_system.call("can_trigger", "chain_lightning", too_deep, spec):
		push_error("can_trigger allowed proc depth above spec max")
		quit(1)
		return

	var depth_two := child.duplicate(true)
	depth_two["proc_depth"] = 2
	if damage_system.call("can_trigger", "chain_lightning", depth_two, spec):
		push_error("can_trigger allowed generated proc packet at max proc depth")
		quit(1)
		return

	target.free()
	recorder.free()
	print("PASS: augment proc safety and DamagePacket normalization")
	quit(0)

func _assert_packet_core(packet: Dictionary, amount: float, tags: Array[String], weapon_id: String) -> bool:
	if not is_equal_approx(float(packet.get("amount", 0.0)), amount):
		push_error("packet amount was %.2f" % float(packet.get("amount", 0.0)))
		return false
	if not _arrays_equal(packet.get("tags", []), tags):
		push_error("packet tags were %s" % [packet.get("tags", [])])
		return false
	if str(packet.get("weapon_id", "")) != weapon_id or str(packet.get("source_id", "")) != weapon_id:
		push_error("packet weapon/source id fields were %s/%s" % [packet.get("weapon_id", ""), packet.get("source_id", "")])
		return false
	if int(packet.get("proc_depth", -1)) != 0:
		push_error("packet proc_depth was %s" % packet.get("proc_depth", null))
		return false
	if not is_equal_approx(float(packet.get("boss_scalar", 0.0)), 1.0):
		push_error("packet boss_scalar was %.2f" % float(packet.get("boss_scalar", 0.0)))
		return false
	return true

func _arrays_equal(left, right: Array) -> bool:
	if not left is Array:
		return false
	if left.size() != right.size():
		return false
	for index in right.size():
		if str(left[index]) != str(right[index]):
			return false
	return true
