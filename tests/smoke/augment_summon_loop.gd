extends SceneTree

const RouteSmokeHelper := preload("res://tests/helpers/augment_route_smoke_helper.gd")
const ROUTE_ID := "summon_engine"
const SMOKE_NAME := "augment_summon_loop.gd"
const COVERED_AUGMENT_IDS: Array[String] = [
	"aug_orbital_laser",
	"aug_quantum_slash",
	"aug_boomerang",
	"aug_firefox",
	"aug_poro_blaster",
	"aug_minionmancer",
	"aug_hand_of_baron",
	"aug_divine_intervention",
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = RouteSmokeHelper.run_route(self, ROUTE_ID, COVERED_AUGMENT_IDS, SMOKE_NAME)
	if failures.is_empty():
		print("PASS: %s covers 8 summon_engine augments with runtime, UI, and proc assertions" % SMOKE_NAME)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
