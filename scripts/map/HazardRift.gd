class_name HazardRift
extends Area2D

@export var rift_id: String = ""
@export var display_name: String = ""
@export var warning_seconds: float = 0.7
@export var active_seconds: float = 0.6
@export var idle_seconds: float = 3.0
@export var damage: float = 6.0

var state: String = "idle"
var state_timer: float = 0.0
var _damaged_this_active_window: bool = false
var _visual: CanvasItem

func _ready() -> void:
	_visual = get_node_or_null("Visual") as CanvasItem
	_enter_state("idle")

func _process(delta: float) -> void:
	state_timer -= delta
	if state == "active":
		_damage_overlapping_player_once()
	if state_timer > 0.0:
		return
	if state == "idle":
		_enter_state("warning")
	elif state == "warning":
		_enter_state("active")
	else:
		_enter_state("idle")

func force_active_for_test(player: Node) -> void:
	_enter_state("active")
	_damage_player_once(player)

func _enter_state(new_state: String) -> void:
	state = new_state
	if state == "warning":
		state_timer = warning_seconds
		_damaged_this_active_window = false
		_set_visual_color(Color(1.0, 0.75, 0.18, 0.72))
	elif state == "active":
		state_timer = active_seconds
		_damaged_this_active_window = false
		_set_visual_color(Color(0.95, 0.15, 0.08, 0.88))
	else:
		state_timer = idle_seconds
		_damaged_this_active_window = false
		_set_visual_color(Color(0.18, 0.48, 0.62, 0.45))

func _damage_overlapping_player_once() -> void:
	for area in get_overlapping_areas():
		var player := area.get_parent()
		if _damage_player_once(player):
			return
	for body in get_overlapping_bodies():
		if _damage_player_once(body):
			return

func _damage_player_once(player: Node) -> bool:
	if _damaged_this_active_window or player == null:
		return false
	if player.has_method("take_contact_damage") == false:
		return false
	player.call("take_contact_damage", damage)
	_damaged_this_active_window = true
	return true

func _set_visual_color(color: Color) -> void:
	if _visual != null:
		_visual.modulate = color
