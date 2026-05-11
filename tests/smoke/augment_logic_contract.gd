extends SceneTree

const HarnessScript := preload("res://tests/helpers/augment_test_harness.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var harness = HarnessScript.new()
	failures.append_array(harness.setup(self, 424242))
	if not failures.is_empty():
		_finish(harness, failures)
		return

	var augments: Array = harness.get_augments()
	if augments.is_empty():
		failures.append("AugmentRegistry returned no production augments")

	var positive_ids: Array[String] = []
	var negative_ids: Array[String] = []
	var required_value_case_count := 0
	var cooldown_case_count := 0

	for augment_value in augments:
		var augment := augment_value as Resource
		if augment == null:
			failures.append("registry returned a null augment")
			continue
		var augment_id := str(augment.get("id"))
		_assert_positive_trigger_case(harness, augment, positive_ids, failures)
		_assert_negative_signal_case(harness, augment, negative_ids, failures)
		required_value_case_count += _assert_required_value_negative_cases(harness, augment, failures)
		cooldown_case_count += _assert_cooldown_cases(harness, augment, failures)
		_assert_visual_feedback_is_emitted_for_positive_case(harness, augment, failures)
		_assert_state_isolated_after_reset(harness, augment_id, failures)

	if positive_ids.size() != augments.size():
		failures.append("positive trigger coverage expected %d augments, got %d: %s" % [augments.size(), positive_ids.size(), positive_ids])
	if negative_ids.size() != augments.size():
		failures.append("negative trigger coverage expected %d augments, got %d: %s" % [augments.size(), negative_ids.size(), negative_ids])
	_assert_multi_augment_event_isolation(harness, augments, failures)
	print("augment_logic_contract covered %d positive cases, %d negative cases, %d required-value negative cases, %d cooldown/repeat cases" % [positive_ids.size(), negative_ids.size(), required_value_case_count, cooldown_case_count])
	_finish(harness, failures)

func _assert_positive_trigger_case(harness, augment: Resource, positive_ids: Array[String], failures: Array[String]) -> void:
	var augment_id := str(augment.get("id"))
	harness.reset_runtime()
	var before: Dictionary = harness.get_snapshot()
	if not bool(harness.install_augment(augment, {"smoke": "augment_logic_contract", "case": "positive"})):
		failures.append("%s positive case failed to acquire augment" % augment_id)
		return
	var signal_name: String = harness.primary_signal_name(augment)
	if signal_name != "augment_acquired":
		harness.emit_positive_trigger(augment, {"signal_name": signal_name})
	var after: Dictionary = harness.get_snapshot()
	var proc_delta: int = harness.proc_delta(augment_id, before, after)
	if proc_delta <= 0 and not bool(harness.any_runtime_artifact_delta(augment, before, after)):
		failures.append("%s did not trigger from positive signal %s; before=%s after=%s" % [augment_id, signal_name, before.get("augment_proc_counts", {}), after.get("augment_proc_counts", {})])
		return
	positive_ids.append(augment_id)
	_assert_every_effect_observable(harness, augment, before, after, failures)
	_assert_trigger_metadata_recorded(harness, augment, after, failures)

func _assert_negative_signal_case(harness, augment: Resource, negative_ids: Array[String], failures: Array[String]) -> void:
	var augment_id := str(augment.get("id"))
	harness.reset_runtime()
	if not bool(harness.install_augment(augment, {"smoke": "augment_logic_contract", "case": "negative_signal"})):
		failures.append("%s negative case failed to acquire augment" % augment_id)
		return
	var before: Dictionary = harness.get_snapshot()
	var negative_signal: String = harness.emit_negative_trigger(augment)
	var after: Dictionary = harness.get_snapshot()
	var delta: int = harness.proc_delta(augment_id, before, after)
	if delta != 0:
		failures.append("%s triggered on wrong signal %s; proc_delta=%d" % [augment_id, negative_signal, delta])
		return
	negative_ids.append(augment_id)

func _assert_required_value_negative_cases(harness, augment: Resource, failures: Array[String]) -> int:
	var cases := 0
	var augment_id := str(augment.get("id"))
	var trigger_spec: Dictionary = harness.trigger_spec_dictionary(augment)
	var required_values: Dictionary = trigger_spec.get("required_packet_values", {})
	if required_values.is_empty() or harness.primary_signal_name(augment) == "augment_acquired":
		return 0
	for key in required_values.keys():
		cases += 1
		harness.reset_runtime()
		if not bool(harness.install_augment(augment, {"smoke": "augment_logic_contract", "case": "negative_required_value", "field": str(key)})):
			failures.append("%s required-value case failed to acquire augment" % augment_id)
			continue
		var before: Dictionary = harness.get_snapshot()
		var packet: Dictionary = harness.make_packet_for_augment(augment)
		packet[str(key)] = "__augment_contract_negative_value__"
		harness.emit_signal_event(harness.primary_signal_name(augment), harness.trigger_id(augment), packet, {"owner": harness.owner, "target": harness.target})
		var after: Dictionary = harness.get_snapshot()
		var delta: int = harness.proc_delta(augment_id, before, after)
		if delta != 0:
			failures.append("%s triggered despite mismatched required_packet_value %s; expected %s" % [augment_id, str(key), str(required_values[key])])
	return cases

func _assert_cooldown_cases(harness, augment: Resource, failures: Array[String]) -> int:
	var augment_id := str(augment.get("id"))
	var primary_signal: String = harness.primary_signal_name(augment)
	if primary_signal == "augment_acquired":
		return 0
	var has_declared_cooldown := false
	var trigger_spec: Dictionary = harness.trigger_spec_dictionary(augment)
	if float(trigger_spec.get("source_cooldown", 0.0)) > 0.0 or float(trigger_spec.get("per_target_cooldown", 0.0)) > 0.0:
		has_declared_cooldown = true
	for effect_spec in harness.effect_spec_array(augment):
		var params: Dictionary = effect_spec.get("params", {})
		if float(effect_spec.get("source_cooldown", 0.0)) > 0.0 or float(effect_spec.get("per_target_cooldown", 0.0)) > 0.0 or float(params.get("source_cooldown", 0.0)) > 0.0 or float(params.get("per_target_cooldown", 0.0)) > 0.0:
			has_declared_cooldown = true
	if not has_declared_cooldown:
		return 0

	harness.reset_runtime()
	if not bool(harness.install_augment(augment, {"smoke": "augment_logic_contract", "case": "cooldown"})):
		failures.append("%s cooldown case failed to acquire augment" % augment_id)
		return 1
	var packet: Dictionary = harness.make_packet_for_augment(augment)
	harness.emit_signal_event(primary_signal, harness.trigger_id(augment), packet, {"owner": harness.owner, "target": harness.target})
	var after_first: Dictionary = harness.get_snapshot()
	harness.emit_signal_event(primary_signal, harness.trigger_id(augment), packet, {"owner": harness.owner, "target": harness.target})
	var after_second: Dictionary = harness.get_snapshot()
	var second_delta: int = harness.proc_delta(augment_id, after_first, after_second)
	var blocked_counts: Dictionary = after_second.get("blocked_counts", {})
	var has_block := int(blocked_counts.get("source_cooldown", 0)) > 0 or int(blocked_counts.get("per_target_cooldown", 0)) > 0
	if second_delta > 0 and not has_block:
		failures.append("%s declares cooldown but repeated same-source event triggered again without cooldown block" % augment_id)
	return 1

func _assert_visual_feedback_is_emitted_for_positive_case(harness, augment: Resource, failures: Array[String]) -> void:
	var augment_id := str(augment.get("id"))
	harness.reset_runtime()
	var before_visuals: int = harness.captured_visual_events.size()
	var before_feedback: int = harness.captured_feedback_events.size()
	if not bool(harness.install_augment(augment, {"smoke": "augment_logic_contract", "case": "visual_feedback"})):
		failures.append("%s visual feedback case failed to acquire augment" % augment_id)
		return
	var expected_visual_baseline: int = before_visuals
	var expected_feedback_baseline: int = before_feedback
	if harness.primary_signal_name(augment) != "augment_acquired":
		expected_visual_baseline = harness.captured_visual_events.size()
		expected_feedback_baseline = harness.captured_feedback_events.size()
		harness.emit_positive_trigger(augment)
	var visual_delta: int = harness.captured_visual_events.size() - expected_visual_baseline
	var feedback_delta: int = harness.captured_feedback_events.size() - expected_feedback_baseline
	var signature: Dictionary = harness.visual_signature_for_augment(augment)
	if str(signature.get("missing_reason", "")) != "":
		failures.append("%s has no visual signature for positive feedback case: %s" % [augment_id, str(signature.get("missing_reason", ""))])
	elif visual_delta <= 0 and feedback_delta <= 0:
		failures.append("%s positive trigger emitted no augment_visual_played or feedback_requested event" % augment_id)

func _assert_every_effect_observable(harness, augment: Resource, before: Dictionary, after: Dictionary, failures: Array[String]) -> void:
	var augment_id := str(augment.get("id"))
	var expected: Dictionary = harness.expected_effect_counts(augment)
	for effect_type in expected.keys():
		var delta: int = harness.effect_count_delta(str(effect_type), before, after)
		if delta < int(expected[effect_type]):
			failures.append("%s positive case did not execute effect %s; delta=%d expected_at_least=%d" % [augment_id, str(effect_type), delta, int(expected[effect_type])])
		var artifact_keys: Array[String] = harness.artifact_keys_for_effect(str(effect_type))
		if artifact_keys.is_empty():
			failures.append("%s effect %s has no artifact mapping in AugmentTestHarness" % [augment_id, str(effect_type)])
		elif not bool(harness.any_snapshot_key_changed(before, after, artifact_keys)):
			failures.append("%s effect %s executed but no observable artifact changed in %s" % [augment_id, str(effect_type), artifact_keys])

func _assert_trigger_metadata_recorded(harness, augment: Resource, after: Dictionary, failures: Array[String]) -> void:
	var augment_id := str(augment.get("id"))
	var last_triggers: Dictionary = after.get("last_trigger_by_augment", {})
	if not last_triggers.has(augment_id):
		failures.append("%s did not record last_trigger_by_augment" % augment_id)
		return
	var entry: Dictionary = last_triggers.get(augment_id, {})
	if str(entry.get("trigger_id", "")) == "":
		failures.append("%s last trigger metadata missing trigger_id" % augment_id)
	if str(entry.get("signal_name", "")) == "":
		failures.append("%s last trigger metadata missing signal_name" % augment_id)

func _assert_state_isolated_after_reset(harness, augment_id: String, failures: Array[String]) -> void:
	harness.reset_runtime()
	var snapshot: Dictionary = harness.get_snapshot()
	for key in ["ranks", "owned_ids", "augment_proc_counts", "effect_counts", "generated_packets", "active_counts", "blocked_counts", "visual_events"]:
		var value = snapshot.get(key, [] if key == "generated_packets" or key == "visual_events" else {})
		if value is Array and not (value as Array).is_empty():
			failures.append("%s reset leaked array state for %s: %s" % [augment_id, key, value])
		elif value is Dictionary and not (value as Dictionary).is_empty():
			failures.append("%s reset leaked dictionary state for %s: %s" % [augment_id, key, value])

func _assert_multi_augment_event_isolation(harness, augments: Array, failures: Array[String]) -> void:
	var by_signal := {}
	for augment_value in augments:
		var augment := augment_value as Resource
		if augment == null:
			continue
		var signal_name: String = harness.primary_signal_name(augment)
		if signal_name == "augment_acquired":
			continue
		if not by_signal.has(signal_name):
			by_signal[signal_name] = []
		(by_signal[signal_name] as Array).append(augment)
	var checked_pairs := 0
	for signal_name in by_signal.keys():
		var group: Array = by_signal[signal_name]
		if group.size() < 2:
			continue
		for index in range(0, group.size() - 1):
			if checked_pairs >= 12:
				return
			var first := group[index] as Resource
			var second := group[index + 1] as Resource
			if first == null or second == null:
				continue
			checked_pairs += 1
			harness.reset_runtime()
			if not bool(harness.install_augment(first, {"smoke": "augment_logic_contract", "case": "multi", "slot": "first"})):
				failures.append("multi-augment case failed to acquire %s" % str(first.get("id")))
				continue
			if not bool(harness.install_augment(second, {"smoke": "augment_logic_contract", "case": "multi", "slot": "second"})):
				failures.append("multi-augment case failed to acquire %s" % str(second.get("id")))
				continue
			var before: Dictionary = harness.get_snapshot()
			harness.emit_positive_trigger(first)
			harness.emit_positive_trigger(second)
			var after: Dictionary = harness.get_snapshot()
			if harness.proc_delta(str(first.get("id")), before, after) <= 0:
				failures.append("multi-augment same-signal case swallowed %s on %s" % [str(first.get("id")), str(signal_name)])
			if harness.proc_delta(str(second.get("id")), before, after) <= 0:
				failures.append("multi-augment same-signal case swallowed %s on %s" % [str(second.get("id")), str(signal_name)])

func _finish(harness, failures: Array[String]) -> void:
	if harness != null:
		harness.cleanup()
	if failures.is_empty():
		print("PASS: augment_logic_contract")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
