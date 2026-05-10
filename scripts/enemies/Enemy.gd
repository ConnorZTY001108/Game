class_name Enemy
extends CharacterBody2D

const EnemyDataScript := preload("res://data/resources/enemy_data.gd")
const HealthComponentScript := preload("res://scripts/components/HealthComponent.gd")
const PlayerScript := preload("res://scripts/player/Player.gd")

@export var enemy_data: EnemyDataScript = preload("res://data/content/enemies/dust_thrall.tres")

@onready var health_component: HealthComponentScript = $HealthComponent
@onready var drop_component: Node = $DropComponent
@onready var status_receiver: Node = $StatusReceiver

@export var contact_interval: float = 0.6

var target: Node2D
var contact_cooldown: float = 0.0
var contact_targets: Array[PlayerScript] = []

func _ready() -> void:
	health_component.configure(enemy_data.max_health)
	health_component.died.connect(_on_died)

func configure(data: EnemyDataScript, chase_target: Node2D) -> void:
	enemy_data = data
	target = chase_target
	if is_node_ready():
		health_component.configure(enemy_data.max_health)

func _physics_process(delta: float) -> void:
	contact_cooldown = max(0.0, contact_cooldown - delta)
	if contact_cooldown <= 0.0 and not contact_targets.is_empty():
		for player in contact_targets:
			if is_instance_valid(player) and enemy_data != null:
				player.take_contact_damage(enemy_data.contact_damage)
		contact_cooldown = contact_interval

	if GameRuntime.state != GameRuntime.RunState.PLAYING or target == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var direction := global_position.direction_to(target.global_position)
	velocity = direction * enemy_data.move_speed
	move_and_slide()

func apply_damage(amount: float, tags: Array[String]) -> void:
	health_component.apply_damage(amount)
	GameEvents.damage_applied.emit(self, amount, tags)

func _on_died() -> void:
	GameEvents.enemy_died.emit(self, enemy_data.experience_value)
	queue_free()

func _on_contact_area_body_entered(body: Node2D) -> void:
	if body is PlayerScript and not contact_targets.has(body):
		contact_targets.append(body)

func _on_contact_area_body_exited(body: Node2D) -> void:
	if body is PlayerScript:
		contact_targets.erase(body)
