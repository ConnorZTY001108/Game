class_name Projectile
extends Area2D

var velocity: Vector2 = Vector2.ZERO
var damage: float = 0.0
var tags: Array[String] = []
var lifetime: float = 0.0
var remaining_pierce: int = 0
var payload: Dictionary = {}

func configure(direction: Vector2, speed: float, new_damage: float, new_lifetime: float, new_pierce: int, new_tags: Array[String], new_payload: Dictionary) -> void:
	velocity = direction.normalized() * speed
	damage = new_damage
	lifetime = new_lifetime
	remaining_pierce = new_pierce
	tags = new_tags.duplicate()
	payload = new_payload.duplicate(true)

func _ready() -> void:
	if area_entered.is_connected(_on_area_entered) == false:
		area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	var hit_payload := payload.duplicate(true)
	hit_payload["hit_position"] = global_position
	DamageSystem.apply_damage(target, damage, tags, hit_payload)
	if remaining_pierce <= 0:
		queue_free()
	else:
		remaining_pierce -= 1
