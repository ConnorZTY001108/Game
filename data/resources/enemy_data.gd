class_name EnemyData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var max_health: float = 30.0
@export var move_speed: float = 130.0
@export var contact_damage: float = 8.0
@export var experience_value: int = 1
@export var behavior_type: String = "chase"
@export var element_rules: Array[String] = []
@export var visual_texture: Texture2D
