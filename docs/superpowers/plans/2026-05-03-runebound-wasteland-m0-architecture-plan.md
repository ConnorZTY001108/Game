# Runebound Wasteland M0 Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Godot 4 M0 baseline for Runebound Wasteland Survivor: a data-driven project skeleton plus one playable combat loop where the player moves, enemies spawn and chase, one weapon auto-attacks, enemies drop experience, level-up choices apply, and one rune/element trigger chain can be verified.

**Architecture:** Use Godot scenes for entities and presentation, Resources for configurable content data, lightweight components for health/damage/status/drop behavior, and autoloaded systems for run state, spawning, experience, upgrades, runes, elements, and damage events. M0 intentionally implements only one character, one weapon, one enemy, one wave profile, one upgrade path, and one rune chain while preserving the file boundaries needed to add later content without rewriting player or enemy logic.

**Tech Stack:** Godot 4.x, GDScript 2.0, Godot Resource files (`.tres`), scene files (`.tscn`), PowerShell validation commands, Godot headless smoke scripts when the CLI is available.

---

## File Structure / Ownership Map

All paths below are relative to `C:/Users/19612/Documents/Codex/2026-05-03/new-chat` unless shown as absolute paths. M0 workers must only edit files listed in their assigned task.

### Project Root

- `project.godot` owns Godot project metadata, input actions, main scene, and autoload registration.
- `.gitignore` owns Godot/editor generated file exclusions.
- `README.md` owns local run and validation instructions for M0 only.

### Autoload Runtime Systems

- `autoload/GameEvents.gd` owns shared signals only; it does not store run state.
- `autoload/GameRuntime.gd` owns run lifecycle: boot, playing, paused, level-up, game-over, victory, settlement entry.
- `autoload/DamageSystem.gd` owns damage requests and hit/death event routing.
- `autoload/ElementStatusSystem.gd` owns element stack/duration data attached to damageable targets.
- `autoload/RuneSystem.gd` owns equipped rune list, trigger dispatch, and rune effects.
- `autoload/ExperienceSystem.gd` owns experience total, level thresholds, pickup collection, and level-up signal.
- `autoload/UpgradeSystem.gd` owns level-up option generation and applying selected upgrades.

### Data Resources

- `data/resources/character_data.gd` defines `CharacterData`.
- `data/resources/weapon_data.gd` defines `WeaponData`.
- `data/resources/rune_data.gd` defines `RuneData`.
- `data/resources/enemy_data.gd` defines `EnemyData`.
- `data/resources/wave_data.gd` defines `WaveData`.
- `data/resources/upgrade_data.gd` defines `UpgradeData`.
- `data/content/characters/wasteland_walker.tres` is the single M0 character.
- `data/content/weapons/rune_bolt.tres` is the single M0 weapon.
- `data/content/runes/scorch_mark.tres` is the single M0 rune.
- `data/content/enemies/dust_thrall.tres` is the single M0 enemy.
- `data/content/waves/m0_wave.tres` is the M0 spawn profile.
- `data/content/upgrades/*.tres` contains three M0 stat choices plus the Scorch Mark rune choice enabled in Task 10.

### Components

- `scripts/components/HealthComponent.gd` owns max/current health, damage application, death signal.
- `scripts/components/HitboxComponent.gd` owns receiving hits from projectiles/contact damage.
- `scripts/components/HurtboxComponent.gd` owns outgoing contact/projectile collision metadata.
- `scripts/components/DropComponent.gd` owns experience pickup spawning.
- `scripts/components/StatusReceiver.gd` owns bridge calls from `ElementStatusSystem` for a target.

### Scenes and Entity Scripts

- `scenes/Main.tscn` is the boot scene and owns high-level menu-to-run entry for M0.
- `scenes/run/GameRoot.tscn` owns autoload-backed runtime composition.
- `scenes/run/RunScene.tscn` owns the actual playable 2D run, map bounds, entity containers, and system nodes.
- `scenes/player/Player.tscn` and `scripts/player/Player.gd` own player movement, loaded character data, weapon mounting, and death forwarding.
- `scenes/enemies/Enemy.tscn` and `scripts/enemies/Enemy.gd` own chase movement and enemy data binding.
- `scenes/projectiles/Projectile.tscn` and `scripts/projectiles/Projectile.gd` own projectile travel, lifetime, hit forwarding, and pierce count.
- `scenes/pickups/ExperiencePickup.tscn` and `scripts/pickups/ExperiencePickup.gd` own pickup magnet behavior and collection.
- `scenes/weapons/WeaponController.tscn` and `scripts/weapons/WeaponController.gd` own cooldown and projectile spawn using `WeaponData`.
- `scenes/ui/HUD.tscn` and `scripts/ui/HUD.gd` own health, level, experience, timer, and kill count display.
- `scenes/ui/LevelUpPanel.tscn` and `scripts/ui/LevelUpPanel.gd` own the three-choice upgrade UI.
- `scenes/ui/DebugOverlay.tscn` and `scripts/ui/DebugOverlay.gd` own FPS and object counts.

### Run Systems as Scene Nodes

- `scripts/systems/SpawnSystem.gd` owns timed enemy spawning from `WaveData`.
- `scripts/systems/RunTimerSystem.gd` owns elapsed time and phase signals.
- `scripts/systems/DropSystem.gd` owns constructing pickup instances.

### Tests and Validation Helpers

- `tests/smoke/parse_all_scripts.gd` loads every `.gd` script under `res://` and exits non-zero on parse/load failure.
- `tests/smoke/load_core_scenes.gd` loads main M0 scenes and critical data Resources.
- `docs/qa/m0-smoke-test.md` records manual smoke test steps and expected observations.

---

## Implementation Tasks

### Task 1: Godot 4 Project Skeleton and Validation Entry Points

**Files:**
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/project.godot`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/.gitignore`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/README.md`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/tests/smoke/parse_all_scripts.gd`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/tests/smoke/load_core_scenes.gd`
- Test: `where.exe godot`, `where.exe godot4`, `godot --headless --path . --quit`, `godot4 --headless --path . --quit`

- [ ] **Step 1: Verify whether a Godot CLI exists**

Run both commands from the workspace root:

```powershell
where.exe godot
where.exe godot4
```

Expected: at least one command prints an executable path. If both commands print `INFO: Could not find files for the given pattern(s).`, continue with the manual fallback in Step 5 and do not claim automated Godot validation passed.

- [ ] **Step 2: Create the Godot folder layout**

Create these directories:

```powershell
New-Item -ItemType Directory -Force -Path autoload,data/resources,data/content/characters,data/content/weapons,data/content/runes,data/content/enemies,data/content/waves,data/content/upgrades,scenes/run,scenes/player,scenes/enemies,scenes/projectiles,scenes/pickups,scenes/weapons,scenes/ui,scripts/components,scripts/player,scripts/enemies,scripts/projectiles,scripts/pickups,scripts/weapons,scripts/ui,scripts/systems,tools,tests/smoke,docs/qa
```

- [ ] **Step 3: Create minimal project metadata**

Write `project.godot` with:

```ini
; Engine configuration file.
; Generated for Runebound Wasteland Survivor M0.

config_version=5

[application]
config/name="Runebound Wasteland Survivor"
run/main_scene="res://scenes/Main.tscn"
config/features=PackedStringArray("4.2")

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"

[input]
move_left={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":65,"physical_keycode":0,"key_label":0,"unicode":0,"echo":false,"script":null)]
}
move_right={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":68,"physical_keycode":0,"key_label":0,"unicode":0,"echo":false,"script":null)]
}
move_up={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":87,"physical_keycode":0,"key_label":0,"unicode":0,"echo":false,"script":null)]
}
move_down={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":83,"physical_keycode":0,"key_label":0,"unicode":0,"echo":false,"script":null)]
}
debug_toggle={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194338,"physical_keycode":0,"key_label":0,"unicode":0,"echo":false,"script":null)]
}
```

- [ ] **Step 4: Create smoke script skeletons**

Create `tests/smoke/parse_all_scripts.gd`:

```gdscript
extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
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
```

Create `tests/smoke/load_core_scenes.gd`:

```gdscript
extends SceneTree

const REQUIRED_PATHS: Array[String] = [
	"res://scenes/Main.tscn",
	"res://scenes/run/GameRoot.tscn",
	"res://scenes/run/RunScene.tscn",
	"res://data/content/characters/wasteland_walker.tres",
	"res://data/content/weapons/rune_bolt.tres",
	"res://data/content/runes/scorch_mark.tres",
	"res://data/content/enemies/dust_thrall.tres",
	"res://data/content/waves/m0_wave.tres"
]

func _initialize() -> void:
	var failures: Array[String] = []
	for path in REQUIRED_PATHS:
		if ResourceLoader.exists(path) == false:
			failures.append("Missing resource: %s" % path)
			continue
		if load(path) == null:
			failures.append("Failed to load: %s" % path)
	if failures.is_empty():
		print("PASS: core scenes and resources loaded")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
```

- [ ] **Step 5: Create Godot/editor ignore rules**

Create `.gitignore`:

```gitignore
.godot/
.import/
export.cfg
export_presets.cfg
*.translation
*.tmp
```

- [ ] **Step 6: Document validation fallback**

Create `README.md` with M0-only instructions:

```markdown
# Runebound Wasteland Survivor M0

Godot 4 project for the M0 architecture baseline and minimum combat loop.

## CLI Validation

Check whether Godot is on PATH:

```powershell
where.exe godot
where.exe godot4
```

If `godot` exists:

```powershell
godot --headless --path . --quit
godot --headless --path . --script res://tests/smoke/parse_all_scripts.gd
godot --headless --path . --script res://tests/smoke/load_core_scenes.gd
```

If only `godot4` exists, replace `godot` with `godot4`.

If no CLI exists, open this folder in Godot 4 Editor, confirm `scenes/Main.tscn` opens, press Play, and record the manual smoke result in `docs/qa/m0-smoke-test.md`.
```

- [ ] **Step 7: Run the available project check**

If `godot` exists, run:

```powershell
godot --headless --path . --quit
```

If only `godot4` exists, run:

```powershell
godot4 --headless --path . --quit
```

Expected after Task 1: project metadata loads. Scene/data smoke scripts are expected to fail until later tasks create the referenced files.

- [ ] **Step 8: Commit**

```powershell
git add project.godot .gitignore README.md tests/smoke
git commit -m "chore: initialize godot m0 project skeleton"
```

If this workspace is not a git repository, skip the commit and state `git repository not initialized` in the handoff.

### Task 2: Autoload Event Bus and Run State Baseline

**Files:**
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/autoload/GameEvents.gd`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/autoload/GameRuntime.gd`
- Modify: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/project.godot`
- Test: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/tests/smoke/parse_all_scripts.gd`

- [ ] **Step 1: Create shared signals**

Create `autoload/GameEvents.gd`:

```gdscript
extends Node

signal run_started
signal run_paused(is_paused: bool)
signal run_finished(result: String)
signal player_died
signal enemy_died(enemy: Node, experience_value: int)
signal damage_applied(target: Node, amount: float, tags: Array[String])
signal weapon_hit(target: Node, payload: Dictionary)
signal experience_collected(amount: int)
signal level_changed(level: int)
signal level_up_requested(options: Array[Resource])
signal upgrade_selected(upgrade: Resource)
signal rune_triggered(rune_id: String, target: Node, payload: Dictionary)
```

- [ ] **Step 2: Create run state controller**

Create `autoload/GameRuntime.gd`:

```gdscript
extends Node

enum RunState { BOOT, PLAYING, PAUSED, LEVEL_UP, GAME_OVER, VICTORY }

var state: RunState = RunState.BOOT
var elapsed_seconds: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func start_run() -> void:
	elapsed_seconds = 0.0
	state = RunState.PLAYING
	get_tree().paused = false
	GameEvents.run_started.emit()

func set_paused(is_paused: bool) -> void:
	if state == RunState.GAME_OVER or state == RunState.VICTORY:
		return
	state = RunState.PAUSED if is_paused else RunState.PLAYING
	get_tree().paused = is_paused
	GameEvents.run_paused.emit(is_paused)

func enter_level_up() -> void:
	if state != RunState.PLAYING:
		return
	state = RunState.LEVEL_UP
	get_tree().paused = true

func resume_from_level_up() -> void:
	if state != RunState.LEVEL_UP:
		return
	state = RunState.PLAYING
	get_tree().paused = false

func finish_run(result: String) -> void:
	if result == "victory":
		state = RunState.VICTORY
	else:
		state = RunState.GAME_OVER
	get_tree().paused = true
	GameEvents.run_finished.emit(result)
```

- [ ] **Step 3: Register autoloads**

Add this section to `project.godot`:

```ini
[autoload]
GameEvents="*res://autoload/GameEvents.gd"
GameRuntime="*res://autoload/GameRuntime.gd"
```

- [ ] **Step 4: Run script parse check**

```powershell
godot --headless --path . --script res://tests/smoke/parse_all_scripts.gd
```

If only `godot4` exists:

```powershell
godot4 --headless --path . --script res://tests/smoke/parse_all_scripts.gd
```

Expected: `PASS: all scripts loaded`.

- [ ] **Step 5: Commit**

```powershell
git add autoload/GameEvents.gd autoload/GameRuntime.gd project.godot
git commit -m "feat: add m0 runtime event autoloads"
```

### Task 3: Resource Data Types and M0 Content Data

**Files:**
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/data/resources/character_data.gd`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/data/resources/weapon_data.gd`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/data/resources/rune_data.gd`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/data/resources/enemy_data.gd`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/data/resources/wave_data.gd`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/data/resources/upgrade_data.gd`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/data/content/characters/wasteland_walker.tres`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/data/content/weapons/rune_bolt.tres`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/data/content/runes/scorch_mark.tres`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/data/content/enemies/dust_thrall.tres`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/data/content/waves/m0_wave.tres`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/data/content/upgrades/damage_focus.tres`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/data/content/upgrades/cooldown_focus.tres`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/data/content/upgrades/pickup_focus.tres`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/data/content/upgrades/scorch_mark_pick.tres`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/tools/create_m0_resources.gd`
- Test: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/tests/smoke/load_core_scenes.gd`

- [ ] **Step 1: Define Resource classes**

Create `data/resources/character_data.gd`:

```gdscript
class_name CharacterData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var max_health: float = 100.0
@export var move_speed: float = 260.0
@export var pickup_radius: float = 72.0
@export var damage_multiplier: float = 1.0
@export var cooldown_multiplier: float = 1.0
@export var starting_weapon: WeaponData
@export var passive_tags: Array[String] = []
```

Create `data/resources/weapon_data.gd`:

```gdscript
class_name WeaponData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var attack_mode: String = "projectile"
@export var damage: float = 10.0
@export var cooldown: float = 0.8
@export var projectile_speed: float = 520.0
@export var projectile_lifetime: float = 1.4
@export var projectile_count: int = 1
@export var pierce: int = 0
@export var range: float = 600.0
@export var tags: Array[String] = []
@export var element_tags: Array[String] = []
```

Create `data/resources/rune_data.gd`:

```gdscript
class_name RuneData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var rarity: String = "common"
@export var stream_tags: Array[String] = []
@export var applies_to_weapon_tags: Array[String] = []
@export var trigger: String = "on_hit"
@export var effect: String = "add_element_stack"
@export var element_tag: String = "scorch"
@export var stack_threshold: int = 3
@export var bonus_damage: float = 12.0
@export var internal_cooldown: float = 0.25
```

Create `data/resources/enemy_data.gd`:

```gdscript
class_name EnemyData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var max_health: float = 30.0
@export var move_speed: float = 130.0
@export var contact_damage: float = 8.0
@export var experience_value: int = 1
@export var behavior_type: String = "chase"
@export var element_rules: Array[String] = []
```

Create `data/resources/wave_data.gd`:

```gdscript
class_name WaveData
extends Resource

@export var id: String = ""
@export var duration_seconds: float = 180.0
@export var spawn_interval: float = 1.2
@export var max_alive: int = 40
@export var spawn_radius: float = 760.0
@export var enemy_data: EnemyData
```

Create `data/resources/upgrade_data.gd`:

```gdscript
class_name UpgradeData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var upgrade_type: String = "weapon_stat"
@export var stat_key: String = "damage_multiplier"
@export var value: float = 0.15
@export var rune: RuneData
```

- [ ] **Step 2: Create exact Resource generation script**

Create `tools/create_m0_resources.gd`:

```gdscript
extends SceneTree

func _initialize() -> void:
	_make_dirs()
	var weapon := WeaponData.new()
	weapon.id = "rune_bolt"
	weapon.display_name = "Rune Bolt"
	weapon.description = "Fires a readable rune projectile at the nearest enemy."
	weapon.attack_mode = "projectile"
	weapon.damage = 12.0
	weapon.cooldown = 0.75
	weapon.projectile_speed = 560.0
	weapon.projectile_lifetime = 1.3
	weapon.projectile_count = 1
	weapon.pierce = 0
	weapon.range = 640.0
	weapon.tags = ["projectile", "rune"]
	weapon.element_tags = []
	_save(weapon, "res://data/content/weapons/rune_bolt.tres")

	var character := CharacterData.new()
	character.id = "wasteland_walker"
	character.display_name = "Wasteland Walker"
	character.max_health = 100.0
	character.move_speed = 260.0
	character.pickup_radius = 72.0
	character.damage_multiplier = 1.0
	character.cooldown_multiplier = 1.0
	character.starting_weapon = weapon
	character.passive_tags = ["m0_basic"]
	_save(character, "res://data/content/characters/wasteland_walker.tres")

	var rune := RuneData.new()
	rune.id = "scorch_mark"
	rune.display_name = "Scorch Mark"
	rune.description = "Rune Bolt hits apply scorch stacks. Three stacks trigger bonus damage."
	rune.rarity = "common"
	rune.stream_tags = ["m0_chain"]
	rune.applies_to_weapon_tags = ["projectile", "rune"]
	rune.trigger = "on_hit"
	rune.effect = "add_element_stack"
	rune.element_tag = "scorch"
	rune.stack_threshold = 3
	rune.bonus_damage = 12.0
	rune.internal_cooldown = 0.25
	_save(rune, "res://data/content/runes/scorch_mark.tres")

	var enemy := EnemyData.new()
	enemy.id = "dust_thrall"
	enemy.display_name = "Dust Thrall"
	enemy.max_health = 32.0
	enemy.move_speed = 125.0
	enemy.contact_damage = 8.0
	enemy.experience_value = 1
	enemy.behavior_type = "chase"
	enemy.element_rules = ["scorch_stack"]
	_save(enemy, "res://data/content/enemies/dust_thrall.tres")

	var wave := WaveData.new()
	wave.id = "m0_wave"
	wave.duration_seconds = 180.0
	wave.spawn_interval = 1.2
	wave.max_alive = 40
	wave.spawn_radius = 760.0
	wave.enemy_data = enemy
	_save(wave, "res://data/content/waves/m0_wave.tres")

	_create_upgrade("damage_focus", "Sharpened Rune Bolt", "Rune Bolt deals 15% more damage.", "weapon_stat", "damage_multiplier", 0.15, null, "res://data/content/upgrades/damage_focus.tres")
	_create_upgrade("cooldown_focus", "Faster Inscription", "Rune Bolt cooldown is reduced by 10%.", "weapon_stat", "cooldown_multiplier", -0.10, null, "res://data/content/upgrades/cooldown_focus.tres")
	_create_upgrade("pickup_focus", "Wider Rune Sense", "Increase pickup radius by 24 pixels.", "player_stat", "pickup_radius", 24.0, null, "res://data/content/upgrades/pickup_focus.tres")
	_create_upgrade("scorch_mark_pick", "Scorch Mark", "Equip the Scorch Mark rune chain.", "rune", "", 0.0, rune, "res://data/content/upgrades/scorch_mark_pick.tres")
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

func _create_upgrade(id: String, title: String, text: String, upgrade_type: String, stat_key: String, value: float, rune: RuneData, path: String) -> void:
	var upgrade := UpgradeData.new()
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
```

- [ ] **Step 3: Generate `.tres` content with Godot headless**

If `godot` exists, run:

```powershell
godot --headless --path . --script res://tools/create_m0_resources.gd
```

If only `godot4` exists, run:

```powershell
godot4 --headless --path . --script res://tools/create_m0_resources.gd
```

Expected: `PASS: M0 resources created`, and all files listed in Task 3 `Files` exist. If no CLI exists, open Godot 4 Editor, run `tools/create_m0_resources.gd` from the Script editor, and confirm the same generated `.tres` files exist in the FileSystem dock.

- [ ] **Step 4: Verify generated Resource values**

Open the generated `.tres` files in Godot Inspector and verify these exact values:

```text
wasteland_walker.tres: id=wasteland_walker, max_health=100, move_speed=260, pickup_radius=72, starting_weapon=rune_bolt.tres
rune_bolt.tres: id=rune_bolt, damage=12, cooldown=0.75, projectile_speed=560, tags=["projectile", "rune"]
scorch_mark.tres: id=scorch_mark, trigger=on_hit, element_tag=scorch, stack_threshold=3, bonus_damage=12
dust_thrall.tres: id=dust_thrall, max_health=32, move_speed=125, contact_damage=8, experience_value=1
m0_wave.tres: id=m0_wave, duration_seconds=180, spawn_interval=1.2, max_alive=40, spawn_radius=760
damage_focus.tres: upgrade_type=weapon_stat, stat_key=damage_multiplier, value=0.15
cooldown_focus.tres: upgrade_type=weapon_stat, stat_key=cooldown_multiplier, value=-0.10
pickup_focus.tres: upgrade_type=player_stat, stat_key=pickup_radius, value=24
scorch_mark_pick.tres: upgrade_type=rune, rune=scorch_mark.tres
```

- [ ] **Step 5: Run Resource load check**

Run after Task 4 creates scenes, or run now expecting scene paths to fail and data paths to load:

```powershell
godot --headless --path . --script res://tests/smoke/load_core_scenes.gd
```

Expected after Task 3 only: generated data Resources load, missing scene errors remain. Expected after Task 4: all required paths load.

- [ ] **Step 6: Commit**

```powershell
git add data/resources data/content tools/create_m0_resources.gd
git commit -m "feat: add m0 resource data model"
```

### Task 4: Core Scenes and UI Shells

**Files:**
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scenes/Main.tscn`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scenes/run/GameRoot.tscn`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scenes/run/RunScene.tscn`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scenes/player/Player.tscn`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scenes/enemies/Enemy.tscn`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scenes/projectiles/Projectile.tscn`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scenes/pickups/ExperiencePickup.tscn`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scenes/weapons/WeaponController.tscn`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scenes/ui/HUD.tscn`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scenes/ui/LevelUpPanel.tscn`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scenes/ui/DebugOverlay.tscn`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/tools/create_m0_scenes.gd`
- Test: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/tests/smoke/load_core_scenes.gd`

- [ ] **Step 1: Create exact scene generation script**

Create `tools/create_m0_scenes.gd`:

```gdscript
extends SceneTree

func _initialize() -> void:
	_make_dirs()
	_save_scene(_weapon_controller(), "res://scenes/weapons/WeaponController.tscn")
	_save_scene(_projectile(), "res://scenes/projectiles/Projectile.tscn")
	_save_scene(_experience_pickup(), "res://scenes/pickups/ExperiencePickup.tscn")
	_save_scene(_player(), "res://scenes/player/Player.tscn")
	_save_scene(_enemy(), "res://scenes/enemies/Enemy.tscn")
	_save_scene(_hud(), "res://scenes/ui/HUD.tscn")
	_save_scene(_level_up_panel(), "res://scenes/ui/LevelUpPanel.tscn")
	_save_scene(_debug_overlay(), "res://scenes/ui/DebugOverlay.tscn")
	_save_scene(_run_scene(), "res://scenes/run/RunScene.tscn")
	_save_scene(_game_root(), "res://scenes/run/GameRoot.tscn")
	_save_scene(_main(), "res://scenes/Main.tscn")
	print("PASS: M0 scenes created")
	quit(0)

func _make_dirs() -> void:
	for path in ["res://scenes/run", "res://scenes/player", "res://scenes/enemies", "res://scenes/projectiles", "res://scenes/pickups", "res://scenes/weapons", "res://scenes/ui"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))

func _main() -> Node:
	var root := Node.new()
	root.name = "Main"
	_add_instance(root, "GameRoot", "res://scenes/run/GameRoot.tscn")
	return root

func _game_root() -> Node:
	var root := Node.new()
	root.name = "GameRoot"
	_add_instance(root, "RunScene", "res://scenes/run/RunScene.tscn")
	return root

func _run_scene() -> Node2D:
	var root := Node2D.new()
	root.name = "RunScene"
	var world := Node2D.new()
	world.name = "World"
	root.add_child(world)
	var bounds := Node2D.new()
	bounds.name = "Bounds"
	world.add_child(bounds)
	var spawn := Marker2D.new()
	spawn.name = "PlayerSpawn"
	world.add_child(spawn)
	_add_instance(world, "Player", "res://scenes/player/Player.tscn")
	for name in ["Enemies", "Projectiles", "Pickups"]:
		var container := Node2D.new()
		container.name = name
		world.add_child(container)
	var systems := Node.new()
	systems.name = "Systems"
	root.add_child(systems)
	for name in ["RunTimerSystem", "SpawnSystem", "DropSystem"]:
		var system := Node.new()
		system.name = name
		systems.add_child(system)
	var layer := CanvasLayer.new()
	layer.name = "CanvasLayer"
	root.add_child(layer)
	_add_instance(layer, "HUD", "res://scenes/ui/HUD.tscn")
	_add_instance(layer, "LevelUpPanel", "res://scenes/ui/LevelUpPanel.tscn")
	_add_instance(layer, "DebugOverlay", "res://scenes/ui/DebugOverlay.tscn")
	_set_owner_recursive(root, root)
	return root

func _player() -> CharacterBody2D:
	var root := CharacterBody2D.new()
	root.name = "Player"
	_add_color_rect(root, "Visual", Color(0.2, 0.8, 0.9), Vector2(24, 24))
	root.add_child(_named_node("HealthComponent"))
	var pickup := Area2D.new()
	pickup.name = "PickupArea"
	pickup.add_child(_circle_shape(72.0))
	root.add_child(pickup)
	var mount := Node2D.new()
	mount.name = "WeaponMount"
	root.add_child(mount)
	_set_owner_recursive(root, root)
	return root

func _enemy() -> CharacterBody2D:
	var root := CharacterBody2D.new()
	root.name = "Enemy"
	_add_color_rect(root, "Visual", Color(0.8, 0.35, 0.2), Vector2(22, 22))
	root.add_child(_named_node("HealthComponent"))
	var hitbox := Area2D.new()
	hitbox.name = "HitboxComponent"
	hitbox.add_child(_circle_shape(14.0))
	root.add_child(hitbox)
	var contact := Area2D.new()
	contact.name = "ContactArea"
	contact.add_child(_circle_shape(18.0))
	root.add_child(contact)
	root.add_child(_named_node("DropComponent"))
	root.add_child(_named_node("StatusReceiver"))
	_set_owner_recursive(root, root)
	return root

func _projectile() -> Area2D:
	var root := Area2D.new()
	root.name = "Projectile"
	_add_color_rect(root, "Visual", Color(0.4, 0.9, 1.0), Vector2(10, 10))
	root.add_child(_circle_shape(6.0))
	_set_owner_recursive(root, root)
	return root

func _experience_pickup() -> Area2D:
	var root := Area2D.new()
	root.name = "ExperiencePickup"
	_add_color_rect(root, "Visual", Color(0.2, 1.0, 0.35), Vector2(8, 8))
	root.add_child(_circle_shape(8.0))
	_set_owner_recursive(root, root)
	return root

func _weapon_controller() -> Node2D:
	var root := Node2D.new()
	root.name = "WeaponController"
	return root

func _hud() -> Control:
	var root := Control.new()
	root.name = "HUD"
	for name in ["HealthLabel", "LevelLabel", "ExperienceLabel", "TimerLabel", "KillLabel"]:
		var label := Label.new()
		label.name = name
		label.text = name
		root.add_child(label)
	_set_owner_recursive(root, root)
	return root

func _level_up_panel() -> Control:
	var root := Control.new()
	root.name = "LevelUpPanel"
	root.visible = false
	var panel := PanelContainer.new()
	panel.name = "Panel"
	root.add_child(panel)
	var options := VBoxContainer.new()
	options.name = "Options"
	panel.add_child(options)
	_set_owner_recursive(root, root)
	return root

func _debug_overlay() -> Control:
	var root := Control.new()
	root.name = "DebugOverlay"
	var label := Label.new()
	label.name = "DebugLabel"
	label.text = "FPS: 0"
	root.add_child(label)
	_set_owner_recursive(root, root)
	return root

func _add_instance(parent: Node, name: String, path: String) -> void:
	var scene := load(path) as PackedScene
	var child := scene.instantiate()
	child.name = name
	parent.add_child(child)

func _named_node(name: String) -> Node:
	var node := Node.new()
	node.name = name
	return node

func _add_color_rect(parent: Node, name: String, color: Color, size: Vector2) -> void:
	var rect := ColorRect.new()
	rect.name = name
	rect.color = color
	rect.size = size
	rect.position = -size * 0.5
	parent.add_child(rect)

func _circle_shape(radius: float) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	return shape

func _set_owner_recursive(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		_set_owner_recursive(child, root)

func _save_scene(root: Node, path: String) -> void:
	_set_owner_recursive(root, root)
	var scene := PackedScene.new()
	var pack_error := scene.pack(root)
	if pack_error != OK:
		push_error("Failed to pack %s: %s" % [path, pack_error])
		quit(1)
	var save_error := ResourceSaver.save(scene, path)
	if save_error != OK:
		push_error("Failed to save %s: %s" % [path, save_error])
		quit(1)
```

- [ ] **Step 2: Generate scene files headlessly or through editor fallback**

If `godot` exists, run:

```powershell
godot --headless --path . --script res://tools/create_m0_scenes.gd
```

If only `godot4` exists, run:

```powershell
godot4 --headless --path . --script res://tools/create_m0_scenes.gd
```

Expected: `PASS: M0 scenes created`. If no CLI exists, open Godot 4 Editor, run `tools/create_m0_scenes.gd` from the Script editor, then confirm every scene listed in Task 4 `Files` exists.

- [ ] **Step 3: Verify generated scene ownership and node names**

Open `scenes/run/RunScene.tscn` and verify the node tree contains exactly these M0 integration anchors:

```text
RunScene/World/Player
RunScene/World/Enemies
RunScene/World/Projectiles
RunScene/World/Pickups
RunScene/Systems/RunTimerSystem
RunScene/Systems/SpawnSystem
RunScene/Systems/DropSystem
RunScene/CanvasLayer/HUD
RunScene/CanvasLayer/LevelUpPanel
RunScene/CanvasLayer/DebugOverlay
```

- [ ] **Step 4: Run scene/data load check**

```powershell
godot --headless --path . --script res://tests/smoke/load_core_scenes.gd
```

Expected: `PASS: core scenes and resources loaded`.

- [ ] **Step 5: Commit**

```powershell
git add scenes tools/create_m0_scenes.gd
git commit -m "feat: add m0 scene skeletons"
```

### Task 5: Player Movement, Health, and Death

**Files:**
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scripts/components/HealthComponent.gd`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scripts/player/Player.gd`
- Modify: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scenes/player/Player.tscn`
- Modify: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scenes/run/RunScene.tscn`
- Test: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/tests/smoke/parse_all_scripts.gd`

- [ ] **Step 1: Implement HealthComponent**

Create `scripts/components/HealthComponent.gd`:

```gdscript
class_name HealthComponent
extends Node

signal health_changed(current: float, maximum: float)
signal died

@export var max_health: float = 100.0
var current_health: float = 100.0
var is_dead: bool = false

func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)

func configure(new_max_health: float) -> void:
	max_health = new_max_health
	current_health = max_health
	is_dead = false
	health_changed.emit(current_health, max_health)

func apply_damage(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current_health = max(0.0, current_health - amount)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		is_dead = true
		died.emit()
```

- [ ] **Step 2: Implement Player movement and data loading**

Create `scripts/player/Player.gd`:

```gdscript
class_name Player
extends CharacterBody2D

@export var character_data: CharacterData = preload("res://data/content/characters/wasteland_walker.tres")

@onready var health_component: HealthComponent = $HealthComponent
@onready var weapon_mount: Node2D = $WeaponMount

var damage_multiplier: float = 1.0
var cooldown_multiplier: float = 1.0
var pickup_radius: float = 72.0

func _ready() -> void:
	_apply_character_data()
	health_component.died.connect(_on_died)

func _physics_process(_delta: float) -> void:
	if GameRuntime.state != GameRuntime.RunState.PLAYING:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_vector * character_data.move_speed
	move_and_slide()

func _apply_character_data() -> void:
	health_component.configure(character_data.max_health)
	damage_multiplier = character_data.damage_multiplier
	cooldown_multiplier = character_data.cooldown_multiplier
	pickup_radius = character_data.pickup_radius

func apply_upgrade_stat(stat_key: String, value: float) -> void:
	if stat_key == "damage_multiplier":
		damage_multiplier += value
	elif stat_key == "cooldown_multiplier":
		cooldown_multiplier = max(0.2, cooldown_multiplier + value)
	elif stat_key == "pickup_radius":
		pickup_radius = max(24.0, pickup_radius + value)

func take_contact_damage(amount: float) -> void:
	health_component.apply_damage(amount)

func _on_died() -> void:
	GameEvents.player_died.emit()
	GameRuntime.finish_run("defeat")
```

- [ ] **Step 3: Attach scripts in scenes**

Attach `Player.gd` to the `Player` root and `HealthComponent.gd` to `Player/HealthComponent`.

- [ ] **Step 4: Connect run start**

In `RunScene.tscn`, ensure `Player` starts at `PlayerSpawn` and `GameRuntime.start_run()` is called by a RunScene script in Task 6. Until Task 6, press Play and confirm the scene opens without script errors.

- [ ] **Step 5: Run parse check**

```powershell
godot --headless --path . --script res://tests/smoke/parse_all_scripts.gd
```

Expected: `PASS: all scripts loaded`.

- [ ] **Step 6: Commit**

```powershell
git add scripts/components/HealthComponent.gd scripts/player/Player.gd scenes/player/Player.tscn scenes/run/RunScene.tscn
git commit -m "feat: add player movement and health"
```

### Task 6: Run Scene Wiring, Timer, HUD, and Debug Overlay

**Files:**
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scripts/systems/RunTimerSystem.gd`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scripts/ui/HUD.gd`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scripts/ui/DebugOverlay.gd`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scripts/run/RunScene.gd`
- Modify: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scenes/run/RunScene.tscn`
- Modify: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scenes/ui/HUD.tscn`
- Modify: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scenes/ui/DebugOverlay.tscn`
- Test: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/tests/smoke/parse_all_scripts.gd`

- [ ] **Step 1: Create `scripts/run` directory**

```powershell
New-Item -ItemType Directory -Force -Path scripts/run
```

- [ ] **Step 2: Implement run timer**

Create `scripts/systems/RunTimerSystem.gd`:

```gdscript
class_name RunTimerSystem
extends Node

signal time_changed(elapsed_seconds: float)

@export var run_duration_seconds: float = 180.0
var elapsed_seconds: float = 0.0

func _process(delta: float) -> void:
	if GameRuntime.state != GameRuntime.RunState.PLAYING:
		return
	elapsed_seconds += delta
	GameRuntime.elapsed_seconds = elapsed_seconds
	time_changed.emit(elapsed_seconds)
	if elapsed_seconds >= run_duration_seconds:
		GameRuntime.finish_run("victory")
```

- [ ] **Step 3: Implement HUD**

Create `scripts/ui/HUD.gd`:

```gdscript
class_name HUD
extends Control

@onready var health_label: Label = $HealthLabel
@onready var level_label: Label = $LevelLabel
@onready var experience_label: Label = $ExperienceLabel
@onready var timer_label: Label = $TimerLabel
@onready var kill_label: Label = $KillLabel

var kills: int = 0

func _ready() -> void:
	GameEvents.enemy_died.connect(_on_enemy_died)
	GameEvents.level_changed.connect(_on_level_changed)
	GameEvents.experience_collected.connect(_on_experience_collected)
	_on_level_changed(1)
	_on_experience_collected(0)
	_update_timer(0.0)
	kill_label.text = "Kills: 0"

func bind_player(player: Player) -> void:
	player.health_component.health_changed.connect(_on_health_changed)
	_on_health_changed(player.health_component.current_health, player.health_component.max_health)

func bind_timer(timer: RunTimerSystem) -> void:
	timer.time_changed.connect(_update_timer)

func _on_health_changed(current: float, maximum: float) -> void:
	health_label.text = "HP: %d/%d" % [int(current), int(maximum)]

func _on_level_changed(level: int) -> void:
	level_label.text = "Level: %d" % level

func _on_experience_collected(amount: int) -> void:
	experience_label.text = "XP: %d" % amount

func _on_enemy_died(_enemy: Node, _experience_value: int) -> void:
	kills += 1
	kill_label.text = "Kills: %d" % kills

func _update_timer(seconds: float) -> void:
	var minutes := int(seconds) / 60
	var remainder := int(seconds) % 60
	timer_label.text = "Time: %02d:%02d" % [minutes, remainder]
```

- [ ] **Step 4: Implement debug overlay**

Create `scripts/ui/DebugOverlay.gd`:

```gdscript
class_name DebugOverlay
extends Control

@onready var debug_label: Label = $DebugLabel

@export var enemies_path: NodePath
@export var projectiles_path: NodePath
@export var pickups_path: NodePath

var visible_by_toggle: bool = true

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("debug_toggle"):
		visible_by_toggle = not visible_by_toggle
		visible = visible_by_toggle
	if not visible:
		return
	var enemies := _count_children(enemies_path)
	var projectiles := _count_children(projectiles_path)
	var pickups := _count_children(pickups_path)
	debug_label.text = "FPS: %d\nEnemies: %d\nProjectiles: %d\nPickups: %d" % [Engine.get_frames_per_second(), enemies, projectiles, pickups]

func _count_children(path: NodePath) -> int:
	var node := get_node_or_null(path)
	return node.get_child_count() if node != null else 0
```

- [ ] **Step 5: Implement RunScene wiring**

Create `scripts/run/RunScene.gd`:

```gdscript
class_name RunScene
extends Node2D

@onready var player: Player = $World/Player
@onready var run_timer: RunTimerSystem = $Systems/RunTimerSystem
@onready var hud: HUD = $CanvasLayer/HUD
@onready var debug_overlay: DebugOverlay = $CanvasLayer/DebugOverlay

func _ready() -> void:
	hud.bind_player(player)
	hud.bind_timer(run_timer)
	debug_overlay.enemies_path = ^"../../World/Enemies"
	debug_overlay.projectiles_path = ^"../../World/Projectiles"
	debug_overlay.pickups_path = ^"../../World/Pickups"
	GameRuntime.start_run()
```

- [ ] **Step 6: Attach scripts and run parse check**

Attach scripts to matching nodes, then run:

```powershell
godot --headless --path . --script res://tests/smoke/parse_all_scripts.gd
```

Expected: `PASS: all scripts loaded`.

- [ ] **Step 7: Manual smoke test**

Open in Godot 4 Editor, press Play, and verify:

```text
Player visible in the run scene.
WASD moves the player.
HUD shows HP, Level, XP, Time, Kills.
Debug overlay shows FPS and object counts.
F3 toggles debug overlay visibility.
```

- [ ] **Step 8: Commit**

```powershell
git add scripts/systems/RunTimerSystem.gd scripts/ui/HUD.gd scripts/ui/DebugOverlay.gd scripts/run/RunScene.gd scenes/run/RunScene.tscn scenes/ui/HUD.tscn scenes/ui/DebugOverlay.tscn
git commit -m "feat: wire m0 run scene hud and debug overlay"
```

### Task 7: Enemy Spawning and Chase Behavior

**Files:**
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scripts/enemies/Enemy.gd`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scripts/systems/SpawnSystem.gd`
- Modify: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scenes/enemies/Enemy.tscn`
- Modify: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scenes/run/RunScene.tscn`
- Test: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/tests/smoke/parse_all_scripts.gd`

- [ ] **Step 1: Implement Enemy chase and damage hooks**

Create `scripts/enemies/Enemy.gd`:

```gdscript
class_name Enemy
extends CharacterBody2D

@export var enemy_data: EnemyData = preload("res://data/content/enemies/dust_thrall.tres")

@onready var health_component: HealthComponent = $HealthComponent
@onready var drop_component: Node = $DropComponent

var target: Node2D

func _ready() -> void:
	health_component.configure(enemy_data.max_health)
	health_component.died.connect(_on_died)

func configure(data: EnemyData, chase_target: Node2D) -> void:
	enemy_data = data
	target = chase_target
	if is_node_ready():
		health_component.configure(enemy_data.max_health)

func _physics_process(_delta: float) -> void:
	if GameRuntime.state != GameRuntime.RunState.PLAYING or target == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var direction := global_position.direction_to(target.global_position)
	velocity = direction * enemy_data.move_speed
	move_and_slide()

func apply_damage(amount: float, tags: Array[String]) -> void:
	health_component.apply_damage(amount)
	GameEvents.damage_applied.emit(self, amount, tags)

func _on_died() -> void:
	GameEvents.enemy_died.emit(self, enemy_data.experience_value)
	queue_free()
```

- [ ] **Step 2: Implement SpawnSystem**

Create `scripts/systems/SpawnSystem.gd`:

```gdscript
class_name SpawnSystem
extends Node

@export var wave_data: WaveData = preload("res://data/content/waves/m0_wave.tres")
@export var enemy_scene: PackedScene = preload("res://scenes/enemies/Enemy.tscn")
@export var enemies_path: NodePath
@export var player_path: NodePath

var spawn_timer: float = 0.0

func _process(delta: float) -> void:
	if GameRuntime.state != GameRuntime.RunState.PLAYING:
		return
	var enemies := get_node_or_null(enemies_path)
	var player := get_node_or_null(player_path) as Node2D
	if enemies == null or player == null:
		return
	if enemies.get_child_count() >= wave_data.max_alive:
		return
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = wave_data.spawn_interval
		_spawn_enemy(enemies, player)

func _spawn_enemy(enemies: Node, player: Node2D) -> void:
	var enemy := enemy_scene.instantiate() as Enemy
	var angle := randf() * TAU
	enemy.global_position = player.global_position + Vector2.RIGHT.rotated(angle) * wave_data.spawn_radius
	enemy.configure(wave_data.enemy_data, player)
	enemies.add_child(enemy)
```

- [ ] **Step 3: Attach scripts and configure paths**

Attach `Enemy.gd` to `Enemy.tscn` root. Attach `SpawnSystem.gd` to `RunScene/Systems/SpawnSystem` and set:

```text
enemies_path: ../../World/Enemies
player_path: ../../World/Player
wave_data: res://data/content/waves/m0_wave.tres
enemy_scene: res://scenes/enemies/Enemy.tscn
```

- [ ] **Step 4: Run parse check**

```powershell
godot --headless --path . --script res://tests/smoke/parse_all_scripts.gd
```

Expected: `PASS: all scripts loaded`.

- [ ] **Step 5: Manual smoke test**

Press Play and verify:

```text
Enemies appear around the player within 2 seconds.
Enemies move toward the player.
Debug overlay enemy count increases and respects max_alive.
Player can still move while enemies spawn.
```

- [ ] **Step 6: Commit**

```powershell
git add scripts/enemies/Enemy.gd scripts/systems/SpawnSystem.gd scenes/enemies/Enemy.tscn scenes/run/RunScene.tscn
git commit -m "feat: add m0 enemy spawning and chase"
```

### Task 8: Weapon Controller, Projectile, and Damage System

**Files:**
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/autoload/DamageSystem.gd`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scripts/weapons/WeaponController.gd`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scripts/projectiles/Projectile.gd`
- Modify: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/project.godot`
- Modify: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scripts/player/Player.gd`
- Modify: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scenes/projectiles/Projectile.tscn`
- Modify: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scenes/weapons/WeaponController.tscn`
- Modify: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scenes/player/Player.tscn`
- Test: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/tests/smoke/parse_all_scripts.gd`

- [ ] **Step 1: Implement DamageSystem**

Create `autoload/DamageSystem.gd`:

```gdscript
extends Node

func apply_damage(target: Node, amount: float, tags: Array[String], payload: Dictionary = {}) -> void:
	if target == null or not target.has_method("apply_damage"):
		return
	target.apply_damage(amount, tags)
	GameEvents.weapon_hit.emit(target, payload)
```

Register it in `project.godot`:

```ini
DamageSystem="*res://autoload/DamageSystem.gd"
```

- [ ] **Step 2: Implement projectile behavior**

Create `scripts/projectiles/Projectile.gd`:

```gdscript
class_name Projectile
extends Area2D

var velocity: Vector2 = Vector2.ZERO
var damage: float = 1.0
var tags: Array[String] = []
var lifetime: float = 1.0
var remaining_pierce: int = 0
var payload: Dictionary = {}

func configure(direction: Vector2, speed: float, new_damage: float, new_lifetime: float, new_pierce: int, new_tags: Array[String], new_payload: Dictionary) -> void:
	velocity = direction.normalized() * speed
	damage = new_damage
	lifetime = new_lifetime
	remaining_pierce = new_pierce
	tags = new_tags.duplicate()
	payload = new_payload.duplicate()

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	global_position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	DamageSystem.apply_damage(target, damage, tags, payload)
	if remaining_pierce <= 0:
		queue_free()
	else:
		remaining_pierce -= 1
```

- [ ] **Step 3: Implement WeaponController**

Create `scripts/weapons/WeaponController.gd`:

```gdscript
class_name WeaponController
extends Node2D

@export var weapon_data: WeaponData
@export var projectile_scene: PackedScene = preload("res://scenes/projectiles/Projectile.tscn")
@export var projectiles_path: NodePath
@export var enemies_path: NodePath

var owner_player: Player
var cooldown_remaining: float = 0.0
var damage_multiplier: float = 1.0
var cooldown_multiplier: float = 1.0

func configure(player: Player, data: WeaponData) -> void:
	owner_player = player
	weapon_data = data

func _process(delta: float) -> void:
	if GameRuntime.state != GameRuntime.RunState.PLAYING or weapon_data == null:
		return
	cooldown_remaining -= delta
	if cooldown_remaining <= 0.0:
		var target := _find_nearest_enemy()
		if target != null:
			_fire_at(target)
			cooldown_remaining = weapon_data.cooldown * owner_player.cooldown_multiplier

func _find_nearest_enemy() -> Node2D:
	var enemies := get_node_or_null(enemies_path)
	if enemies == null:
		return null
	var nearest: Node2D = null
	var nearest_distance := INF
	for child in enemies.get_children():
		if child is Node2D:
			var distance := global_position.distance_to(child.global_position)
			if distance < nearest_distance and distance <= weapon_data.range:
				nearest = child
				nearest_distance = distance
	return nearest

func _fire_at(target: Node2D) -> void:
	var projectiles := get_node_or_null(projectiles_path)
	if projectiles == null:
		return
	var direction := global_position.direction_to(target.global_position)
	var projectile := projectile_scene.instantiate() as Projectile
	projectile.global_position = global_position
	var final_damage := weapon_data.damage * owner_player.damage_multiplier
	var tags := weapon_data.tags.duplicate()
	tags.append_array(weapon_data.element_tags)
	var payload := {"weapon_id": weapon_data.id, "weapon_tags": weapon_data.tags, "element_tags": weapon_data.element_tags}
	projectile.configure(direction, weapon_data.projectile_speed, final_damage, weapon_data.projectile_lifetime, weapon_data.pierce, tags, payload)
	projectiles.add_child(projectile)
```

- [ ] **Step 4: Mount weapon from Player**

Add to `Player.gd`:

```gdscript
const WEAPON_CONTROLLER_SCENE := preload("res://scenes/weapons/WeaponController.tscn")

func _apply_character_data() -> void:
	health_component.configure(character_data.max_health)
	damage_multiplier = character_data.damage_multiplier
	cooldown_multiplier = character_data.cooldown_multiplier
	pickup_radius = character_data.pickup_radius
	if character_data.starting_weapon != null:
		var weapon := WEAPON_CONTROLLER_SCENE.instantiate() as WeaponController
		weapon.configure(self, character_data.starting_weapon)
		weapon.projectiles_path = ^"../../../Projectiles"
		weapon.enemies_path = ^"../../../Enemies"
		weapon_mount.add_child(weapon)
```

- [ ] **Step 5: Attach scripts and collision layers**

Attach `Projectile.gd` to `Projectile.tscn`, `WeaponController.gd` to `WeaponController.tscn`, and set projectile `Area2D` to detect enemy hitbox areas. Keep M0 collision simple:

```text
Projectile Area2D monitoring: true
Enemy HitboxComponent Area2D monitorable: true
Projectile collision mask includes Enemy HitboxComponent layer
```

- [ ] **Step 6: Run parse check and manual combat test**

```powershell
godot --headless --path . --script res://tests/smoke/parse_all_scripts.gd
```

Manual expected result:

```text
Rune Bolt projectiles fire automatically at the nearest enemy.
Enemy HP decreases when projectile collides.
Enemy disappears when HP reaches zero.
Kill count increases after enemy death.
```

- [ ] **Step 7: Commit**

```powershell
git add autoload/DamageSystem.gd project.godot scripts/weapons/WeaponController.gd scripts/projectiles/Projectile.gd scripts/player/Player.gd scenes/projectiles/Projectile.tscn scenes/weapons/WeaponController.tscn scenes/player/Player.tscn
git commit -m "feat: add weapon projectile damage loop"
```

### Task 9: Experience Drops, Collection, and Level-Up Three Choices

**Files:**
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/autoload/ExperienceSystem.gd`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/autoload/UpgradeSystem.gd`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scripts/systems/DropSystem.gd`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scripts/pickups/ExperiencePickup.gd`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scripts/ui/LevelUpPanel.gd`
- Modify: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/project.godot`
- Modify: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scenes/run/RunScene.tscn`
- Modify: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scenes/pickups/ExperiencePickup.tscn`
- Modify: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scenes/ui/LevelUpPanel.tscn`
- Modify: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scripts/run/RunScene.gd`
- Test: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/tests/smoke/parse_all_scripts.gd`

- [ ] **Step 1: Implement ExperienceSystem**

Create `autoload/ExperienceSystem.gd`:

```gdscript
extends Node

var level: int = 1
var experience: int = 0
var next_level_experience: int = 5

func _ready() -> void:
	GameEvents.experience_collected.connect(add_experience)

func reset() -> void:
	level = 1
	experience = 0
	next_level_experience = 5
	GameEvents.level_changed.emit(level)

func add_experience(amount: int) -> void:
	experience += amount
	while experience >= next_level_experience:
		experience -= next_level_experience
		level += 1
		next_level_experience += 5
		GameEvents.level_changed.emit(level)
		GameRuntime.enter_level_up()
		GameEvents.level_up_requested.emit(UpgradeSystem.generate_options())
```

- [ ] **Step 2: Implement UpgradeSystem**

Create `autoload/UpgradeSystem.gd`:

```gdscript
extends Node

const OPTIONS: Array[Resource] = [
	preload("res://data/content/upgrades/damage_focus.tres"),
	preload("res://data/content/upgrades/cooldown_focus.tres"),
	preload("res://data/content/upgrades/pickup_focus.tres")
]

func generate_options() -> Array[Resource]:
	return OPTIONS.duplicate()

func apply_upgrade(upgrade: UpgradeData, player: Player) -> void:
	if upgrade.upgrade_type == "weapon_stat":
		player.apply_upgrade_stat(upgrade.stat_key, upgrade.value)
	elif upgrade.upgrade_type == "player_stat":
		player.apply_upgrade_stat(upgrade.stat_key, upgrade.value)
	GameEvents.upgrade_selected.emit(upgrade)
	GameRuntime.resume_from_level_up()
```

Register both autoloads in `project.godot` after `DamageSystem`:

```ini
ExperienceSystem="*res://autoload/ExperienceSystem.gd"
UpgradeSystem="*res://autoload/UpgradeSystem.gd"
```

- [ ] **Step 3: Implement DropSystem and pickup**

Create `scripts/systems/DropSystem.gd`:

```gdscript
class_name DropSystem
extends Node

@export var pickup_scene: PackedScene = preload("res://scenes/pickups/ExperiencePickup.tscn")
@export var pickups_path: NodePath
@export var player_path: NodePath

func _ready() -> void:
	GameEvents.enemy_died.connect(_on_enemy_died)

func _on_enemy_died(enemy: Node, experience_value: int) -> void:
	var pickups := get_node_or_null(pickups_path)
	var player := get_node_or_null(player_path) as Player
	if pickups == null or player == null or not enemy is Node2D:
		return
	var pickup := pickup_scene.instantiate() as ExperiencePickup
	pickup.global_position = enemy.global_position
	pickup.amount = experience_value
	pickup.configure_player(player)
	pickups.add_child(pickup)
```

Create `scripts/pickups/ExperiencePickup.gd`:

```gdscript
class_name ExperiencePickup
extends Area2D

@export var amount: int = 1
@export var magnet_speed: float = 420.0

var player: Player

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func configure_player(new_player: Player) -> void:
	player = new_player

func _process(delta: float) -> void:
	if player == null:
		return
	var distance := global_position.distance_to(player.global_position)
	if distance <= player.pickup_radius:
		global_position = global_position.move_toward(player.global_position, magnet_speed * delta)

func _on_area_entered(area: Area2D) -> void:
	if area.get_parent() is Player:
		GameEvents.experience_collected.emit(amount)
		queue_free()
```

- [ ] **Step 4: Implement level-up panel**

Create `scripts/ui/LevelUpPanel.gd`:

```gdscript
class_name LevelUpPanel
extends Control

@export var player_path: NodePath
@onready var options_container: VBoxContainer = $Panel/Options

var current_options: Array[Resource] = []

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameEvents.level_up_requested.connect(_show_options)

func _show_options(options: Array[Resource]) -> void:
	current_options = options
	for child in options_container.get_children():
		child.queue_free()
	for option in current_options:
		var button := Button.new()
		button.text = "%s - %s" % [option.display_name, option.description]
		button.pressed.connect(_select_option.bind(option))
		options_container.add_child(button)
	visible = true

func _select_option(option: UpgradeData) -> void:
	var player := get_node(player_path) as Player
	UpgradeSystem.apply_upgrade(option, player)
	visible = false
```

- [ ] **Step 5: Wire scene paths**

Set:

```text
RunScene/Systems/DropSystem script: res://scripts/systems/DropSystem.gd
DropSystem.pickups_path: ../../World/Pickups
DropSystem.player_path: ../../World/Player
ExperiencePickup script: res://scripts/pickups/ExperiencePickup.gd
LevelUpPanel script: res://scripts/ui/LevelUpPanel.gd
LevelUpPanel.player_path: ../../World/Player
```

In `RunScene.gd`, call:

```gdscript
func _ready() -> void:
	ExperienceSystem.reset()
	hud.bind_player(player)
	hud.bind_timer(run_timer)
	debug_overlay.enemies_path = ^"../../World/Enemies"
	debug_overlay.projectiles_path = ^"../../World/Projectiles"
	debug_overlay.pickups_path = ^"../../World/Pickups"
	GameRuntime.start_run()
```

- [ ] **Step 6: Run parse check and manual level-up test**

```powershell
godot --headless --path . --script res://tests/smoke/parse_all_scripts.gd
```

Manual expected result:

```text
Enemies drop experience pickups.
Pickups move toward the player inside pickup radius.
Collecting enough pickups pauses gameplay and opens three level-up choices.
Selecting Sharpened Rune Bolt increases damage.
Selecting Faster Inscription reduces cooldown.
Selecting Wider Rune Sense increases pickup radius.
Gameplay resumes after one choice.
```

- [ ] **Step 7: Commit**

```powershell
git add autoload/ExperienceSystem.gd autoload/UpgradeSystem.gd project.godot scripts/systems/DropSystem.gd scripts/pickups/ExperiencePickup.gd scripts/ui/LevelUpPanel.gd scripts/run/RunScene.gd scenes/run/RunScene.tscn scenes/pickups/ExperiencePickup.tscn scenes/ui/LevelUpPanel.tscn
git commit -m "feat: add experience and level up loop"
```

### Task 10: Minimal Rune Interface and Element Trigger Chain

**Files:**
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/autoload/RuneSystem.gd`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/autoload/ElementStatusSystem.gd`
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scripts/components/StatusReceiver.gd`
- Modify: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/project.godot`
- Modify: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/autoload/DamageSystem.gd`
- Modify: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/autoload/UpgradeSystem.gd`
- Modify: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scripts/run/RunScene.gd`
- Modify: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scripts/enemies/Enemy.gd`
- Modify: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scenes/enemies/Enemy.tscn`
- Test: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/tests/smoke/parse_all_scripts.gd`

- [ ] **Step 1: Implement ElementStatusSystem**

Create `autoload/ElementStatusSystem.gd`:

```gdscript
extends Node

var stacks_by_target: Dictionary = {}

func add_stack(target: Node, element_tag: String, amount: int, duration_seconds: float = 5.0) -> int:
	if target == null:
		return 0
	if not stacks_by_target.has(target):
		stacks_by_target[target] = {}
	var element_map: Dictionary = stacks_by_target[target]
	var current: Dictionary = element_map.get(element_tag, {"stacks": 0, "duration": duration_seconds})
	current["stacks"] = int(current["stacks"]) + amount
	current["duration"] = duration_seconds
	element_map[element_tag] = current
	return int(current["stacks"])

func clear_stack(target: Node, element_tag: String) -> void:
	if stacks_by_target.has(target):
		var element_map: Dictionary = stacks_by_target[target]
		element_map.erase(element_tag)

func _process(delta: float) -> void:
	for target in stacks_by_target.keys():
		var element_map: Dictionary = stacks_by_target[target]
		for element_tag in element_map.keys():
			var current: Dictionary = element_map[element_tag]
			current["duration"] = float(current["duration"]) - delta
			if float(current["duration"]) <= 0.0:
				element_map.erase(element_tag)
```

- [ ] **Step 2: Implement RuneSystem**

Create `autoload/RuneSystem.gd`:

```gdscript
extends Node

var equipped_runes: Array[RuneData] = []
var cooldowns: Dictionary = {}

func equip_rune(rune: RuneData) -> void:
	if rune == null or equipped_runes.has(rune):
		return
	equipped_runes.append(rune)

func reset() -> void:
	equipped_runes.clear()
	cooldowns.clear()

func _ready() -> void:
	GameEvents.weapon_hit.connect(_on_weapon_hit)

func _process(delta: float) -> void:
	for key in cooldowns.keys():
		cooldowns[key] = max(0.0, float(cooldowns[key]) - delta)

func _on_weapon_hit(target: Node, payload: Dictionary) -> void:
	for rune in equipped_runes:
		if rune.trigger != "on_hit":
			continue
		if not _rune_applies(rune, payload):
			continue
		var cooldown_key := "%s:%s" % [rune.id, target.get_instance_id()]
		if float(cooldowns.get(cooldown_key, 0.0)) > 0.0:
			continue
		cooldowns[cooldown_key] = rune.internal_cooldown
		var stacks := ElementStatusSystem.add_stack(target, rune.element_tag, 1)
		if stacks >= rune.stack_threshold:
			ElementStatusSystem.clear_stack(target, rune.element_tag)
			if target.has_method("apply_damage"):
				target.apply_damage(rune.bonus_damage, [rune.element_tag, "rune_bonus"])
			GameEvents.rune_triggered.emit(rune.id, target, {"element": rune.element_tag, "stacks": stacks})

func _rune_applies(rune: RuneData, payload: Dictionary) -> bool:
	var weapon_tags: Array = payload.get("weapon_tags", [])
	for required_tag in rune.applies_to_weapon_tags:
		if weapon_tags.has(required_tag):
			return true
	return rune.applies_to_weapon_tags.is_empty()
```

Register both autoloads in `project.godot` before `ExperienceSystem`:

```ini
ElementStatusSystem="*res://autoload/ElementStatusSystem.gd"
RuneSystem="*res://autoload/RuneSystem.gd"
```

- [ ] **Step 3: Reset runes on run start**

In `scripts/run/RunScene.gd`, add only this line before `ExperienceSystem.reset()`:

```gdscript
RuneSystem.reset()
```

- [ ] **Step 4: Enable the rune upgrade option after RuneSystem exists**

Modify `autoload/UpgradeSystem.gd` so `OPTIONS` uses the M0 rune pick as the third choice:

```gdscript
const OPTIONS: Array[Resource] = [
	preload("res://data/content/upgrades/damage_focus.tres"),
	preload("res://data/content/upgrades/cooldown_focus.tres"),
	preload("res://data/content/upgrades/scorch_mark_pick.tres")
]
```

Modify `apply_upgrade()` to add the rune branch:

```gdscript
func apply_upgrade(upgrade: UpgradeData, player: Player) -> void:
	if upgrade.upgrade_type == "weapon_stat":
		player.apply_upgrade_stat(upgrade.stat_key, upgrade.value)
	elif upgrade.upgrade_type == "player_stat":
		player.apply_upgrade_stat(upgrade.stat_key, upgrade.value)
	elif upgrade.upgrade_type == "rune" and upgrade.rune != null:
		RuneSystem.equip_rune(upgrade.rune)
	GameEvents.upgrade_selected.emit(upgrade)
	GameRuntime.resume_from_level_up()
```

- [ ] **Step 5: Ensure damage event payload reaches RuneSystem**

Confirm `DamageSystem.apply_damage()` calls:

```gdscript
target.apply_damage(amount, tags)
GameEvents.weapon_hit.emit(target, payload)
```

- [ ] **Step 6: Attach StatusReceiver bridge**

Create `scripts/components/StatusReceiver.gd`:

```gdscript
class_name StatusReceiver
extends Node

func get_status_owner() -> Node:
	return get_parent()
```

Attach it to `Enemy/StatusReceiver`. This keeps a stable node for future status visuals while M0 stores status in `ElementStatusSystem`.

- [ ] **Step 7: Run parse check and manual rune-chain test**

```powershell
godot --headless --path . --script res://tests/smoke/parse_all_scripts.gd
```

Manual expected result:

```text
Pick Scorch Mark from the level-up panel.
Rune Bolt hits the same enemy three times.
On the third stack, the enemy takes bonus damage.
Console or debug output includes rune_triggered signal if temporarily connected for observation.
The weapon script did not need a Scorch Mark-specific branch.
```

- [ ] **Step 8: Commit**

```powershell
git add autoload/RuneSystem.gd autoload/ElementStatusSystem.gd autoload/DamageSystem.gd autoload/UpgradeSystem.gd project.godot scripts/components/StatusReceiver.gd scripts/enemies/Enemy.gd scripts/run/RunScene.gd scenes/enemies/Enemy.tscn
git commit -m "feat: add m0 rune and element trigger chain"
```

### Task 11: Contact Damage, Failure State, and Settlement Entry

**Files:**
- Modify: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scripts/enemies/Enemy.gd`
- Modify: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scripts/player/Player.gd`
- Modify: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scripts/ui/HUD.gd`
- Modify: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/scenes/enemies/Enemy.tscn`
- Test: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/tests/smoke/parse_all_scripts.gd`

- [ ] **Step 1: Add repeated enemy contact damage**

Add these fields to `Enemy.gd`:

```gdscript
@export var contact_interval: float = 0.6
var contact_cooldown: float = 0.0
var contact_targets: Array[Player] = []
```

Replace the existing `_physics_process()` in `Enemy.gd` with:

```gdscript
func _physics_process(delta: float) -> void:
	contact_cooldown = max(0.0, contact_cooldown - delta)
	if contact_cooldown <= 0.0 and not contact_targets.is_empty():
		for player in contact_targets:
			if is_instance_valid(player):
				player.take_contact_damage(enemy_data.contact_damage)
		contact_cooldown = contact_interval

	if GameRuntime.state != GameRuntime.RunState.PLAYING or target == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var direction := global_position.direction_to(target.global_position)
	velocity = direction * enemy_data.move_speed
	move_and_slide()
```

Connect `ContactArea.body_entered` and `ContactArea.body_exited` in the scene, then add:

```gdscript
func _on_contact_area_body_entered(body: Node2D) -> void:
	if body is Player and not contact_targets.has(body):
		contact_targets.append(body)

func _on_contact_area_body_exited(body: Node2D) -> void:
	if body is Player:
		contact_targets.erase(body)
```

- [ ] **Step 2: Display run result in HUD**

Add to `HUD.gd`:

```gdscript
func _ready() -> void:
	GameEvents.enemy_died.connect(_on_enemy_died)
	GameEvents.level_changed.connect(_on_level_changed)
	GameEvents.experience_collected.connect(_on_experience_collected)
	GameEvents.run_finished.connect(_on_run_finished)
	_on_level_changed(1)
	_on_experience_collected(0)
	_update_timer(0.0)
	kill_label.text = "Kills: 0"

func _on_run_finished(result: String) -> void:
	timer_label.text = "Run finished: %s" % result
```

- [ ] **Step 3: Confirm settlement entry is state-only in M0**

Do not create meta-progression UI in M0. Verify `GameRuntime.finish_run(result)` emits `run_finished` and pauses the tree. This is the M0 settlement entry point for later phases.

- [ ] **Step 4: Run parse check and manual failure test**

```powershell
godot --headless --path . --script res://tests/smoke/parse_all_scripts.gd
```

Manual expected result:

```text
Enemy contact reduces player HP.
When HP reaches zero, GameRuntime enters defeat state.
The tree pauses and HUD shows Run finished: defeat.
If the 180-second timer elapses, HUD shows Run finished: victory.
```

- [ ] **Step 5: Commit**

```powershell
git add scripts/enemies/Enemy.gd scripts/player/Player.gd scripts/ui/HUD.gd scenes/enemies/Enemy.tscn
git commit -m "feat: add contact damage and run finish states"
```

### Task 12: M0 Validation Checklist and Architecture Acceptance

**Files:**
- Create: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/docs/qa/m0-smoke-test.md`
- Modify: `C:/Users/19612/Documents/Codex/2026-05-03/new-chat/README.md`
- Test: full M0 CLI and manual smoke suite

- [ ] **Step 1: Create manual QA checklist**

Create `docs/qa/m0-smoke-test.md`:

```markdown
# M0 Smoke Test

Date:
Godot Version:
Tester:

## Automated Checks

- `godot --headless --path . --quit`:
- `godot --headless --path . --script res://tests/smoke/parse_all_scripts.gd`:
- `godot --headless --path . --script res://tests/smoke/load_core_scenes.gd`:

If the executable is `godot4`, record the same commands with `godot4`.

## Manual Checks

- [ ] Project opens in Godot 4 Editor.
- [ ] Pressing Play loads the run scene.
- [ ] Player moves with WASD.
- [ ] HUD shows HP, level, XP, time, and kills.
- [ ] Debug overlay shows FPS, enemies, projectiles, and pickups.
- [ ] Enemies spawn around the player and chase.
- [ ] Rune Bolt fires automatically at the nearest enemy.
- [ ] Projectiles damage enemies.
- [ ] Dead enemies drop experience pickups.
- [ ] Experience pickups collect into the player.
- [ ] Level-up opens three choices and pauses gameplay.
- [ ] Selecting a weapon stat upgrade changes combat behavior.
- [ ] Selecting Scorch Mark equips a rune.
- [ ] Scorch Mark triggers bonus damage after three stacks on a target.
- [ ] Enemy contact damages the player.
- [ ] Player death ends the run with defeat state.
- [ ] Timer completion ends the run with victory state.

## Architecture Acceptance

- [ ] Adding a new weapon can start from a new `WeaponData` Resource and `WeaponController` behavior, without editing `Player.gd`.
- [ ] Adding a new basic enemy can start from a new `EnemyData` Resource, without editing `DamageSystem.gd`.
- [ ] Adding a new rune can start from a new `RuneData` Resource and `RuneSystem` effect branch, without editing projectile firing logic.
- [ ] Run state transitions are centralized in `GameRuntime.gd`.
- [ ] Entity scripts do not own global progression, upgrade, rune, or spawn state.

## Remaining Risks

Record only verified issues observed during this test pass.
```

- [ ] **Step 2: Run full automated validation if Godot CLI exists**

Use `godot` or `godot4`, matching the executable found in Task 1:

```powershell
godot --headless --path . --quit
godot --headless --path . --script res://tests/smoke/parse_all_scripts.gd
godot --headless --path . --script res://tests/smoke/load_core_scenes.gd
```

Expected:

```text
Project check exits with code 0.
parse_all_scripts prints PASS: all scripts loaded.
load_core_scenes prints PASS: core scenes and resources loaded.
```

- [ ] **Step 3: Run manual smoke test**

Open Godot 4 Editor, press Play, complete every checklist item in `docs/qa/m0-smoke-test.md`, and fill in command results exactly as observed.

- [ ] **Step 4: Update README with final M0 validation**

Append:

```markdown
## M0 Acceptance

M0 is accepted when:

- Godot opens the project and runs `scenes/Main.tscn`.
- The minimum combat loop works: move, spawn, chase, auto-fire, hit, kill, drop XP, collect XP, level up, choose upgrade, resume.
- Scorch Mark demonstrates one rune and element trigger chain.
- Debug overlay reports FPS and object counts.
- Run finish states exist for defeat and timer victory.
```

- [ ] **Step 5: Commit**

```powershell
git add docs/qa/m0-smoke-test.md README.md
git commit -m "docs: add m0 validation checklist"
```

---

## Final M0 Acceptance Checklist

- [ ] Godot 4 project opens from `C:/Users/19612/Documents/Codex/2026-05-03/new-chat`.
- [ ] CLI validation is run with `godot` or `godot4`, or manual fallback is documented when no CLI is installed.
- [ ] `parse_all_scripts.gd` passes.
- [ ] `load_core_scenes.gd` passes.
- [ ] Player movement, health, damage, and death work.
- [ ] One character loads through `CharacterData`.
- [ ] One weapon loads through `WeaponData` and auto-attacks.
- [ ] One enemy loads through `EnemyData`, spawns from `WaveData`, chases, takes damage, dies, and drops XP.
- [ ] XP pickup and level-up three-choice entry work.
- [ ] One `RuneData` option can be equipped.
- [ ] One element/status trigger chain can be reproduced: hit applies stack, stack threshold triggers bonus effect.
- [ ] Debug overlay displays FPS, enemy count, projectile count, and pickup count.
- [ ] Run state is centralized in `GameRuntime`.
- [ ] No networking, multiplayer, Steam SDK, payment, account, ranking, complex story, second map, full commercial art pass, or complete commercial Demo content is included.

## Self-Review

- Spec coverage: The plan covers the M0 requirements from the design spec: Godot 4 structure, Scene + Resource loading, player movement/health/death, one character, one weapon, one enemy, one wave, one rune, one element trigger chain, basic runtime state, basic timer/wave flow, level-up entry, debug overlay, and validation. Full Demo targets such as two characters, four weapons, twelve runes, seven enemies, Boss, elite event, 18-minute commercial pacing, second-stage content fill, audio polish, and meta-progression UI are intentionally excluded from M0.
- Red-flag scan: The plan has no empty sections, deferred-detail markers, or vague implementation steps. Temporary visual work is described as primitive editor shapes with stable node names, not as a content deliverable.
- File ownership: Tasks are split by system boundary. Shared files touched by multiple tasks are `project.godot`, `RunScene.tscn`, `RunScene.gd`, `Player.gd`, `Enemy.gd`, and `HUD.gd`; each later task lists its exact modifications and does not require reverting earlier work.
- Subagent readiness: Each task has bounded files, checkbox steps, validation commands, expected results, and a commit point. A fresh subagent can execute one task without needing to plan the whole project.
- Revision review: Task 9 no longer depends on `RuneSystem`; it validates three stat-based choices and moves rune equip behavior into Task 10 after `RuneSystem` exists. `DropSystem` now owns `player_path` and calls `pickup.configure_player(player)`. Task 10 lists both `autoload/UpgradeSystem.gd` and `scripts/run/RunScene.gd` in its file boundary. Task 3 and Task 4 now provide exact Godot headless generation scripts with editor fallback paths. Task 11 now tracks overlapping player bodies and applies contact damage repeatedly on `contact_interval`.
