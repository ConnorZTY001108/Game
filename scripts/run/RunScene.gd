class_name RunScene
extends Node2D

const PlayerScript := preload("res://scripts/player/Player.gd")
const RunTimerSystemScript := preload("res://scripts/systems/RunTimerSystem.gd")
const HUDScript := preload("res://scripts/ui/HUD.gd")
const DebugOverlayScript := preload("res://scripts/ui/DebugOverlay.gd")

@onready var player: PlayerScript = $World/Player
@onready var player_camera: Camera2D = get_node_or_null("World/Player/Camera2D") as Camera2D
@onready var run_timer: RunTimerSystemScript = $Systems/RunTimerSystem
@onready var hud: HUDScript = $CanvasLayer/HUD
@onready var debug_overlay: DebugOverlayScript = $CanvasLayer/DebugOverlay

func _ready() -> void:
	_configure_player_camera()
	hud.bind_player(player)
	hud.bind_timer(run_timer)
	debug_overlay.enemies_path = ^"../../World/Enemies"
	debug_overlay.projectiles_path = ^"../../World/Projectiles"
	debug_overlay.pickups_path = ^"../../World/Pickups"
	if GameEvents.run_finished.is_connected(_on_run_finished) == false:
		GameEvents.run_finished.connect(_on_run_finished)

func begin_run() -> void:
	RuneSystem.reset()
	ExperienceSystem.reset()
	GameRuntime.start_run()

func _configure_player_camera() -> void:
	if player_camera == null:
		push_error("RunScene requires World/Player/Camera2D")
		return
	player_camera.enabled = true
	player_camera.make_current()
	if player_camera.is_current() == false:
		push_error("World/Player/Camera2D failed to become the current camera")

func _on_run_finished(result: String) -> void:
	var elapsed: float = float(run_timer.elapsed_seconds)
	GameEvents.settlement_requested.emit({
		"result": result,
		"survival_time": elapsed,
		"kills": hud.kills,
		"level": int(ExperienceSystem.level),
		"upgrades": GameEvents.get_selected_upgrade_summaries(),
		"map_objectives": GameEvents.get_map_objective_summary()
	})
