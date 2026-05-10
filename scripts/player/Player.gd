class_name Player
extends CharacterBody2D

const CharacterDataScript := preload("res://data/resources/character_data.gd")
const HealthComponentScript := preload("res://scripts/components/HealthComponent.gd")
const WeaponControllerScene := preload("res://scenes/weapons/WeaponController.tscn")

@export var character_data: CharacterDataScript = preload("res://data/content/characters/wasteland_walker.tres")

@onready var health_component: HealthComponentScript = $HealthComponent
@onready var weapon_mount: Node2D = $WeaponMount

var damage_multiplier: float = 1.0
var cooldown_multiplier: float = 1.0
var pickup_radius: float = 72.0

func _ready() -> void:
	_apply_character_data()
	health_component.died.connect(_on_died)

func _physics_process(_delta: float) -> void:
	if GameRuntime.state != GameRuntime.RunState.PLAYING:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_vector * character_data.move_speed
	move_and_slide()

func _apply_character_data() -> void:
	health_component.configure(character_data.max_health)
	damage_multiplier = character_data.damage_multiplier
	cooldown_multiplier = character_data.cooldown_multiplier
	pickup_radius = character_data.pickup_radius
	_mount_starting_weapon()

func _mount_starting_weapon() -> void:
	var starting_weapon := character_data.starting_weapon
	if starting_weapon == null or weapon_mount == null:
		return
	var weapon := weapon_mount.get_node_or_null("StartingWeaponController")
	if weapon == null:
		weapon = WeaponControllerScene.instantiate()
		weapon.name = "StartingWeaponController"
		weapon_mount.add_child(weapon)
	weapon.projectiles_path = ^"../../../Projectiles"
	weapon.enemies_path = ^"../../../Enemies"
	weapon.configure(self, starting_weapon)

func apply_upgrade_stat(stat_key: String, value: float) -> void:
	if stat_key == "damage_multiplier":
		damage_multiplier += value
	elif stat_key == "cooldown_multiplier":
		cooldown_multiplier = max(0.2, cooldown_multiplier + value)
	elif stat_key == "pickup_radius":
		pickup_radius = max(24.0, pickup_radius + value)

func take_contact_damage(amount: float) -> void:
	health_component.apply_damage(amount)

func _on_died() -> void:
	GameEvents.player_died.emit()
	GameRuntime.finish_run("defeat")
