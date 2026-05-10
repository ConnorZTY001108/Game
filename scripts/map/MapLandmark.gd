class_name MapLandmark
extends Node2D

@export var landmark_id: String = ""
@export var display_name: String = ""
@export var importance: int = 1
@export var show_direction_hint: bool = true

func is_valid_landmark() -> bool:
	return landmark_id.strip_edges() != "" and display_name.strip_edges() != ""
