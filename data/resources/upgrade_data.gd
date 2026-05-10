class_name UpgradeData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var upgrade_type: String = "weapon_stat"
@export var stat_key: String = "damage_multiplier"
@export var value: float = 0.15
@export var rune: Resource
