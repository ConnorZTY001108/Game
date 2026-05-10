extends SceneTree

const RouteSmokeHelper := preload("res://tests/helpers/augment_route_smoke_helper.gd")
const ROUTE_ID := "aegis_transmutation"
const SMOKE_NAME := "augment_aegis_loop.gd"
const COVERED_AUGMENT_IDS: Array[String] = [
	"aug_shield_egg",
	"aug_circle_of_death",
	"aug_critical_healing",
	"aug_windspeaker",
	"aug_sonic_holy",
	"aug_big_brain_barrier",
	"aug_faith_shockwave",
	"aug_laser_heal_array",
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = RouteSmokeHelper.run_route(self, ROUTE_ID, COVERED_AUGMENT_IDS, SMOKE_NAME)
	if failures.is_empty():
		print("PASS: %s covers 8 aegis_transmutation augments with runtime, UI, and proc assertions" % SMOKE_NAME)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
