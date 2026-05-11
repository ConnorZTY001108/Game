class_name AugmentFeedbackDirector
extends Node

const VisualRegistryScript := preload("res://scripts/augment/AugmentVisualRegistry.gd")
const VfxFactoryScript := preload("res://scripts/feedback/AugmentVfxFactory.gd")

@export var vfx_root_path: NodePath = ^"../../VFXRoot2D"
@export var hud_root_path: NodePath = ^"../../CanvasLayer/HUD"

var _visual_registry: Node
var _vfx_factory: RefCounted
var _owned_augments: Dictionary = {}
var _spawn_sequence: int = 0

func _ready() -> void:
	_visual_registry = VisualRegistryScript.new()
	add_child(_visual_registry)
	_vfx_factory = VfxFactoryScript.new()
	if is_instance_valid(AugmentRegistry):
		_visual_registry.rebuild_from_augment_registry(AugmentRegistry)
	_connect_events()

func _exit_tree() -> void:
	_disconnect_events()
	_owned_augments.clear()

func _connect_events() -> void:
	if not is_instance_valid(GameEvents):
		return
	for entry in _event_connections():
		_connect(str(entry["signal_name"]), entry["callable"])

func _disconnect_events() -> void:
	if not is_instance_valid(GameEvents):
		return
	for entry in _event_connections():
		var signal_name := str(entry["signal_name"])
		var callback: Callable = entry["callable"]
		if GameEvents.has_signal(signal_name) and GameEvents.is_connected(signal_name, callback):
			GameEvents.disconnect(signal_name, callback)

func _connect(signal_name: String, callable: Callable) -> void:
	if GameEvents.has_signal(signal_name) and not GameEvents.is_connected(signal_name, callable):
		GameEvents.connect(signal_name, callable)

func _event_connections() -> Array[Dictionary]:
	return [
		{"signal_name": "augment_acquired", "callable": _on_augment_acquired},
		{"signal_name": "augment_effect_triggered", "callable": _on_augment_effect_triggered},
		{"signal_name": "weapon_fired", "callable": _on_weapon_fired},
		{"signal_name": "projectile_spawned", "callable": _on_projectile_spawned},
		{"signal_name": "projectile_hit", "callable": _on_projectile_hit},
		{"signal_name": "damage_applied_packet", "callable": _on_damage_applied_packet},
		{"signal_name": "burn_stack_applied", "callable": _on_burn_stack_applied},
		{"signal_name": "rift_chain_triggered", "callable": _on_rift_chain_triggered},
		{"signal_name": "shield_gained", "callable": _on_shield_gained},
		{"signal_name": "heal_received", "callable": _on_heal_received},
		{"signal_name": "dash_started", "callable": _on_dash_started},
		{"signal_name": "augment_periodic_tick", "callable": _on_augment_periodic_tick},
	]

func _on_augment_acquired(augment_id: String, augment: Resource, owner: Node, _snapshot: Dictionary) -> void:
	_owned_augments[augment_id] = augment
	var position := _node_position(owner)
	_spawn_for_augment(augment_id, "augment_acquired", position)

func _on_augment_effect_triggered(payload: Dictionary) -> void:
	var augment_id := str(payload.get("augment_id", ""))
	if augment_id == "":
		return
	_spawn_for_augment(augment_id, str(payload.get("signal_name", "augment_effect_triggered")), _position_from_payload(payload))

func _on_weapon_fired(player: Node, _weapon: Resource, packet: Dictionary) -> void:
	_spawn_for_runtime_event("weapon_fired", _node_position(player), packet)

func _on_projectile_spawned(projectile: Node, packet: Dictionary) -> void:
	_spawn_for_runtime_event("projectile_spawned", _node_position(projectile), packet)

func _on_projectile_hit(target: Node, packet: Dictionary) -> void:
	_spawn_for_runtime_event("projectile_hit", _node_position(target), packet)

func _on_damage_applied_packet(target: Node, packet: Dictionary) -> void:
	_spawn_for_runtime_event("damage_applied_packet", _node_position(target), packet)

func _on_burn_stack_applied(target: Node, _stacks_added: int, _total_stacks: int, packet: Dictionary) -> void:
	_spawn_for_runtime_event("burn_stack_applied", _node_position(target), packet)

func _on_rift_chain_triggered(_region_id: String, _chain_count: int, packet: Dictionary) -> void:
	_spawn_for_runtime_event("rift_chain_triggered", _position_from_packet(packet), packet)

func _on_shield_gained(target: Node, _amount: float, packet: Dictionary) -> void:
	_spawn_for_runtime_event("shield_gained", _node_position(target), packet)

func _on_heal_received(target: Node, _amount: float, packet: Dictionary) -> void:
	_spawn_for_runtime_event("heal_received", _node_position(target), packet)

func _on_dash_started(player: Node, packet: Dictionary) -> void:
	_spawn_for_runtime_event("dash_started", _node_position(player), packet)

func _on_augment_periodic_tick(_elapsed_seconds: float) -> void:
	_spawn_for_runtime_event("augment_periodic_tick", Vector2.ZERO, {})

func _spawn_for_runtime_event(trigger_event: String, world_position: Vector2, packet: Dictionary) -> void:
	var explicit_ids := _augment_ids_from_packet(packet)
	if explicit_ids.is_empty():
		for augment_id in _owned_augments.keys():
			var spec: Dictionary = _visual_registry.get_spec(str(augment_id))
			if _to_string_array(spec.get("trigger_events", [])).has(trigger_event):
				explicit_ids.append(str(augment_id))
	for augment_id in explicit_ids:
		_spawn_for_augment(augment_id, trigger_event, world_position)

func _spawn_for_augment(augment_id: String, trigger_event: String, world_position: Vector2) -> void:
	var spec: Dictionary = _visual_registry.get_spec(augment_id)
	if spec.is_empty():
		return
	var parent := _target_parent(spec)
	if parent == null:
		return
	var node: Node = _vfx_factory.create_vfx(augment_id, spec, trigger_event, world_position)
	_spawn_sequence += 1
	node.set_meta("spawn_index", _spawn_sequence)
	parent.add_child(node)

func _target_parent(spec: Dictionary) -> Node:
	if str(spec.get("target_layer", "world")) == "hud":
		var hud := get_node_or_null(hud_root_path)
		if hud != null:
			return hud
	return get_node_or_null(vfx_root_path)

func _augment_ids_from_packet(packet: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key in ["augment_id", "source_augment_id", "generated_by_augment", "generated_augment_id"]:
		var value := str(packet.get(key, ""))
		if value != "" and not result.has(value):
			result.append(value)
	return result

func _position_from_payload(payload: Dictionary) -> Vector2:
	var position = payload.get("world_position", Vector2.ZERO)
	if position is Vector2:
		return position
	return Vector2.ZERO

func _position_from_packet(packet: Dictionary) -> Vector2:
	var position = packet.get("hit_position", packet.get("world_position", Vector2.ZERO))
	if position is Vector2:
		return position
	var owner = packet.get("owner", null)
	if owner is Node2D:
		return (owner as Node2D).global_position
	var target = packet.get("target", null)
	if target is Node2D:
		return (target as Node2D).global_position
	return Vector2.ZERO

func _node_position(node: Node) -> Vector2:
	if node is Node2D:
		return (node as Node2D).global_position
	return Vector2.ZERO

func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is PackedStringArray:
		for item in value:
			result.append(str(item))
	elif value is Array:
		for item in value:
			result.append(str(item))
	elif value is String and str(value) != "":
		for part in str(value).split(",", false):
			result.append(part.strip_edges())
	return result
