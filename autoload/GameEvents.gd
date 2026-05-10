extends Node

signal run_started
signal run_paused(is_paused: bool)
signal run_finished(result: String)
signal player_died
signal enemy_died(enemy: Node, experience_value: int)
signal damage_applied(target: Node, amount: float, tags: Array[String])
signal weapon_hit(target: Node, payload: Dictionary)
signal experience_collected(amount: int)
signal level_changed(level: int)
signal level_up_requested(options: Array[Resource])
signal upgrade_selected(upgrade: Resource)
signal rune_triggered(rune_id: String, target: Node, payload: Dictionary)
