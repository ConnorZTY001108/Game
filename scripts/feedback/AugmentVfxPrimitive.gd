extends CanvasItem

@export var lifetime_seconds: float = 0.75
@export var motion: String = "pulse"

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var tween := create_tween()
	tween.set_parallel(true)
	if tween.has_method("set_pause_mode"):
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 0.0, lifetime_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var current_position = get("position")
	if current_position is Vector2:
		tween.tween_property(self, "position", current_position + _motion_offset(motion), lifetime_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var current_scale = get("scale")
	if current_scale is Vector2:
		tween.tween_property(self, "scale", current_scale * 1.35, lifetime_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(queue_free)

func _motion_offset(motion_name: String) -> Vector2:
	if motion_name.contains("forward") or motion_name.contains("sweep") or motion_name.contains("dash"):
		return Vector2(54.0, 0.0)
	if motion_name.contains("rise") or motion_name.contains("pop") or motion_name.contains("glow"):
		return Vector2(0.0, -38.0)
	if motion_name.contains("pull") or motion_name.contains("collapse") or motion_name.contains("inward"):
		return Vector2(-18.0, -18.0)
	if motion_name.contains("jump") or motion_name.contains("fork") or motion_name.contains("snap"):
		return Vector2(30.0, -28.0)
	return Vector2(0.0, -24.0)
