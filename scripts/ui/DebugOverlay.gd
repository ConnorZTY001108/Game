class_name DebugOverlay
extends Control

@onready var debug_label: Label = $Panel/Margin/DebugLabel

@export var enemies_path: NodePath
@export var projectiles_path: NodePath
@export var pickups_path: NodePath

var visible_by_toggle: bool = true

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("debug_toggle"):
		visible_by_toggle = not visible_by_toggle
		visible = visible_by_toggle
	if not visible:
		return
	var enemies := _count_children(enemies_path)
	var projectiles := _count_children(projectiles_path)
	var pickups := _count_children(pickups_path)
	debug_label.text = "帧率: %d\n敌人: %d\n子弹: %d\n拾取物: %d" % [Engine.get_frames_per_second(), enemies, projectiles, pickups]

func _count_children(path: NodePath) -> int:
	var node := get_node_or_null(path)
	return node.get_child_count() if node != null else 0
