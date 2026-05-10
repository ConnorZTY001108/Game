extends Node

func apply_damage(target: Node, amount: float, tags: Array[String], payload: Dictionary = {}) -> void:
	if target == null or not target.has_method("apply_damage"):
		return
	target.apply_damage(amount, tags)
	GameEvents.weapon_hit.emit(target, payload.duplicate(true))
