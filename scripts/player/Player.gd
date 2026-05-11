class_name Player
extends CharacterBody2D

const CharacterDataScript := preload("res://data/resources/character_data.gd")
const HealthComponentScript := preload("res://scripts/components/HealthComponent.gd")
const WeaponControllerScene := preload("res://scenes/weapons/WeaponController.tscn")
const DAMAGE_BLINK_SECONDS := 0.35
const LOW_HP_EVENT_RATIO := 0.35

@export var character_data: CharacterDataScript = preload("res://data/content/characters/wasteland_walker.tres")

@onready var health_component: HealthComponentScript = $HealthComponent
@onready var visual: Sprite2D = $Visual
@onready var weapon_mount: Node2D = $WeaponMount

var damage_multiplier: float = 1.0
var cooldown_multiplier: float = 1.0
var pickup_radius: float = 72.0
var _temporary_pickup_radius_bonus: float = 0.0
var _temporary_pickup_radius_bonus_serial: int = 0
var _damage_blink_remaining: float = 0.0
var _visual_base_modulate: Color = Color.WHITE
var _low_hp_event_active: bool = false

func _ready() -> void:
	if visual != null:
		_visual_base_modulate = visual.modulate
	_apply_character_data()
	health_component.died.connect(_on_died)

func _process(delta: float) -> void:
	_update_damage_blink(delta)

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
	_low_hp_event_active = false
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

func get_stat_snapshot() -> Dictionary:
	return {
		"damage_multiplier": damage_multiplier,
		"cooldown_multiplier": cooldown_multiplier,
		"pickup_radius": pickup_radius,
		"health": health_component.current_health if health_component != null else 0.0,
		"max_health": health_component.max_health if health_component != null else 0.0,
		"move_speed": character_data.move_speed if character_data != null else 0.0
	}

func apply_temporary_pickup_radius_bonus(value: float, duration_seconds: float) -> void:
	_temporary_pickup_radius_bonus_serial += 1
	var serial := _temporary_pickup_radius_bonus_serial
	if _temporary_pickup_radius_bonus > 0.0:
		pickup_radius = max(24.0, pickup_radius - _temporary_pickup_radius_bonus)
	_temporary_pickup_radius_bonus = max(0.0, value)
	pickup_radius = max(24.0, pickup_radius + _temporary_pickup_radius_bonus)
	if duration_seconds <= 0.0 or get_tree() == null:
		return
	await get_tree().create_timer(duration_seconds).timeout
	if serial != _temporary_pickup_radius_bonus_serial:
		return
	pickup_radius = max(24.0, pickup_radius - _temporary_pickup_radius_bonus)
	_temporary_pickup_radius_bonus = 0.0

func add_weapon(weapon_data: Resource) -> bool:
	if weapon_data == null or weapon_mount == null:
		return false
	var weapon_id := str(weapon_data.get("id"))
	if weapon_id == "":
		return false
	for child in weapon_mount.get_children():
		if child.get("weapon_data") == weapon_data:
			return false
		var child_weapon_data = child.get("weapon_data")
		if child_weapon_data != null and str(child_weapon_data.get("id")) == weapon_id:
			return false
	var weapon := WeaponControllerScene.instantiate()
	weapon.name = "%sController" % weapon_id.to_pascal_case()
	weapon_mount.add_child(weapon)
	weapon.projectiles_path = ^"../../../Projectiles"
	weapon.enemies_path = ^"../../../Enemies"
	weapon.configure(self, weapon_data)
	return true

func take_contact_damage(amount: float) -> void:
	var health_before := health_component.current_health
	var state_before := GameRuntime.get_state_name()
	var packet := _make_contact_damage_packet(amount)
	if amount > 0.0 and health_component.is_dead == false and amount >= health_before:
		GameEvents.fatal_damage_received.emit(self, packet.duplicate(true))
	if amount > 0.0 and health_component.is_dead == false:
		_start_damage_blink()
	health_component.apply_damage(amount)
	_emit_low_hp_if_needed(packet)
	GameRuntime.log_state("player_contact_damage_applied", {
		"amount": amount,
		"state_before": state_before,
		"state_after": GameRuntime.get_state_name(),
		"health_before": health_before,
		"health_after": health_component.current_health,
		"max_health": health_component.max_health,
		"is_dead": health_component.is_dead,
		"player_position": global_position
	})

func is_damage_blink_active() -> bool:
	return _damage_blink_remaining > 0.0

func _on_died() -> void:
	GameEvents.player_died.emit()
	GameRuntime.finish_run("defeat")

func _make_contact_damage_packet(amount: float) -> Dictionary:
	var tags: Array[String] = ["contact"]
	return DamageSystem.make_packet(amount, tags, {
		"owner": null,
		"target": self,
		"source_kind": "contact",
		"source_id": "enemy_contact",
		"hit_position": global_position
	})

func _emit_low_hp_if_needed(packet: Dictionary) -> void:
	var ratio := 0.0
	if health_component.max_health > 0.0:
		ratio = health_component.current_health / health_component.max_health
	if ratio > LOW_HP_EVENT_RATIO:
		_low_hp_event_active = false
		return
	if _low_hp_event_active or health_component.is_dead:
		return
	_low_hp_event_active = true
	var event_packet := packet.duplicate(true)
	event_packet["health_ratio"] = ratio
	GameEvents.low_hp_entered.emit(self, ratio, event_packet)

func _start_damage_blink() -> void:
	_damage_blink_remaining = DAMAGE_BLINK_SECONDS
	if visual != null:
		visual.modulate = Color(1.0, 0.45, 0.4, 1.0)

func _update_damage_blink(delta: float) -> void:
	if _damage_blink_remaining <= 0.0:
		return
	_damage_blink_remaining = max(0.0, _damage_blink_remaining - delta)
	if visual == null:
		return
	if _damage_blink_remaining <= 0.0:
		visual.modulate = _visual_base_modulate
		return
	var pulse := int(_damage_blink_remaining / 0.07) % 2
	visual.modulate = Color(1.0, 0.45, 0.4, 1.0) if pulse == 0 else _visual_base_modulate
