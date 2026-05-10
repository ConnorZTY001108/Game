extends SceneTree

const RouteSmokeHelper := preload("res://tests/helpers/augment_route_smoke_helper.gd")
const ROUTE_ID := "blood_reaver"
const SMOKE_NAME := "augment_blood_loop.gd"
const COVERED_AUGMENT_IDS: Array[String] = [
	"aug_ominous_pact",
	"aug_devil_shoulder",
	"aug_vampirism",
	"aug_escape_plan",
	"aug_dawn_resolve",
	"aug_blood_debt_execute",
	"aug_final_transit",
	"aug_glass_cannon",
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = RouteSmokeHelper.run_route(self, ROUTE_ID, COVERED_AUGMENT_IDS, SMOKE_NAME)
	if failures.is_empty():
		print("PASS: %s covers 8 blood_reaver augments with runtime, UI, and proc assertions" % SMOKE_NAME)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
