class_name MapRegion
extends Area2D

@export var region_id: String = ""
@export var display_name: String = ""
# Area2D already exposes `priority`; MapDirector reads that native property.

func contains_world_position(world_position: Vector2) -> bool:
	var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or collision_shape.disabled:
		return false
	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle == null:
		return false
	var local_position := to_local(world_position)
	var half_size := rectangle.size * 0.5
	return absf(local_position.x) <= half_size.x and absf(local_position.y) <= half_size.y
