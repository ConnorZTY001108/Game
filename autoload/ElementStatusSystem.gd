extends Node

var stacks_by_target: Dictionary = {}

func add_stack(target: Node, element_tag: String, amount: int, duration_seconds: float = 5.0) -> int:
	if target == null or not is_instance_valid(target):
		return 0
	if not stacks_by_target.has(target):
		stacks_by_target[target] = {}
	var element_map: Dictionary = stacks_by_target[target]
	var current: Dictionary = element_map.get(element_tag, {"stacks": 0, "duration": duration_seconds})
	current["stacks"] = int(current["stacks"]) + amount
	current["duration"] = duration_seconds
	element_map[element_tag] = current
	return int(current["stacks"])

func clear_stack(target: Node, element_tag: String) -> void:
	if stacks_by_target.has(target):
		var element_map: Dictionary = stacks_by_target[target]
		element_map.erase(element_tag)
		if element_map.is_empty():
			stacks_by_target.erase(target)

func _process(delta: float) -> void:
	for target in stacks_by_target.keys():
		if not is_instance_valid(target):
			stacks_by_target.erase(target)
			continue
		var element_map: Dictionary = stacks_by_target[target]
		for element_tag in element_map.keys():
			var current: Dictionary = element_map[element_tag]
			current["duration"] = float(current["duration"]) - delta
			if float(current["duration"]) <= 0.0:
				element_map.erase(element_tag)
		if element_map.is_empty():
			stacks_by_target.erase(target)
