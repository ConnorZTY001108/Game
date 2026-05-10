class_name RunScene
extends Node2D

const PlayerScript := preload("res://scripts/player/Player.gd")
const RunTimerSystemScript := preload("res://scripts/systems/RunTimerSystem.gd")
const HUDScript := preload("res://scripts/ui/HUD.gd")
const DebugOverlayScript := preload("res://scripts/ui/DebugOverlay.gd")

@onready var player: PlayerScript = $World/Player
@onready var run_timer: RunTimerSystemScript = $Systems/RunTimerSystem
@onready var hud: HUDScript = $CanvasLayer/HUD
@onready var debug_overlay: DebugOverlayScript = $CanvasLayer/DebugOverlay

func _ready() -> void:
	RuneSystem.reset()
	ExperienceSystem.reset()
	hud.bind_player(player)
	hud.bind_timer(run_timer)
	debug_overlay.enemies_path = ^"../../World/Enemies"
	debug_overlay.projectiles_path = ^"../../World/Projectiles"
	debug_overlay.pickups_path = ^"../../World/Pickups"
	GameRuntime.start_run()
