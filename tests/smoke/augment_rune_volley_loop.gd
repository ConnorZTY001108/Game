extends SceneTree

const RouteSmokeHelper := preload("res://tests/helpers/augment_route_smoke_helper.gd")
const ROUTE_ID := "rune_volley"
const SMOKE_NAME := "augment_rune_volley_loop.gd"
const COVERED_AUGMENT_IDS: Array[String] = [
	"aug_rune_dual_wield",
	"aug_typhoon_split",
	"aug_jeweled_rune",
	"aug_critical_shards",
	"aug_ethereal_weapon",
	"aug_press_chain",
	"aug_crit_cast_engine",
	"aug_collector_mark",
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = RouteSmokeHelper.run_route(self, ROUTE_ID, COVERED_AUGMENT_IDS, SMOKE_NAME)
	if failures.is_empty():
		print("PASS: %s covers 8 rune_volley augments with runtime, UI, and proc assertions" % SMOKE_NAME)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
