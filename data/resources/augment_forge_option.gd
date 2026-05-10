class_name AugmentForgeOption
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var stat_key: String = ""
@export var operation: String = "add_percent"
@export var value: float = 0.0
@export var rarity: String = "silver"
@export var weight: float = 1.0
@export var tags: Array[String] = []

func validate() -> Array[String]:
	var errors: Array[String] = []
	if id == "":
		errors.append("forge_missing_id")
	if stat_key == "":
		errors.append("forge_missing_stat_key")
	if weight <= 0.0:
		errors.append("forge_invalid_weight")
	return errors

func to_runtime_metadata() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"stat_key": stat_key,
		"operation": operation,
		"value": value,
		"rarity": rarity,
		"weight": weight,
		"tags": tags.duplicate()
	}
