extends Node

var equipped_runes: Array[Resource] = []
var cooldowns: Dictionary = {}

func equip_rune(rune: Resource) -> void:
	if not is_valid_rune(rune) or equipped_runes.has(rune):
		return
	equipped_runes.append(rune)

func is_valid_rune(rune: Resource) -> bool:
	if rune == null:
		return false
	return (
		typeof(rune.get("id")) != TYPE_NIL
		and typeof(rune.get("trigger")) != TYPE_NIL
		and typeof(rune.get("element_tag")) != TYPE_NIL
		and typeof(rune.get("stack_threshold")) != TYPE_NIL
		and typeof(rune.get("bonus_damage")) != TYPE_NIL
		and typeof(rune.get("applies_to_weapon_tags")) != TYPE_NIL
	)

func reset() -> void:
	equipped_runes.clear()
	cooldowns.clear()

func _ready() -> void:
	if GameEvents.weapon_hit.is_connected(_on_weapon_hit) == false:
		GameEvents.weapon_hit.connect(_on_weapon_hit)

func _process(delta: float) -> void:
	for key in cooldowns.keys():
		cooldowns[key] = max(0.0, float(cooldowns[key]) - delta)

func _on_weapon_hit(target: Node, payload: Dictionary) -> void:
	if target == null or not is_instance_valid(target):
		return
	for rune in equipped_runes:
		if _get_string(rune, "trigger", "") != "on_hit":
			continue
		if not _rune_applies(rune, payload):
			continue
		var rune_id := _get_string(rune, "id", "")
		var element_tag := _get_string(rune, "element_tag", "")
		var cooldown_key := "%s:%s" % [rune_id, target.get_instance_id()]
		if float(cooldowns.get(cooldown_key, 0.0)) > 0.0:
			continue
		cooldowns[cooldown_key] = _get_float(rune, "internal_cooldown", 0.0)
		var stacks := ElementStatusSystem.add_stack(target, element_tag, 1)
		if stacks >= _get_int(rune, "stack_threshold", 1):
			ElementStatusSystem.clear_stack(target, element_tag)
			if target.has_method("apply_damage"):
				var damage_tags: Array[String] = [element_tag, "rune_bonus"]
				var effect_tag := _get_string(rune, "effect", "")
				if effect_tag != "" and effect_tag != "add_element_stack":
					damage_tags.append(effect_tag)
				target.apply_damage(_get_float(rune, "bonus_damage", 0.0), damage_tags)
			GameEvents.rune_triggered.emit(rune_id, target, {
				"element": element_tag,
				"stacks": stacks,
				"route_id": _get_string(rune, "route_id", ""),
				"route_label": _get_string(rune, "route_label", ""),
				"effect": _get_string(rune, "effect", ""),
				"short_effect": _get_string(rune, "short_effect", ""),
				"source_weapon_id": str(payload.get("weapon_id", ""))
			})

func _rune_applies(rune: Resource, payload: Dictionary) -> bool:
	var weapon_tags: Array = payload.get("weapon_tags", [])
	var applies_to_weapon_tags := _get_string_array(rune, "applies_to_weapon_tags")
	for required_tag in applies_to_weapon_tags:
		if weapon_tags.has(required_tag):
			return true
	return applies_to_weapon_tags.is_empty()

func _get_string(resource: Resource, key: String, fallback: String) -> String:
	var value = resource.get(key)
	if typeof(value) == TYPE_NIL:
		return fallback
	return str(value)

func _get_float(resource: Resource, key: String, fallback: float) -> float:
	var value = resource.get(key)
	if typeof(value) == TYPE_NIL:
		return fallback
	return float(value)

func _get_int(resource: Resource, key: String, fallback: int) -> int:
	var value = resource.get(key)
	if typeof(value) == TYPE_NIL:
		return fallback
	return int(value)

func _get_string_array(resource: Resource, key: String) -> Array[String]:
	var result: Array[String] = []
	var value = resource.get(key)
	if value is Array:
		for item in value:
			result.append(str(item))
	return result
