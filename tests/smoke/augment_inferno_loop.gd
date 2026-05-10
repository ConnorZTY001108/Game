extends SceneTree

const RouteSmokeHelper := preload("res://tests/helpers/augment_route_smoke_helper.gd")
const ROUTE_ID := "inferno_conduit"
const SMOKE_NAME := "augment_inferno_loop.gd"
const COVERED_AUGMENT_IDS: Array[String] = [
	"aug_infernal_conduit",
	"aug_firebrand_runes",
	"aug_slow_cooker_aura",
	"aug_chili_oil",
	"aug_holy_fire_conversion",
	"aug_vulnerable_flame",
	"aug_tormentor_brand",
	"aug_infernal_detonation",
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = RouteSmokeHelper.run_route(self, ROUTE_ID, COVERED_AUGMENT_IDS, SMOKE_NAME)
	if failures.is_empty():
		print("PASS: %s covers 8 inferno_conduit augments with runtime, UI, and proc assertions" % SMOKE_NAME)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
