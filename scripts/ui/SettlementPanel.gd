class_name SettlementPanel
extends Control

@onready var title_label: Label = $Panel/Margin/Content/TitleLabel
@onready var summary_label: Label = $Panel/Margin/Content/SummaryLabel
@onready var restart_button: Button = $Panel/Margin/Content/Actions/RestartButton
@onready var return_menu_button: Button = $Panel/Margin/Content/Actions/ReturnMenuButton
@onready var quit_button: Button = $Panel/Margin/Content/Actions/QuitButton

var last_summary: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	restart_button.process_mode = Node.PROCESS_MODE_ALWAYS
	return_menu_button.process_mode = Node.PROCESS_MODE_ALWAYS
	quit_button.process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	GameEvents.run_started.connect(_on_run_started)
	GameEvents.settlement_requested.connect(show_summary)
	if restart_button.pressed.is_connected(_on_restart_button_pressed) == false:
		restart_button.pressed.connect(_on_restart_button_pressed)
	if return_menu_button.pressed.is_connected(_on_return_menu_button_pressed) == false:
		return_menu_button.pressed.connect(_on_return_menu_button_pressed)
	if quit_button.pressed.is_connected(_on_quit_button_pressed) == false:
		quit_button.pressed.connect(_on_quit_button_pressed)

func show_summary(summary: Dictionary) -> void:
	last_summary = summary.duplicate(true)
	var result: String = str(summary.get("result", "defeat"))
	title_label.text = "胜利" if result == "victory" else "失败"
	summary_label.text = _format_summary(summary)
	visible = true

func get_summary_text() -> String:
	if summary_label == null:
		return ""
	return "%s\n%s" % [title_label.text, summary_label.text]

func _on_run_started() -> void:
	visible = false
	last_summary.clear()

func _on_restart_button_pressed() -> void:
	GameEvents.restart_run_requested.emit()

func _on_return_menu_button_pressed() -> void:
	GameEvents.return_to_menu_requested.emit()

func _on_quit_button_pressed() -> void:
	GameEvents.quit_game_requested.emit()

func _format_summary(summary: Dictionary) -> String:
	var seconds: float = float(summary.get("survival_time", 0.0))
	var minutes: int = int(seconds) / 60
	var remainder: int = int(seconds) % 60
	var upgrades: Array = []
	var upgrades_value: Variant = summary.get("upgrades", [])
	if upgrades_value is Array:
		upgrades = upgrades_value
	var upgrade_text: String = "无"
	if upgrades is Array and upgrades.size() > 0:
		upgrade_text = ", ".join(PackedStringArray(_string_array(upgrades)))
	var base_text := "存活时间：%02d:%02d\n击杀：%d\n等级：%d\n本局选择：%s" % [
		minutes,
		remainder,
		int(summary.get("kills", 0)),
		int(summary.get("level", 1)),
		upgrade_text
	]
	if summary.has("map_objectives"):
		base_text += "\n%s" % _format_map_objectives(summary.get("map_objectives"))
	return base_text

func _format_map_objectives(value: Variant) -> String:
	var map_summary: Dictionary = {}
	if value is Dictionary:
		map_summary = value
	var activated := int(map_summary.get("activated_obelisks", 0))
	var total := int(map_summary.get("total_obelisks", 0))
	var events := int(map_summary.get("triggered_map_events", 0))
	var complete := bool(map_summary.get("all_obelisks_activated", false))
	var status := "已完成" if complete else "未完成"
	return "符文碑：%d/%d\n地图事件：%d\n地图目标：%s" % [activated, total, events, status]

func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result
