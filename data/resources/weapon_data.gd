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
@export var area_radius: float = 96.0
@export var tick_interval: float = 0.6
@export var orbit_radius: float = 72.0
@export var pulse_duration: float = 0.15
@export var tags: Array[String] = []
@export var element_tags: Array[String] = []
