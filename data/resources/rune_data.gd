class_name RuneData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var rarity: String = "common"
@export var stream_tags: Array[String] = []
@export var applies_to_weapon_tags: Array[String] = []
@export var trigger: String = "on_hit"
@export var effect: String = "add_element_stack"
@export var element_tag: String = "scorch"
@export var stack_threshold: int = 3
@export var bonus_damage: float = 12.0
@export var internal_cooldown: float = 0.25
