class_name AugmentData
extends Resource

const AugmentTriggerSpecScript := preload("res://data/resources/augment_trigger_spec.gd")
const AugmentEffectSpecScript := preload("res://data/resources/augment_effect_spec.gd")
const AugmentConditionSpecScript := preload("res://data/resources/augment_condition_spec.gd")

const VALID_RARITIES: Array[String] = ["银色", "金色", "棱彩", "silver", "gold", "prismatic"]

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var source_augment_name: String = ""
@export var source_augment_rarity: String = ""
@export var route_id: String = ""
@export var route_label: String = ""
@export var rarity: String = "银色"
@export var max_rank: int = 1
@export var unique: bool = true
@export var upgrade_type: String = "启动器"

@export var source_trigger: String = ""
@export_multiline var effect: String = ""
@export_multiline var source_condition: String = ""
@export var value: Dictionary = {}

@export var trigger: Resource
@export var effects: Array[Resource] = []
@export var condition: Resource

@export var synergy_tags: Array[String] = []
@export var required_tags: Array[String] = []
@export var excludes_tags: Array[String] = []
@export var excludes_ids: Array[String] = []

@export_multiline var combo_value: String = ""
@export_multiline var fit: String = ""
@export_multiline var risk: String = ""
@export_multiline var why_close: String = ""
@export_multiline var implementation_hint: String = ""

@export var weight: float = 1.0
@export var min_upgrade_index: int = 0
@export var max_upgrade_index: int = -1
@export var manifest_resource_path: String = ""
@export var test_owner: String = ""
@export var checkpoint_priority: int = 0

@export var manifest_fields: Dictionary = {}
@export var trigger_spec: Dictionary = {}
@export var effect_spec_blueprint: Array[Dictionary] = []

func ensure_runtime_specs_from_blueprint() -> Array[String]:
	var errors: Array[String] = []
	if trigger == null and not trigger_spec.is_empty():
		var new_trigger = AugmentTriggerSpecScript.new()
		new_trigger.apply_spec(trigger_spec)
		trigger = new_trigger
	if effects.is_empty() and not effect_spec_blueprint.is_empty():
		for index in range(effect_spec_blueprint.size()):
			var blueprint := effect_spec_blueprint[index]
			var effect_spec = AugmentEffectSpecScript.new()
			effect_spec.apply_blueprint(blueprint)
			effects.append(effect_spec)
	if trigger != null and trigger.has_method("validate"):
		errors.append_array(trigger.call("validate"))
	for effect_resource in effects:
		if effect_resource == null or not effect_resource.has_method("validate"):
			errors.append("effect_invalid_resource")
			continue
		errors.append_array(effect_resource.call("validate"))
	return errors

func validate(expected_resource_path: String = "") -> Array[String]:
	var errors: Array[String] = []
	errors.append_array(_validate_manifest_specs())
	errors.append_array(ensure_runtime_specs_from_blueprint())
	if id == "":
		errors.append("augment_missing_id")
	if display_name == "":
		errors.append("augment_missing_display_name")
	if route_id == "":
		errors.append("augment_missing_route_id")
	if rarity == "" or not VALID_RARITIES.has(rarity):
		errors.append("augment_invalid_rarity:%s" % rarity)
	if max_rank <= 0:
		errors.append("augment_invalid_max_rank")
	if trigger == null or not trigger is AugmentTriggerSpecScript:
		errors.append("augment_invalid_trigger_spec")
	if effects.is_empty():
		errors.append("augment_missing_effects")
	for effect_resource in effects:
		if effect_resource == null or not effect_resource is AugmentEffectSpecScript:
			errors.append("augment_invalid_effect_spec")
	if condition != null and not condition is AugmentConditionSpecScript:
		errors.append("augment_invalid_condition_spec")
	elif condition != null and condition.has_method("validate"):
		errors.append_array(condition.call("validate"))
	var declared_path := manifest_resource_path
	if declared_path == "" and resource_path != "":
		declared_path = resource_path.trim_prefix("res://")
	if declared_path == "":
		errors.append("augment_missing_resource_path")
	elif expected_resource_path != "" and declared_path != expected_resource_path:
		errors.append("augment_resource_path_mismatch:%s!=%s" % [declared_path, expected_resource_path])
	if test_owner == "":
		errors.append("augment_missing_test_owner")
	if checkpoint_priority < 0:
		errors.append("augment_invalid_checkpoint_priority")
	if weight <= 0.0:
		errors.append("augment_invalid_weight")
	if min_upgrade_index < 0:
		errors.append("augment_invalid_min_upgrade_index")
	if max_upgrade_index < -1:
		errors.append("augment_invalid_max_upgrade_index")
	if max_upgrade_index >= 0 and max_upgrade_index < min_upgrade_index:
		errors.append("augment_max_upgrade_before_min")
	return errors

func _validate_manifest_specs() -> Array[String]:
	var errors: Array[String] = []
	if trigger_spec.is_empty():
		errors.append("augment_missing_trigger_spec")
	else:
		var spec_trigger = AugmentTriggerSpecScript.new()
		spec_trigger.apply_spec(trigger_spec)
		for error in spec_trigger.validate():
			errors.append("trigger_spec_%s" % error)
	if effect_spec_blueprint.is_empty():
		errors.append("augment_missing_effect_spec_blueprint")
	else:
		for index in range(effect_spec_blueprint.size()):
			var blueprint := effect_spec_blueprint[index]
			var spec_effect = AugmentEffectSpecScript.new()
			spec_effect.apply_blueprint(blueprint)
			for error in spec_effect.validate():
				errors.append("effect_spec_blueprint_%d_%s" % [index, error])
	return errors

func get_runtime_metadata() -> Dictionary:
	var effect_metadata: Array[Dictionary] = []
	for effect_resource in effects:
		if effect_resource != null and effect_resource.has_method("to_runtime_metadata"):
			effect_metadata.append(effect_resource.call("to_runtime_metadata"))
	return {
		"id": id,
		"route_id": route_id,
		"rarity": rarity,
		"unique": unique,
		"max_rank": max_rank,
		"trigger": trigger.call("to_runtime_metadata") if trigger != null and trigger.has_method("to_runtime_metadata") else {},
		"effects": effect_metadata,
		"condition": condition.call("to_runtime_metadata") if condition != null and condition.has_method("to_runtime_metadata") else {},
		"value": value.duplicate(true),
		"synergy_tags": synergy_tags.duplicate(),
		"required_tags": required_tags.duplicate(),
		"excludes_tags": excludes_tags.duplicate(),
		"excludes_ids": excludes_ids.duplicate()
	}

func get_all_tags() -> Array[String]:
	var result: Array[String] = []
	for tag in synergy_tags + required_tags:
		if tag != "" and not result.has(tag):
			result.append(tag)
	return result
