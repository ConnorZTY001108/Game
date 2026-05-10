class_name MapObjectiveSystem
extends Node

@export var objectives_path: NodePath

var _activated_obelisk_ids: Dictionary = {}
var _triggered_event_ids: Dictionary = {}

func _ready() -> void:
	if GameEvents.run_started.is_connected(_on_run_started) == false:
		GameEvents.run_started.connect(_on_run_started)
	call_deferred("_register_total_obelisks")

func record_obelisk_activated(obelisk_id: String, display_name: String) -> bool:
	if obelisk_id == "" or _activated_obelisk_ids.has(obelisk_id):
		return false
	_activated_obelisk_ids[obelisk_id] = true
	GameEvents.record_map_obelisk_activation()
	GameEvents.request_feedback("map_objective", "符文碑激活：%s" % display_name, Vector2.ZERO, {
		"obelisk_id": obelisk_id,
		"lifetime": 1.5
	})
	return true

func record_map_event(event_id: String, display_name: String) -> bool:
	if event_id == "" or _triggered_event_ids.has(event_id):
		return false
	_triggered_event_ids[event_id] = true
	GameEvents.record_map_event_trigger(event_id, display_name)
	return true

func _on_run_started() -> void:
	_activated_obelisk_ids.clear()
	_triggered_event_ids.clear()
	_register_total_obelisks()

func _register_total_obelisks() -> void:
	GameEvents.reset_map_objective_counters(_count_obelisks())

func _count_obelisks() -> int:
	var root_node := get_node_or_null(objectives_path)
	if root_node == null:
		root_node = get_parent()
	if root_node == null:
		return 0
	return _count_obelisks_recursive(root_node)

func _count_obelisks_recursive(node: Node) -> int:
	var count := 0
	var value: Variant = node.get("obelisk_id")
	if typeof(value) != TYPE_NIL and str(value) != "":
		count += 1
	for child in node.get_children():
		if child != self:
			count += _count_obelisks_recursive(child)
	return count
