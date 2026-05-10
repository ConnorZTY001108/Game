class_name AugmentTriggerSpec
extends Resource

@export var trigger_id: String = ""
@export var signal_names: Array[String] = []
@export var required_packet_keys: Array[String] = []
@export var required_packet_values: Dictionary = {}
@export var synthetic_test: String = ""
@export var tags: Array[String] = []
@export var source_cooldown: float = 0.0
@export var per_target_cooldown: float = 0.0
@export var allow_proc_triggers: bool = true

func validate() -> Array[String]:
	var errors: Array[String] = []
	if trigger_id == "":
		errors.append("trigger_missing_id")
	if signal_names.is_empty():
		errors.append("trigger_missing_signals")
	for key in required_packet_keys:
		if key == "":
			errors.append("trigger_empty_required_packet_key")
	if not required_packet_values is Dictionary:
		errors.append("trigger_required_values_not_dictionary")
	if source_cooldown < 0.0:
		errors.append("trigger_negative_source_cooldown")
	if per_target_cooldown < 0.0:
		errors.append("trigger_negative_per_target_cooldown")
	return errors

func to_runtime_metadata() -> Dictionary:
	return {
		"trigger_id": trigger_id,
		"signal_names": signal_names.duplicate(),
		"required_packet_keys": required_packet_keys.duplicate(),
		"required_packet_values": required_packet_values.duplicate(true),
		"synthetic_test": synthetic_test,
		"tags": tags.duplicate(),
		"source_cooldown": source_cooldown,
		"per_target_cooldown": per_target_cooldown,
		"allow_proc_triggers": allow_proc_triggers
	}

func apply_spec(spec: Dictionary) -> void:
	trigger_id = str(spec.get("trigger_id", trigger_id))
	signal_names = _to_string_array(spec.get("signal_names", spec.get("signals", signal_names)))
	required_packet_keys = _to_string_array(spec.get("required_packet_keys", required_packet_keys))
	var values = spec.get("required_packet_values", required_packet_values)
	required_packet_values = values.duplicate(true) if values is Dictionary else {}
	synthetic_test = str(spec.get("synthetic_test", synthetic_test))
	tags = _to_string_array(spec.get("tags", tags))
	source_cooldown = max(0.0, float(spec.get("source_cooldown", source_cooldown)))
	per_target_cooldown = max(0.0, float(spec.get("per_target_cooldown", per_target_cooldown)))
	allow_proc_triggers = bool(spec.get("allow_proc_triggers", allow_proc_triggers))

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
