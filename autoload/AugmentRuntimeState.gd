class_name AugmentRuntimeState
extends RefCounted

var ranks: Dictionary = {}
var owned_ids: Dictionary = {}
var route_counts: Dictionary = {}
var owned_tags: Dictionary = {}
var owners: Dictionary = {}
var cooldowns: Dictionary = {}
var per_target_cooldowns: Dictionary = {}
var once_ledgers: Dictionary = {}
var active_counts: Dictionary = {}
var active_ledgers: Dictionary = {}
var _active_ledger_serial: int = 0
var generated_packets: Array[Dictionary] = []
var effect_counts: Dictionary = {}
var blocked_counts: Dictionary = {}
var stat_modifiers: Dictionary = {}
var choice_state: Dictionary = {}
var quest_progress: Dictionary = {}
var shields: Dictionary = {}
var heals: Dictionary = {}
var controls: Dictionary = {}
var mobility: Dictionary = {}
var cooldown_refunds: Dictionary = {}
var pending_effects: Dictionary = {}
var modes: Dictionary = {}
var counters: Dictionary = {}
var rewards: Dictionary = {}
var safe_states: Dictionary = {}
var runtime_log: Array[Dictionary] = []

func reset() -> void:
	ranks.clear()
	owned_ids.clear()
	route_counts.clear()
	owned_tags.clear()
	owners.clear()
	cooldowns.clear()
	per_target_cooldowns.clear()
	once_ledgers.clear()
	active_counts.clear()
	active_ledgers.clear()
	_active_ledger_serial = 0
	generated_packets.clear()
	effect_counts.clear()
	blocked_counts.clear()
	stat_modifiers.clear()
	choice_state.clear()
	quest_progress.clear()
	shields.clear()
	heals.clear()
	controls.clear()
	mobility.clear()
	cooldown_refunds.clear()
	pending_effects.clear()
	modes.clear()
	counters.clear()
	rewards.clear()
	safe_states.clear()
	runtime_log.clear()

func record_acquired(augment: Resource, owner: Node) -> void:
	var augment_id := _get_string(augment, "id", "")
	if augment_id == "":
		return
	ranks[augment_id] = int(ranks.get(augment_id, 0)) + 1
	owned_ids[augment_id] = true
	owners[augment_id] = owner
	var route_id := _get_string(augment, "route_id", "")
	if route_id != "":
		route_counts[route_id] = int(route_counts.get(route_id, 0)) + 1
	for tag in _augment_tags(augment):
		owned_tags[tag] = true
	record_log("acquire", augment_id, {"rank": ranks[augment_id], "route_id": route_id})

func can_rank(augment: Resource) -> bool:
	var augment_id := _get_string(augment, "id", "")
	if augment_id == "":
		return false
	var rank := int(ranks.get(augment_id, 0))
	var max_rank := int(augment.get("max_rank"))
	if bool(augment.get("unique")) and rank > 0:
		return false
	if max_rank > 0 and rank >= max_rank:
		return false
	return true

func mark_effect(effect_type: String, payload: Dictionary = {}) -> void:
	effect_counts[effect_type] = int(effect_counts.get(effect_type, 0)) + 1
	record_log(effect_type, str(payload.get("augment_id", "")), payload)

func mark_block(reason: String) -> void:
	blocked_counts[reason] = int(blocked_counts.get(reason, 0)) + 1

func is_source_cooldown_ready(key: String, now_seconds: float, cooldown: float) -> bool:
	if cooldown <= 0.0 or key == "":
		return true
	return now_seconds >= float(cooldowns.get(key, -INF))

func start_source_cooldown(key: String, now_seconds: float, cooldown: float) -> void:
	if cooldown > 0.0 and key != "":
		cooldowns[key] = now_seconds + cooldown

func is_per_target_cooldown_ready(key: String, target: Node, now_seconds: float, cooldown: float) -> bool:
	if cooldown <= 0.0 or key == "":
		return true
	var ledger_key := "%s:%s" % [key, _node_key(target)]
	return now_seconds >= float(per_target_cooldowns.get(ledger_key, -INF))

func start_per_target_cooldown(key: String, target: Node, now_seconds: float, cooldown: float) -> void:
	if cooldown > 0.0 and key != "":
		per_target_cooldowns["%s:%s" % [key, _node_key(target)]] = now_seconds + cooldown

func has_once_key(key: String) -> bool:
	return key != "" and once_ledgers.has(key)

func mark_once_key(key: String) -> void:
	if key != "":
		once_ledgers[key] = true

func increment_active(kind: String, augment_id: String, cap: int, ttl_seconds: float = 0.0) -> bool:
	cleanup_active()
	var key := "%s:%s" % [augment_id, kind]
	var current := int(active_counts.get(kind, 0))
	var per_augment_key := "augment:%s:%s" % [augment_id, kind]
	var per_augment_current := int(active_counts.get(per_augment_key, 0))
	if cap > 0 and per_augment_current >= cap:
		mark_block("%s_cap" % kind)
		return false
	active_counts[kind] = current + 1
	active_counts[per_augment_key] = per_augment_current + 1
	active_counts[key] = int(active_counts.get(key, 0)) + 1
	_active_ledger_serial += 1
	var ledger_key := "%s:%s:%d" % [augment_id, kind, _active_ledger_serial]
	active_ledgers[ledger_key] = {
		"kind": kind,
		"augment_id": augment_id,
		"expires_at": _now_seconds() + maxf(0.0, ttl_seconds)
	}
	return true

func cleanup_active(now_seconds: float = -1.0) -> void:
	var resolved_now := now_seconds if now_seconds >= 0.0 else _now_seconds()
	for ledger_key in active_ledgers.keys():
		var entry: Dictionary = active_ledgers.get(ledger_key, {})
		var expires_at := float(entry.get("expires_at", 0.0))
		if expires_at <= resolved_now:
			_release_active_entry(entry)
			active_ledgers.erase(ledger_key)

func release_active(kind: String, augment_id: String, count: int = 1) -> void:
	var released := 0
	for ledger_key in active_ledgers.keys():
		if released >= count:
			return
		var entry: Dictionary = active_ledgers.get(ledger_key, {})
		if str(entry.get("kind", "")) == kind and str(entry.get("augment_id", "")) == augment_id:
			_release_active_entry(entry)
			active_ledgers.erase(ledger_key)
			released += 1

func record_generated_packet(packet: Dictionary) -> void:
	generated_packets.append(packet.duplicate(true))
	if generated_packets.size() > 32:
		generated_packets.pop_front()

func add_stat_modifier(stat: String, value: float, op: String, augment_id: String) -> void:
	var entry: Dictionary = stat_modifiers.get(stat, {"flat": 0.0, "percent": 0.0, "sources": {}})
	if op == "add_percent" or op == "percent":
		entry["percent"] = float(entry.get("percent", 0.0)) + value
	else:
		entry["flat"] = float(entry.get("flat", 0.0)) + value
	var sources: Dictionary = entry.get("sources", {})
	sources[augment_id] = float(sources.get(augment_id, 0.0)) + value
	entry["sources"] = sources
	stat_modifiers[stat] = entry

func add_choice_count(key: String, amount: int) -> void:
	choice_state[key] = int(choice_state.get(key, 0)) + amount

func add_quest_progress(augment_id: String, amount: int, total: int) -> Dictionary:
	var entry: Dictionary = quest_progress.get(augment_id, {"amount": 0, "total": total, "complete": false})
	entry["amount"] = int(entry.get("amount", 0)) + amount
	entry["total"] = total
	if total > 0 and int(entry["amount"]) >= total:
		entry["complete"] = true
	quest_progress[augment_id] = entry
	return entry

func add_cooldown_refund(key: String, amount: float) -> void:
	cooldown_refunds[key] = float(cooldown_refunds.get(key, 0.0)) + amount

func set_pending_effect(key: String, payload: Dictionary) -> void:
	pending_effects[key] = payload.duplicate(true)

func add_mode(key: String, payload: Dictionary) -> void:
	modes[key] = payload.duplicate(true)

func add_counter(key: String, amount: int = 1, total: int = 0) -> Dictionary:
	var entry: Dictionary = counters.get(key, {"amount": 0, "total": total, "complete": false})
	entry["amount"] = int(entry.get("amount", 0)) + amount
	if total > 0:
		entry["total"] = total
		if int(entry["amount"]) >= total:
			entry["complete"] = true
	counters[key] = entry
	return entry

func add_reward(key: String, amount: int = 1) -> void:
	rewards[key] = int(rewards.get(key, 0)) + amount

func add_safe_state(key: String, payload: Dictionary) -> void:
	safe_states[key] = payload.duplicate(true)

func get_snapshot() -> Dictionary:
	return {
		"ranks": ranks.duplicate(true),
		"owned_ids": _dictionary_keys(owned_ids),
		"route_counts": route_counts.duplicate(true),
		"owned_tags": _dictionary_keys(owned_tags),
		"cooldowns": cooldowns.duplicate(true),
		"per_target_cooldowns": per_target_cooldowns.duplicate(true),
		"active_counts": active_counts.duplicate(true),
		"active_ledgers": active_ledgers.duplicate(true),
		"generated_packets": generated_packets.duplicate(true),
		"effect_counts": effect_counts.duplicate(true),
		"blocked_counts": blocked_counts.duplicate(true),
		"stat_modifiers": stat_modifiers.duplicate(true),
		"choice_state": choice_state.duplicate(true),
		"quest_progress": quest_progress.duplicate(true),
		"shields": shields.duplicate(true),
		"heals": heals.duplicate(true),
		"controls": controls.duplicate(true),
		"mobility": mobility.duplicate(true),
		"cooldown_refunds": cooldown_refunds.duplicate(true),
		"pending_effects": pending_effects.duplicate(true),
		"modes": modes.duplicate(true),
		"counters": counters.duplicate(true),
		"rewards": rewards.duplicate(true),
		"safe_states": safe_states.duplicate(true),
		"runtime_log": runtime_log.duplicate(true)
	}

func record_log(event_type: String, augment_id: String, payload: Dictionary = {}) -> void:
	var entry := payload.duplicate(true)
	entry["event_type"] = event_type
	entry["augment_id"] = augment_id
	runtime_log.append(entry)
	if runtime_log.size() > 96:
		runtime_log.pop_front()

func _release_active_entry(entry: Dictionary) -> void:
	var kind := str(entry.get("kind", ""))
	var augment_id := str(entry.get("augment_id", ""))
	if kind == "" or augment_id == "":
		return
	var per_augment_key := "augment:%s:%s" % [augment_id, kind]
	var local_key := "%s:%s" % [augment_id, kind]
	_decrement_active_count(kind)
	_decrement_active_count(per_augment_key)
	_decrement_active_count(local_key)

func _decrement_active_count(key: String) -> void:
	var next_count: int = max(0, int(active_counts.get(key, 0)) - 1)
	if next_count <= 0:
		active_counts.erase(key)
	else:
		active_counts[key] = next_count

func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

func _augment_tags(augment: Resource) -> Array[String]:
	var result: Array[String] = []
	for property in ["synergy_tags", "required_tags", "excludes_tags"]:
		for tag in _to_string_array(augment.get(property)):
			if tag != "" and not result.has(tag):
				result.append(tag)
	var route_id := _get_string(augment, "route_id", "")
	if route_id != "":
		result.append("route:%s" % route_id)
	if bool(augment.get("unique")):
		result.append("unique")
	return result

func _node_key(node: Node) -> String:
	if node == null:
		return "none"
	return "%s:%d" % [node.name, node.get_instance_id()]

func _dictionary_keys(dictionary: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key in dictionary.keys():
		result.append(str(key))
	return result

func _get_string(resource: Resource, key: String, fallback: String) -> String:
	if resource == null:
		return fallback
	var value: Variant = resource.get(key)
	if typeof(value) == TYPE_NIL:
		return fallback
	return str(value)

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
