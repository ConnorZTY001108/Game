extends Node

const MAX_PROC_DEPTH := 2

var _proc_chain_serial: int = 0

func make_packet(amount: float, tags: Array[String], payload: Dictionary = {}) -> Dictionary:
	var packet := _default_packet()
	packet["amount"] = amount
	packet["base_amount"] = float(payload.get("base_amount", amount))
	packet["tags"] = _to_string_array(tags)
	for key in payload.keys():
		packet[key] = _duplicate_value(payload[key])
	packet["amount"] = float(packet.get("amount", amount))
	packet["base_amount"] = float(packet.get("base_amount", packet["amount"]))
	packet["tags"] = _to_string_array(packet.get("tags", tags))
	packet["proc_flags"] = _to_string_array(packet.get("proc_flags", []))
	packet["proc_depth"] = max(0, int(packet.get("proc_depth", 0)))
	packet["proc_chain_id"] = _ensure_proc_chain_id(str(packet.get("proc_chain_id", "")))
	packet["weapon_id"] = str(packet.get("weapon_id", payload.get("weapon_id", "")))
	packet["source_id"] = _first_non_empty([
		str(packet.get("source_id", "")),
		str(packet.get("weapon_id", "")),
		str(packet.get("augment_id", ""))
	])
	packet["source_kind"] = _infer_source_kind(packet)
	packet["boss_scalar"] = _normalize_boss_scalar(packet.get("boss_scalar", 1.0))
	packet["on_hit_efficiency"] = max(0.0, float(packet.get("on_hit_efficiency", 1.0)))
	packet["crit_chance"] = max(0.0, float(packet.get("crit_chance", 0.0)))
	packet["crit_multiplier"] = max(0.0, float(packet.get("crit_multiplier", 1.5)))
	return packet

func normalize_packet(target: Node, packet_or_amount: Variant, tags: Array[String] = [], payload: Dictionary = {}) -> Dictionary:
	var packet: Dictionary
	if packet_or_amount is Dictionary:
		packet = (packet_or_amount as Dictionary).duplicate(true)
		for key in payload.keys():
			packet[key] = _duplicate_value(payload[key])
		packet = make_packet(float(packet.get("amount", 0.0)), _to_string_array(packet.get("tags", tags)), packet)
	else:
		if payload.get("damage_packet", null) is Dictionary:
			packet = (payload["damage_packet"] as Dictionary).duplicate(true)
			for key in payload.keys():
				if key != "damage_packet":
					packet[key] = _duplicate_value(payload[key])
			packet["amount"] = float(packet_or_amount)
			packet["tags"] = _to_string_array(tags)
			packet = make_packet(float(packet["amount"]), _to_string_array(packet["tags"]), packet)
		else:
			packet = make_packet(float(packet_or_amount), tags, payload)
	packet["target"] = target
	if not packet.has("target_max_hp_ratio") or typeof(packet["target_max_hp_ratio"]) == TYPE_NIL:
		packet["target_max_hp_ratio"] = 0.0
	return packet

func validate_packet(packet: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in [
		"amount",
		"base_amount",
		"damage_type",
		"tags",
		"source_kind",
		"source_id",
		"augment_id",
		"weapon_id",
		"owner",
		"target",
		"hit_position",
		"target_max_hp_ratio",
		"boss_scalar",
		"can_crit",
		"crit_chance",
		"crit_multiplier",
		"is_crit",
		"on_hit_efficiency",
		"proc_depth",
		"proc_chain_id",
		"proc_flags",
		"parent_event_id",
		"cooldown_source_id"
	]:
		if packet.has(key) == false:
			errors.append("missing:%s" % key)
	if packet.has("tags") and not packet["tags"] is Array:
		errors.append("tags_not_array")
	if packet.has("proc_flags") and not packet["proc_flags"] is Array:
		errors.append("proc_flags_not_array")
	if str(packet.get("proc_chain_id", "")) == "":
		errors.append("empty_proc_chain_id")
	if int(packet.get("proc_depth", 0)) < 0:
		errors.append("negative_proc_depth")
	if float(packet.get("boss_scalar", 1.0)) <= 0.0:
		errors.append("invalid_boss_scalar")
	return errors

func child_proc_packet(parent: Dictionary, effect_family: String, augment_id: String, params: Dictionary = {}) -> Dictionary:
	var child := parent.duplicate(true)
	for key in params.keys():
		if key == "on_hit_efficiency":
			continue
		child[key] = _duplicate_value(params[key])
	child["amount"] = float(params.get("amount", child.get("amount", 0.0)))
	child["base_amount"] = float(params.get("base_amount", child.get("base_amount", child["amount"])))
	child["source_kind"] = str(params.get("source_kind", "augment"))
	child["source_id"] = str(params.get("source_id", effect_family))
	child["augment_id"] = augment_id
	child["proc_chain_id"] = _ensure_proc_chain_id(str(parent.get("proc_chain_id", "")))
	child["proc_depth"] = int(parent.get("proc_depth", 0)) + int(params.get("proc_depth_increment", 1))
	child["proc_flags"] = _append_unique_string(_to_string_array(parent.get("proc_flags", [])), effect_family)
	child["on_hit_efficiency"] = max(0.0, float(parent.get("on_hit_efficiency", 1.0)) * float(params.get("on_hit_efficiency", 1.0)))
	child["boss_scalar"] = _normalize_boss_scalar(child.get("boss_scalar", 1.0))
	return make_packet(float(child.get("amount", 0.0)), _to_string_array(child.get("tags", [])), child)

func can_trigger(effect_family: String, packet: Dictionary, spec: Variant = {}) -> bool:
	var max_depth := _get_spec_int(spec, "max_proc_depth", MAX_PROC_DEPTH)
	if int(packet.get("proc_depth", 0)) >= max_depth:
		return false
	var flags: Array[String] = _to_string_array(packet.get("proc_flags", []))
	var blocks_same_family := _get_spec_bool(spec, "blocks_same_family_recursion", true)
	var blocked_flag := _get_nested_param_string(spec, "block_if_proc_flag_exists", effect_family)
	if blocks_same_family and flags.has(effect_family):
		return false
	if blocked_flag != "" and flags.has(blocked_flag):
		return false
	return true

func apply_damage(target: Node, packet_or_amount: Variant, tags: Array[String] = [], payload: Dictionary = {}) -> Dictionary:
	var packet := normalize_packet(target, packet_or_amount, tags, payload)
	if target == null or not target.has_method("apply_damage"):
		return packet
	_enrich_target_class(target, packet)
	GameEvents.damage_roll_requested.emit(packet)
	var applied_amount: float = max(0.0, float(packet.get("amount", 0.0)))
	var applied_tags: Array[String] = _to_string_array(packet.get("tags", []))
	target.apply_damage(applied_amount, applied_tags)
	packet["amount"] = applied_amount
	packet["tags"] = applied_tags
	GameEvents.damage_applied_packet.emit(target, packet.duplicate(true))
	if str(packet.get("target_class", "")) == "boss":
		GameEvents.boss_damaged.emit(target, packet.duplicate(true))
	if _is_projectile_hit_packet(packet):
		GameEvents.projectile_hit.emit(target, packet.duplicate(true))
	if _should_emit_weapon_hit(packet):
		GameEvents.weapon_hit.emit(target, _legacy_weapon_hit_payload(packet, payload))
	return packet

func _enrich_target_class(target: Node, packet: Dictionary) -> void:
	if packet.has("target_class") and str(packet.get("target_class", "")) != "":
		return
	if target != null and target.has_method("get_enemy_class"):
		packet["target_class"] = str(target.call("get_enemy_class"))
	elif target != null and target.has_method("get"):
		var enemy_data = target.get("enemy_data")
		if enemy_data != null:
			packet["target_class"] = _infer_enemy_class(enemy_data)

func _infer_enemy_class(enemy_data: Resource) -> String:
	var enemy_id := str(enemy_data.get("id")).to_lower()
	if enemy_id.contains("boss"):
		return "boss"
	if enemy_id.contains("elite") or float(enemy_data.get("experience_value")) >= 5.0:
		return "elite"
	if float(enemy_data.get("max_health")) >= 60.0:
		return "large"
	return "normal"

func _default_packet() -> Dictionary:
	return {
		"amount": 0.0,
		"base_amount": 0.0,
		"damage_type": "physical",
		"tags": [],
		"source_kind": "weapon",
		"source_id": "",
		"augment_id": "",
		"weapon_id": "",
		"owner": null,
		"target": null,
		"hit_position": Vector2.ZERO,
		"target_max_hp_ratio": 0.0,
		"boss_scalar": 1.0,
		"can_crit": false,
		"crit_chance": 0.0,
		"crit_multiplier": 1.5,
		"is_crit": false,
		"on_hit_efficiency": 1.0,
		"proc_depth": 0,
		"proc_chain_id": "",
		"proc_flags": [],
		"parent_event_id": "",
		"cooldown_source_id": ""
	}

func _legacy_weapon_hit_payload(packet: Dictionary, original_payload: Dictionary) -> Dictionary:
	var legacy := original_payload.duplicate(true)
	legacy.erase("tags")
	legacy["weapon_id"] = str(packet.get("weapon_id", legacy.get("weapon_id", "")))
	legacy["source_id"] = str(packet.get("source_id", legacy.get("source_id", "")))
	if not legacy.has("weapon_tags"):
		legacy["weapon_tags"] = _to_string_array(packet.get("tags", []))
	if not legacy.has("element_tags"):
		legacy["element_tags"] = []
	legacy["hit_position"] = packet.get("hit_position", Vector2.ZERO)
	legacy["owner"] = packet.get("owner", legacy.get("owner", null))
	legacy["damage_packet"] = packet.duplicate(true)
	return legacy

func _should_emit_weapon_hit(packet: Dictionary) -> bool:
	var source_kind: String = str(packet.get("source_kind", ""))
	return source_kind == "weapon" or source_kind == "projectile"

func _is_projectile_hit_packet(packet: Dictionary) -> bool:
	var tags: Array[String] = _to_string_array(packet.get("tags", []))
	var source_kind: String = str(packet.get("source_kind", ""))
	return tags.has("projectile") or source_kind == "projectile"

func _ensure_proc_chain_id(current_id: String) -> String:
	if current_id != "":
		return current_id
	_proc_chain_serial += 1
	return "proc_%d_%d" % [Time.get_ticks_usec(), _proc_chain_serial]

func _infer_source_kind(packet: Dictionary) -> String:
	var source_kind: String = str(packet.get("source_kind", ""))
	if source_kind != "":
		return source_kind
	if str(packet.get("augment_id", "")) != "":
		return "augment"
	if str(packet.get("weapon_id", "")) != "":
		return "weapon"
	return "weapon"

func _normalize_boss_scalar(value: Variant) -> float:
	return max(0.0, float(value))

func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result

func _append_unique_string(values: Array[String], value: String) -> Array[String]:
	var result := values.duplicate()
	if value != "" and not result.has(value):
		result.append(value)
	return result

func _first_non_empty(values: Array[String]) -> String:
	for value in values:
		if value != "":
			return value
	return ""

func _duplicate_value(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value

func _get_spec_int(spec: Variant, key: String, fallback: int) -> int:
	if spec is Dictionary:
		return int((spec as Dictionary).get(key, fallback))
	if spec is Resource:
		var value: Variant = (spec as Resource).get(key)
		if typeof(value) != TYPE_NIL:
			return int(value)
	return fallback

func _get_spec_bool(spec: Variant, key: String, fallback: bool) -> bool:
	if spec is Dictionary:
		return bool((spec as Dictionary).get(key, fallback))
	if spec is Resource:
		var value: Variant = (spec as Resource).get(key)
		if typeof(value) != TYPE_NIL:
			return bool(value)
	return fallback

func _get_nested_param_string(spec: Variant, key: String, fallback: String = "") -> String:
	var params: Variant = null
	if spec is Dictionary:
		params = (spec as Dictionary).get("params", {})
	elif spec is Resource:
		params = (spec as Resource).get("params")
	if params is Dictionary:
		return str((params as Dictionary).get(key, fallback))
	return fallback
