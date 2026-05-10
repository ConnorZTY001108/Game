extends SceneTree

const RouteSmokeHelper := preload("res://tests/helpers/augment_route_smoke_helper.gd")
const ROUTE_ID := "colossus_furnace"
const SMOKE_NAME := "augment_colossus_loop.gd"
const COVERED_AUGMENT_IDS: Array[String] = [
	"aug_colossus_courage",
	"aug_cruel_comet",
	"aug_impassable",
	"aug_adamant_layers",
	"aug_soul_eater",
	"aug_immolate_engine",
	"aug_goliath",
	"aug_stuck_with_me",
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = RouteSmokeHelper.run_route(self, ROUTE_ID, COVERED_AUGMENT_IDS, SMOKE_NAME)
	if failures.is_empty():
		print("PASS: %s covers 8 colossus_furnace augments with runtime, UI, and proc assertions" % SMOKE_NAME)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
