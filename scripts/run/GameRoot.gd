class_name GameRoot
extends Node

const RUN_SCENE: PackedScene = preload("res://scenes/run/RunScene.tscn")

var current_run: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func start_new_run() -> Node:
	clear_run()
	current_run = RUN_SCENE.instantiate()
	add_child(current_run)
	current_run.call("begin_run")
	return current_run

func restart_run() -> Node:
	return start_new_run()

func clear_run() -> void:
	for child in get_children():
		if child == current_run or child.name == "RunScene":
			remove_child(child)
			child.queue_free()
	current_run = null

func get_current_run() -> Node:
	return current_run
