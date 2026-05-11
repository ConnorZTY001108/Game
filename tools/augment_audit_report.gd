extends SceneTree

const HarnessScript := preload("res://tests/helpers/augment_test_harness.gd")
const SPEC_JSON_PATH := "res://docs/qa/augment-test-specs.json"
const COVERAGE_REPORT_PATH := "res://docs/qa/augment-description-coverage.md"
const VISUAL_REPORT_PATH := "res://docs/qa/augment-visual-differentiation.md"
const VISUAL_SIGNATURE_JSON_PATH := "res://docs/qa/augment-visual-signatures.json"
const ACCEPTANCE_REPORT_PATH := "res://docs/qa/augment-system-acceptance.md"
const COLLISION_THRESHOLD := 0.90
const CLUSTER_MIN_SIZE := 5

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var harness = HarnessScript.new()
	failures.append_array(harness.setup(self, 717171))
	if not failures.is_empty():
		_finish(harness, failures, true)
		return

	var augments: Array = harness.get_augments()
	var specs: Array[Dictionary] = []
	var description_rows: Array[Dictionary] = []
	var signatures: Array[Dictionary] = []
	var description_failures: Array[String] = []
	var description_manual_count := 0
	var total_verifiable := 0
	var total_covered := 0
	var total_undocumented := 0

	for augment_value in augments:
		var augment := augment_value as Resource
		if augment == null:
			continue
		var spec := harness.build_machine_spec(augment)
		var augment_id := str(spec.get("augment_id", ""))
		var covered: Array[Dictionary] = []
		var uncovered: Array[Dictionary] = []
		var manual: Array[Dictionary] = []
		for claim_value in spec.get("parsed_claims", []):
			var claim := claim_value as Dictionary
			if claim == null:
				continue
			if bool(claim.get("verifiable", false)):
				total_verifiable += 1
				if (claim.get("mapped_assertions", []) as Array).is_empty():
					uncovered.append(claim)
				else:
					covered.append(claim)
					total_covered += 1
			else:
				manual.append(claim)
		var undocumented := harness.undocumented_behaviors(augment)
		total_undocumented += undocumented.size()
		var status := "PASS"
		if not uncovered.is_empty() or not undocumented.is_empty():
			status = "FAIL"
			description_failures.append("%s uncovered=%d undocumented=%d" % [augment_id, uncovered.size(), undocumented.size()])
		elif not manual.is_empty():
			status = "MANUAL_REVIEW"
			description_manual_count += 1
		var row := {
			"augment_id": augment_id,
			"display_name": str(spec.get("display_name", "")),
			"route_id": str(augment.get("route_id")),
			"rarity": str(augment.get("rarity")),
			"description_text": str(spec.get("description_text", "")),
			"covered_claims": covered,
			"uncovered_claims": uncovered,
			"manual_review_claims": manual,
			"undocumented_behaviors": undocumented,
			"test_files": ["tests/smoke/augment_logic_contract.gd", "tests/smoke/augment_description_coverage.gd"],
			"status": status,
		}
		description_rows.append(row)
		spec["description_coverage"] = row
		specs.append(spec)
		var signature := harness.visual_signature_for_augment(augment)
		signature["augment_id"] = augment_id
		signature["display_name"] = str(augment.get("display_name"))
		signature["route_id"] = str(augment.get("route_id"))
		signature["rarity"] = str(augment.get("rarity"))
		signatures.append(signature)

	var missing_visuals := harness.visual_missing_identities(augments)
	var visual_collisions := harness.visual_collision_pairs(augments, COLLISION_THRESHOLD)
	var visual_clusters := harness.visual_homogenized_clusters(augments, CLUSTER_MIN_SIZE)

	harness.write_json_file(SPEC_JSON_PATH, specs)
	harness.write_json_file(VISUAL_SIGNATURE_JSON_PATH, signatures)
	_write_description_report(harness, description_rows, total_verifiable, total_covered, description_manual_count, total_undocumented)
	_write_visual_report(harness, signatures, missing_visuals, visual_collisions, visual_clusters)
	_write_acceptance_report(harness, augments, specs, description_failures, description_manual_count, missing_visuals, visual_collisions, visual_clusters)

	var fail_on_audit := OS.get_cmdline_args().has("--fail-on-audit")
	var audit_failures: Array[String] = []
	audit_failures.append_array(description_failures)
	for entry in missing_visuals:
		audit_failures.append("missing visual: %s" % str(entry.get("augment_id", "")))
	for entry in visual_collisions:
		audit_failures.append("visual collision %.2f: %s vs %s" % [float(entry.get("similarity", 0.0)), str(entry.get("left", "")), str(entry.get("right", ""))])
	for entry in visual_clusters:
		audit_failures.append("visual cluster: %s" % str(entry.get("cluster_key", "")))
	print("augment audit wrote %s, %s, %s, %s" % [SPEC_JSON_PATH, COVERAGE_REPORT_PATH, VISUAL_REPORT_PATH, ACCEPTANCE_REPORT_PATH])
	_finish(harness, audit_failures, fail_on_audit)

func _write_description_report(harness, rows: Array[Dictionary], total_verifiable: int, total_covered: int, manual_count: int, total_undocumented: int) -> void:
	var pass_count := 0
	var fail_count := 0
	for row in rows:
		if str(row.get("status", "")) == "PASS":
			pass_count += 1
		elif str(row.get("status", "")) == "FAIL":
			fail_count += 1
	var lines: Array[String] = []
	lines.append("# Augment Description Coverage")
	lines.append("")
	lines.append("Generated by `tools/augment_audit_report.gd`.")
	lines.append("")
	lines.append("| Metric | Value |")
	lines.append("|---|---:|")
	lines.append("| Augments scanned | %d |" % rows.size())
	lines.append("| PASS | %d |" % pass_count)
	lines.append("| FAIL | %d |" % fail_count)
	lines.append("| MANUAL_REVIEW | %d |" % manual_count)
	lines.append("| Verifiable claims | %d |" % total_verifiable)
	lines.append("| Covered verifiable claims | %d |" % total_covered)
	lines.append("| Undocumented runtime behaviors | %d |" % total_undocumented)
	lines.append("")
	for row in rows:
		lines.append("## %s — %s" % [str(row.get("augment_id", "")), str(row.get("display_name", ""))])
		lines.append("")
		lines.append("- Status: **%s**" % str(row.get("status", "")))
		lines.append("- Test files: `%s`" % "`, `".join(_string_array(row.get("test_files", []))))
		lines.append("- Description: %s" % str(row.get("description_text", "")).replace("\n", " / "))
		lines.append("- Covered claims: %d" % (row.get("covered_claims", []) as Array).size())
		lines.append("- Uncovered claims: %d" % (row.get("uncovered_claims", []) as Array).size())
		for claim in row.get("uncovered_claims", []):
			var claim_dict := claim as Dictionary
			if claim_dict != null:
				lines.append("  - %s" % str(claim_dict.get("text", "")))
		lines.append("- Undocumented behavior: `%s`" % "`, `".join(_string_array(row.get("undocumented_behaviors", []))))
		lines.append("")
	harness.write_markdown_file(COVERAGE_REPORT_PATH, lines)

func _write_visual_report(harness, signatures: Array[Dictionary], missing: Array[Dictionary], collisions: Array[Dictionary], clusters: Array[Dictionary]) -> void:
	var lines: Array[String] = []
	lines.append("# Augment Visual Differentiation")
	lines.append("")
	lines.append("Generated by `tools/augment_audit_report.gd`.")
	lines.append("")
	lines.append("| Metric | Value |")
	lines.append("|---|---:|")
	lines.append("| Augments scanned | %d |" % signatures.size())
	lines.append("| Missing visual identity | %d |" % missing.size())
	lines.append("| Similarity collisions | %d |" % collisions.size())
	lines.append("| Homogenized clusters | %d |" % clusters.size())
	lines.append("")
	lines.append("## Missing visual identity")
	if missing.is_empty():
		lines.append("- none")
	else:
		for entry in missing:
			lines.append("- `%s`: %s" % [str(entry.get("augment_id", "")), str(entry.get("reason", ""))])
	lines.append("")
	lines.append("## Similarity collisions")
	if collisions.is_empty():
		lines.append("- none")
	else:
		for entry in collisions:
			lines.append("- `%.2f` `%s` ↔ `%s`" % [float(entry.get("similarity", 0.0)), str(entry.get("left", "")), str(entry.get("right", ""))])
	lines.append("")
	lines.append("## Homogenized clusters")
	if clusters.is_empty():
		lines.append("- none")
	else:
		for entry in clusters:
			lines.append("- `%s` size=%d: `%s`" % [str(entry.get("cluster_key", "")), int(entry.get("size", 0)), "`, `".join(_string_array(entry.get("augment_ids", [])))])
	lines.append("")
	lines.append("## Signatures")
	lines.append("| augment_id | route | rarity | primary | secondary | shape | animation | anchor | duration | scale | particle/trail | screen | audio |")
	lines.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	for signature in signatures:
		lines.append("| `%s` | `%s` | `%s` | `%s` | `%s` | `%s` | `%s` | `%s` | `%s` | `%s` | `%s` | `%s` | `%s` |" % [
			str(signature.get("augment_id", "")),
			str(signature.get("route_id", "")),
			str(signature.get("rarity", "")),
			str(signature.get("primary_color", "")),
			str(signature.get("secondary_color", "")),
			str(signature.get("shape_family", "")),
			str(signature.get("animation_type", "")),
			str(signature.get("spawn_anchor", "")),
			str(signature.get("duration_bucket", "")),
			str(signature.get("scale_bucket", "")),
			str(signature.get("particle_or_trail_usage", "")),
			str(signature.get("screen_feedback_usage", "")),
			str(signature.get("audio_feedback_key", "")),
		])
	harness.write_markdown_file(VISUAL_REPORT_PATH, lines)

func _write_acceptance_report(harness, augments: Array, specs: Array[Dictionary], description_failures: Array[String], description_manual_count: int, missing_visuals: Array[Dictionary], visual_collisions: Array[Dictionary], visual_clusters: Array[Dictionary]) -> void:
	var logic_summary: Dictionary = _logic_coverage_summary(specs)
	var logic_status: String = "PASS" if int(logic_summary.get("positive", 0)) == specs.size() and int(logic_summary.get("negative", 0)) == specs.size() and specs.size() == augments.size() and specs.size() > 0 else "FAIL"
	var lines: Array[String] = []
	lines.append("## Auto Augment Acceptance Audit")
	lines.append("")
	lines.append("Generated by `tools/augment_audit_report.gd`.")
	lines.append("")
	lines.append("### Current code surface")
	lines.append("")
	lines.append("- `AugmentRegistry` scans `res://data/content/augments` and validates `AugmentData` resources.")
	lines.append("- `AugmentData` already carries `trigger_spec`, `effect_spec_blueprint`, runtime trigger/effect resources, manifest fields and player-facing copy.")
	lines.append("- `AugmentSystem` owns runtime state, bridges `GameEvents` into trigger matching, and provides `emit_synthetic_event` for deterministic smoke tests.")
	lines.append("- `AugmentEffectRunner` executes effect resources and records observable runtime artifacts through `AugmentRuntimeState`.")
	lines.append("- `AugmentVisualDirector` and `AugmentVisualRegistry` provide visual specs and emit `augment_visual_played`/feedback events.")
	lines.append("")
	lines.append("### Test commands")
	lines.append("")
	lines.append("```bash")
	lines.append("godot --headless --path . --script tests/smoke/augment_logic_contract.gd")
	lines.append("godot --headless --path . --script tests/smoke/augment_description_coverage.gd")
	lines.append("godot --headless --path . --script tests/smoke/augment_visual_differentiation.gd")
	lines.append("godot --headless --path . --script tools/augment_audit_report.gd")
	lines.append("godot --headless --path . --script tools/augment_audit_report.gd --fail-on-audit")
	lines.append("```")
	lines.append("")
	lines.append("### Acceptance status")
	lines.append("")
	lines.append("| Area | Status | Evidence |")
	lines.append("|---|---|---|")
	lines.append("| All current augments have machine specs | %s | `%s` entries written to `docs/qa/augment-test-specs.json` |" % ["PASS" if specs.size() == augments.size() and specs.size() > 0 else "FAIL", specs.size()])
	lines.append("| Positive/negative trigger cases | %s | Automated refs cover %d positive, %d negative, and %d visual-feedback cases across `%d` specs; `tests/smoke/augment_logic_contract.gd` is the live smoke. |" % [
		logic_status,
		int(logic_summary.get("positive", 0)),
		int(logic_summary.get("negative", 0)),
		int(logic_summary.get("visual_feedback", 0)),
		specs.size(),
	])
	lines.append("| Description claim coverage | %s | %d failing rows, %d manual-review rows |" % ["PASS" if description_failures.is_empty() else "FAIL", description_failures.size(), description_manual_count])
	lines.append("| Visual signatures | %s | %d missing identities |" % ["PASS" if missing_visuals.is_empty() else "FAIL", missing_visuals.size()])
	lines.append("| Visual differentiation | %s | %d collisions, %d homogenized clusters |" % ["PASS" if visual_collisions.is_empty() and visual_clusters.is_empty() else "FAIL", visual_collisions.size(), visual_clusters.size()])
	lines.append("")
	lines.append("### Current failing augments and reasons")
	lines.append("")
	lines.append("#### Description not implemented / not tested")
	if description_failures.is_empty():
		lines.append("- none")
	else:
		for failure in description_failures:
			lines.append("- %s" % failure)
	lines.append("")
	lines.append("#### Missing visual identity")
	if missing_visuals.is_empty():
		lines.append("- none")
	else:
		for entry in missing_visuals:
			lines.append("- `%s`: %s" % [str(entry.get("augment_id", "")), str(entry.get("reason", ""))])
	lines.append("")
	lines.append("#### Visual collisions")
	if visual_collisions.is_empty():
		lines.append("- none")
	else:
		for entry in visual_collisions:
			lines.append("- `%.2f` `%s` ↔ `%s`" % [float(entry.get("similarity", 0.0)), str(entry.get("left", "")), str(entry.get("right", ""))])
	lines.append("")
	lines.append("#### Homogenized visual clusters")
	if visual_clusters.is_empty():
		lines.append("- none")
	else:
		for entry in visual_clusters:
			lines.append("- `%s` size=%d: `%s`" % [str(entry.get("cluster_key", "")), int(entry.get("size", 0)), "`, `".join(_string_array(entry.get("augment_ids", [])))])
	lines.append("")
	lines.append("### Manual design decisions")
	lines.append("")
	lines.append("- Claims classified as `manual_review` usually describe fantasy/flavor, build fit, or risk text that is not directly observable in current runtime state.")
	lines.append("- Visual collisions should be reviewed by design/art before changing color/shape/motion, because the detector intentionally flags semantic sameness rather than pixel output.")
	_upsert_acceptance_section(harness, lines)

func _logic_coverage_summary(specs: Array[Dictionary]) -> Dictionary:
	var positive_count := 0
	var negative_count := 0
	var visual_feedback_count := 0
	for spec in specs:
		var refs: Array[String] = _string_array(spec.get("assertion_refs", []))
		if _has_ref_prefix(refs, "tests/smoke/augment_logic_contract.gd::positive_trigger:"):
			positive_count += 1
		if _has_ref_prefix(refs, "tests/smoke/augment_logic_contract.gd::negative_trigger:"):
			negative_count += 1
		if _has_ref_prefix(refs, "tests/smoke/augment_logic_contract.gd::visual_feedback:"):
			visual_feedback_count += 1
	return {
		"positive": positive_count,
		"negative": negative_count,
		"visual_feedback": visual_feedback_count,
	}

func _has_ref_prefix(refs: Array[String], prefix: String) -> bool:
	for ref in refs:
		if ref.begins_with(prefix):
			return true
	return false

func _upsert_acceptance_section(harness, lines: Array[String]) -> void:
	var begin_marker := "## Auto Augment Acceptance Audit"
	var end_marker := "## End Auto Augment Acceptance Audit"
	var section := "\n".join(lines) + "\n\n" + end_marker + "\n"
	var existing := ""
	if FileAccess.file_exists(ACCEPTANCE_REPORT_PATH):
		existing = FileAccess.get_file_as_string(ACCEPTANCE_REPORT_PATH)
	if existing.strip_edges() == "":
		harness.write_text_file(ACCEPTANCE_REPORT_PATH, section)
		return
	var begin_index := existing.find(begin_marker)
	if begin_index >= 0:
		var end_index := existing.find(end_marker, begin_index)
		if end_index >= 0:
			var after_end := end_index + end_marker.length()
			if after_end < existing.length() and existing.substr(after_end, 1) == "\n":
				after_end += 1
			var updated := existing.substr(0, begin_index).rstrip("\n") + "\n\n" + section + existing.substr(after_end)
			harness.write_text_file(ACCEPTANCE_REPORT_PATH, updated)
			return
	var appended := existing.rstrip("\n") + "\n\n" + section
	harness.write_text_file(ACCEPTANCE_REPORT_PATH, appended)

func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result

func _finish(harness, failures: Array[String], fail_on_audit: bool) -> void:
	if harness != null:
		harness.cleanup()
	if failures.is_empty():
		print("PASS: augment_audit_report")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1 if fail_on_audit else 0)
