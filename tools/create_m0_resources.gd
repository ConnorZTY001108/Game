extends SceneTree

const CharacterData = preload("res://data/resources/character_data.gd")
const EnemyData = preload("res://data/resources/enemy_data.gd")
const RuneData = preload("res://data/resources/rune_data.gd")
const UpgradeData = preload("res://data/resources/upgrade_data.gd")
const WaveData = preload("res://data/resources/wave_data.gd")
const WeaponData = preload("res://data/resources/weapon_data.gd")

func _init() -> void:
	_make_dirs()
	var weapon = WeaponData.new()
	weapon.id = "rune_bolt"
	weapon.display_name = "符文弹"
	weapon.description = "自动向最近的敌人发射符文弹。"
	weapon.attack_mode = "projectile"
	weapon.damage = 12.0
	weapon.cooldown = 0.75
	weapon.projectile_speed = 560.0
	weapon.projectile_lifetime = 1.3
	weapon.projectile_count = 1
	weapon.pierce = 0
	weapon.range = 640.0
	weapon.tags = _strings(["projectile", "rune"])
	weapon.element_tags = _strings([])
	_save(weapon, "res://data/content/weapons/rune_bolt.tres")

	var character = CharacterData.new()
	character.id = "wasteland_walker"
	character.display_name = "荒原行者"
	character.max_health = 100.0
	character.move_speed = 260.0
	character.pickup_radius = 72.0
	character.damage_multiplier = 1.0
	character.cooldown_multiplier = 1.0
	character.starting_weapon = weapon
	character.passive_tags = _strings(["m0_basic"])
	_save(character, "res://data/content/characters/wasteland_walker.tres")

	var rune = RuneData.new()
	rune.id = "scorch_mark"
	rune.display_name = "灼痕"
	rune.description = "符文弹命中会施加灼痕层数。三层触发额外伤害。"
	rune.rarity = "common"
	rune.stream_tags = _strings(["m0_chain"])
	rune.applies_to_weapon_tags = _strings(["projectile", "rune"])
	rune.trigger = "on_hit"
	rune.effect = "add_element_stack"
	rune.element_tag = "scorch"
	rune.stack_threshold = 3
	rune.bonus_damage = 12.0
	rune.internal_cooldown = 0.25
	_save(rune, "res://data/content/runes/scorch_mark.tres")

	var enemy = EnemyData.new()
	enemy.id = "dust_thrall"
	enemy.display_name = "尘骸仆从"
	enemy.max_health = 32.0
	enemy.move_speed = 125.0
	enemy.contact_damage = 8.0
	enemy.experience_value = 1
	enemy.behavior_type = "chase"
	enemy.element_rules = _strings(["scorch_stack"])
	_save(enemy, "res://data/content/enemies/dust_thrall.tres")

	var wave = WaveData.new()
	wave.id = "m0_wave"
	wave.duration_seconds = 180.0
	wave.spawn_interval = 1.2
	wave.max_alive = 40
	wave.spawn_radius = 760.0
	wave.enemy_data = enemy
	_save(wave, "res://data/content/waves/m0_wave.tres")

	_create_upgrade("damage_focus", "锋锐符文弹", "符文弹造成的伤害提高 15%。", "weapon_stat", "damage_multiplier", 0.15, null, "res://data/content/upgrades/damage_focus.tres")
	_create_upgrade("cooldown_focus", "急速铭刻", "符文弹冷却缩短 10%。", "weapon_stat", "cooldown_multiplier", -0.10, null, "res://data/content/upgrades/cooldown_focus.tres")
	_create_upgrade("pickup_focus", "符文感知", "拾取半径增加 24 像素。", "player_stat", "pickup_radius", 24.0, null, "res://data/content/upgrades/pickup_focus.tres")
	_create_upgrade("scorch_mark_pick", "灼痕", "装备灼痕符文链。", "rune", "", 0.0, rune, "res://data/content/upgrades/scorch_mark_pick.tres")
	print("PASS: M0 resources created")
	quit(0)

func _make_dirs() -> void:
	for path in [
		"res://data/content/characters",
		"res://data/content/weapons",
		"res://data/content/runes",
		"res://data/content/enemies",
		"res://data/content/waves",
		"res://data/content/upgrades"
	]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))

func _create_upgrade(id: String, title: String, text: String, upgrade_type: String, stat_key: String, value: float, rune: Resource, path: String) -> void:
	var upgrade = UpgradeData.new()
	upgrade.id = id
	upgrade.display_name = title
	upgrade.description = text
	upgrade.upgrade_type = upgrade_type
	upgrade.stat_key = stat_key
	upgrade.value = value
	upgrade.rune = rune
	_save(upgrade, path)

func _save(resource: Resource, path: String) -> void:
	var error := ResourceSaver.save(resource, path)
	if error != OK:
		push_error("Failed to save %s: %s" % [path, error])
		quit(1)

func _strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result
