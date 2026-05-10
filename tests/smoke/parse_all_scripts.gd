extends SceneTree

const REQUIRED_SCRIPT_PATHS: Array[String] = [
	"res://autoload/DamageSystem.gd",
	"res://autoload/ElementStatusSystem.gd",
	"res://autoload/ExperienceSystem.gd",
	"res://autoload/RuneSystem.gd",
	"res://autoload/UpgradeSystem.gd",
	"res://scripts/components/StatusReceiver.gd",
	"res://scripts/systems/DropSystem.gd",
	"res://scripts/pickups/ExperiencePickup.gd",
	"res://scripts/ui/LevelUpPanel.gd",
	"res://scripts/projectiles/Projectile.gd",
	"res://scripts/weapons/WeaponController.gd"
]

func _initialize() -> void:
	var failures: Array[String] = []
	for script_path in REQUIRED_SCRIPT_PATHS:
		if ResourceLoader.exists(script_path) == false:
			failures.append("Missing required script: %s" % script_path)
	_scan_dir("res://", failures)
	if failures.is_empty():
		print("PASS: all scripts loaded")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _scan_dir(path: String, failures: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		failures.append("Cannot open directory: %s" % path)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full_path := path.path_join(entry)
		if dir.current_is_dir():
			_scan_dir(full_path, failures)
		elif entry.ends_with(".gd"):
			var script := load(full_path)
			if script == null:
				failures.append("Failed to load script: %s" % full_path)
		entry = dir.get_next()
	dir.list_dir_end()
