extends SceneTree

const RouteSmokeHelper := preload("res://tests/helpers/augment_route_smoke_helper.gd")
const ROUTE_ID := "snowstep_vanguard"
const SMOKE_NAME := "augment_snowstep_loop.gd"
const COVERED_AUGMENT_IDS: Array[String] = [
	"aug_holy_snowmark",
	"aug_flash2",
	"aug_flashbang",
	"aug_dashing_engine",
	"aug_shadow_runner",
	"aug_poro_king_bounce",
	"aug_dropkick_dash",
	"aug_speed_demon",
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = RouteSmokeHelper.run_route(self, ROUTE_ID, COVERED_AUGMENT_IDS, SMOKE_NAME)
	if failures.is_empty():
		print("PASS: %s covers 8 snowstep_vanguard augments with runtime, UI, and proc assertions" % SMOKE_NAME)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
