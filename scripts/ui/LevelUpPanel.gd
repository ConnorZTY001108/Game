class_name LevelUpPanel
extends Control

const UpgradeDataScript := preload("res://data/resources/upgrade_data.gd")
const AugmentDataScript := preload("res://data/resources/augment_data.gd")
const PlayerScript := preload("res://scripts/player/Player.gd")

@export var player_path: NodePath
@onready var options_container: VBoxContainer = $Panel/Margin/Content/Options

var current_options: Array[Resource] = []

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameEvents.level_up_requested.connect(_show_options)

func _show_options(options: Array[Resource]) -> void:
	current_options = options
	for child in options_container.get_children():
		child.free()
	for option in current_options:
		var button := Button.new()
		button.text = _format_option_text(option)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(560.0, 132.0 if option is AugmentDataScript else 92.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set("autowrap_mode", TextServer.AUTOWRAP_WORD_SMART)
		button.set("text_overrun_behavior", TextServer.OVERRUN_NO_TRIMMING)
		button.pressed.connect(_select_option.bind(option))
		options_container.add_child(button)
	visible = true

func _select_option(option: Resource) -> void:
	var player := get_node_or_null(player_path) as PlayerScript
	if option == null or player == null:
		return
	visible = false
	current_options.clear()
	_clear_option_buttons()
	UpgradeSystem.apply_choice(option, player)

func _format_option_text(option: Resource) -> String:
	if option is AugmentDataScript:
		return _format_augment_text(option)
	var display_name := _get_string(option, "display_name", "未知升级")
	var route_label := _get_string(option, "route_label", "")
	var route_id := _get_string(option, "route_id", "")
	var summary := _get_string(option, "summary", "")
	var details := _get_string(option, "details", "")
	if route_label == "":
		route_label = route_id if route_id != "" else "通用强化"
	if summary == "":
		summary = _get_string(option, "description", "")
	if details == "":
		details = "条件：立即生效。"
	return "%s\n路线：%s\n效果：%s | %s" % [display_name, route_label, summary, details]

func _format_augment_text(option: Resource) -> String:
	var display_name := _get_string(option, "display_name", "Augment")
	var route_id := _get_string(option, "route_id", "augment")
	var route_label := _get_string(option, "route_label", _get_string(option, "route_id", "augment"))
	var rarity := _rarity_label(_get_string(option, "rarity", ""))
	var upgrade_type := _get_string(option, "upgrade_type", "")
	var source := _join_non_empty([_get_string(option, "source_augment_name", ""), _get_string(option, "source_augment_rarity", "")], " / ")
	var effect := _first_non_empty([
		_get_string(option, "effect", ""),
		_get_string(option, "description", ""),
		_get_string(option, "summary", "")
	])
	var condition := _get_string(option, "source_condition", "")
	var fit := _get_string(option, "fit", "")
	var risk := _get_string(option, "risk", "")
	var tags := _join_non_empty(_get_string_array(option, "synergy_tags") + _get_string_array(option, "required_tags"), ", ")
	var cues := "%s (%s) / %s / %s" % [route_label, route_id, rarity, upgrade_type]
	return "%s\n%s | Tags: %s\nSource: %s\nEffect: %s\nCondition: %s | Fit: %s | Risk: %s" % [
		display_name,
		cues,
		_truncate_text(tags, 80),
		_truncate_text(source, 88),
		_truncate_text(effect, 92),
		_truncate_text(condition, 34),
		_truncate_text(fit, 28),
		_truncate_text(risk, 28)
	]

func _clear_option_buttons() -> void:
	for child in options_container.get_children():
		child.queue_free()

func _get_string(resource: Resource, key: String, fallback: String) -> String:
	if resource == null:
		return fallback
	var value = resource.get(key)
	if typeof(value) == TYPE_NIL:
		return fallback
	return str(value)

func _get_string_array(resource: Resource, key: String) -> Array[String]:
	var result: Array[String] = []
	if resource == null:
		return result
	var value: Variant = resource.get(key)
	if value is PackedStringArray:
		for item in value:
			result.append(str(item))
	elif value is Array:
		for item in value:
			result.append(str(item))
	return result

func _first_non_empty(values: Array) -> String:
	for value in values:
		if value.strip_edges() != "":
			return value
	return ""

func _truncate_text(value: String, max_length: int) -> String:
	if value.length() <= max_length:
		return value
	return value.substr(0, max_length - 3) + "..."

func _join_non_empty(values: Array, separator: String) -> String:
	var result: Array[String] = []
	for value in values:
		var text := str(value)
		if text.strip_edges() != "":
			result.append(text)
	return separator.join(result)

func _rarity_label(value: String) -> String:
	match value:
		"silver":
			return "Silver"
		"gold":
			return "Gold"
		"prismatic":
			return "Prismatic"
		_:
			return value
