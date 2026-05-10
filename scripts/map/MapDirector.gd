class_name MapDirector
extends Node2D

@export var player_path: NodePath

var landmarks: Array[Node] = []
var regions: Array[Node] = []
var _active_region_id: String = ""
var _active_region_display_name: String = ""
var _player: Node2D

func _ready() -> void:
	refresh_map_cache()
	call_deferred("_update_active_region")

func _process(_delta: float) -> void:
	_update_active_region()

func refresh_map_cache() -> void:
	landmarks.clear()
	regions.clear()
	_player = get_node_or_null(player_path) as Node2D

	var landmarks_root := get_node_or_null("Landmarks")
	if landmarks_root != null:
		for child in landmarks_root.get_children():
			if child.has_method("is_valid_landmark") and bool(child.call("is_valid_landmark")):
				landmarks.append(child)

	var regions_root := get_node_or_null("Regions")
	if regions_root != null:
		for child in regions_root.get_children():
			var region_id := str(child.get("region_id"))
			if child.has_method("contains_world_position") and region_id.strip_edges() != "":
				regions.append(child)

func get_landmark_count() -> int:
	return landmarks.size()

func get_region_count() -> int:
	return regions.size()

func get_active_region_id() -> String:
	return _active_region_id

func has_landmark_id(landmark_id: String) -> bool:
	for landmark in landmarks:
		if str(landmark.get("landmark_id")) == landmark_id:
			return true
	return false

func get_region_id_for_world_position(world_position: Vector2) -> String:
	var region := _get_region_for_world_position(world_position)
	if region == null:
		return ""
	return str(region.get("region_id"))

func _update_active_region() -> void:
	if _player == null:
		_player = get_node_or_null(player_path) as Node2D
	if _player == null:
		return

	var region := _get_region_for_world_position(_player.global_position)
	if region == null:
		return
	var region_id := str(region.get("region_id"))
	if region_id == _active_region_id:
		return

	_active_region_id = region_id
	_active_region_display_name = str(region.get("display_name"))
	GameEvents.map_region_changed.emit(_active_region_id, _active_region_display_name)

func _get_region_for_world_position(world_position: Vector2) -> Node:
	var best_region: Node = null
	var best_priority := -2147483648
	for region in regions:
		var region_priority := int(region.get("priority"))
		if bool(region.call("contains_world_position", world_position)) and region_priority > best_priority:
			best_region = region
			best_priority = region_priority
	return best_region
