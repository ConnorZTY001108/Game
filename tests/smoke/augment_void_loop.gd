extends SceneTree

const RouteSmokeHelper := preload("res://tests/helpers/augment_route_smoke_helper.gd")
const ROUTE_ID := "void_cascade"
const SMOKE_NAME := "augment_void_loop.gd"
const COVERED_AUGMENT_IDS: Array[String] = [
	"aug_void_rift",
	"aug_magic_missile",
	"aug_trueshot_prod",
	"aug_erosion_loop",
	"aug_hextech_chain",
	"aug_pinball_rift",
	"aug_duality_charge",
	"aug_void_collapse",
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = RouteSmokeHelper.run_route(self, ROUTE_ID, COVERED_AUGMENT_IDS, SMOKE_NAME)
	if failures.is_empty():
		print("PASS: %s covers 8 void_cascade augments with runtime, UI, and proc assertions" % SMOKE_NAME)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
