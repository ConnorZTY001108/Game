class_name AugmentConditionSpec
extends Resource

@export var required_routes: Array[String] = []
@export var required_tags: Array[String] = []
@export var excludes_tags: Array[String] = []
@export var required_augments: Array[String] = []
@export var excludes_augments: Array[String] = []
@export var min_upgrade_index: int = 0
@export var max_upgrade_index: int = -1
@export var min_player_level: int = 0
@export var params: Dictionary = {}

func validate() -> Array[String]:
	var errors: Array[String] = []
	if min_upgrade_index < 0:
		errors.append("condition_negative_min_upgrade_index")
	if max_upgrade_index < -1:
		errors.append("condition_invalid_max_upgrade_index")
	if max_upgrade_index >= 0 and max_upgrade_index < min_upgrade_index:
		errors.append("condition_max_before_min")
	if min_player_level < 0:
		errors.append("condition_negative_min_player_level")
	if not params is Dictionary:
		errors.append("condition_params_not_dictionary")
	return errors

func to_runtime_metadata() -> Dictionary:
	return {
		"required_routes": required_routes.duplicate(),
		"required_tags": required_tags.duplicate(),
		"excludes_tags": excludes_tags.duplicate(),
		"required_augments": required_augments.duplicate(),
		"excludes_augments": excludes_augments.duplicate(),
		"min_upgrade_index": min_upgrade_index,
		"max_upgrade_index": max_upgrade_index,
		"min_player_level": min_player_level,
		"params": params.duplicate(true)
	}
