extends Node

const AugmentDataScript := preload("res://data/resources/augment_data.gd")

const DEFAULT_CONTENT_ROOT := "res://data/content/augments"

var _content_root: String = DEFAULT_CONTENT_ROOT
var _all: Array[Resource] = []
var _by_id: Dictionary = {}
var _validation_errors: Array[String] = []

func _ready() -> void:
	reload()

func reload(content_root: String = DEFAULT_CONTENT_ROOT) -> void:
	_content_root = content_root
	_all.clear()
	_by_id.clear()
	_validation_errors.clear()
	_scan_root(_content_root)

func get_all() -> Array[Resource]:
	return _all.duplicate()

func get_by_id(augment_id: String) -> Resource:
	return _by_id.get(augment_id, null)

func get_by_route(route_id: String) -> Array[Resource]:
	var result: Array[Resource] = []
	for augment in _all:
		if str(augment.get("route_id")) == route_id:
			result.append(augment)
	return result

func get_validation_errors() -> Array[String]:
	return _validation_errors.duplicate()

func validate_all() -> Array[String]:
	var errors := _validation_errors.duplicate()
	for augment in _all:
		var expected_path := _trim_res_prefix(augment.resource_path)
		if augment.has_method("validate"):
			for error in augment.call("validate", expected_path):
				errors.append("%s:%s" % [expected_path, error])
	return errors

func query_candidates(context: Dictionary = {}) -> Array[Resource]:
	var candidates: Array[Resource] = []
	for augment in _all:
		if _matches_context(augment, context):
			candidates.append(augment)
	candidates.sort_custom(func(a: Resource, b: Resource) -> bool:
		return str(a.get("id")) < str(b.get("id"))
	)
	if context.has("rng_seed"):
		_shuffle_deterministic(candidates, int(context.get("rng_seed", 0)))
	var limit := int(context.get("limit", 0))
	if limit > 0 and candidates.size() > limit:
		return candidates.slice(0, limit)
	return candidates

func _scan_root(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full_path := path.path_join(entry)
		if dir.current_is_dir():
			_scan_root(full_path)
		elif entry.ends_with(".tres") or entry.ends_with(".res"):
			_load_augment(full_path)
		entry = dir.get_next()
	dir.list_dir_end()

func _load_augment(path: String) -> void:
	var resource := load(path) as Resource
	if resource == null:
		_validation_errors.append("%s:load_failed" % _trim_res_prefix(path))
		return
	if resource.get_script() != AugmentDataScript:
		_validation_errors.append("%s:not_augment_data" % _trim_res_prefix(path))
		return
	var expected_path := _trim_res_prefix(path)
	var errors: Array = resource.call("validate", expected_path)
	for error in errors:
		_validation_errors.append("%s:%s" % [expected_path, error])
	if not errors.is_empty():
		return
	var augment_id := str(resource.get("id"))
	if augment_id == "":
		return
	if _by_id.has(augment_id):
		_validation_errors.append("%s:duplicate_id:%s" % [expected_path, augment_id])
		return
	_by_id[augment_id] = resource
	_all.append(resource)

func _matches_context(augment: Resource, context: Dictionary) -> bool:
	if context.has("id") and str(augment.get("id")) != str(context.get("id")):
		return false
	if context.has("include_ids") and not _to_string_array(context.get("include_ids")).has(str(augment.get("id"))):
		return false
	if _to_string_array(context.get("exclude_ids", [])).has(str(augment.get("id"))):
		return false
	if context.has("route_id") and str(augment.get("route_id")) != str(context.get("route_id")):
		return false
	var route_ids := _to_string_array(context.get("route_ids", []))
	if not route_ids.is_empty() and not route_ids.has(str(augment.get("route_id"))):
		return false
	if context.has("rarity") and str(augment.get("rarity")) != str(context.get("rarity")):
		return false
	var rarities := _to_string_array(context.get("rarities", []))
	if not rarities.is_empty() and not rarities.has(str(augment.get("rarity"))):
		return false
	var tags := _to_string_array(context.get("tags", []))
	if not _has_all_tags(augment.call("get_all_tags"), tags):
		return false
	var owned_tags := _to_string_array(context.get("owned_tags", context.get("required_tags", [])))
	if not _has_all_tags(owned_tags, _to_string_array(augment.get("required_tags"))):
		return false
	var blocked_tags := _to_string_array(context.get("excluded_tags", [])) + owned_tags
	if _intersects(_to_string_array(augment.get("excludes_tags")), blocked_tags):
		return false
	var owned_ids := _to_string_array(context.get("owned_ids", []))
	if bool(augment.get("unique")) and owned_ids.has(str(augment.get("id"))):
		return false
	if _intersects(_to_string_array(augment.get("excludes_ids")), owned_ids):
		return false
	var upgrade_index := int(context.get("upgrade_index", -1))
	if upgrade_index >= 0:
		var min_index := int(augment.get("min_upgrade_index"))
		var max_index := int(augment.get("max_upgrade_index"))
		if upgrade_index < min_index:
			return false
		if max_index >= 0 and upgrade_index > max_index:
			return false
	return true

func _shuffle_deterministic(values: Array[Resource], seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var current := values[index]
		values[index] = values[swap_index]
		values[swap_index] = current

func _trim_res_prefix(path: String) -> String:
	if path.begins_with("res://"):
		return path.trim_prefix("res://")
	return path

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

func _has_all_tags(source: Array[String], required: Array[String]) -> bool:
	for tag in required:
		if tag != "" and not source.has(tag):
			return false
	return true

func _intersects(left: Array[String], right: Array[String]) -> bool:
	for item in left:
		if item != "" and right.has(item):
			return true
	return false
