extends Node

const UpgradeDataScript := preload("res://data/resources/upgrade_data.gd")
const PlayerScript := preload("res://scripts/player/Player.gd")

const MAX_OPTIONS_PER_LEVEL := 3
const OPTIONS: Array[Resource] = [
	preload("res://data/content/upgrades/damage_focus.tres"),
	preload("res://data/content/upgrades/cooldown_focus.tres"),
	preload("res://data/content/upgrades/scorch_mark_pick.tres"),
	preload("res://data/content/upgrades/pickup_focus.tres")
]

var _next_option_start: int = 0

func generate_options() -> Array[Resource]:
	var option_count: int = min(MAX_OPTIONS_PER_LEVEL, OPTIONS.size())
	if OPTIONS.size() <= MAX_OPTIONS_PER_LEVEL:
		return OPTIONS.duplicate()
	var generated: Array[Resource] = []
	for offset in range(option_count):
		var option_index := (_next_option_start + offset) % OPTIONS.size()
		generated.append(OPTIONS[option_index])
	_next_option_start = (_next_option_start + 1) % OPTIONS.size()
	return generated

func apply_upgrade(upgrade: Resource, player: Node) -> bool:
	var upgrade_data := upgrade as UpgradeDataScript
	var player_node := player as PlayerScript
	if upgrade_data == null or player_node == null:
		return false
	if upgrade_data.upgrade_type == "weapon_stat" or upgrade_data.upgrade_type == "player_stat":
		player_node.apply_upgrade_stat(upgrade_data.stat_key, upgrade_data.value)
	elif upgrade_data.upgrade_type == "rune" and upgrade_data.rune != null:
		if not RuneSystem.is_valid_rune(upgrade_data.rune):
			return false
		RuneSystem.equip_rune(upgrade_data.rune)
	else:
		return false
	GameEvents.upgrade_selected.emit(upgrade_data)
	ExperienceSystem.complete_level_up_selection()
	return true
