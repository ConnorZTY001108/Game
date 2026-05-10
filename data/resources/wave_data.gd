class_name WaveData
extends Resource

@export var id: String = ""
@export var duration_seconds: float = 180.0
@export var spawn_interval: float = 1.2
@export var max_alive: int = 40
@export var spawn_radius: float = 760.0
@export var enemy_data: Resource
@export var phases: Array[Dictionary] = []

func get_phase_at_time(elapsed_seconds: float) -> Dictionary:
	if phases.is_empty():
		return _legacy_phase()

	var clamped_elapsed := maxf(0.0, elapsed_seconds)
	var fallback_phase := _normalize_phase(phases[0])
	for phase in phases:
		var normalized := _normalize_phase(phase)
		var start_time := float(normalized.get("start_time", 0.0))
		var duration := float(normalized.get("duration", duration_seconds))
		if clamped_elapsed >= start_time:
			fallback_phase = normalized
		if clamped_elapsed >= start_time and clamped_elapsed < start_time + duration:
			return normalized
	return fallback_phase

func _legacy_phase() -> Dictionary:
	var pool: Array[Resource] = []
	if enemy_data != null:
		pool.append(enemy_data)
	return {
		"start_time": 0.0,
		"duration": duration_seconds,
		"spawn_interval": spawn_interval,
		"max_alive": max_alive,
		"spawn_radius": spawn_radius,
		"enemy_pool": pool
	}

func _normalize_phase(phase: Dictionary) -> Dictionary:
	var result := _legacy_phase()
	for key in phase.keys():
		result[key] = phase[key]
	var pool = result.get("enemy_pool", [])
	if not pool is Array or pool.is_empty():
		var fallback_pool: Array[Resource] = []
		if enemy_data != null:
			fallback_pool.append(enemy_data)
		result["enemy_pool"] = fallback_pool
	return result
