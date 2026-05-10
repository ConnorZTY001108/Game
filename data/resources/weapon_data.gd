class_name WeaponData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var attack_mode: String = "projectile"
@export var damage: float = 10.0
@export var cooldown: float = 0.8
@export var projectile_speed: float = 520.0
@export var projectile_lifetime: float = 1.4
@export var projectile_count: int = 1
@export var pierce: int = 0
@export var range: float = 600.0
@export var tags: Array[String] = []
@export var element_tags: Array[String] = []
