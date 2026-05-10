class_name LevelUpPanel
extends Control

const UpgradeDataScript := preload("res://data/resources/upgrade_data.gd")
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
		button.custom_minimum_size = Vector2(560.0, 92.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set("autowrap_mode", TextServer.AUTOWRAP_WORD_SMART)
		button.set("text_overrun_behavior", TextServer.OVERRUN_NO_TRIMMING)
		button.pressed.connect(_select_option.bind(option))
		options_container.add_child(button)
	visible = true

func _select_option(option: Resource) -> void:
	var upgrade := option as UpgradeDataScript
	var player := get_node_or_null(player_path) as PlayerScript
	if upgrade == null or player == null:
		return
	visible = false
	UpgradeSystem.apply_upgrade(upgrade, player)

func _format_option_text(option: Resource) -> String:
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

func _get_string(resource: Resource, key: String, fallback: String) -> String:
	var value = resource.get(key)
	if typeof(value) == TYPE_NIL:
		return fallback
	return str(value)
