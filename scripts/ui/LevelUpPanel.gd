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
		child.queue_free()
	for option in current_options:
		var button := Button.new()
		button.text = "%s - %s" % [option.get("display_name"), option.get("description")]
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
