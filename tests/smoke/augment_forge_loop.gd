extends SceneTree

const RouteSmokeHelper := preload("res://tests/helpers/augment_route_smoke_helper.gd")
const ROUTE_ID := "quest_forge"
const SMOKE_NAME := "augment_forge_loop.gd"
const COVERED_AUGMENT_IDS: Array[String] = [
	"aug_stats_forge",
	"aug_stats_on_stats",
	"aug_red_envelope",
	"aug_goldrend",
	"aug_pandora_box",
	"aug_transmute_chaos",
	"aug_urf_champion",
	"aug_mobile_zhonya",
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = RouteSmokeHelper.run_route(self, ROUTE_ID, COVERED_AUGMENT_IDS, SMOKE_NAME)
	if failures.is_empty():
		print("PASS: %s covers 8 quest_forge augments with runtime, UI, and proc assertions" % SMOKE_NAME)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
