class_name Enemy
extends CharacterBody2D

const EnemyDataScript := preload("res://data/resources/enemy_data.gd")
const HealthComponentScript := preload("res://scripts/components/HealthComponent.gd")
const PlayerScript := preload("res://scripts/player/Player.gd")
const HIT_FLASH_SECONDS := 0.1
const DEATH_FEEDBACK_SECONDS := 0.28

@export var enemy_data: EnemyDataScript = preload("res://data/content/enemies/dust_thrall.tres")

@onready var health_component: HealthComponentScript = $HealthComponent
@onready var drop_component: Node = $DropComponent
@onready var status_receiver: Node = $StatusReceiver
@onready var visual: Sprite2D = $Visual

@export var contact_interval: float = 0.6

var target: Node2D
var contact_cooldown: float = 0.0
var contact_targets: Array[PlayerScript] = []
var _hit_flash_remaining: float = 0.0
var _visual_base_modulate: Color = Color.WHITE

func _ready() -> void:
	health_component.configure(enemy_data.max_health)
	_apply_visual()
	if visual != null:
		_visual_base_modulate = visual.modulate
	health_component.died.connect(_on_died)

func _process(delta: float) -> void:
	_update_hit_flash(delta)

func configure(data: EnemyDataScript, chase_target: Node2D) -> void:
	enemy_data = data
	target = chase_target
	if is_node_ready():
		health_component.configure(enemy_data.max_health)
		_apply_visual()

func _physics_process(delta: float) -> void:
	contact_cooldown = max(0.0, contact_cooldown - delta)
	if contact_cooldown <= 0.0 and not contact_targets.is_empty():
		var damaged_target_count := 0
		for player in contact_targets:
			if is_instance_valid(player) and enemy_data != null:
				_log_contact_damage_tick(player)
				player.take_contact_damage(enemy_data.contact_damage)
				damaged_target_count += 1
		if damaged_target_count > 0:
			contact_cooldown = contact_interval

	if GameRuntime.state != GameRuntime.RunState.PLAYING or target == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var direction := global_position.direction_to(target.global_position)
	velocity = direction * enemy_data.move_speed
	move_and_slide()

func apply_damage(amount: float, tags: Array[String]) -> void:
	if amount > 0.0 and health_component.is_dead == false:
		_start_hit_flash()
	health_component.apply_damage(amount)
	GameEvents.damage_applied.emit(self, amount, tags)
	GameEvents.damage_number_requested.emit(amount, global_position, tags)

func get_enemy_class() -> String:
	if enemy_data == null:
		return "normal"
	var enemy_id := enemy_data.id.to_lower()
	if enemy_id.contains("boss"):
		return "boss"
	if enemy_id.contains("elite") or enemy_data.experience_value >= 5:
		return "elite"
	if enemy_data.max_health >= 60.0:
		return "large"
	return "normal"

func is_hit_flash_active() -> bool:
	return _hit_flash_remaining > 0.0

func _apply_visual() -> void:
	if visual != null and enemy_data != null and enemy_data.visual_texture != null:
		visual.texture = enemy_data.visual_texture

func _on_died() -> void:
	_spawn_death_feedback()
	GameEvents.feedback_requested.emit("kill", "KILL +%d XP" % enemy_data.experience_value, global_position, {
		"experience_value": enemy_data.experience_value
	})
	var enemy_class := get_enemy_class()
	if enemy_class == "elite" or enemy_class == "boss":
		var tags: Array[String] = ["kill"]
		var packet := DamageSystem.make_packet(0.0, tags, {
			"target": self,
			"target_class": enemy_class,
			"source_kind": "kill",
			"source_id": "enemy_death",
			"hit_position": global_position
		})
		GameEvents.elite_killed.emit(self, packet)
	GameEvents.enemy_died.emit(self, enemy_data.experience_value)
	queue_free()

func _start_hit_flash() -> void:
	_hit_flash_remaining = HIT_FLASH_SECONDS
	if visual != null:
		visual.modulate = Color(1.0, 0.95, 0.55, 1.0)

func _update_hit_flash(delta: float) -> void:
	if _hit_flash_remaining <= 0.0:
		return
	_hit_flash_remaining = max(0.0, _hit_flash_remaining - delta)
	if _hit_flash_remaining <= 0.0 and visual != null:
		visual.modulate = _visual_base_modulate

func _spawn_death_feedback() -> void:
	var parent_node := get_parent()
	if parent_node == null or visual == null:
		return
	var ghost := Sprite2D.new()
	ghost.name = "EnemyDeathFeedback"
	ghost.texture = visual.texture
	ghost.global_position = global_position
	ghost.scale = visual.scale
	ghost.modulate = visual.modulate
	ghost.z_index = z_index + 1
	parent_node.add_child(ghost)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, DEATH_FEEDBACK_SECONDS)
	tween.parallel().tween_property(ghost, "scale", ghost.scale * 0.55, DEATH_FEEDBACK_SECONDS)
	tween.tween_callback(ghost.queue_free)

func _on_contact_area_body_entered(body: Node2D) -> void:
	if body is PlayerScript and not contact_targets.has(body):
		contact_targets.append(body)
		GameRuntime.log_state("enemy_contact_entered", {
			"enemy_id": _get_enemy_id(),
			"contact_damage": enemy_data.contact_damage if enemy_data != null else 0.0,
			"target_count": contact_targets.size(),
			"enemy_position": global_position,
			"player_position": body.global_position
		})

func _on_contact_area_body_exited(body: Node2D) -> void:
	if body is PlayerScript:
		contact_targets.erase(body)
		GameRuntime.log_state("enemy_contact_exited", {
			"enemy_id": _get_enemy_id(),
			"target_count": contact_targets.size(),
			"enemy_position": global_position,
			"player_position": body.global_position
		})

func _log_contact_damage_tick(player: PlayerScript) -> void:
	GameRuntime.log_state("enemy_contact_damage_tick", {
		"enemy_id": _get_enemy_id(),
		"amount": enemy_data.contact_damage if enemy_data != null else 0.0,
		"cooldown_before": contact_cooldown,
		"contact_interval": contact_interval,
		"target_count": contact_targets.size(),
		"player_health_before": player.health_component.current_health if player.health_component != null else -1.0,
		"enemy_position": global_position,
		"player_position": player.global_position
	})

func _get_enemy_id() -> String:
	if enemy_data == null:
		return "unknown_enemy"
	return enemy_data.id
