class_name UpgradeData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var route_id: String = ""
@export var route_label: String = ""
@export var summary: String = ""
@export_multiline var details: String = ""
@export var max_rank: int = 0
@export var unique: bool = false
@export var upgrade_type: String = "weapon_stat"
@export var stat_key: String = "damage_multiplier"
@export var value: float = 0.15
@export var rune: Resource
@export var weapon: Resource
