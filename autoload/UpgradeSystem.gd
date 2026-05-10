extends Node

const UpgradeDataScript := preload("res://data/resources/upgrade_data.gd")
const AugmentDataScript := preload("res://data/resources/augment_data.gd")
const PlayerScript := preload("res://scripts/player/Player.gd")

const MAX_OPTIONS_PER_LEVEL := 3
const DEFAULT_AUGMENT_TAGS: Array[String] = ["weapon:projectile", "damage_build", "early_game"]
const OPTIONS: Array[Resource] = [
	preload("res://data/content/upgrades/damage_focus.tres"),
	preload("res://data/content/upgrades/cooldown_focus.tres"),
	preload("res://data/content/upgrades/scorch_mark_pick.tres"),
	preload("res://data/content/upgrades/pickup_focus.tres"),
	preload("res://data/content/upgrades/weapon_sigil_orbit_pick.tres"),
	preload("res://data/content/upgrades/storm_orbit_pick.tres")
]

var _next_option_start: int = 0
var _applied_unique_ids: Dictionary = {}
var _applied_ranks: Dictionary = {}
var _augment_offer_index: int = 0
var _augment_ranks: Dictionary = {}
var _augment_route_counts: Dictionary = {}
var _augment_route_starters: Dictionary = {}
var _augment_route_supports: Dictionary = {}
var _augment_owned_tags: Dictionary = {}
var _augment_owned_ids: Dictionary = {}
var _prismatic_seen_in_offers: bool = false
var _recent_dominated_routes: Array[String] = []
var _active_choice_ids: Array[String] = []
var _pending_next_choice_refresh_per_slot: int = 0
var _last_consumed_next_choice_refresh_per_slot: int = 0

func _ready() -> void:
	if GameEvents.run_started.is_connected(reset) == false:
		GameEvents.run_started.connect(reset)

func reset() -> void:
	if is_instance_valid(AugmentSystem):
		AugmentSystem.reset()
	_next_option_start = 0
	_applied_unique_ids.clear()
	_applied_ranks.clear()
	_augment_offer_index = 0
	_augment_ranks.clear()
	_augment_route_counts.clear()
	_augment_route_starters.clear()
	_augment_route_supports.clear()
	_augment_owned_tags.clear()
	_augment_owned_ids.clear()
	_prismatic_seen_in_offers = false
	_recent_dominated_routes.clear()
	_active_choice_ids.clear()
	_pending_next_choice_refresh_per_slot = 0
	_last_consumed_next_choice_refresh_per_slot = 0

func generate_options() -> Array[Resource]:
	var candidates := _available_options()
	var option_count: int = min(MAX_OPTIONS_PER_LEVEL, candidates.size())
	if candidates.size() <= MAX_OPTIONS_PER_LEVEL:
		return candidates.duplicate()
	var generated: Array[Resource] = []
	var ordered: Array[Resource] = []
	for offset in range(candidates.size()):
		var option_index := (_next_option_start + offset) % candidates.size()
		ordered.append(candidates[option_index])
	var used_routes := {}
	for option in ordered:
		var route_id := _get_string(option, "route_id", "general")
		if route_id == "":
			route_id = "general"
		if used_routes.has(route_id):
			continue
		generated.append(option)
		used_routes[route_id] = true
		if generated.size() >= option_count:
			break
	for option in ordered:
		if generated.size() >= option_count:
			break
		if generated.has(option):
			continue
		generated.append(option)
	_next_option_start = (_next_option_start + 1) % OPTIONS.size()
	return generated

func generate_level_up_options(context: Dictionary = {}) -> Array[Resource]:
	var options := generate_augment_options(context)
	if options.size() == MAX_OPTIONS_PER_LEVEL:
		return options
	return generate_options()

func generate_augment_options(context: Dictionary = {}) -> Array[Resource]:
	_ensure_augment_registry_loaded()
	var option_count: int = clampi(int(context.get("option_count", MAX_OPTIONS_PER_LEVEL)), 1, MAX_OPTIONS_PER_LEVEL)
	var roll_context := _build_augment_context(context)
	_consume_next_choice_state(roll_context)
	var candidates := _available_augments(roll_context)
	var selected := _roll_weighted_augments(candidates, option_count, roll_context)
	_enforce_augment_roll_rules(selected, candidates, option_count, roll_context)
	_record_augment_offer(selected)
	_active_choice_ids = _resource_ids(selected)
	if not context.has("upgrade_index"):
		_augment_offer_index += 1
	return selected

func apply_upgrade(upgrade: Resource, player: Node) -> bool:
	var upgrade_data := upgrade as UpgradeDataScript
	if upgrade_data == null and (upgrade is AugmentDataScript):
		return apply_augment(upgrade, player)
	var player_node := player as PlayerScript
	if upgrade_data == null or player_node == null:
		return false
	if not _is_upgrade_available(upgrade_data):
		return false
	if upgrade_data.upgrade_type == "weapon_stat" or upgrade_data.upgrade_type == "player_stat":
		player_node.apply_upgrade_stat(upgrade_data.stat_key, upgrade_data.value)
	elif upgrade_data.upgrade_type == "rune" and upgrade_data.rune != null:
		if not RuneSystem.is_valid_rune(upgrade_data.rune):
			return false
		RuneSystem.equip_rune(upgrade_data.rune)
	elif upgrade_data.upgrade_type == "weapon_pick" and upgrade_data.weapon != null:
		if not player_node.add_weapon(upgrade_data.weapon):
			return false
	else:
		return false
	_mark_applied(upgrade_data)
	_active_choice_ids.clear()
	GameEvents.upgrade_selected.emit(upgrade_data)
	ExperienceSystem.complete_level_up_selection()
	return true

func apply_choice(choice: Resource, player: Node) -> bool:
	if choice is AugmentDataScript:
		return apply_augment(choice, player)
	return apply_upgrade(choice, player)

func apply_augment(augment: Resource, player: Node) -> bool:
	if not (augment is AugmentDataScript):
		return false
	if player == null:
		return false
	var context := _build_augment_context({})
	if not _is_runtime_valid_augment(augment):
		return false
	if not _is_augment_available(augment, context):
		return false
	if not AugmentSystem.acquire_augment(augment, player):
		return false
	_mark_augment_applied(augment)
	GameEvents.upgrade_selected.emit(augment)
	ExperienceSystem.complete_level_up_selection()
	return true

func get_augment_candidate_weight(augment: Resource, context: Dictionary = {}) -> float:
	if not (augment is AugmentDataScript):
		return 0.0
	return _augment_weight(augment, _build_augment_context(context))

func get_owned_augment_rank(augment_id: String) -> int:
	if is_instance_valid(AugmentSystem):
		return max(int(_augment_ranks.get(augment_id, 0)), int(AugmentSystem.get_owned_augment_rank(augment_id)))
	return int(_augment_ranks.get(augment_id, 0))

func is_augment_available_for_selection(augment: Resource, context: Dictionary = {}) -> bool:
	if not _is_runtime_valid_augment(augment):
		return false
	return _is_augment_available(augment, _build_augment_context(context))

func set_next_choice_refresh_per_slot(refresh_per_slot: int) -> void:
	_pending_next_choice_refresh_per_slot = max(0, refresh_per_slot)

func get_pending_next_choice_refresh_per_slot() -> int:
	return _pending_next_choice_refresh_per_slot

func get_last_consumed_next_choice_refresh_per_slot() -> int:
	return _last_consumed_next_choice_refresh_per_slot

func get_active_choice_ids() -> Array[String]:
	return _active_choice_ids.duplicate()

func _available_options() -> Array[Resource]:
	var result: Array[Resource] = []
	for option in OPTIONS:
		var upgrade_data := option as UpgradeDataScript
		if upgrade_data == null:
			continue
		if _is_upgrade_available(upgrade_data):
			result.append(option)
	return result

func _is_upgrade_available(upgrade_data: UpgradeDataScript) -> bool:
	var upgrade_id := _upgrade_id(upgrade_data)
	if upgrade_id == "":
		return false
	if bool(upgrade_data.get("unique")) and _applied_unique_ids.has(upgrade_id):
		return false
	var max_rank := int(upgrade_data.get("max_rank"))
	if max_rank > 0 and int(_applied_ranks.get(upgrade_id, 0)) >= max_rank:
		return false
	if upgrade_data.upgrade_type == "rune" and upgrade_data.rune != null:
		for rune in RuneSystem.equipped_runes:
			if str(rune.get("id")) == str(upgrade_data.rune.get("id")):
				return false
	return true

func _mark_applied(upgrade_data: UpgradeDataScript) -> void:
	var upgrade_id := _upgrade_id(upgrade_data)
	if upgrade_id == "":
		return
	_applied_ranks[upgrade_id] = int(_applied_ranks.get(upgrade_id, 0)) + 1
	if bool(upgrade_data.get("unique")):
		_applied_unique_ids[upgrade_id] = true

func _upgrade_id(upgrade_data: UpgradeDataScript) -> String:
	return _get_string(upgrade_data, "id", "")

func _get_string(resource: Resource, key: String, fallback: String) -> String:
	if resource == null:
		return fallback
	var value = resource.get(key)
	if typeof(value) == TYPE_NIL:
		return fallback
	return str(value)

func _ensure_augment_registry_loaded() -> void:
	if not is_instance_valid(AugmentRegistry):
		return
	if (AugmentRegistry.get_all() as Array).is_empty():
		AugmentRegistry.reload()

func _build_augment_context(context: Dictionary) -> Dictionary:
	var result := context.duplicate(true)
	var upgrade_index := int(result.get("upgrade_index", _augment_offer_index + 1))
	result["upgrade_index"] = max(1, upgrade_index)
	result["owned_ids"] = _string_keys(_augment_owned_ids)
	result["owned_tags"] = _merge_string_arrays([
		DEFAULT_AUGMENT_TAGS if bool(result.get("include_default_tags", true)) else [],
		_dictionary_keys_as_strings(_augment_owned_tags),
		_to_string_array(result.get("available_tags", [])),
		_to_string_array(result.get("owned_tags", []))
	])
	result["blocked_tags"] = _merge_string_arrays([
		_dictionary_keys_as_strings(_augment_owned_tags),
		_to_string_array(result.get("blocked_tags", []))
	])
	if not result.has("recent_dominated_routes"):
		result["recent_dominated_routes"] = _recent_dominated_routes.duplicate()
	return result

func _available_augments(context: Dictionary) -> Array[Resource]:
	var result: Array[Resource] = []
	for candidate in AugmentRegistry.get_all():
		var augment := candidate as Resource
		if not _is_runtime_valid_augment(augment):
			continue
		if _is_augment_available(augment, context):
			result.append(augment)
	return result

func _is_augment_available(augment: Resource, context: Dictionary) -> bool:
	if not (augment is AugmentDataScript):
		return false
	if not _is_runtime_valid_augment(augment):
		return false
	var augment_id := _get_string(augment, "id", "")
	if augment_id == "":
		return false
	var rank := int(_augment_ranks.get(augment_id, 0))
	var max_rank := int(augment.get("max_rank"))
	if bool(augment.get("unique")) and rank > 0:
		return false
	if max_rank > 0 and rank >= max_rank:
		return false
	var upgrade_index := int(context.get("upgrade_index", 1))
	var min_index := int(augment.get("min_upgrade_index"))
	var max_index := int(augment.get("max_upgrade_index"))
	if upgrade_index < min_index:
		return false
	if max_index >= 0 and upgrade_index > max_index:
		return false
	var owned_ids := _to_string_array(context.get("owned_ids", []))
	if owned_ids.has(augment_id) and bool(augment.get("unique")):
		return false
	if _intersects(_to_string_array(augment.get("excludes_ids")), owned_ids):
		return false
	var owned_tags := _to_string_array(context.get("owned_tags", []))
	var blocked_tags := _to_string_array(context.get("blocked_tags", []))
	if _intersects(_to_string_array(augment.get("excludes_tags")), owned_tags + blocked_tags):
		return false
	for tag in _to_string_array(augment.get("required_tags")):
		if _is_hard_required_tag(tag) and not owned_tags.has(tag):
			return false
	return true

func _is_runtime_valid_augment(augment: Resource) -> bool:
	if not (augment is AugmentDataScript):
		return false
	if not is_instance_valid(AugmentSystem):
		return false
	return bool(AugmentSystem.call("is_augment_runtime_valid", augment))

func _roll_weighted_augments(candidates: Array[Resource], option_count: int, context: Dictionary) -> Array[Resource]:
	var selected: Array[Resource] = []
	var rng := RandomNumberGenerator.new()
	if context.has("rng_seed"):
		rng.seed = int(context.get("rng_seed", 0))
	else:
		rng.randomize()
	while selected.size() < option_count:
		var next := _pick_weighted_candidate(candidates, selected, context, rng, "")
		if next == null:
			break
		selected.append(next)
	return selected

func _pick_weighted_candidate(candidates: Array[Resource], selected: Array[Resource], context: Dictionary, rng: RandomNumberGenerator, required_rarity: String) -> Resource:
	var weighted: Array[Dictionary] = []
	var total_weight := 0.0
	var high_risk_selected := _count_high_risk(selected)
	for candidate in candidates:
		if selected.has(candidate):
			continue
		if required_rarity != "" and _normalized_rarity(candidate) != required_rarity:
			continue
		if high_risk_selected > 0 and _is_high_risk(candidate):
			continue
		var weight := _augment_weight(candidate, context)
		if weight <= 0.0:
			continue
		total_weight += weight
		weighted.append({"resource": candidate, "cumulative": total_weight})
	if weighted.is_empty():
		return null
	var roll := rng.randf() * total_weight
	for entry in weighted:
		if roll <= float(entry["cumulative"]):
			return entry["resource"] as Resource
	return weighted[weighted.size() - 1]["resource"] as Resource

func _augment_weight(augment: Resource, context: Dictionary) -> float:
	if not (augment is AugmentDataScript):
		return 0.0
	var weight: float = maxf(0.0, float(augment.get("weight")))
	var rarity_weights: Dictionary = _rarity_weights(int(context.get("upgrade_index", 1)))
	weight *= float(rarity_weights.get(_normalized_rarity(augment), 0.0))
	weight *= _route_weight_multiplier(augment)
	weight *= _route_stage_multiplier(augment)
	if _is_finisher(augment) and int(_augment_route_starters.get(_get_string(augment, "route_id", ""), 0)) <= 0:
		weight *= 0.20
	if _is_high_risk(augment) and int(context.get("upgrade_index", 1)) < 4:
		weight *= 0.35
	weight *= _required_tag_multiplier(augment, context)
	return weight

func _rarity_weights(upgrade_index: int) -> Dictionary:
	if upgrade_index <= 2:
		return {"silver": 70.0, "gold": 27.0, "prismatic": 3.0}
	if upgrade_index <= 5:
		return {"silver": 55.0, "gold": 35.0, "prismatic": 10.0}
	if upgrade_index <= 8:
		return {"silver": 42.0, "gold": 40.0, "prismatic": 18.0}
	return {"silver": 32.0, "gold": 42.0, "prismatic": 26.0}

func _route_weight_multiplier(augment: Resource) -> float:
	var route_count := int(_augment_route_counts.get(_get_string(augment, "route_id", ""), 0))
	if route_count >= 3:
		return 2.0
	if route_count == 2:
		return 1.70
	if route_count == 1:
		return 1.35
	return 1.0

func _route_stage_multiplier(augment: Resource) -> float:
	var route_id := _get_string(augment, "route_id", "")
	if _is_finisher(augment) and int(_augment_route_starters.get(route_id, 0)) > 0 and int(_augment_route_supports.get(route_id, 0)) > 0:
		return 1.40
	if not _is_starter(augment) and not _is_finisher(augment) and int(_augment_route_starters.get(route_id, 0)) > 0:
		return 1.25
	return 1.0

func _required_tag_multiplier(augment: Resource, context: Dictionary) -> float:
	var owned_tags := _to_string_array(context.get("owned_tags", []))
	var multiplier := 1.0
	for tag in _to_string_array(augment.get("required_tags")):
		if tag != "" and not owned_tags.has(tag) and not _is_hard_required_tag(tag):
			multiplier *= 0.45
	return multiplier

func _enforce_augment_roll_rules(selected: Array[Resource], candidates: Array[Resource], option_count: int, context: Dictionary) -> void:
	if selected.is_empty():
		return
	_force_prismatic_if_required(selected, candidates, context)
	_force_starter_if_required(selected, candidates, context)
	_force_off_route_if_required(selected, candidates, context)
	_fill_missing_options(selected, candidates, option_count, context)

func _force_prismatic_if_required(selected: Array[Resource], candidates: Array[Resource], context: Dictionary) -> void:
	if _prismatic_seen_in_offers or int(context.get("upgrade_index", 1)) < 10:
		return
	if _has_rarity(selected, "prismatic"):
		return
	var replacement := _best_candidate(candidates, selected, context, "prismatic", false, "")
	if replacement != null:
		_replace_lowest_priority(selected, replacement, context)

func _force_starter_if_required(selected: Array[Resource], candidates: Array[Resource], context: Dictionary) -> void:
	var upgrade_index := int(context.get("upgrade_index", 1))
	var needs_starter := upgrade_index <= 2 or (upgrade_index >= 3 and not _has_owned_starter())
	if not needs_starter or _has_starter(selected):
		return
	var replacement := _best_candidate(candidates, selected, context, "", true, "")
	if replacement != null:
		_replace_lowest_priority(selected, replacement, context)

func _force_off_route_if_required(selected: Array[Resource], candidates: Array[Resource], context: Dictionary) -> void:
	var recent := _to_string_array(context.get("recent_dominated_routes", []))
	if recent.size() < 2 or recent[recent.size() - 1] != recent[recent.size() - 2]:
		return
	var blocked_route := recent[recent.size() - 1]
	if _has_off_route_or_stabilizer(selected, blocked_route):
		return
	var replacement := _best_candidate(candidates, selected, context, "", false, blocked_route)
	if replacement != null:
		_replace_lowest_priority(selected, replacement, context)

func _fill_missing_options(selected: Array[Resource], candidates: Array[Resource], option_count: int, context: Dictionary) -> void:
	while selected.size() < option_count:
		var replacement := _best_candidate(candidates, selected, context, "", false, "")
		if replacement == null:
			break
		if _is_high_risk(replacement) and _count_high_risk(selected) > 0:
			break
		selected.append(replacement)

func _best_candidate(candidates: Array[Resource], selected: Array[Resource], context: Dictionary, required_rarity: String, require_starter: bool, blocked_route: String) -> Resource:
	var best: Resource = null
	var best_weight := -1.0
	for candidate in candidates:
		if selected.has(candidate):
			continue
		if required_rarity != "" and _normalized_rarity(candidate) != required_rarity:
			continue
		if require_starter and not _is_starter(candidate):
			continue
		if blocked_route != "" and not _is_off_route_or_stabilizer(candidate, blocked_route):
			continue
		if _is_high_risk(candidate) and _count_high_risk(selected) > 0:
			continue
		var weight := _augment_weight(candidate, context)
		if weight > best_weight:
			best = candidate
			best_weight = weight
	return best

func _replace_lowest_priority(selected: Array[Resource], replacement: Resource, context: Dictionary) -> void:
	if replacement == null or selected.has(replacement):
		return
	var replace_index := 0
	var lowest_weight := INF
	for index in range(selected.size()):
		var candidate := selected[index]
		if _is_starter(candidate) and not _is_starter(replacement):
			continue
		var weight := _augment_weight(candidate, context)
		if weight < lowest_weight:
			lowest_weight = weight
			replace_index = index
	selected[replace_index] = replacement

func _record_augment_offer(selected: Array[Resource]) -> void:
	for augment in selected:
		if _normalized_rarity(augment) == "prismatic":
			_prismatic_seen_in_offers = true
	var dominated_route := _dominated_route(selected)
	if dominated_route != "":
		_recent_dominated_routes.append(dominated_route)
		if _recent_dominated_routes.size() > 2:
			_recent_dominated_routes.pop_front()
	elif not _recent_dominated_routes.is_empty():
		_recent_dominated_routes.clear()

func _mark_augment_applied(augment: Resource) -> void:
	var augment_id := _get_string(augment, "id", "")
	if augment_id == "":
		return
	_augment_ranks[augment_id] = int(_augment_ranks.get(augment_id, 0)) + 1
	_augment_owned_ids[augment_id] = true
	var route_id := _get_string(augment, "route_id", "")
	_augment_route_counts[route_id] = int(_augment_route_counts.get(route_id, 0)) + 1
	if _is_starter(augment):
		_augment_route_starters[route_id] = int(_augment_route_starters.get(route_id, 0)) + 1
	elif not _is_finisher(augment):
		_augment_route_supports[route_id] = int(_augment_route_supports.get(route_id, 0)) + 1
	for tag in _augment_tags_for_state(augment):
		_augment_owned_tags[tag] = true
	_active_choice_ids.clear()

func _consume_next_choice_state(roll_context: Dictionary) -> void:
	_last_consumed_next_choice_refresh_per_slot = _pending_next_choice_refresh_per_slot
	roll_context["refresh_per_slot"] = _last_consumed_next_choice_refresh_per_slot
	_pending_next_choice_refresh_per_slot = 0

func _augment_tags_for_state(augment: Resource) -> Array[String]:
	var tags := _merge_string_arrays([
		_to_string_array(augment.get("synergy_tags")),
		_to_string_array(augment.get("required_tags")),
		_to_string_array(augment.get("excludes_tags"))
	])
	if bool(augment.get("unique")):
		tags.append("unique")
	if _is_starter(augment):
		tags.append("starter")
	if _is_finisher(augment):
		tags.append("finisher")
	if _is_high_risk(augment):
		tags.append("high_risk")
	var route_id := _get_string(augment, "route_id", "")
	if route_id != "":
		tags.append("route:%s" % route_id)
	return _merge_string_arrays([tags])

func _normalized_rarity(augment: Resource) -> String:
	var rarity := _get_string(augment, "rarity", "silver").to_lower()
	if rarity == "閲戣壊":
		return "gold"
	if rarity == "妫卞僵":
		return "prismatic"
	if rarity == "閾惰壊":
		return "silver"
	return rarity

func _is_starter(augment: Resource) -> bool:
	return _manifest_bool(augment, "is_starter")

func _is_finisher(augment: Resource) -> bool:
	return _manifest_bool(augment, "is_finisher")

func _is_high_risk(augment: Resource) -> bool:
	return _manifest_bool(augment, "is_high_risk")

func _manifest_bool(resource: Resource, key: String) -> bool:
	var manifest = resource.get("manifest_fields")
	if manifest is Dictionary and (manifest as Dictionary).has(key):
		return bool((manifest as Dictionary).get(key))
	return false

func _has_owned_starter() -> bool:
	for route_id in _augment_route_starters.keys():
		if int(_augment_route_starters[route_id]) > 0:
			return true
	return false

func _has_starter(options: Array[Resource]) -> bool:
	for option in options:
		if _is_starter(option):
			return true
	return false

func _has_rarity(options: Array[Resource], rarity: String) -> bool:
	for option in options:
		if _normalized_rarity(option) == rarity:
			return true
	return false

func _count_high_risk(options: Array[Resource]) -> int:
	var count := 0
	for option in options:
		if _is_high_risk(option):
			count += 1
	return count

func _dominated_route(options: Array[Resource]) -> String:
	var counts := {}
	for option in options:
		var route_id := _get_string(option, "route_id", "")
		counts[route_id] = int(counts.get(route_id, 0)) + 1
	for route_id in counts.keys():
		if int(counts[route_id]) >= 2:
			return str(route_id)
	return ""

func _has_off_route_or_stabilizer(options: Array[Resource], blocked_route: String) -> bool:
	for option in options:
		if _is_off_route_or_stabilizer(option, blocked_route):
			return true
	return false

func _is_off_route_or_stabilizer(augment: Resource, blocked_route: String) -> bool:
	if _get_string(augment, "route_id", "") != blocked_route:
		return true
	var tags := _to_string_array(augment.get("synergy_tags"))
	var upgrade_type := _get_string(augment, "upgrade_type", "")
	return tags.has("economy") or tags.has("survival") or upgrade_type.contains("鐢熷瓨") or upgrade_type.contains("缁忔祹")

func _is_hard_required_tag(tag: String) -> bool:
	return tag.begins_with("weapon:")

func _intersects(left: Array[String], right: Array[String]) -> bool:
	for item in left:
		if item != "" and right.has(item):
			return true
	return false

func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is PackedStringArray:
		for item in value:
			result.append(str(item))
	elif value is Array:
		for item in value:
			result.append(str(item))
	elif value is Dictionary:
		for item in (value as Dictionary).keys():
			result.append(str(item))
	elif value is String and str(value) != "":
		for part in str(value).split(",", false):
			result.append(part.strip_edges())
	return result

func _merge_string_arrays(groups: Array) -> Array[String]:
	var result: Array[String] = []
	for group in groups:
		for item in _to_string_array(group):
			if item != "" and not result.has(item):
				result.append(item)
	return result

func _string_keys(dictionary: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key in dictionary.keys():
		result.append(str(key))
	return result

func _dictionary_keys_as_strings(dictionary: Dictionary) -> Array[String]:
	return _string_keys(dictionary)

func _resource_ids(resources: Array[Resource]) -> Array[String]:
	var result: Array[String] = []
	for resource in resources:
		var resource_id := _get_string(resource, "id", "")
		if resource_id != "":
			result.append(resource_id)
	return result
