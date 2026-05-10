extends Node

const UpgradeDataScript := preload("res://data/resources/upgrade_data.gd")
const PlayerScript := preload("res://scripts/player/Player.gd")

const MAX_OPTIONS_PER_LEVEL := 3
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

func _ready() -> void:
	if GameEvents.run_started.is_connected(reset) == false:
		GameEvents.run_started.connect(reset)

func reset() -> void:
	_next_option_start = 0
	_applied_unique_ids.clear()
	_applied_ranks.clear()

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

func apply_upgrade(upgrade: Resource, player: Node) -> bool:
	var upgrade_data := upgrade as UpgradeDataScript
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
	GameEvents.upgrade_selected.emit(upgrade_data)
	ExperienceSystem.complete_level_up_selection()
	return true

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
	var value = resource.get(key)
	if typeof(value) == TYPE_NIL:
		return fallback
	return str(value)
